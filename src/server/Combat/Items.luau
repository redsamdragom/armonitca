-- Efectos de los objetos, organizados por evento. Cada entrada de HANDLERS implementa un objeto
-- del catálogo (Data/Items.luau); `n` es el número de copias.
--
-- Encadenamiento: sólo 8 fuentes de daño de objetos activan otros objetos (coeficiente en PROC);
-- el resto usa coeficiente 0. Overpowered Lamp añade tiradas independientes salvo exclusiones.
-- Los valores marcados [Pendiente] son provisionales; los [Discrepancia] están en docs/MATRIZ.md.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Stats = require(ReplicatedStorage.Shared.Stats)
local Fx = require(script.Parent.Fx)
local Damage = require(script.Parent.Damage)
local Status = require(script.Parent.Status)

local Items = {}

local U = Config.UnitToStuds
local FLAT = Vector3.new(1, 0, 1)

-- Coeficientes de activación de las fuentes de daño de objetos (referencia comunitaria).
local PROC = {
	Cactus = 0.5,
	ElectricPlug = 0.5,
	ToxicBarrel = 0.5,
	ShatteredKnowledge = 0.5,
	HolyBook = 0.5,
	EnergyCore = 1,
	Mirror = 1,
	CursedDoll = 1,
}

local function count(session, id: string): number
	return session.items[id] or 0
end
Items.count = count

local function data(session, id: string)
	local d = session.itemData[id]
	if not d then
		d = {}
		session.itemData[id] = d
	end
	return d
end

-- Tiradas con Overpowered Lamp: cada copia añade una tirada independiente.
local function rolls(session, chance: number, coef: number, allowLamp: boolean?): number
	local tries = 1 + (if allowLamp ~= false then count(session, "OverpoweredLamp") else 0)
	local hits = 0
	local p = chance * coef
	for _ = 1, tries do
		local guaranteed = math.floor(p)
		hits += guaranteed
		if session.rng:NextNumber() < p - guaranteed then
			hits += 1
		end
	end
	return hits
end

local function itemDamage(session, enemy, id: string, amount: number, extra: any?)
	local info = {
		source = "item:" .. id,
		amount = amount,
		procCoef = PROC[id] or 0,
		depth = 1,
	}
	if extra then
		for k, v in extra do
			info[k] = v
		end
	end
	return Damage.toEnemy(session, enemy, info)
end

local function area(session, id: string, position: Vector3, radius: number, amount: number, col: Color3, extra: any?)
	Fx.flash("Ball", CFrame.new(position), Vector3.one * radius * 2, col, 0.18, 0.55)
	for _, enemy in session.enemies:query(position, radius) do
		itemDamage(session, enemy, id, amount, extra)
	end
end

local function levelDamage(session, base: number): number
	return base + session.level
end

local function rootPos(session): Vector3
	return session.root.Position
end

local function cooldownReady(session, id: string, cd: number): boolean
	local d = data(session, id)
	if (d.readyAt or 0) <= session.time then
		d.readyAt = session.time + cd
		return true
	end
	return false
end

-- Golpe diferido con un destello en línea (misiles, almas, orbes).
local function homingHit(session, id: string, from: Vector3, enemy, amount: number, col: Color3, extra: any?)
	Fx.beam(from, enemy.pos, 0.35, col, 0.15)
	session:after(0.15, function()
		if not enemy.dead then
			itemDamage(session, enemy, id, amount, extra)
		end
	end)
end

local HANDLERS = {}

-- Comunes -------------------------------------------------------------------------------------

HANDLERS.MoldyCheese = {
	onHit = function(session, n, enemy, info)
		local stacks = rolls(session, 0.4 * n, info.procCoef)
		if stacks > 0 then
			Status.poison(session, enemy, stacks, "item:MoldyCheese")
		end
	end,
}

HANDLERS.Borgar = {
	onKill = function(session, n, enemy)
		if (enemy.pos - rootPos(session)).Magnitude > 30 * U then
			return
		end
		if session.rng:NextNumber() < 0.02 + 0.01 * (n - 1) then
			local heal = math.max(0.08 * session.stats.MaxHealth, 8 + 2 * n)
			session:spawnPickup("Burger", enemy.pos, heal, { lifetime = 30 })
		end
	end,
}

HANDLERS.Wrench = {} -- lo usa Interactables (tiempo de carga y recompensas de santuarios)
HANDLERS.Clover = { stats = function(s, n) s.Luck += 0.10 * n end }
HANDLERS.TimeBracelet = { stats = function(s, n) s.XPGain += 0.08 * n end }
HANDLERS.SlipperyRing = { stats = function(s, n) s.Evasion += 0.15 * n end }
HANDLERS.GoldenGlove = {} -- multiplicador de oro por baja en RunSession
HANDLERS.GymSauce = { stats = function(s, n) s.Damage += 0.10 * n end }
HANDLERS.Oats = { stats = function(s, n) s.MaxHealth += 25 * n end }
HANDLERS.Medkit = { stats = function(s, n) s.Regen += 45 * n end }
HANDLERS.TurboSocks = { stats = function(s, n) s.MoveSpeed += 0.15 * n end }

