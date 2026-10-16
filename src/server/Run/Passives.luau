-- Pasivas especiales de los personajes (las bonificaciones planas por nivel están en los datos).
-- Coeficientes marcados [Pendiente] son provisionales.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Fx = require(script.Parent.Parent.Combat.Fx)
local Damage = require(script.Parent.Parent.Combat.Damage)
local Status = require(script.Parent.Parent.Combat.Status)
local Weapons = require(script.Parent.Parent.Combat.Weapons)

local Passives = {}

local U = Config.UnitToStuds

local function special(session): string?
	return session.character.passive.special
end

-- Robinette: tramos de daño por oro [Pendiente: umbrales exactos]
local STONKS_TIERS = {
	{ upTo = 10000, per1000 = 0.10 },
	{ upTo = 100000, per1000 = 0.05 },
	{ upTo = 1000000, per1000 = 0.02 },
	{ upTo = math.huge, per1000 = 0.035 }, -- v1.0.64: 3,5% por 1.000 tras un millón
}

local function stonksBonus(gold: number): number
	local bonus, previous = 0, 0
	for _, tier in STONKS_TIERS do
		local span = math.min(gold, tier.upTo) - previous
		if span <= 0 then
			break
		end
		bonus += span / 1000 * tier.per1000
		previous = tier.upTo
	end
	return bonus
end
Passives.stonksBonus = stonksBonus

function Passives.damageMult(session, enemy, info): number
	local kind = special(session)
	local d = session.passiveData
	if kind == "Momentum" then
		-- +0,5% de daño por cada 1% de multiplicador de velocidad, según el impulso alcanzado
		local momentum = session.momentum or 0
		local speedBonus = math.max(0, session.stats.MoveSpeed + 0.6 * momentum)
		return 1 + 0.5 * speedBonus * momentum
	elseif kind == "Flex" then
		return 1 + 0.025 * (d.flexStacks or 0)
	elseif kind == "LockIn" then
		local ratio = math.clamp(session.health / session.stats.MaxHealth, 0, 1)
		return 1 + 0.5 * (1 - ratio) -- [Pendiente]
	elseif kind == "Stonks" then
		return 1 + stonksBonus(session.gold)
	elseif kind == "Enduring" then
		return 1 + 0.015 * session.frozenCount
	end
	return 1
end

function Passives.speedMult(session): number
	if special(session) == "Momentum" then
		return 1 + 0.6 * (session.momentum or 0) -- [Pendiente] velocidad extra por impulso
	end
	return 1
end

function Passives.onHit(session, enemy, info, amount: number)
	if special(session) == "Bullseye" and session.passiveData.mark == enemy and info.weapon then
		session.passiveData.mark = nil
		local radius = 4 * session.stats.Size + 4
		Fx.flash("Ball", CFrame.new(enemy.pos), Vector3.one * radius * 2, Color3.fromRGB(255, 60, 60), 0.2, 0.5)
		for _, other in session.enemies:query(enemy.pos, radius) do
			Damage.toEnemy(session, other, { source = "passive:Bullseye", amount = amount * 0.5, flat = true, procCoef = 0, depth = 1 })
		end
	end
end

function Passives.tryBlock(session, attacker): boolean
	if special(session) ~= "Flex" then
		return false
	end
	local d = session.passiveData
	if session.time < (d.flexReadyAt or 0) then
		return false
	end
	local cooldown = math.max(3, 12 - 0.2 * (session.level - 1)) -- [Pendiente]
	d.flexReadyAt = session.time + cooldown
	d.flexStacks = (d.flexStacks or 0) + 1
	local radius = 9
	Fx.ring(session.root.Position, radius, Color3.fromRGB(255, 220, 160), 0.25)
	for _, enemy in session.enemies:query(session.root.Position, radius) do
		Status.stun(session, enemy, 1.5)
	end
	session:toast("¡Flex!")
	return true
end

function Passives.onEvade(session, attacker)
	if special(session) == "Shadowstep" and attacker and not attacker.dead then
		local amount = if attacker.boss or attacker.miniboss then attacker.maxHealth * 0.02 else attacker.health + 1
		Fx.beam(session.root.Position, attacker.pos, 0.5, Color3.fromRGB(40, 40, 60), 0.15)
		Damage.toEnemy(session, attacker, {
			source = "passive:Shadowstep",
			amount = amount,
			flat = true,
			canCrit = false,
			procCoef = 0,
			kind = "execute",
		})
	end
end

