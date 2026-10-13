-- Genera una arena abierta con colinas, rampas y plataformas si el lugar no tiene una propia.
-- Para usar un mapa hecho a mano, crea en Workspace un Model o Folder llamado "Arena".

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local Map = {}

local function part(props): BasePart
	local className = props.ClassName or "Part"
	props.ClassName = nil
	local p = Instance.new(className)
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		p[key] = value
	end
	return p
end

function Map.build()
	if workspace:FindFirstChild("Arena") then
		return
	end

	local old = workspace:FindFirstChild("Baseplate")
	if old then
		old:Destroy()
	end

	local half = Config.Run.ArenaHalfSize
	local size = half * 2 + 40
	local rng = Random.new(42)

	local arena = Instance.new("Folder")
	arena.Name = "Arena"

	part({
		Name = "Floor",
		Size = Vector3.new(size, 2, size),
		CFrame = CFrame.new(0, -1, 0),
		Material = Enum.Material.Grass,
		Color = Color3.fromRGB(80, 140, 70),
		Parent = arena,
	})

	-- Muros invisibles en el borde
	for _, dir in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local isX = dir.X ~= 0
		part({
			Name = "Wall",
			Size = if isX then Vector3.new(4, 60, size) else Vector3.new(size, 60, 4),
			CFrame = CFrame.new(dir * (size / 2) + Vector3.new(0, 30, 0)),
			Transparency = 1,
			Parent = arena,
		})
	end

	-- Colinas: esferas semienterradas
	for _ = 1, 18 do
		local radius = rng:NextNumber(20, 45)
		local x, z = rng:NextNumber(-half, half), rng:NextNumber(-half, half)
		if Vector2.new(x, z).Magnitude > 40 then
			part({
				Name = "Hill",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * radius * 2,
				CFrame = CFrame.new(x, -radius * rng:NextNumber(0.55, 0.75), z),
				Material = Enum.Material.Grass,
				Color = Color3.fromRGB(70, 130, 65),
				Parent = arena,
			})
		end
	end

	-- Rampas y plataformas para saltar
	for _ = 1, 10 do
		local x, z = rng:NextNumber(-half, half), rng:NextNumber(-half, half)
		local yaw = rng:NextNumber(0, math.pi * 2)
		local height = rng:NextNumber(6, 14)
		local base = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
		part({
			ClassName = "WedgePart",
			Name = "Ramp",
			Size = Vector3.new(12, height, 24),
			CFrame = base * CFrame.new(0, height / 2, 0),
			Material = Enum.Material.Rock,
			Color = Color3.fromRGB(140, 130, 120),
			Parent = arena,
		})
		part({
			Name = "Platform",
			Size = Vector3.new(16, 2, 20),
			CFrame = base * CFrame.new(0, height - 1, -22),
			Material = Enum.Material.Rock,
			Color = Color3.fromRGB(140, 130, 120),
			Parent = arena,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(0, 0.5, 0)
	spawn.Transparency = 0.5
	spawn.Duration = 0
	spawn.Parent = arena

	arena.Parent = workspace
end

return Map