HANDLERS.TacticalGlasses = {
	-- [Discrepancia] límite >= 90% o > 90%: se usa >=
	damageMult = function(session, n, enemy)
		if enemy.health >= enemy.maxHealth * 0.9 then
			return 1 + 0.2 * n
		end
		return 1
	end,
}

HANDLERS.Battery = { stats = function(s, n) s.AttackSpeed += 0.08 * n end }
HANDLERS.ForbiddenJuice = { stats = function(s, n) s.CritChance += 0.10 * n end }

HANDLERS.CursedDoll = {
	tick = function(session, n)
		local d = data(session, "CursedDoll")
		if session.time < (d.next or 0) then
			return
		end
		d.next = session.time + 1
		local active = 0
		for _, enemy in session.enemies.list do
			if not enemy.dead and enemy.cursedUntil and enemy.cursedUntil > session.time then
				active += 1
			end
		end
		local budget = math.min(5, 2 * n - active)
		for _ = 1, budget do
			local enemy = session.enemies:random(rootPos(session), 50)
			if enemy and not (enemy.cursedUntil and enemy.cursedUntil > session.time) then
				Status.curse(session, enemy, 4)
			end
		end
	end,
}

HANDLERS.BossBuster = {
	damageMult = function(session, n, enemy)
		if enemy.elite or enemy.boss or enemy.miniboss then
			return 1 + 0.15 * n
		end
		return 1
	end,
}

HANDLERS.Key = {} -- Interactables: 0,1n / (1 + 0,1n)

HANDLERS.IceCrystal = {
	-- [Discrepancia] probabilidad y duración: se usa la fórmula hiperbólica (~9,09%) y 1,5 s
	onHit = function(session, n, enemy, info)
		if rolls(session, Stats.hyperbolic(0.1, n, 1), info.procCoef) > 0 then
			Status.freeze(session, enemy, 1.5, "item:IceCrystal")
		end
	end,
}

HANDLERS.Skuleg = { stats = function(s, n) s.Difficulty += 0.07 * n end }

HANDLERS.Ghost = {
	onInteract = function(session, n)
		for _ = 1, 6 * n do
			local enemy = session.enemies:random(rootPos(session), 60)
			if enemy then
				homingHit(session, "Ghost", rootPos(session), enemy, levelDamage(session, 6) * (1 + session.stats.Damage), Color3.fromRGB(220, 220, 255))
			end
		end
	end,
}

HANDLERS.Cactus = {
	onDamageTaken = function(session, n, amount, attacker, selfInflicted)
		local spikes = math.min(40, 3 + 2 * (n - 1))
		local origin = rootPos(session)
		local dmg = (10 + session.stats.Thorns) * (1 + session.stats.Damage)
		for i = 1, spikes do
			local a = i * (2 * math.pi / spikes)
			local to = origin + Vector3.new(math.cos(a), 0, math.sin(a)) * 14
			Fx.beam(origin, to, 0.25, Color3.fromRGB(90, 170, 80), 0.12)
			for _, enemy in session.enemies:query(origin:Lerp(to, 0.6), 5) do
				itemDamage(session, enemy, "Cactus", dmg, { canCrit = true })
				break
			end
		end
	end,
}

HANDLERS.OldMask = { stats = function(s, n) s.EliteSpawn += 0.15 * n end }

-- Raros ---------------------------------------------------------------------------------------

HANDLERS.CreditCardRed = {
	stats = function(s, n, session)
		s.Damage += 0.025 * n * session.chestsOpened
	end,
}

HANDLERS.GoldenShield = {
	onAcquire = function(session)
		local d = data(session, "GoldenShield")
		d.level = d.level or session.level
	end,
	onDamageTaken = function(session, n, amount, attacker, selfInflicted)
		local d = data(session, "GoldenShield")
		local gold = (d.level or session.level) * n * 0.5 -- [Pendiente]
		if selfInflicted then
			gold *= 0.25
		end
		session:gainGold(gold, true)
	end,
}

HANDLERS.ThunderMitts = {
	onHit = function(session, n, enemy)
		if not cooldownReady(session, "ThunderMitts", 10) then
			return
		end
		local radius = 8 * U
		Fx.beam(enemy.pos + Vector3.new(0, 30, 0), enemy.pos, 1, Color3.fromRGB(150, 200, 255), 0.15)
		for _, other in session.enemies:query(enemy.pos, radius) do
			itemDamage(session, other, "ThunderMitts", levelDamage(session, 20) * (1 + 0.5 * (n - 1)), { element = "Electric" })
			Status.stun(session, other, 3)
		end
	end,
}

HANDLERS.Feathers = {
	stats = function(s, n)
		s.JumpHeight += 2.2 * n * 0.5 -- [Pendiente] conversión de 0,15 de atributo y 2,2 de impulso
		s.ExtraJumps += n
	end,
}

