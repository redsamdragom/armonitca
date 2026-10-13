-- Armas: estadísticas efectivas y patrones de ataque (ver Data/Weapons.luau).
-- Las colisiones de ataques persistentes usan intervalos por enemigo (`rehit`) para que el DPS no
-- dependa de los FPS.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Ground = require(script.Parent.Parent.World.Ground)
local Fx = require(script.Parent.Fx)
local Damage = require(script.Parent.Damage)
local Status = require(script.Parent.Status)

local Weapons = {}

local KNOCKBACK_SCALE = 10 -- studs/s por unidad de retroceso [Pendiente]
local BURST_INTERVAL = 0.1 -- separación entre disparos sucesivos de una ráfaga [Pendiente]
local DICE_SCALE = 3.5 -- [Pendiente]
local FLAT = Vector3.new(1, 0, 1)
local CYLINDER_UP = CFrame.Angles(0, 0, math.pi / 2)

local function color(def)
	return Color3.fromRGB(def.color[1], def.color[2], def.color[3])
end

function Weapons.new(id: string)
	local def = Catalog.Weapon[id]
	assert(def, "arma desconocida " .. id)
	return {
		id = id,
		def = def,
		level = 1,
		bonus = {},
		stats = {},
		timer = 0.3,
		queue = {},
		state = {},
		diceCrit = 0,
		color = color(def),
	}
end

function Weapons.maxLevel(session): number
	return Config.Slots.WeaponMaxLevel + session.weaponLevelBonus
end

-- Estadísticas efectivas del arma: base + mejoras propias + estadísticas globales compatibles.
function Weapons.compute(session, w)
	local def, base, b, g = w.def, w.def.base, w.bonus, session.stats
	local st = w.stats
	st.Damage = (base.Damage or 0) + (b.Damage or 0)
	local quantity = if def.globalQuantity == false then 0 else g.Quantity
	st.Count = math.max(1, math.floor((base.Count or 1) + (b.Count or 0) + quantity + 1e-6))
	st.Bounces = math.floor((base.Bounces or 0) + (b.Bounces or 0) + g.Bounces + 1e-6)
	st.Size = (base.Size or 1) * (1 + (b.Size or 0)) * (1 + g.Size)
	st.Duration = ((base.Duration or 0) + (b.Duration or 0)) * (1 + g.Duration)
	local attackSpeed = 1 + g.AttackSpeed + session.tempAttackSpeed + session.passiveAttackSpeed
	st.Cooldown = (base.Cooldown or 1) / math.max(0.1, attackSpeed)
	st.ProjectileSpeed = ((base.ProjectileSpeed or 1) + (b.ProjectileSpeed or 0)) * (def.speedScale or 40) * (1 + g.ProjectileSpeed)
	st.Knockback = ((base.Knockback or 0) + (b.Knockback or 0)) * KNOCKBACK_SCALE
	st.CritChance = (base.CritChance or 0) + (b.CritChance or 0) + w.diceCrit
	st.CritDamage = (base.CritDamage or 0) + (b.CritDamage or 0)
end

local function hit(session, w, enemy, amount: number, direction: Vector3?, extra: any?)
	local info = {
		source = "weapon:" .. w.id,
		weapon = w,
		amount = amount,
		procCoef = w.def.procCoef or 1,
		element = w.def.element,
		knockback = if direction and w.stats.Knockback > 0 then direction * w.stats.Knockback else nil,
	}
	if extra then
		for k, v in extra do
			info[k] = v
		end
	end
	return Damage.toEnemy(session, enemy, info)
end

local function flatDir(v: Vector3): Vector3
	local f = v * FLAT
	if f.Magnitude < 0.01 then
		return Vector3.zAxis
	end
	return f.Unit
end

local function facing(session): Vector3
	return flatDir(session.root.CFrame.LookVector)
end

local function target(session, w, range: number)
	local rootPos = session.root.Position
	local targeting = w.def.targeting or "nearest"
	if targeting == "random" then
		return session.enemies:random(rootPos, range)
	end
	return (session.enemies:nearest(rootPos, range))
