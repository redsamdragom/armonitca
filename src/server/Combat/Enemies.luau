-- Enemigos de una partida: aparición, IA (Chase, Float, Charge, Ranged, Boss), separación,
-- retroceso, proyectiles enemigos y consultas espaciales.
-- Cada enemigo es una pieza anclada movida con BulkMoveTo para soportar hordas grandes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Ground = require(script.Parent.Parent.World.Ground)
local SpatialHash = require(script.Parent.SpatialHash)
local Fx = require(script.Parent.Fx)

local Enemies = {}
Enemies.__index = Enemies

-- Enlazado tardío para evitar dependencias circulares (lo asigna RunSession).
Enemies.Damage = nil :: any

local SHAPES = { Block = Enum.PartType.Block, Ball = Enum.PartType.Ball, Cylinder = Enum.PartType.Cylinder }
local CYLINDER_UP = CFrame.Angles(0, 0, math.pi / 2)
local GOLD = Color3.fromRGB(255, 200, 60)

function Enemies.new(session)
	local folder = Instance.new("Folder")
	folder.Name = "Enemies_" .. session.player.UserId
	folder.Parent = workspace
	return setmetatable({
		session = session,
		list = {},
		grid = SpatialHash.new(8),
		folder = folder,
		projectiles = {},
		nextId = 0,
	}, Enemies)
end

function Enemies:count(): number
	return #self.list
end

function Enemies:spawn(defId: string, groundPosition: Vector3, opts: any?)
	opts = opts or {}
	local def = Catalog.Enemies[defId]
	assert(def, "enemigo desconocido " .. defId)
	local elite = opts.elite == true
	local scale = if elite then Config.Enemies.EliteSizeMult else 1
	local size = Vector3.new(def.size[1], def.size[2], def.size[3]) * scale

	local color = Color3.fromRGB(def.color[1], def.color[2], def.color[3])
	if elite then
		color = color:Lerp(GOLD, 0.35)
	end
	local p = Instance.new(if def.shape == "Wedge" then "WedgePart" else "Part") :: BasePart
	if def.shape ~= "Wedge" then
		(p :: Part).Shape = SHAPES[def.shape] or Enum.PartType.Block
	end
	p.Name = defId
	p.Size = if def.shape == "Cylinder" then Vector3.new(size.Y, size.X, size.Z) else size
	p.Color = color
	p.Material = if def.neon or elite then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = not def.neon

	self.nextId += 1
	local health = def.health * (opts.hpMult or 1) * (if elite then Config.Enemies.EliteHealthMult else 1)
	local enemy = {
		id = self.nextId,
		defId = defId,
		def = def,
		part = p,
		color = color,
		size = size,
		radius = math.max(size.X, size.Z) / 2,
		halfHeight = size.Y / 2,
		health = health,
		maxHealth = health,
		damage = def.damage * (opts.dmgMult or 1) * (if elite then Config.Enemies.EliteDamageMult else 1),
		speed = def.speed,
		elite = elite,
		boss = def.boss == true,
		miniboss = def.miniboss == true,
		pos = groundPosition + Vector3.new(0, size.Y / 2, 0),
		vel = Vector3.zero,
		groundY = groundPosition.Y,
		groundTimer = math.random() * 0.25,
		attackCd = 0,
		state = "Chase",
		stateTimer = 0,
		hitTimes = {},
		flashUntil = 0,
		dead = false,
		spawnTime = self.session.time,
	}
	p.CFrame = CFrame.new(enemy.pos) * (if def.shape == "Cylinder" then CYLINDER_UP else CFrame.identity)
	p.Parent = self.folder

	if def.ai == "Boss" then
		enemy.attackCd = 2
		enemy.phase = 1
	end
	table.insert(self.list, enemy)
	self.grid:insert(enemy, enemy.pos)
	return enemy
end

