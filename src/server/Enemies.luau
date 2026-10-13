-- Enemigos: aparición, persecución del jugador más cercano, daño por contacto y muerte.
-- Se usan Parts anclados movidos con BulkMoveTo en vez de Humanoids para soportar hordas grandes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Ground = require(script.Parent.Ground)

local Enemies = {}

local list = {}
local folder: Folder

-- Se llama con (enemy, killer: Player?) cuando un enemigo muere.
Enemies.onDeath = nil :: ((any, Player?) -> ())?

function Enemies.init()
	folder = Instance.new("Folder")
	folder.Name = "Enemies"
	folder.Parent = workspace
end

function Enemies.count(): number
	return #list
end

function Enemies.spawn(typeId: string, groundPosition: Vector3, healthScale: number)
	local def = Config.Enemies[typeId]
	local p = Instance.new("Part")
	p.Name = typeId
	p.Size = def.Size
	p.Color = def.Color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false

	local health = def.Health * healthScale
	local enemy = {
		Type = typeId,
		Def = def,
		Part = p,
		Health = health,
		MaxHealth = health,
		Radius = math.max(def.Size.X, def.Size.Z) / 2,
		HalfHeight = def.Size.Y / 2,
		GroundY = groundPosition.Y,
		GroundTimer = math.random() * 0.25,
		FlashUntil = 0,
		HitTimes = {},
		Position = groundPosition + Vector3.new(0, def.Size.Y / 2, 0),
		Dead = false,
	}
	p.CFrame = CFrame.new(enemy.Position)
	p.Parent = folder
	table.insert(list, enemy)
	return enemy
end

function Enemies.damage(enemy, amount: number, source: Player?)
	if enemy.Dead then
		return
	end
	enemy.Health -= amount
	enemy.Part.Color = enemy.Def.Color:Lerp(Color3.new(1, 1, 1), 0.6)
	enemy.FlashUntil = os.clock() + 0.08
	if enemy.Health <= 0 then
		enemy.Dead = true
		enemy.Position = enemy.Part.Position
		enemy.Part:Destroy()
		if Enemies.onDeath then
			Enemies.onDeath(enemy, source)
		end
	end
end

-- Enemigos vivos cuyo cuerpo toca la esfera (position, radius).
function Enemies.inRadius(position: Vector3, radius: number)
	local found = {}
	for _, enemy in list do
		if not enemy.Dead and (enemy.Part.Position - position).Magnitude <= radius + enemy.Radius then
			table.insert(found, enemy)
		end
	end
	return found
end

-- Hasta `count` enemigos vivos más cercanos dentro de `range`, ordenados por distancia.
function Enemies.nearest(position: Vector3, range: number, count: number)
	local candidates = {}
	for _, enemy in list do
		if not enemy.Dead then
			local distance = (enemy.Part.Position - position).Magnitude
			if distance <= range then
				table.insert(candidates, { enemy = enemy, distance = distance })
			end
		end
	end
	table.sort(candidates, function(a, b)
		return a.distance < b.distance
	end)
	local result = {}
	for i = 1, math.min(count, #candidates) do
		result[i] = candidates[i].enemy
	end
	return result
end

-- targets: { { root: BasePart, humanoid: Humanoid } }
function Enemies.step(dt: number, targets)
	local parts, cframes = {}, {}
	local now = os.clock()
	local i = 1
	while i <= #list do
		local enemy = list[i]
		if enemy.Dead then
			list[i] = list[#list]
			list[#list] = nil
			continue
		end

		local position = enemy.Part.Position
		local nearest, nearestDistance = nil, math.huge
		for _, target in targets do
			local distance = (target.root.Position - position).Magnitude
			if distance < nearestDistance then
				nearest, nearestDistance = target, distance
			end
		end

		local newPosition = position
		local facing = nil
		if nearest then
			local flat = (nearest.root.Position - position) * Vector3.new(1, 0, 1)
			local flatDistance = flat.Magnitude
			if flatDistance > 0.1 then
				facing = flat.Unit
				local move = math.min(enemy.Def.Speed * dt, math.max(0, flatDistance - enemy.Radius))
				newPosition = position + facing * move
			end
			local verticalGap = math.abs(nearest.root.Position.Y - position.Y)
			if flatDistance <= enemy.Radius + 2 and verticalGap < enemy.HalfHeight + 4 then
				nearest.humanoid:TakeDamage(enemy.Def.Damage * dt)
			end
		end

		enemy.GroundTimer -= dt
		if enemy.GroundTimer <= 0 then
			enemy.GroundTimer = 0.25
			enemy.GroundY = Ground.height(newPosition, enemy.GroundY)
		end
		local targetY = enemy.GroundY + enemy.HalfHeight
		local y = position.Y + (targetY - position.Y) * math.min(1, dt * 10)
		local final = Vector3.new(newPosition.X, y, newPosition.Z)

		if enemy.FlashUntil > 0 and now >= enemy.FlashUntil then
			enemy.FlashUntil = 0
			enemy.Part.Color = enemy.Def.Color
		end

		table.insert(parts, enemy.Part)
		table.insert(cframes, if facing then CFrame.lookAt(final, final + facing) else CFrame.new(final))
		i += 1
	end

	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function Enemies.clear()
	for _, enemy in list do
		enemy.Dead = true
		enemy.Part:Destroy()
	end
	table.clear(list)
end

return Enemies