end

local function schedule(w, at: number, fn)
	table.insert(w.queue, { at = at, fn = fn })
end

-- Proyectiles ------------------------------------------------------------------------------

local function spawnProjectile(session, w, origin: Vector3, direction: Vector3, opts)
	local def, st, params = w.def, w.stats, w.def.params or {}
	local radius = (params.width or 1) * 0.8 * st.Size
	local part = Fx.acquire(
		if params.spin then "Block" else "Ball",
		w.color,
		if params.spin then Vector3.new(radius * 2.4, 0.4, radius * 1.2) else Vector3.one * math.max(0.6, radius * 1.4)
	)
	part.Position = origin
	local p = {
		w = w,
		part = part,
		pos = origin,
		dir = direction.Unit,
		speed = st.ProjectileSpeed,
		radius = radius,
		pierce = params.pierce or 1,
		bounces = st.Bounces,
		hit = {},
		rehit = params.rehit,
		hitTimes = {},
		travel = 0,
		range = params.range or 60,
		homing = params.homing,
		target = opts and opts.target,
		boomerang = params.boomerang,
		returning = false,
		explode = params.explode,
		spin = params.spin,
		life = if st.Duration > 0 and params.spin then st.Duration else nil,
		damageMult = opts and opts.damageMult or 1,
	}
	if params.lob and opts and opts.landAt then
		p.lob = { from = origin, to = opts.landAt, t = 0, duration = math.max(0.35, (opts.landAt - origin).Magnitude / st.ProjectileSpeed) }
	end
	table.insert(session.projectiles, p)
	session:addCounter("projectiles", 1)
	return p
end

local function explode(session, w, position: Vector3, radius: number, amount: number)
	Fx.flash("Ball", CFrame.new(position), Vector3.one * radius * 2, w.color, 0.18, 0.5)
	for _, enemy in session.enemies:query(position, radius) do
		local dir = flatDir(enemy.pos - position)
		hit(session, w, enemy, amount, dir)
		if w.def.params and w.def.params.poison then
			Status.poison(session, enemy, w.def.params.poison, "weapon:" .. w.id)
		end
	end
end

local function projectileDamage(session, w, p): number
	if w.def.params and w.def.params.dice then
		local roll = session.rng:NextInteger(1, 6)
		if roll == 6 then
			w.diceCrit += 0.005
			Weapons.compute(session, w)
		end
		-- La referencia documenta un resultado inicial de 1 a 6; la escala respecto a las demás
		-- armas no está documentada: DICE_SCALE es [Pendiente].
		return (roll * DICE_SCALE + w.stats.Damage) * p.damageMult
	end
	return w.stats.Damage * p.damageMult
end