HANDLERS.ElectricPlug = {
	onDamageTaken = function(session, n)
		local targets = session.enemies:nearestN(rootPos(session), 25, 6 + 4 * (n - 1))
		for _, enemy in targets do
			Fx.beam(rootPos(session), enemy.pos, 0.3, Color3.fromRGB(150, 220, 255), 0.12)
			itemDamage(session, enemy, "ElectricPlug", levelDamage(session, 15) * (1 + session.stats.Damage), { element = "Electric" })
		end
	end,
}

HANDLERS.CowardsCloak = {
	stats = function(s, n, session)
		s.MoveSpeed += 0.05 * n
		local d = data(session, "CowardsCloak")
		if (d.untilTime or 0) > session.time then
			s.MoveSpeed += 0.10 * (d.stacks or 0)
		end
	end,
	onDamageTaken = function(session, n)
		local d = data(session, "CowardsCloak")
		if (d.untilTime or 0) <= session.time then
			d.stacks = 0
		end
		d.stacks = math.min(3 + n, (d.stacks or 0) + 1)
		d.untilTime = session.time + 3 + n
		session.statsDirty = true
		session:after(3 + n + 0.05, function()
			session.statsDirty = true
		end)
	end,
}

HANDLERS.UnstableTransfusion = {
	onHit = function(session, n, enemy, info)
		local stacks = rolls(session, 0.35 * n, info.procCoef)
		if stacks > 0 then
			Status.bloodmark(session, enemy, stacks)
		end
	end,
}

HANDLERS.Beer = {
	stats = function(s, n, session)
		s.Damage += 0.2 * n
		session.maxHealthMult *= math.max(0.05, 1 - 0.05 * n)
	end,
}

HANDLERS.Beacon = {} -- Interactables: zona curativa al completar Charge Shrines
HANDLERS.Backpack = { stats = function(s, n) s.Quantity += n end }

HANDLERS.PhantomShroud = {
	-- [Discrepancia] ×2 (descripción) vs ×3 (análisis): se usa ×3 con hasta 4 cargas
	stats = function(s, n, session)
		local d = data(session, "PhantomShroud")
		if (d.untilTime or 0) > session.time then
			s.AttackSpeed += 0.25 * (d.charges or 0)
			s.MoveSpeed += 0.5
		end
	end,
	onEvade = function(session, n)
		local d = data(session, "PhantomShroud")
		d.charges = math.min(4, (d.charges or 0) + 1)
		d.untilTime = session.time + 3
		session.statsDirty = true
		session:after(3.05, function()
			session.statsDirty = true
		end)
	end,
	damageMult = function(session, n, enemy, info)
		local d = data(session, "PhantomShroud")
		if (d.charges or 0) > 0 and info.weapon and not info.isDot then
			d.charges -= 1
			return 3
		end
		return 1
	end,
}

HANDLERS.Campfire = {
	stats = function(s, n, session)
		if session.stationaryTime >= 0.6 then
			s.Regen += 1100 * n
		end
	end,
}

HANDLERS.BrassKnuckles = {
	damageMult = function(session, n, enemy)
		local reach = (8 + 2 * (n - 1)) * U
		if (enemy.pos - rootPos(session)).Magnitude <= reach + enemy.radius then
			return 1 + 0.25 * n
		end
		return 1
	end,
}

HANDLERS.DemonicBlade = {
	stats = function(s) s.CritChance += 0.01 end,
	onCrit = function(session, n)
		local heals = rolls(session, 0.25 * n, 1)
		if heals > 0 then
			Damage.heal(session, heals, "DemonicBlade")
		end
	end,
}

HANDLERS.DemonicBlood = {
	stats = function(s, n, session)
		s.MaxHealth += 0.5 * (data(session, "DemonicBlood").kills or 0)
	end,
	onKill = function(session, n)
		local d = data(session, "DemonicBlood")
		if (d.kills or 0) < 200 * n then
			d.kills = (d.kills or 0) + 1
			session.health += 0.5
			session.statsDirty = true
		end
	end,
}

HANDLERS.EchoShard = {
	onKill = function(session, n, enemy)
		if session.rng:NextNumber() < 0.12 * n then
			session:spawnPickup("XP", enemy.pos + Vector3.new(1, 0, 0), enemy.def.xp)
		end
	end,
}

HANDLERS.MoldyGloves = {
	onHit = function(session, n, enemy)
		if not cooldownReady(session, "MoldyGloves", 9.5) then
			return
		end
		local radius = 15 * U * 0.5
		Fx.flash("Ball", CFrame.new(enemy.pos), Vector3.one * radius * 2, Status.POISON_COLOR, 0.4, 0.6)
		for _, other in session.enemies:query(enemy.pos, radius) do
			itemDamage(session, other, "MoldyGloves", levelDamage(session, 10) * (1 + 0.5 * (n - 1)))
			Status.poison(session, other, 10, "item:MoldyGloves")
		end
	end,
}