function Enemies:isAirborne(enemy): boolean
	return enemy.def.ai == "Float" or (enemy.airUntil ~= nil and enemy.airUntil > self.session.time)
end

function Enemies:flash(enemy)
	enemy.part.Color = enemy.color:Lerp(Color3.new(1, 1, 1), 0.6)
	enemy.flashUntil = self.session.time + 0.08
end

-- Elimina al enemigo y avisa a la sesión (botín, contadores, efectos al matar).
function Enemies:kill(enemy, info)
	if enemy.dead then
		return
	end
	enemy.dead = true
	enemy.part:Destroy()
	if enemy.telegraph then
		Fx.release(enemy.telegraph)
		enemy.telegraph = nil
	end
	self.session:onEnemyKilled(enemy, info)
end

-- Enemigos vivos cuyo cuerpo (cilindro vertical) toca la esfera (position, radius):
-- distancia horizontal más solapamiento de altura, para que los ataques horizontales a la altura
-- del pecho alcancen también a enemigos bajos.
function Enemies:query(position: Vector3, radius: number)
	local found = {}
	self.grid:each(position, radius + 8, function(enemy)
		if not enemy.dead then
			local offset = enemy.pos - position
			local horizontal = Vector3.new(offset.X, 0, offset.Z).Magnitude
			if horizontal <= radius + enemy.radius and math.abs(offset.Y) <= radius + enemy.halfHeight + 1 then
				table.insert(found, enemy)
			end
		end
		return false
	end)
	return found
end

function Enemies:nearest(position: Vector3, range: number, exclude: { [any]: boolean }?)
	local best, bestDistance = nil, math.huge
	for _, enemy in self.list do
		if not enemy.dead and not (exclude and exclude[enemy]) then
			local d = (enemy.pos - position).Magnitude
			if d < bestDistance and d <= range then
				best, bestDistance = enemy, d
			end
		end
	end
	return best, bestDistance
end