local function fireProjectileWeapon(session, w)
	local def, st, params = w.def, w.stats, w.def.params or {}
	local root = session.root
	local range = params.range or 60
	local origin = root.Position + Vector3.new(0, 0.5, 0)

	if def.targeting == "aim" then
		local dir = session.aimDir
		local count = st.Count
		if params.pellets then
			-- Escopeta: todos los perdigones a la vez en cono
			for i = 1, count do
				local spread = math.rad(params.spread or 25)
				local yaw = (session.rng:NextNumber() - 0.5) * spread
				local pitch = (session.rng:NextNumber() - 0.5) * spread * 0.3
				spawnProjectile(session, w, origin, (CFrame.lookAt(Vector3.zero, dir) * CFrame.Angles(pitch, yaw, 0)).LookVector)
			end
		else
			for i = 1, count do
				schedule(w, session.time + (i - 1) * BURST_INTERVAL * 2, function()
					spawnProjectile(session, w, session.root.Position + Vector3.new(0, 0.5, 0), session.aimDir)
				end)
			end
		end
		return true
	end

	local first = target(session, w, range)
	if not first and not params.lob then
		return false
	end
	if params.lob and not first then
		return false
	end

	if params.spread then
		-- Abanico (Bow): todas las flechas a la vez
		local base = flatDir(first.pos - origin)
		local count = st.Count
		local spread = math.rad(params.spread)
		for i = 1, count do
			local offset = (i - (count + 1) / 2) * spread
			local dir = (CFrame.Angles(0, offset, 0) * CFrame.lookAt(Vector3.zero, base)).LookVector
			spawnProjectile(session, w, origin, dir)
		end
		return true
	end

	for i = 1, st.Count do
		schedule(w, session.time + (i - 1) * BURST_INTERVAL, function()
			local from = session.root.Position + Vector3.new(0, 0.5, 0)
			local t = if i == 1 and first and not first.dead then first else target(session, w, range)
			if not t then
				return
			end
			if params.lob then
				spawnProjectile(session, w, from, t.pos - from, { landAt = Vector3.new(t.pos.X, t.groundY, t.pos.Z) })
			elseif params.spin and params.lobUp then
				-- Hacha: sale hacia arriba y gira en el sitio de forma persistente
				local dir = flatDir(t.pos - from)
				spawnProjectile(session, w, from, dir + Vector3.new(0, 0.15, 0))
			else
				spawnProjectile(session, w, from, t.pos - from, { target = t })
			end
		end)
	end
	return true
end

