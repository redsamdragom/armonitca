-- Armas automáticas: cada tipo (Projectile, Aura, Orbit) se dispara solo según su recarga.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Enemies = require(script.Parent.Enemies)
local PlayerState = require(script.Parent.PlayerState)

local Weapons = {}

local projectiles = {}
local visuals: { [Player]: any } = {}
local folder: Folder

local function effectPart(props): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Material = Enum.Material.Neon
	for key, value in props do
		p[key] = value
	end
	p.Parent = folder
	return p
end

function Weapons.init()
	folder = Instance.new("Folder")
	folder.Name = "WeaponEffects"
	folder.Parent = workspace
end

local function getVisuals(player: Player)
	local v = visuals[player]
	if not v then
		v = { Aura = nil, Blades = {} }
		visuals[player] = v
	end
	return v
end

local function fireProjectile(owner: Player, origin: Vector3, direction: Vector3, stats, damage: number)
	table.insert(projectiles, {
		Owner = owner,
		Part = effectPart({ Shape = Enum.PartType.Ball, Size = Vector3.one, Color = stats.Color, Position = origin }),
		Position = origin,
		Direction = direction,
		Speed = stats.Speed,
		Remaining = stats.Range,
		Damage = damage,
		Pierce = stats.Pierce,
		Hit = {},
	})
end

local function stepProjectileWeapon(player, state, id, stats, root, dt, damage, cooldown)
	state.Cooldowns[id] = (state.Cooldowns[id] or 0) - dt
	if state.Cooldowns[id] > 0 then
		return
	end
	local targets = Enemies.nearest(root.Position, stats.Range, stats.Count)
	if #targets == 0 then
		return
	end
	state.Cooldowns[id] = cooldown
	for i = 1, stats.Count do
		local target = targets[(i - 1) % #targets + 1]
		local direction = (target.Part.Position - root.Position).Unit
		fireProjectile(player, root.Position, direction, stats, damage)
	end
end

local function stepAura(player, state, id, stats, root, dt, damage, cooldown)
	local v = getVisuals(player)
	if not v.Aura then
		v.Aura = effectPart({ Shape = Enum.PartType.Cylinder, Color = stats.Color, Transparency = 0.75 })
	end
	v.Aura.Size = Vector3.new(0.3, stats.Radius * 2, stats.Radius * 2)
	v.Aura.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.8, 0)) * CFrame.Angles(0, 0, math.pi / 2)

	state.Cooldowns[id] = (state.Cooldowns[id] or 0) - dt
	if state.Cooldowns[id] > 0 then
		return
	end
	state.Cooldowns[id] = cooldown
	for _, enemy in Enemies.inRadius(root.Position, stats.Radius) do
		Enemies.damage(enemy, damage, player)
	end
end

local function stepOrbit(player, id, stats, root, now, damage, cooldown)
	local v = getVisuals(player)
	local blades = v.Blades
	while #blades < stats.Count do
		table.insert(blades, effectPart({ Size = Vector3.new(0.4, 0.4, 3), Color = stats.Color }))
	end
	while #blades > stats.Count do
		table.remove(blades):Destroy()
	end

	local hitKey = tostring(player.UserId) .. id
	local baseAngle = now * stats.RotationSpeed
	for i, blade in blades do
		local angle = baseAngle + (i - 1) * (2 * math.pi / #blades)
		local position = root.Position + Vector3.new(math.cos(angle) * stats.Radius, 0, math.sin(angle) * stats.Radius)
		blade.CFrame = CFrame.new(position) * CFrame.Angles(0, -angle, 0)
		for _, enemy in Enemies.inRadius(position, 1.5) do
			local last = enemy.HitTimes[hitKey]
			if not last or now - last >= cooldown then
				enemy.HitTimes[hitKey] = now
				Enemies.damage(enemy, damage, player)
			end
		end
	end
end

function Weapons.stepPlayer(player: Player, state, root: BasePart, dt: number, now: number)
	local playerStats = PlayerState.stats(state)
	for id, level in state.Weapons do
		local stats = Config.weaponStats(id, level)
		local damage = stats.Damage * playerStats.DamageMult
		local cooldown = stats.Cooldown * playerStats.CooldownMult
		if stats.Kind == "Projectile" then
			stepProjectileWeapon(player, state, id, stats, root, dt, damage, cooldown)
		elseif stats.Kind == "Aura" then
			stepAura(player, state, id, stats, root, dt, damage, cooldown)
		elseif stats.Kind == "Orbit" then
			stepOrbit(player, id, stats, root, now, damage, cooldown)
		end
	end
end

function Weapons.stepProjectiles(dt: number)
	for i = #projectiles, 1, -1 do
		local projectile = projectiles[i]
		local move = projectile.Speed * dt
		projectile.Position += projectile.Direction * move
		projectile.Remaining -= move
		projectile.Part.Position = projectile.Position

		for _, enemy in Enemies.inRadius(projectile.Position, 1) do
			if not projectile.Hit[enemy] then
				projectile.Hit[enemy] = true
				Enemies.damage(enemy, projectile.Damage, projectile.Owner)
				projectile.Pierce -= 1
				if projectile.Pierce <= 0 then
					break
				end
			end
		end

		if projectile.Pierce <= 0 or projectile.Remaining <= 0 then
			projectile.Part:Destroy()
			table.remove(projectiles, i)
		end
	end
end

function Weapons.clearPlayer(player: Player)
	local v = visuals[player]
	if not v then
		return
	end
	if v.Aura then
		v.Aura:Destroy()
	end
	for _, blade in v.Blades do
		blade:Destroy()
	end
	visuals[player] = nil
end

function Weapons.clearAll()
	for player in visuals do
		Weapons.clearPlayer(player)
	end
	for _, projectile in projectiles do
		projectile.Part:Destroy()
	end
	table.clear(projectiles)
end

return Weapons