function Passives.onDamageTaken(session, amount: number, attacker)
	if special(session) == "Momentum" and session.momentum then
		local loss = 0.25 * math.max(0.4, 1 - session.level / 200) -- menor a niveles altos [Pendiente]
		session.momentum *= 1 - loss
	end
end

function Passives.onKill(session, enemy)
	if special(session) == "Plague" and (enemy.poison or 0) > 0 then
		local growth = math.min(1, (session.level - 1) / 220)
		local radius = (4 + 8 * growth) * U * (1 + session.stats.Size)
		Fx.flash("Ball", CFrame.new(enemy.pos), Vector3.one * radius * 2, Status.POISON_COLOR, 0.2, 0.55)
		for _, other in session.enemies:query(enemy.pos, radius) do
			if other ~= enemy then
				Status.poison(session, other, enemy.poison, "passive:Plague")
			end
		end
	end
end

-- Dicehead: una tirada por nivel; eficiencia 75%, mínimo 6% (v1.0.49) [Pendiente: fórmula exacta]
local TOME_VALUE = {}
for _, tome in ipairs(Catalog.Tomes) do
	TOME_VALUE[tome.stat] = tome.value
end

function Passives.onLevelUp(session)
	if special(session) ~= "Gamba" then
		return
	end
	local pool = Catalog.ChaosPool
	local stat = pool[session.rng:NextInteger(1, #pool)]
	local efficiency = math.max(0.06, 0.75 / (1 + 0.04 * (session.level - 2)))
	local gain = (TOME_VALUE[stat] or 0.05) * efficiency
	session.bonus[stat] = (session.bonus[stat] or 0) + gain
	session.statsDirty = true
	session:toast(string.format("Gamba: %s", stat))
end

local function markTarget(session)
	local d = session.passiveData
	if d.mark and not d.mark.dead then
		return
	end
	d.mark = session.enemies:random(session.root.Position, 45)
	if d.markPart then
		d.markPart.Parent = nil
	end
	if d.mark then
		if not d.markPart then
			local p = Instance.new("Part")
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
			p.Shape = Enum.PartType.Cylinder
			p.Material = Enum.Material.Neon
			p.Color = Color3.fromRGB(255, 50, 50)
			p.Transparency = 0.3
			d.markPart = p
		end
		d.markPart.Parent = Fx.folder()
	end
end

function Passives.tick(session, dt: number)
	local kind = special(session)
	local d = session.passiveData
	if kind == "Momentum" then
		local moving = session.horizontalSpeed > session.walkSpeed * 0.5
		session.momentum = math.clamp((session.momentum or 0) + (if moving then dt / 4 else -dt / 1.5), 0, 1)
	elseif kind == "LockIn" then
		local bonus = if Weapons.aegisActive(session) then 0 else 1.5
		if bonus ~= session.passiveAttackSpeed then
			session.passiveAttackSpeed = bonus
			session.statsDirty = true
		end
	elseif kind == "Zap" then
		d.charge = (d.charge or 0) + session.frameDistance
		if d.charge >= 30 then -- [Pendiente] distancia por carga
			d.charge = 0
			for _, enemy in session.enemies:nearestN(session.root.Position, 25, 3) do
				Fx.beam(session.root.Position, enemy.pos, 0.35, Color3.fromRGB(255, 240, 80), 0.12)
				Damage.toEnemy(session, enemy, {
					source = "passive:Zap",
					amount = 10 + session.level,
					element = "Electric",
					procCoef = 0.5,
					depth = 1,
				})
			end
		end
	elseif kind == "Bullseye" then
		d.markTimer = (d.markTimer or 0) - dt
		if d.markTimer <= 0 then
			d.markTimer = 3
			markTarget(session)
		end
		if d.markPart and d.mark and not d.mark.dead then
			local r = d.mark.radius + 1
			d.markPart.Size = Vector3.new(0.2, r * 2, r * 2)
			d.markPart.CFrame = CFrame.new(d.mark.pos + Vector3.new(0, d.mark.halfHeight + 1, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		elseif d.markPart then
			d.markPart.Parent = nil
		end
	elseif kind == "Hoarder" then
		d.chestTimer = (d.chestTimer or 60) - dt
		if d.chestTimer <= 0 then
			d.chests = (d.chests or 0) + 1
			d.chestTimer = math.min(120, 60 + 2.5 * d.chests)
			session:spawnFreeChest()
		end
	end
end

function Passives.cleanup(session)
	local d = session.passiveData
	if d.markPart then
		d.markPart:Destroy()
	end
end

return Passives