function Weapons.stepProjectiles(session, dt: number)
	local list = session.projectiles
	local now = session.time
	local parts, cframes = {}, {}
	for i = #list, 1, -1 do
		local p = list[i]
		local w = p.w
		local finished = false

		if p.lob then
			local lob = p.lob
			lob.t += dt / lob.duration
			local t = math.min(1, lob.t)
			local flat = lob.from:Lerp(lob.to, t)
			p.pos = flat + Vector3.new(0, math.sin(t * math.pi) * 10, 0)
			if t >= 1 then
				explode(session, w, lob.to, (p.explode or 4) * w.stats.Size, projectileDamage(session, w, p))
				finished = true
			end
		else
			if p.homing and (not p.target or p.target.dead) then
				p.target = session.enemies:nearest(p.pos, 40, p.hit)
			end
			if p.homing and p.target then
				local desired = (p.target.pos - p.pos).Unit
				p.dir = p.dir:Lerp(desired, math.min(1, p.homing * dt)).Unit
			end
			if p.boomerang then
				if not p.returning and p.travel >= p.boomerang then
					p.returning = true
					table.clear(p.hitTimes)
				end
				if p.returning then
					local back = session.root.Position - p.pos
					if back.Magnitude < 2.5 then
						finished = true
					else
						p.dir = back.Unit
					end
				end
			end
			local step = p.speed * dt
			if p.spin and p.life then
				-- Persistente: avanza decelerando y gira
				step *= math.max(0.15, p.life / math.max(0.1, w.stats.Duration))
			end
			p.pos += p.dir * step
			p.travel += step
			if p.life then
				p.life -= dt
				if p.life <= 0 then
					finished = true
				end
			elseif not p.boomerang and p.travel >= p.range then
				finished = true
			end

			if not finished then
				for _, enemy in session.enemies:query(p.pos, p.radius) do
					local canHit
					if p.rehit then
						local last = p.hitTimes[enemy]
						canHit = not last or now - last >= p.rehit
					else
						canHit = not p.hit[enemy]
					end
					if canHit then
						p.hit[enemy] = true
						p.hitTimes[enemy] = now
						if p.explode then
							explode(session, w, p.pos, p.explode * w.stats.Size, projectileDamage(session, w, p))
							finished = true
							break
						end
						hit(session, w, enemy, projectileDamage(session, w, p), p.dir, {
							executeChance = w.def.params and w.def.params.execute,
						})
						if not p.rehit then
							p.pierce -= 1
							if p.pierce <= 0 then
								if p.bounces > 0 then
									local nextTarget = session.enemies:nearest(p.pos, 25, p.hit)
									if nextTarget then
										p.bounces -= 1
										p.pierce = 1
										p.dir = (nextTarget.pos - p.pos).Unit
										p.target = nextTarget
										p.travel = math.max(0, p.range - 30)
									else
										finished = true
									end
								else
									finished = true
								end
								break
							end
						end
					end
				end
			end
		end

		if finished then
			Fx.release(p.part)
			list[i] = list[#list]
			list[#list] = nil
		else
			table.insert(parts, p.part)
			local cf = CFrame.lookAt(p.pos, p.pos + p.dir)
			if p.spin then
				cf *= CFrame.Angles(0, now * 18, 0)
			end
			table.insert(cframes, cf)
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

-- Cuerpo a cuerpo ---------------------------------------------------------------------------

local function swing(session, w, direction: Vector3, damageMult: number, big: boolean?)
	local params, st = w.def.params, w.stats
	local rootPos = session.root.Position
	local range = params.range * st.Size * (if big then 1.5 else 1)
	local arc = math.rad(params.arc)
	local amount = st.Damage * damageMult
	if params.lowHpBonus then
		local ratio = math.clamp(session.health / session.stats.MaxHealth, 0, 1)
		amount *= 1 + params.lowHpBonus * (1 - ratio)
	end
	for _, enemy in session.enemies:query(rootPos, range) do
		local to = flatDir(enemy.pos - rootPos)
		if params.arc >= 360 or math.acos(math.clamp(to:Dot(direction), -1, 1)) <= arc / 2 then
			hit(session, w, enemy, amount, to)
		end
	end
	-- Visual
	local col = if big then Color3.fromRGB(255, 80, 80) else w.color
	if params.arc >= 360 then
		Fx.ring(rootPos - Vector3.new(0, 1.5, 0), range, col, 0.15)
	else
		local cf = CFrame.lookAt(rootPos, rootPos + direction) * CFrame.new(0, 0, -range / 2)
		Fx.flash("Block", cf, Vector3.new(range * math.sin(math.min(arc, math.pi) / 2) * 2, 0.3, range), col, 0.12, 0.45)
	end
	if params.wave then
		local p = spawnProjectile(session, w, rootPos, direction)
		p.pierce, p.range, p.damageMult = 999, 40, 0.7
	end
	if params.back then
		local p = spawnProjectile(session, w, rootPos, -direction)
		p.pierce, p.range, p.damageMult = 999, 55, 0.6
	end
end

local function fireMelee(session, w)
	local params = w.def.params
	local first = nil
	if w.def.targeting == "nearest" then
		first = session.enemies:nearest(session.root.Position, params.range * w.stats.Size * 3)
		if not first then
			return false
		end
	elseif #session.enemies:query(session.root.Position, params.range * w.stats.Size * 1.5) == 0 then
		return false
	end
	for i = 1, w.stats.Count do
		schedule(w, session.time + (i - 1) * 0.15, function()
			local dir
			if first and not first.dead then
				dir = flatDir(first.pos - session.root.Position)
			else
				dir = facing(session)
			end
			if i % 2 == 0 and w.def.targeting == "facing" then
				dir = -dir -- los tajos extra alternan delante/detrás [Pendiente]
			end
			local big = false
			if params.eliteCharge and (w.state.charge or 0) >= params.eliteCharge then
				w.state.charge = 0
				big = true
			end
			swing(session, w, dir, if big then 3 else 1, big)
		end)
	end
	return true
end

-- Rayo / área instantánea --------------------------------------------------------------------

local function fireStrike(session, w)
	local params, st = w.def.params, w.stats
	local struck = {}
	local any = false
	for _ = 1, st.Count do
		local t = if w.def.targeting == "nearest"
			then session.enemies:nearest(session.root.Position, params.range, struck)
			else session.enemies:random(session.root.Position, params.range)
		if not t then
			break
		end
		any = true
		local current = t
		local radius = params.radius * st.Size
		Fx.beam(current.pos + Vector3.new(0, 40, 0), current.pos, 0.6, w.color, 0.12)
		for chain = 0, st.Bounces do
			struck[current] = true
			Fx.ring(current.pos, radius, w.color, 0.15)
			for _, enemy in session.enemies:query(current.pos, radius) do
				hit(session, w, enemy, st.Damage, nil)
			end
			if chain < st.Bounces then
				local nextTarget = session.enemies:nearest(current.pos, 18, struck)
				if not nextTarget then
					break
				end
				Fx.beam(current.pos, nextTarget.pos, 0.4, w.color, 0.12)
				current = nextTarget
			end
		end
	end
	return any
end

-- Zonas genéricas (rastros, minas, campos, nubes, curación) ----------------------------------

function Weapons.addZone(session, zone)
	table.insert(session.zones, zone)
	return zone
end

function Weapons.stepZones(session, dt: number)
	local now = session.time
	local zones = session.zones
	for i = #zones, 1, -1 do
		local z = zones[i]
		local done = now >= z.untilTime
		if not done and z.step then
			done = z.step(z, dt) == true
		end
		if not done and z.tick and now >= z.nextTick then
			z.nextTick = now + z.tick
			done = z.onTick(z) == true
		end
		if done then
			if z.part then
				if z.pooled then
					Fx.release(z.part)
				else
					z.part:Destroy()
				end
			end
			if z.onEnd then
				z.onEnd(z)
			end
			zones[i] = zones[#zones]
			zones[#zones] = nil
		end
	end
end

local function zonePart(position: Vector3, radius: number, col: Color3, transparency: number)
	local part = Fx.acquire("Cylinder", col, Vector3.new(0.3, radius * 2, radius * 2))
	part.Transparency = transparency
	part.CFrame = CFrame.new(position) * CYLINDER_UP
	return part
end

local function groundAt(position: Vector3): Vector3
	return Vector3.new(position.X, Ground.height(position, position.Y - 3) + 0.2, position.Z)
end

local function fireTrail(session, w)
	local st, params = w.stats, w.def.params
	local rootPos = session.root.Position
	local last = w.state.lastDrop
	if last and (rootPos - last).Magnitude < 2 then
		return true
	end
	w.state.lastDrop = rootPos
	for i = 1, st.Count do
		local offset = if i == 1 then Vector3.zero else Vector3.new(session.rng:NextNumber(-3, 3), 0, session.rng:NextNumber(-3, 3))
		local pos = groundAt(rootPos + offset)
		local radius = params.radius * st.Size
		Weapons.addZone(session, {
			pos = pos,
			radius = radius,
			untilTime = session.time + math.max(0.3, st.Duration),
			tick = params.tick,
			nextTick = session.time,
			part = zonePart(pos, radius, w.color, 0.45),
			pooled = true,
			onTick = function(z)
				for _, enemy in session.enemies:query(z.pos, z.radius) do
					hit(session, w, enemy, st.Damage, nil)
				end
			end,
		})
	end
	return true
end

local function fireMines(session, w)
	local st, params = w.stats, w.def.params
	for _ = 1, st.Count do
		local offset = Vector3.new(session.rng:NextNumber(-6, 6), 0, session.rng:NextNumber(-6, 6))
		local pos = groundAt(session.root.Position + offset)
		local part = Fx.acquire("Cylinder", w.color, Vector3.new(0.6, 2, 2))
		part.CFrame = CFrame.new(pos) * CYLINDER_UP
		local armedAt = session.time + 0.4
		Weapons.addZone(session, {
			pos = pos,
			untilTime = session.time + st.Duration,
			part = part,
			pooled = true,
			step = function(z)
				if session.time < armedAt then
					return false
				end
				if #session.enemies:query(z.pos, params.trigger) > 0 then
					explode(session, w, z.pos, params.radius * st.Size, st.Damage)
					return true
				end
				return false
			end,
		})
	end
	return true
end

local function fireField(session, w)
	local st, params = w.stats, w.def.params
	for i = 1, st.Count do
		local radius = params.radius * st.Size
		local center
		local velocity = Vector3.zero
		if params.mode == "pull" then
			local t = target(session, w, params.range or 35)
			if not t then
				return i > 1
			end
			center = t.pos
		else
			local angle = session.rng:NextNumber(0, math.pi * 2)
			center = session.root.Position
			velocity = Vector3.new(math.cos(angle), 0, math.sin(angle)) * st.ProjectileSpeed
		end
		local part = Fx.acquire("Ball", w.color, Vector3.one * radius * (if params.mode == "pull" then 0.6 else 1.2))
		part.Transparency = if params.mode == "pull" then 0.1 else 0.5
		part.Position = center
		Weapons.addZone(session, {
			pos = center,
			radius = radius,
			untilTime = session.time + st.Duration,
			tick = params.tick,
			nextTick = session.time,
			part = part,
			pooled = true,
			step = function(z, dt)
				if params.mode == "push" then
					if params.wander and session.rng:NextNumber() < dt * 0.8 then
						local a = session.rng:NextNumber(0, math.pi * 2)
						velocity = Vector3.new(math.cos(a), 0, math.sin(a)) * st.ProjectileSpeed
					end
					z.pos = groundAt(z.pos + velocity * dt) + Vector3.new(0, radius * 0.6, 0)
				end
				z.part.Position = z.pos
				for _, enemy in session.enemies:query(z.pos, radius * (if params.mode == "pull" then 1.8 else 1)) do
					if not (enemy.boss or enemy.miniboss) then
						local to = flatDir(z.pos - enemy.pos)
						if params.mode == "pull" then
							enemy.vel += to * 40 * dt
						else
							enemy.vel += -to * st.Knockback * 2 * dt
						end
					end
				end
				return false
			end,
			onTick = function(z)
				for _, enemy in session.enemies:query(z.pos, radius) do
					hit(session, w, enemy, st.Damage, nil)
				end
			end,
		})
	end
	return true
end

-- Haz y cono continuos ------------------------------------------------------------------------

local function segmentDistance(p: Vector3, a: Vector3, b: Vector3): number
	local ab = b - a
	local t = math.clamp((p - a):Dot(ab) / math.max(ab:Dot(ab), 1e-6), 0, 1)
	return (p - (a + ab * t)).Magnitude
end

local function fireBeam(session, w)
	local st, params = w.stats, w.def.params
	local t = session.enemies:nearest(session.root.Position, params.range)
	if not t then
		return false
	end
	local part = Fx.acquire("Block", w.color, Vector3.new(1, 1, 1))
	part.Transparency = 0.25
	local current = t
	Weapons.addZone(session, {
		untilTime = session.time + st.Duration,
		tick = params.tick,
		nextTick = session.time,
		part = part,
		pooled = true,
		step = function(z)
			if current.dead then
				current = session.enemies:nearest(session.root.Position, params.range)
				if not current then
					return true
				end
			end
			local from, to = session.root.Position, current.pos
			local width = params.width * st.Size
			local length = (to - from).Magnitude
			z.part.Size = Vector3.new(width * 0.5, width * 0.5, math.max(0.1, length))
			z.part.CFrame = CFrame.lookAt((from + to) / 2, to)
			z.from, z.to, z.width = from, to, width
			return false
		end,
		onTick = function(z)
			if not z.from then
				return
			end
			local mid = (z.from + z.to) / 2
			local half = (z.to - z.from).Magnitude / 2
			for _, enemy in session.enemies:query(mid, half + z.width) do
				if segmentDistance(enemy.pos, z.from, z.to) <= z.width + enemy.radius then
					hit(session, w, enemy, st.Damage, nil)
				end
			end
		end,
	})
	return true
end

local function fireCone(session, w)
	local st, params = w.stats, w.def.params
	if not session.enemies:nearest(session.root.Position, params.range * st.Size * 1.5) then
		return false
	end
	Weapons.addZone(session, {
		untilTime = session.time + st.Duration,
		tick = params.tick,
		nextTick = session.time,
		onTick = function()
			local rootPos = session.root.Position
			local range = params.range * st.Size
			local aim = session.enemies:nearest(rootPos, range * 1.5)
			local dir = if aim then flatDir(aim.pos - rootPos) else facing(session)
			local half = math.rad(params.angle) / 2
			for _, enemy in session.enemies:query(rootPos, range) do
				local to = flatDir(enemy.pos - rootPos)
				if math.acos(math.clamp(to:Dot(dir), -1, 1)) <= half then
					hit(session, w, enemy, st.Damage * params.tick, nil)
				end
			end
			local cf = CFrame.lookAt(rootPos, rootPos + dir) * CFrame.new(0, 0, -range / 2)
			Fx.flash("Block", cf, Vector3.new(range * math.tan(half) * 1.6, 1.2, range), w.color, params.tick, 0.5)
		end,
	})
	return true
end

-- Órbita --------------------------------------------------------------------------------------

local function fireOrbit(session, w)
	local st, params = w.stats, w.def.params
	local count = st.Count
	local parts = {}
	for i = 1, count do
		parts[i] = Fx.acquire("Ball", w.color, Vector3.one * 2.2 * st.Size, Enum.Material.Slate)
	end
	local start = session.time
	local duration = math.max(0.5, st.Duration)
	local hitTimes = {}
	Weapons.addZone(session, {
		untilTime = start + duration,
		step = function()
			local rootPos = session.root.Position
			local t = (session.time - start) / duration
			local radius = (params.radius + params.grow * t) * st.Size
			local spin = (session.time - start) * 2.5 * (st.ProjectileSpeed / (w.def.speedScale or 40))
			for i, part in parts do
				local a = spin + (i - 1) * (2 * math.pi / count)
				local pos = rootPos + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
				part.Position = pos
				for _, enemy in session.enemies:query(pos, 1.2 * st.Size) do
					local last = hitTimes[enemy]
					if not last or session.time - last >= params.rehit then
						hitTimes[enemy] = session.time
						hit(session, w, enemy, st.Damage, flatDir(enemy.pos - rootPos))
					end
				end
			end
			return false
		end,
		onEnd = function()
			for _, part in parts do
				Fx.release(part)
			end
		end,
	})
	return true
end

-- Aura ----------------------------------------------------------------------------------------

local function stepAura(session, w)
	local st, params = w.stats, w.def.params
	local radius = params.radius * st.Size
	local part = w.state.part
	if not part then
		part = Fx.acquire("Cylinder", w.color, Vector3.one)
		part.Transparency = 0.75
		w.state.part = part
	end
	part.Size = Vector3.new(0.3, radius * 2, radius * 2)
	part.CFrame = CFrame.new(session.root.Position - Vector3.new(0, 2.8, 0)) * CYLINDER_UP
end

local function fireAura(session, w)
	local st, params = w.stats, w.def.params
	local radius = params.radius * st.Size
	for _, enemy in session.enemies:query(session.root.Position, radius) do
		hit(session, w, enemy, st.Damage, nil)
		if params.freeze and not enemy.dead then
			Status.freeze(session, enemy, math.max(0.3, st.Duration), "weapon:" .. w.id)
		end
	end
	return true
end

-- Aegis ---------------------------------------------------------------------------------------

local function stepAegis(session, w, dt)
	local st = w.stats
	w.state.charges = w.state.charges or st.Count
	if w.state.charges < st.Count then
		w.state.recharge = (w.state.recharge or st.Cooldown) - dt
		if w.state.recharge <= 0 then
			w.state.charges += 1
			w.state.recharge = st.Cooldown
		end
	end
	-- Visual: un escudo orbital por carga
	w.state.parts = w.state.parts or {}
	local parts = w.state.parts
	while #parts < w.state.charges do
		table.insert(parts, Fx.acquire("Block", w.color, Vector3.new(1.6, 2, 0.3), Enum.Material.Metal))
	end
	while #parts > w.state.charges do
		Fx.release(table.remove(parts) :: BasePart)
	end
	local rootPos = session.root.Position
	for i, part in parts do
		local a = session.time * 1.5 + (i - 1) * (2 * math.pi / #parts)
		local pos = rootPos + Vector3.new(math.cos(a) * 3.2, 0, math.sin(a) * 3.2)
		part.CFrame = CFrame.lookAt(pos, rootPos)
	end
end

function Weapons.aegisActive(session): boolean
	for _, w in session.weapons do
		if w.def.behavior == "Aegis" and (w.state.charges or 0) > 0 then
			return true
		end
	end
	return false
end

function Weapons.tryAegisBlock(session, attacker): boolean
	for _, w in session.weapons do
		if w.def.behavior == "Aegis" and (w.state.charges or 0) > 0 then
			w.state.charges -= 1
			w.state.recharge = w.stats.Cooldown
			session:addCounter("aegis.blocks", 1)
			local rootPos = session.root.Position
			local radius = w.def.params.radius * w.stats.Size
			Fx.ring(rootPos, radius, w.color, 0.2)
			for _, enemy in session.enemies:query(rootPos, radius) do
				hit(session, w, enemy, w.stats.Damage, flatDir(enemy.pos - rootPos))
			end
			return true
		end
	end
	return false
end

-- Bucle ---------------------------------------------------------------------------------------

local FIRE = {
	Projectile = fireProjectileWeapon,
	Melee = fireMelee,
	Strike = fireStrike,
	Trail = fireTrail,
	Mines = fireMines,
	Field = fireField,
	Beam = fireBeam,
	Cone = fireCone,
	Orbit = fireOrbit,
	Aura = fireAura,
}

function Weapons.tick(session, w, dt: number)
	local now = session.time
	local queue = w.queue
	for i = #queue, 1, -1 do
		if now >= queue[i].at then
			local action = table.remove(queue, i)
			action.fn()
		end
	end

	local behavior = w.def.behavior
	if behavior == "Aegis" then
		stepAegis(session, w, dt)
		return
	end
	if behavior == "Aura" then
		stepAura(session, w)
	end
	w.timer -= dt
	if w.timer <= 0 then
		local fired = FIRE[behavior](session, w)
		if fired then
			local cooldown = w.stats.Cooldown
			if behavior == "Orbit" or behavior == "Beam" or behavior == "Cone" or behavior == "Field" then
				cooldown += w.stats.Duration
			end
			w.timer = cooldown
		else
			w.timer = 0.2
		end
	end
end

-- Efectos al matar propios de armas (Blood Magic, Scythe).
function Weapons.onKill(session, enemy, info)
	if info and info.source == "weapon:BloodMagic" then
		if session.rng:NextNumber() < 0.05 then
			session.bonus.MaxHealth = (session.bonus.MaxHealth or 0) + 1
			session.health += 1
			session.statsDirty = true
			session:addCounter("maxhp.BloodMagic", 1)
		end
	end
	if enemy.elite or enemy.miniboss then
		for _, w in session.weapons do
			if w.def.params and w.def.params.eliteCharge then
				w.state.charge = (w.state.charge or 0) + 1
			end
		end
	end
end

function Weapons.cleanup(session, w)
	if w.state.part then
		Fx.release(w.state.part)
		w.state.part = nil
	end
	if w.state.parts then
		for _, part in w.state.parts do
			Fx.release(part)
		end
		w.state.parts = nil
	end
end

function Weapons.clearAll(session)
	for _, w in session.weapons do
		Weapons.cleanup(session, w)
		table.clear(w.queue)
	end
	for _, p in session.projectiles do
		Fx.release(p.part)
	end
	table.clear(session.projectiles)
	for _, z in session.zones do
		if z.part then
			if z.pooled then
				Fx.release(z.part)
			else
				z.part:Destroy()
			end
		end
		if z.onEnd then
			z.onEnd(z)
		end
	end
	table.clear(session.zones)
end

return Weapons