HANDLERS.GoldenSneakers = {
	onMove = function(session, n, distance)
		local d = data(session, "GoldenSneakers")
		d.acc = (d.acc or 0) + distance
		local step = 10 * U
		while d.acc >= step do
			d.acc -= step
			session:gainGold(n, true)
		end
	end,
}

HANDLERS.IdleJuice = {
	damageMult = function(session, n)
		return 1 + math.min(n, 0.04 * session.stationaryTime)
	end,
}

HANDLERS.LeechingCrystal = {
	-- [Discrepancia] −50% lineal o ×0,5 por copia: se usa ×0,5 por copia; la vida no baja de 1
	stats = function(s, n, session)
		s.MaxHealth += 50 * n
		session.regenMult *= 0.5 ^ n
	end,
}

HANDLERS.Pumpkin = {} -- MapGen: +10 vasijas por copia en fases futuras; Interactables: +18% recompensas

-- Épicos --------------------------------------------------------------------------------------

HANDLERS.BeefyRing = {
	stats = function(s, n) s.MaxHealth += 10 * n end,
	damageMult = function(session, n)
		return 1 + 0.002 * n * (session.stats.MaxHealth + math.max(0, session.health - session.stats.MaxHealth))
	end,
}

HANDLERS.CreditCardGreen = {
	stats = function(s, n, session)
		s.Luck += 0.02 * n * session.chestsOpened
	end,
}

HANDLERS.SpikyShield = {
	stats = function(s, n) s.Armor += 0.10 * n end,
	post = function(s, n)
		s.Thorns += 2 * n * (Stats.diminishing(s.Armor) * 100)
	end,
}

HANDLERS.Scarf = {
	damageMult = function(session, n)
		return if session.airborne then 1 + 0.5 * n else 1
	end,
}

