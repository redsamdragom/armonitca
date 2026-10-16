-- Recogidas del suelo: experiencia, oro, plata, hamburguesas y powerups temporales.
-- Los powerups son recompensas temporales separadas del inventario de objetos.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Fx = require(script.Parent.Parent.Combat.Fx)
local Items = require(script.Parent.Parent.Combat.Items)
local Damage = require(script.Parent.Parent.Combat.Damage)

local Pickups = {}

local MAX_GEMS = 350
local MAGNET_SPEED = 70
local COLLECT_DISTANCE = 2.6

local LOOK = {
	XP = { "Ball", Color3.fromRGB(80, 220, 255) },
	Gold = { "Cylinder", Color3.fromRGB(255, 210, 60) },
	Silver = { "Cylinder", Color3.fromRGB(220, 230, 240) },
	Burger = { "Block", Color3.fromRGB(200, 120, 50) },
	Powerup = { "Ball", Color3.fromRGB(255, 120, 255) },
}

-- Powerups [Pendiente: catálogo, duraciones y probabilidades exactas]
Pickups.Powerups = {
	Heal = { name = "Curación", color = Color3.fromRGB(80, 255, 120) },
	Magnet = { name = "Imán", color = Color3.fromRGB(120, 200, 255) },
	Rage = { name = "Furia", color = Color3.fromRGB(255, 80, 80), duration = 10, stats = { Damage = 0.5 } },
	Haste = { name = "Prisa", color = Color3.fromRGB(255, 230, 80), duration = 10, stats = { AttackSpeed = 0.5, MoveSpeed = 0.3 } },
	Shield = { name = "Invulnerable", color = Color3.fromRGB(230, 230, 255), duration = 5 },
}
local POWERUP_KEYS = { "Heal", "Magnet", "Rage", "Haste", "Shield" }

function Pickups.spawn(session, kind: string, position: Vector3, value: number, opts: any?)
	local list = session.pickups
	if kind == "XP" and session.gemCount >= MAX_GEMS then
		-- Agrupa con la gema más cercana sin perder valor
		local best, bestD = nil, math.huge
		for _, p in list do
			if p.kind == "XP" and not p.target then
				local d = (p.pos - position).Magnitude
				if d < bestD then
					best, bestD = p, d
				end
			end
		end
		if best then
			best.value += value
			return best
		end
	end
	local look = LOOK[kind]
	local size = if kind == "XP" then Vector3.one * math.clamp(0.8 + value * 0.08, 0.8, 2.2)
		elseif kind == "Gold" or kind == "Silver" then Vector3.new(0.3, 1.2, 1.2)
		else Vector3.one * 1.6
	local col = look[2]
	local powerup = opts and opts.powerup
	if powerup then
		col = Pickups.Powerups[powerup].color
	end
	local part = Fx.acquire(look[1], col, size)
	local pos = position + Vector3.new(0, 0.6, 0)
	part.Position = pos
	local pickup = {
		kind = kind,
		value = value,
		pos = pos,
		part = part,
		powerup = powerup,
		expires = opts and opts.lifetime and (session.time + opts.lifetime) or nil,
	}
	table.insert(list, pickup)
	if kind == "XP" then
		session.gemCount += 1
	end
	return pickup
end

function Pickups.magnetAll(session, radius: number?)
	local rootPos = session.root.Position
	for _, p in session.pickups do
		if p.kind == "XP" and (not radius or (p.pos - rootPos).Magnitude <= radius) then
			p.target = true
		end
	end
end

function Pickups.maybePowerup(session, position: Vector3, baseChance: number)
	local chance = baseChance * (1 + session.stats.PowerupChance)
	if session.rng:NextNumber() < chance then
		local key = POWERUP_KEYS[session.rng:NextInteger(1, #POWERUP_KEYS)]
		Pickups.spawn(session, "Powerup", position, 0, { powerup = key, lifetime = 30 })
	end
end

local function applyPowerup(session, key: string)
	local def = Pickups.Powerups[key]
	local duration = (def.duration or 0) * (1 + session.stats.PowerupMult)
	session.runFlags.pickedPowerup = true
	if key == "Heal" then
		Damage.heal(session, session.stats.MaxHealth * 0.3 * (1 + session.stats.PowerupMult), "powerup")
	elseif key == "Magnet" then
		Pickups.magnetAll(session)
	elseif key == "Shield" then
		session.invulnUntil = math.max(session.invulnUntil, session.time + duration)
	else
		session:addTimedStats(def.stats, duration)
	end
	session:toast("Powerup: " .. def.name)
end

local function collect(session, p)
	if p.kind == "XP" then
		session:gainXP(p.value)
	elseif p.kind == "Gold" then
		session:gainGold(p.value)
	elseif p.kind == "Silver" then
		session.silverFound += p.value
	elseif p.kind == "Burger" then
		Damage.heal(session, p.value, "Borgar")
	elseif p.kind == "Powerup" then
		applyPowerup(session, p.powerup)
	end
end

function Pickups.step(session, dt: number)
	local list = session.pickups
	local rootPos = session.root.Position
	local radius = session.pickupRadius
	local parts, cframes = {}, {}
	for i = #list, 1, -1 do
		local p = list[i]
		local remove = false
		if p.expires and session.time >= p.expires then
			remove = true
		else
			local delta = rootPos - p.pos
			local distance = delta.Magnitude
			local reach = if p.kind == "Gold" then radius * 1.5 else radius
			if not p.target and distance <= reach then
				p.target = true
			end
			if p.target then
				if distance <= COLLECT_DISTANCE then
					collect(session, p)
					remove = true
				else
					p.pos += delta.Unit * math.min(distance, MAGNET_SPEED * dt)
					if p.kind == "XP" then
						Items.gemPass(session, p)
					end
				end
			end
		end
		if remove then
			if p.kind == "XP" then
				session.gemCount -= 1
			end
			Fx.release(p.part)
			list[i] = list[#list]
			list[#list] = nil
		elseif p.target then
			table.insert(parts, p.part)
			table.insert(cframes, CFrame.new(p.pos))
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function Pickups.clear(session)
	for _, p in session.pickups do
		Fx.release(p.part)
	end
	table.clear(session.pickups)
	session.gemCount = 0
end

Pickups.CHANCE_ON_KILL = 0.004 -- [Pendiente]
Pickups.CHANCE_ON_POT = 0.08 -- [Pendiente]
Pickups.UNIT = Config.UnitToStuds

return Pickups