function Enemies:nearestN(position: Vector3, range: number, n: number)
	local candidates = {}
	for _, enemy in self.list do
		if not enemy.dead then
			local d = (enemy.pos - position).Magnitude
			if d <= range then
				table.insert(candidates, { enemy, d })
			end
		end
	end
	table.sort(candidates, function(a, b)
		return a[2] < b[2]
	end)
	local result = {}
	for i = 1, math.min(n, #candidates) do
		result[i] = candidates[i][1]
	end
	return result
end

function Enemies:random(position: Vector3, range: number)
	local candidates = {}
	for _, enemy in self.list do
		if not enemy.dead and (enemy.pos - position).Magnitude <= range then
			table.insert(candidates, enemy)
		end
	end
	if #candidates == 0 then
		return nil
	end
	return candidates[self.session.rng:NextInteger(1, #candidates)]
end

-- Proyectil enemigo en línea recta.
function Enemies:shoot(origin: Vector3, direction: Vector3, speed: number, damage: number, source)
	local part = Fx.acquire("Ball", Color3.fromRGB(255, 70, 70), Vector3.one * 1.4)
	part.Position = origin
	table.insert(self.projectiles, {
		part = part,
		pos = origin,
		vel = direction.Unit * speed,
		damage = damage,
		life = 4,
		source = source,
	})
end

local function telegraph(enemy, position: Vector3, radius: number)
	if enemy.telegraph then
		Fx.release(enemy.telegraph)
	end
	local part = Fx.acquire("Cylinder", Color3.fromRGB(255, 40, 40), Vector3.new(0.3, radius * 2, radius * 2))
	part.Transparency = 0.6
	part.CFrame = CFrame.new(position) * CYLINDER_UP
	enemy.telegraph = part
	enemy.telegraphPos = position
	enemy.telegraphRadius = radius
end

local function clearTelegraph(enemy)
	if enemy.telegraph then
		Fx.release(enemy.telegraph)
		enemy.telegraph = nil
	end
end

-- Máquina de estados de minijefes y jefes. Fases por umbral de vida (66% / 33%) [Pendiente].
function Enemies:stepBoss(enemy, dt: number, rootPos: Vector3, toTarget: Vector3, flatDistance: number)
	local session = self.session
	local Damage = Enemies.Damage
	enemy.phase = if enemy.health < enemy.maxHealth * 0.33 then 3 elseif enemy.health < enemy.maxHealth * 0.66 then 2 else 1
	local move = Vector3.zero
	local state = enemy.state

	if state == "Chase" then
		if flatDistance > 0.1 then
			move = toTarget.Unit * enemy.speed
		end
		enemy.attackCd -= dt
		if enemy.attackCd <= 0 then
			local attacks = enemy.def.attacks
			local attack = attacks[session.rng:NextInteger(1, #attacks)]
			enemy.state = attack .. "Windup"
			enemy.attack = attack
			if attack == "Slam" then
				enemy.stateTimer = 1.2
				telegraph(enemy, Vector3.new(enemy.pos.X, enemy.groundY + 0.2, enemy.pos.Z), enemy.radius + 9)
			elseif attack == "Charge" then
				enemy.stateTimer = 0.9
				enemy.chargeDir = if flatDistance > 0.1 then toTarget.Unit else Vector3.xAxis
				telegraph(enemy, Vector3.new(enemy.pos.X, enemy.groundY + 0.2, enemy.pos.Z), enemy.radius + 2)
			else
				enemy.stateTimer = 0.7
			end
		end
	elseif string.sub(state, -6) == "Windup" then
		enemy.stateTimer -= dt
		if enemy.stateTimer <= 0 then
			local attack = enemy.attack
			if attack == "Slam" then
				clearTelegraph(enemy)
				Fx.ring(enemy.telegraphPos, enemy.telegraphRadius, Color3.fromRGB(255, 120, 60), 0.3)
				local d = (Vector3.new(rootPos.X, 0, rootPos.Z) - Vector3.new(enemy.pos.X, 0, enemy.pos.Z)).Magnitude
				if d <= enemy.telegraphRadius and rootPos.Y - enemy.groundY < 8 then
					Damage.toPlayer(session, enemy.damage * 1.5, enemy)
				end
				enemy.state, enemy.stateTimer = "Recover", 0.8
			elseif attack == "Ring" then
				local n = 10 + enemy.phase * 4
				local offset = session.rng:NextNumber() * math.pi
				for i = 1, n do
					local a = offset + i * (2 * math.pi / n)
					self:shoot(enemy.pos, Vector3.new(math.cos(a), 0, math.sin(a)), 24 + enemy.phase * 4, enemy.damage * 0.6, enemy)
				end
				enemy.state, enemy.stateTimer = "Recover", 0.6
			elseif attack == "Charge" then
				clearTelegraph(enemy)
				enemy.state, enemy.stateTimer = "Charging", 1.1
				enemy.chargeHit = false
			elseif attack == "Summon" then
				local summon = session.director:basicEnemy()
				for _ = 1, 4 + enemy.phase * 2 do
					session.director:spawnNear(summon, enemy.pos, 6, 14)
				end
				enemy.state, enemy.stateTimer = "Recover", 0.6
			end
		end
	elseif state == "Charging" then
		move = enemy.chargeDir * enemy.speed * 4
		enemy.stateTimer -= dt
		if not enemy.chargeHit and flatDistance <= enemy.radius + 2.5 then
			enemy.chargeHit = true
			Damage.toPlayer(session, enemy.damage * 1.3, enemy)
		end
		if enemy.stateTimer <= 0 then
			enemy.state, enemy.stateTimer = "Recover", 0.7
		end
	elseif state == "Recover" then
		enemy.stateTimer -= dt
		if enemy.stateTimer <= 0 then
			enemy.state = "Chase"
			enemy.attackCd = math.max(1.2, 3.2 - enemy.phase * 0.6)
		end
	end

	-- Golpe por contacto
	enemy.contactCd = (enemy.contactCd or 0) - dt
	if flatDistance <= enemy.radius + 2 and enemy.contactCd <= 0 then
		enemy.contactCd = Config.Enemies.AttackCooldown
		Damage.toPlayer(session, enemy.damage, enemy)
	end
	return move
end

function Enemies:step(dt: number)
	local session = self.session
	local Damage = Enemies.Damage
	local root = session.root
	if not root then
		return
	end
	local rootPos = root.Position
	local now = session.time
	local parts, cframes = {}, {}
	local list = self.list
	local separation = Config.Enemies.SeparationRadius

	local i = 1
	while i <= #list do
		local enemy = list[i]
		if enemy.dead then
			list[i] = list[#list]
			list[#list] = nil
			continue
		end

		local def = enemy.def
		local pos = enemy.pos
		local toTarget = (rootPos - pos) * Vector3.new(1, 0, 1)
		local flatDistance = toTarget.Magnitude
		local slow = 1
		if enemy.frozenUntil and enemy.frozenUntil > now then
			slow = 1 - Config.Status.FreezeSlow
		end
		local stunned = enemy.stunnedUntil ~= nil and enemy.stunnedUntil > now
		local speedMult = slow * (enemy.speedMult or 1)

		local move = Vector3.zero
		enemy.attackCd -= dt
		if stunned then
			move = Vector3.zero
		elseif def.ai == "Boss" then
			move = self:stepBoss(enemy, dt, rootPos, toTarget, flatDistance) * slow
		elseif def.ai == "Charge" then
			if enemy.state == "Chase" then
				if flatDistance > 0.1 then
					move = toTarget.Unit * enemy.speed * speedMult
				end
				if flatDistance < 22 and enemy.attackCd <= 0 then
					enemy.state, enemy.stateTimer = "Windup", 0.8
					enemy.chargeDir = if flatDistance > 0.1 then toTarget.Unit else Vector3.xAxis
				end
			elseif enemy.state == "Windup" then
				enemy.stateTimer -= dt
				if enemy.stateTimer <= 0 then
					enemy.state, enemy.stateTimer, enemy.chargeHit = "Charging", 0.9, false
				end
			elseif enemy.state == "Charging" then
				move = enemy.chargeDir * (def.chargeSpeed or 35) * slow
				enemy.stateTimer -= dt
				if not enemy.chargeHit and flatDistance <= enemy.radius + 2.2 then
					enemy.chargeHit = true
					Damage.toPlayer(session, enemy.damage, enemy)
				end
				if enemy.stateTimer <= 0 then
					enemy.state = "Chase"
					enemy.attackCd = 2.5
				end
			end
		elseif def.ai == "Ranged" then
			local range = def.range or 28
			if flatDistance > range * 0.8 then
				move = toTarget.Unit * enemy.speed * speedMult
			elseif flatDistance < range * 0.45 and flatDistance > 0.1 then
				move = -toTarget.Unit * enemy.speed * speedMult
			end
			if flatDistance <= range and enemy.attackCd <= 0 then
				enemy.attackCd = 2.4
				local dir = rootPos - pos
				if dir.Magnitude > 0.1 then
					self:shoot(pos, dir, def.projectileSpeed or 28, enemy.damage, enemy)
				end
			end
		else -- Chase / Float
			if flatDistance > enemy.radius + 1.2 then
				move = toTarget.Unit * enemy.speed * speedMult
			end
		end

		-- Golpe cuerpo a cuerpo de los enemigos normales
		if def.ai ~= "Boss" and def.ai ~= "Charge" and not stunned then
			local vertical = math.abs(rootPos.Y - pos.Y)
			if flatDistance <= enemy.radius + 2.3 and vertical < enemy.halfHeight + 4 and enemy.attackCd <= 0 then
				enemy.attackCd = Config.Enemies.AttackCooldown
				Damage.toPlayer(session, enemy.damage, enemy)
			end
		end

		-- Separación entre enemigos (usa la rejilla del frame anterior)
		if not enemy.boss then
			local push = Vector3.zero
			local reach = enemy.radius + separation
			self.grid:each(pos, reach, function(other)
				if other ~= enemy and not other.dead then
					local offset = (pos - other.pos) * Vector3.new(1, 0, 1)
					local d = offset.Magnitude
					local minD = enemy.radius + other.radius
					if d < minD and d > 0.01 then
						push += offset.Unit * (minD - d)
					end
				end
				return false
			end)
			move += push * 4
		end

		-- Retroceso y atracción acumulados
		if enemy.vel.Magnitude > 0.05 then
			move += enemy.vel
			enemy.vel *= math.exp(-6 * dt)
		end

		local newPos = pos + move * dt
		local half = session.mapHalfSize - 4
		newPos = Vector3.new(math.clamp(newPos.X, -half, half), newPos.Y, math.clamp(newPos.Z, -half, half))

		-- Altura
		local targetY
		if def.ai == "Float" then
			targetY = math.max(rootPos.Y + (def.hover or 2), enemy.groundY + enemy.halfHeight)
			enemy.groundTimer -= dt
			if enemy.groundTimer <= 0 then
				enemy.groundTimer = 0.4
				enemy.groundY = Ground.height(newPos, enemy.groundY)
			end
		else
			enemy.groundTimer -= dt
			if enemy.groundTimer <= 0 then
				enemy.groundTimer = 0.25
				enemy.groundY = Ground.height(newPos, enemy.groundY)
			end
			targetY = enemy.groundY + enemy.halfHeight
			if enemy.airUntil and enemy.airUntil > now then
				targetY += 6
			end
		end
		local y = pos.Y + (targetY - pos.Y) * math.min(1, dt * 10)
		local final = Vector3.new(newPos.X, y, newPos.Z)
		enemy.pos = final

		if enemy.flashUntil > 0 and now >= enemy.flashUntil then
			enemy.flashUntil = 0
			enemy.part.Color = if enemy.frozenUntil and enemy.frozenUntil > now
				then enemy.color:Lerp(Color3.fromRGB(80, 220, 210), 0.6)
				else enemy.color
		end

		local facing = if flatDistance > 0.1 then toTarget.Unit else Vector3.zAxis
		local cf = CFrame.lookAt(final, final + facing)
		if def.shape == "Cylinder" then
			cf *= CYLINDER_UP
		end
		table.insert(parts, enemy.part)
		table.insert(cframes, cf)
		i += 1
	end

	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end

	-- Reconstruye la rejilla con las posiciones nuevas
	self.grid:clear()
	for _, enemy in list do
		if not enemy.dead then
			self.grid:insert(enemy, enemy.pos)
		end
	end

	-- Proyectiles enemigos
	local projectiles = self.projectiles
	for j = #projectiles, 1, -1 do
		local p = projectiles[j]
		p.pos += p.vel * dt
		p.life -= dt
		p.part.Position = p.pos
		local hit = (p.pos - rootPos).Magnitude <= 2.6
		if hit then
			Damage.toPlayer(session, p.damage, p.source)
		end
		if hit or p.life <= 0 then
			Fx.release(p.part)
			table.remove(projectiles, j)
		end
	end
end

function Enemies:clearProjectiles()
	for _, p in self.projectiles do
		Fx.release(p.part)
	end
	table.clear(self.projectiles)
end

function Enemies:destroy()
	for _, enemy in self.list do
		enemy.dead = true
		if enemy.telegraph then
			Fx.release(enemy.telegraph)
		end
	end
	table.clear(self.list)
	self:clearProjectiles()
	self.folder:Destroy()
end

return Enemies