HANDLERS.SlurpGloves = {
	onHit = function(session, n, enemy)
		if not cooldownReady(session, "SlurpGloves", 9) then
			return
		end
		local radius = 10 * U * 0.5 * (1 + 0.1 * (n - 1))
		local struck = session.enemies:query(enemy.pos, radius)
		Fx.flash("Ball", CFrame.new(enemy.pos), Vector3.one * radius * 2, Color3.fromRGB(170, 0, 30), 0.25, 0.5)
		for _, other in struck do
			Status.bloodmark(session, other, n)
		end
		Damage.heal(session, 0.075 * session.stats.MaxHealth * #struck, "SlurpGloves")
	end,
}

HANDLERS.Mirror = {
	onDamageTaken = function(session, n, amount, attacker, selfInflicted)
		if selfInflicted or not cooldownReady(session, "Mirror", math.max(4, 7 - (n - 1))) then
			return
		end
		session.invulnUntil = math.max(session.invulnUntil, session.time + 0.5)
		local origin = rootPos(session)
		local dir = (session.root.CFrame.LookVector * FLAT).Unit
		for _, enemy in session.enemies:query(origin, 18) do
			local to = ((enemy.pos - origin) * FLAT).Unit
			if to:Dot(dir) > 0.5 then
				itemDamage(session, enemy, "Mirror", math.max(amount * 3, levelDamage(session, 20)))
			end
		end
		Fx.flash("Block", CFrame.lookAt(origin, origin + dir) * CFrame.new(0, 0, -9), Vector3.new(14, 1, 18), Color3.fromRGB(200, 240, 255), 0.15, 0.5)
	end,
}

HANDLERS.TurboSkates = {
	post = function(s, n)
		s.AttackSpeed += math.clamp(s.MoveSpeed, 0, 0.4 * n * n)
	end,
}

HANDLERS.SluttyCannon = {
	onHit = function(session, n, enemy, info, amount)
		local d = data(session, "SluttyCannon")
		if d.tick ~= session.frame then
			d.tick, d.fired = session.frame, 0
		end
		if d.fired >= 4 then
			return
		end
		local chance = math.min(0.2 * n / (0.2 * n + 0.5), 0.6)
		local hits = math.min(4 - d.fired, rolls(session, chance, info.procCoef))
		for _ = 1, hits do
			d.fired += 1
			local t = session.enemies:random(enemy.pos, 25) or enemy
			homingHit(session, "SluttyCannon", rootPos(session), t, (1 + 0.4 * n) * amount, Color3.fromRGB(255, 100, 180), { flat = true })
		end
	end,
}

HANDLERS.ShatteredKnowledge = {
	onAcquire = function(session)
		local d = data(session, "ShatteredKnowledge")
		d.level = d.level or session.level
	end,
}

HANDLERS.QuinsMask = {
	stats = function(s, n) s.Thorns += 20 * n end,
	onThorns = function(session, n, enemy, thorns)
		if session.rng:NextNumber() < 0.5 then
			area(session, "QuinsMask", enemy.pos, 6, 0.5 * thorns * (1 + session.stats.Damage), Color3.fromRGB(255, 120, 200), { flat = true })
		end
	end,
}

HANDLERS.ToxicBarrel = {
	onDamageTaken = function(session, n)
		if not cooldownReady(session, "ToxicBarrel", 0.25) then
			return
		end
		local radius = 6 + 2 * n
		Fx.flash("Ball", CFrame.new(rootPos(session)), Vector3.one * radius * 2, Status.POISON_COLOR, 0.4, 0.65)
		for _, enemy in session.enemies:query(rootPos(session), radius) do
			Status.poison(session, enemy, 5 * n, "item:ToxicBarrel")
		end
	end,
}

HANDLERS.GasMask = {
	-- Se actualiza cada segundo según los envenenados vivos [Pendiente: coeficientes]
	stats = function(s, n, session)
		local poisoned = data(session, "GasMask").poisoned or 0
		s.Armor += math.min(0.5 * n, poisoned * 0.01)
		s.Overheal += math.min(0.5 * n, poisoned * 0.01)
	end,
	tick = function(session)
		local d = data(session, "GasMask")
		if session.time >= (d.next or 0) then
			d.next = session.time + 1
			if d.poisoned ~= session.poisonedAlive then
				d.poisoned = session.poisonedAlive
				session.statsDirty = true
			end
		end
	end,
}

HANDLERS.GamerGoggles = {
	damageMult = function(session, n)
		local ratio = session.health / session.stats.MaxHealth
		return 1 + n * math.clamp((0.5 - ratio) / 0.5, 0, 1)
	end,
}

HANDLERS.EagleClaw = {
	damageMult = function(session, n, enemy)
		return if session.enemies:isAirborne(enemy) then 1 + 0.66 * n else 1
	end,
	onHit = function(session, n, enemy, info)
		if not (enemy.boss or enemy.miniboss) and rolls(session, Stats.hyperbolic(0.08, n, 1), info.procCoef) > 0 then
			enemy.airUntil = session.time + 1.2
		end
	end,
}

HANDLERS.DemonicSoul = {
	damageMult = function(session, n)
		return 1 + 0.001 * (data(session, "DemonicSoul").stacks or 0)
	end,
	onKill = function(session, n)
		local d = data(session, "DemonicSoul")
		d.stacks = math.min(1000 * n, (d.stacks or 0) + 1)
	end,
}

HANDLERS.BobDead = {
	onMove = function(session, n, distance)
		local d = data(session, "BobDead")
		d.acc = (d.acc or 0) + distance
		local step = 14 * U
		while d.acc >= step do
			d.acc -= step
			for _ = 1, n do
				local enemy = session.enemies:nearest(rootPos(session), 40)
				if enemy then
					homingHit(session, "BobDead", rootPos(session), enemy, levelDamage(session, 10) * (1 + session.stats.Damage), Color3.fromRGB(200, 255, 200))
				end
			end
		end
	end,
}

HANDLERS.GrandmasSecretTonic = {
	stats = function(s) s.CritChance += 0.02 end,
	onCrit = function(session, n, enemy, amount)
		if session.rng:NextNumber() < 0.5 then
			local radius = math.min(10, 4 + n)
			area(session, "GrandmasSecretTonic", enemy.pos, radius, amount * 0.5, Color3.fromRGB(255, 160, 220), { flat = true })
		end
	end,
}

HANDLERS.CursedGrabbies = {
	stats = function(s, n, session)
		s.Difficulty += 0.10 * n
		session.maxHealthMult *= 0.8 ^ n
	end,
	onHit = function(session, n, enemy, info)
		local chance = math.min(0.5, Stats.hyperbolic(0.05, n, 1))
		if rolls(session, chance, info.procCoef) > 0 then
			area(session, "CursedGrabbies", enemy.pos, 5, levelDamage(session, 10) * (1 + session.stats.Damage), Color3.fromRGB(120, 0, 160), { flat = true })
		end
	end,
}

HANDLERS.Kevin = {
	onHit = function(session, n, enemy, info)
		if rolls(session, 0.25 * n, info.procCoef, false) > 0 then
			session:addCounter("kevin.punches", 1)
			Damage.toPlayer(session, 1 + session.level * 0.2, nil, { selfInflicted = true })
		end
	end,
}

HANDLERS.BobsLight = {
	onAcquire = function(session)
		data(session, "BobsLight").next = session.time + 2
	end,
	tick = function(session, n)
		local d = data(session, "BobsLight")
		if session.time < (d.next or 0) then
			return
		end
		d.next = session.time + math.max(5, 45 - 3 * n)
		local radius = math.min(250, 50 + 10 * n) * U * 0.5
		Fx.ring(rootPos(session), radius, Color3.fromRGB(255, 250, 200), 0.4)
		for _, enemy in session.enemies:query(rootPos(session), radius) do
			if enemy.boss or enemy.miniboss then
				itemDamage(session, enemy, "BobsLight", enemy.maxHealth * 0.04, { flat = true, canCrit = false })
			elseif enemy.def.swarm and session.rng:NextNumber() > 0.33 then
				itemDamage(session, enemy, "BobsLight", enemy.maxHealth * 0.04, { flat = true, canCrit = false })
			else
				itemDamage(session, enemy, "BobsLight", enemy.health + 1, { flat = true, canCrit = false })
			end
		end
	end,
}

-- Legendarios ---------------------------------------------------------------------------------

HANDLERS.OverpoweredLamp = {} -- tiradas extra en `rolls`
HANDLERS.ZaWarudo = {} -- Items.tryPreventDeath

HANDLERS.BigBonk = {
	onHit = function(session, n, enemy, info, amount)
		if rolls(session, 0.02 + 0.015 * (n - 1), info.procCoef) > 0 then
			local power = 20 * (1 + 0.1 * (n - 1))
			Fx.flash("Ball", CFrame.new(enemy.pos), Vector3.one * 6, Color3.fromRGB(255, 240, 80), 0.25, 0.3)
			itemDamage(session, enemy, "BigBonk", amount * power, { flat = true, canCrit = false, kind = "bonk" })
			area(session, "BigBonk", enemy.pos, 4 + n, amount, Color3.fromRGB(255, 240, 80), { flat = true, canCrit = false })
		end
	end,
}

HANDLERS.SpicyMeatball = {
	onHit = function(session, n, enemy, info, amount)
		if rolls(session, 0.25, info.procCoef) > 0 then
			local radius = math.min(10, 3 + n)
			Fx.flash("Ball", CFrame.new(enemy.pos), Vector3.one * radius * 2, Color3.fromRGB(255, 90, 40), 0.15, 0.5)
			for _, other in session.enemies:query(enemy.pos, radius) do
				if other ~= enemy then
					itemDamage(session, other, "SpicyMeatball", amount * 0.65, { flat = true })
				end
			end
		end
	end,
}

HANDLERS.IceCube = {
	onHit = function(session, n, enemy, info, amount)
		if rolls(session, Stats.hyperbolic(0.2, n, 1), info.procCoef) > 0 then
			itemDamage(session, enemy, "IceCube", amount * 0.2 * n, { flat = true, element = "Ice" })
			Status.freeze(session, enemy, 3, "item:IceCube")
		end
	end,
}

HANDLERS.GiantFork = {
	stats = function(s, n) s.CritChance += 0.15 * n end,
}

HANDLERS.PowerGloves = {
	onHit = function(session, n, enemy, info)
		if not cooldownReady(session, "PowerGloves", math.max(1, 4 - 0.5 * (n - 1))) then
			return
		end
		if rolls(session, Stats.hyperbolic(0.08, n, 1), info.procCoef) == 0 then
			data(session, "PowerGloves").readyAt = session.time
			return
		end
		local radius = 8 + 2 * n
		Fx.flash("Ball", CFrame.new(enemy.pos), Vector3.one * radius * 2, Color3.fromRGB(255, 200, 120), 0.25, 0.4)
		for _, other in session.enemies:query(enemy.pos, radius) do
			local push = ((other.pos - enemy.pos) * FLAT)
			itemDamage(session, other, "PowerGloves", levelDamage(session, 20) * 2 * n * (1 + session.stats.Damage), {
				flat = true,
				knockback = if push.Magnitude > 0.1 then push.Unit * 30 else nil,
			})
			Status.stun(session, other, 3)
		end
	end,
}

HANDLERS.LightningOrb = {
	onHit = function(session, n, enemy, info)
		local chance = math.min(0.9, Stats.hyperbolic(0.25, n, 1))
		if rolls(session, chance, info.procCoef) == 0 then
			return
		end
		local current = enemy
		local struck = {}
		for _ = 1, 3 do
			struck[current] = true
			itemDamage(session, current, "LightningOrb", levelDamage(session, 10) * (1 + 0.5 * (n - 1)) * (1 + session.stats.Damage), { flat = true, element = "Electric" })
			if session.rng:NextNumber() < chance then
				Status.stun(session, current, 3)
			end
			local nextEnemy = session.enemies:nearest(current.pos, 15, struck)
			if not nextEnemy then
				break
			end
			Fx.beam(current.pos, nextEnemy.pos, 0.3, Color3.fromRGB(170, 210, 255), 0.12)
			current = nextEnemy
		end
	end,
}

HANDLERS.Chonkplate = {
	stats = function(s, n)
		s.Overheal += 0.75 * n
		s.Lifesteal += 0.20 * n
	end,
}

HANDLERS.Dragonfire = {
	onHit = function(session, n, enemy, info, amount)
		if info.element == "Fire" then
			Status.burn(session, enemy, amount * 0.2, nil, "item:Dragonfire")
		end
		local chance = 0.15 * n / (0.15 * n + 0.5)
		if rolls(session, chance, info.procCoef) > 0 then
			local pos = enemy.pos
			local radius = 4
			local part = Fx.acquire("Cylinder", Color3.fromRGB(255, 100, 20), Vector3.new(0.3, radius * 2, radius * 2))
			part.Transparency = 0.5
			part.CFrame = CFrame.new(pos - Vector3.new(0, enemy.halfHeight - 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
			session:addZone({
				pos = pos,
				untilTime = session.time + 2,
				tick = 0.5,
				nextTick = session.time,
				part = part,
				pooled = true,
				onTick = function(z)
					for _, other in session.enemies:query(z.pos, radius) do
						itemDamage(session, other, "Dragonfire", amount * 0.25, { flat = true, element = "Fire" })
					end
				end,
			})
		end
	end,
}

HANDLERS.SuckyMagnet = {
	tick = function(session, n)
		local d = data(session, "SuckyMagnet")
		if session.time < (d.next or 0) then
			return
		end
		d.next = session.time + 15 / n
		session:magnetGems(50 * n * U * 0.5)
	end,
}

HANDLERS.HolyBook = {
	stats = function(s, n)
		s.MaxHealth += 100 * n
		s.Regen += 50 * n
		s.Overheal += 0.25 * n
	end,
	onHeal = function(session, n, amount)
		local d = data(session, "HolyBook")
		d.pool = (d.pool or 0) + amount
	end,
	tick = function(session, n)
		local d = data(session, "HolyBook")
		if session.time < (d.next or 0) then
			return
		end
		d.next = session.time + 1.5
		if (d.pool or 0) > 0 then
			area(session, "HolyBook", rootPos(session), 10, d.pool * 2 * n * (1 + session.stats.Damage), Color3.fromRGB(255, 255, 200), { flat = true })
			d.pool = 0
		end
	end,
}

HANDLERS.SpeedBoi = {
	onDamageTaken = function(session, n)
		local d = data(session, "SpeedBoi")
		if session.health >= session.stats.MaxHealth * 0.5 or session.time < (d.readyAt or 0) then
			return
		end
		local duration = math.min(15, 5 + 2.5 * (n - 1))
		d.readyAt = session.time + duration + 10
		session:setTimeSlow(duration)
	end,
}

HANDLERS.EnergyCore = {
	tick = function(session, n)
		local d = data(session, "EnergyCore")
		if session.time < (d.next or 0) then
			return
		end
		d.next = session.time + math.max(0.3, 2 / n)
		local targets = session.enemies:nearestN(rootPos(session), 35, n)
		for _, enemy in targets do
			homingHit(session, "EnergyCore", rootPos(session), enemy, levelDamage(session, 8) * (1 + session.stats.Damage), Color3.fromRGB(120, 255, 255), { flat = true })
		end
	end,
}

HANDLERS.Anvil = {} -- Offers: +1 atributo por copia en mejoras de arma

HANDLERS.SoulHarvester = {
	onKill = function(session, n, enemy)
		for _ = 1, 2 do
			local t = session.enemies:nearest(enemy.pos, 30)
			if t then
				homingHit(session, "SoulHarvester", enemy.pos, t, levelDamage(session, 5) * (1 + 0.5 * (n - 1)) * (1 + session.stats.Damage), Color3.fromRGB(180, 220, 255), { flat = true })
			end
		end
	end,
}

HANDLERS.JoesDagger = {
	damageMult = function(session, n)
		return 1 + 0.01 * n * (data(session, "JoesDagger").executes or 0)
	end,
	onHit = function(session, n, enemy, info)
		if rolls(session, 0.01, info.procCoef, false) == 0 then
			return
		end
		local d = data(session, "JoesDagger")
		if enemy.boss or enemy.miniboss then
			itemDamage(session, enemy, "JoesDagger", enemy.maxHealth * 0.02, { flat = true, canCrit = false })
		else
			itemDamage(session, enemy, "JoesDagger", enemy.health + 1, { flat = true, canCrit = false, kind = "execute" })
			if session.time >= (d.lastStack or -1) + 0.3 then
				d.lastStack = session.time
				d.executes = (d.executes or 0) + 1
			end
		end
	end,
}

HANDLERS.BloodyCleaver = {
	onHit = function(session, n, enemy, info)
		session.itemData.lastHitEnemy = enemy
		local stacks = rolls(session, 0.5 * n, info.procCoef)
		if stacks > 0 then
			Status.bloodmark(session, enemy, stacks)
		end
	end,
	onHeal = function(session, n, amount, source)
		local enemy = session.itemData.lastHitEnemy
		if source == "lifesteal" and enemy and not enemy.dead then
			session:after(0, function()
				Status.bloodmark(session, enemy, amount * n, true)
			end)
		end
	end,
}

HANDLERS.GoldenRing = {} -- sin efecto de combate (Golden Microwave pendiente)

HANDLERS.Snek = {
	onHit = function(session, n, enemy, info)
		Status.poison(session, enemy, 4 * n, "item:Snek")
		if rolls(session, 0.05 * n, info.procCoef) > 0 and (enemy.poison or 0) > 0 and enemy.poisonUntil then
			local ticks = math.max(0, (enemy.poisonUntil - session.time) / Config.Status.PoisonTick)
			local pending = enemy.poison * ticks * math.max(1, 1 + session.stats.Damage)
			itemDamage(session, enemy, "Snek", pending + levelDamage(session, 10), { flat = true, element = "Poison", kind = "poison" })
		end
	end,
}

-- Progresión +10, +9, ... mínimo +2 por copia.
local function capBonus(n: number): number
	local total = 0
	for i = 1, n do
		total += math.max(2, 11 - i)
	end
	return total
end

HANDLERS.PotStainlessSteel = {
	onAcquire = function(session)
		session.weaponLevelBonus = capBonus(count(session, "PotStainlessSteel"))
	end,
}

HANDLERS.WizardsHat = {
	onAcquire = function(session)
		session.tomeLevelBonus = capBonus(count(session, "WizardsHat"))
	end,
}

-- API ----------------------------------------------------------------------------------------

function Items.implemented(id: string): boolean
	return HANDLERS[id] ~= nil
end

function Items.applyStats(session, s)
	for id, n in session.items do
		local h = HANDLERS[id]
		if h and h.stats and n > 0 then
			h.stats(s, n, session)
		end
	end
end

function Items.postStats(session, s)
	for id, n in session.items do
		local h = HANDLERS[id]
		if h and h.post and n > 0 then
			h.post(s, n, session)
		end
	end
end

function Items.damageMult(session, enemy, info): number
	local m = 1
	for id, n in session.items do
		local h = HANDLERS[id]
		if h and h.damageMult and n > 0 then
			m *= h.damageMult(session, n, enemy, info)
		end
	end
	return m
end

-- Giant Fork: cada crítico puede ser megacrítico (×4 sobre el daño crítico, +0,15 por copia extra).
function Items.critMult(session): number
	local n = count(session, "GiantFork")
	if n > 0 and session.rng:NextNumber() < 0.14 * n then
		return 4 + 0.15 * (n - 1)
	end
	return 1
end

local function dispatch(event: string, session, ...)
	for id, n in session.items do
		local h = HANDLERS[id]
		local fn = h and h[event]
		if fn and n > 0 then
			fn(session, n, ...)
		end
	end
end

function Items.onHit(session, enemy, info, amount: number, isCrit: boolean)
	dispatch("onHit", session, enemy, info, amount)
	if isCrit then
		dispatch("onCrit", session, enemy, amount)
	end
end

function Items.onKill(session, enemy, info)
	dispatch("onKill", session, enemy, info)
end

function Items.onDamageTaken(session, amount: number, attacker, selfInflicted: boolean)
	dispatch("onDamageTaken", session, amount, attacker, selfInflicted)
end

function Items.onEvade(session, attacker)
	dispatch("onEvade", session, attacker)
end

function Items.onHeal(session, amount: number, source: string?)
	dispatch("onHeal", session, amount, source)
end

function Items.onThorns(session, enemy, thorns: number)
	dispatch("onThorns", session, enemy, thorns)
end

function Items.onInteract(session, kind: string)
	dispatch("onInteract", session, kind)
end

function Items.onMove(session, distance: number)
	dispatch("onMove", session, distance)
end

function Items.onAcquire(session, id: string)
	local h = HANDLERS[id]
	if h and h.onAcquire then
		h.onAcquire(session)
	end
end

function Items.tick(session, dt: number)
	for id, n in session.items do
		local h = HANDLERS[id]
		if h and h.tick and n > 0 then
			h.tick(session, n, dt)
		end
	end
end

-- Shattered Knowledge: las gemas atraídas dañan a los enemigos que atraviesan.
function Items.gemPass(session, gem)
	local n = count(session, "ShatteredKnowledge")
	if n == 0 then
		return
	end
	gem.hits = gem.hits or {}
	local level = data(session, "ShatteredKnowledge").level or session.level
	for _, enemy in session.enemies:query(gem.pos, 1.5) do
		if not gem.hits[enemy] then
			gem.hits[enemy] = true
			itemDamage(session, enemy, "ShatteredKnowledge", (5 + level) * n * (1 + session.stats.Damage), { flat = true })
		end
	end
end

-- Za Warudo: impide una muerte y detiene el tiempo 15 s; consume una copia.
function Items.tryPreventDeath(session): boolean
	local n = count(session, "ZaWarudo")
	if n <= 0 then
		return false
	end
	session:removeItem("ZaWarudo", 1)
	session.health = math.max(1, session.stats.MaxHealth * 0.3) -- [Pendiente] vida restaurada
	session.invulnUntil = session.time + 1
	for _, enemy in session.enemies.list do
		Status.stun(session, enemy, 15)
	end
	session.enemies:clearProjectiles()
	session:toast("¡ZA WARUDO! El tiempo se detiene.")
	return true
end

return Items
