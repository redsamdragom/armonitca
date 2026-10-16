-- Generación de mapas con semilla: terreno con colinas y mesetas, rampas, árboles o cactus,
-- ruinas y límites. Reglas por bioma en Data/Maps.luau. Dimensiones [Pendiente].

local Lighting = game:GetService("Lighting")

local MapGen = {}

local function rgb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function part(className: string, props): BasePart
	local p = Instance.new(className) :: BasePart
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

function MapGen.clear()
	local old = workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
	workspace.Terrain:Clear()
end

local function tree(folder, biome, rng, x: number, y: number, z: number)
	if biome.cactus then
		local h = rng:NextNumber(6, 12)
		local col = rgb(biome.treeTrunk)
		part("Part", { Name = "Cactus", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 2.2, 2.2), CFrame = CFrame.new(x, y + h / 2, z) * CFrame.Angles(0, 0, math.pi / 2), Color = col, Material = Enum.Material.Grass, Parent = folder })
		if rng:NextNumber() < 0.7 then
			local side = if rng:NextNumber() < 0.5 then 1 else -1
			part("Part", { Name = "CactusArm", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3.5, 1.4, 1.4), CFrame = CFrame.new(x + side * 1.6, y + h * 0.6, z) * CFrame.Angles(0, 0, math.pi / 2), Color = col, Material = Enum.Material.Grass, Parent = folder })
		end
		return
	end
	local h = rng:NextNumber(10, 18)
	part("Part", { Name = "Trunk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 2.4, 2.4), CFrame = CFrame.new(x, y + h / 2, z) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(biome.treeTrunk), Material = Enum.Material.Wood, Parent = folder })
	local r = rng:NextNumber(8, 13)
	part("Part", { Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.one * r, CFrame = CFrame.new(x, y + h + r * 0.25, z), Color = rgb(biome.treeLeaves), Material = Enum.Material.Grass, CanCollide = false, Parent = folder })
end

local function ruin(folder, biome, rng, x: number, y: number, z: number)
	local col = rgb(biome.ruinColor)
	local yaw = rng:NextNumber(0, math.pi * 2)
	local base = CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0)
	local kind = rng:NextInteger(1, 3)
	if kind == 1 then
		-- Muro roto con hueco
		for i = -2, 2 do
			if i ~= 0 or rng:NextNumber() < 0.3 then
				local h = rng:NextNumber(4, 10)
				part("Part", { Name = "Wall", Size = Vector3.new(4, h, 2), CFrame = base * CFrame.new(i * 4, h / 2, 0), Color = col, Material = Enum.Material.Cobblestone, Parent = folder })
			end
		end
	elseif kind == 2 then
		-- Columnas
		for i = 1, 4 do
			local a = i * math.pi / 2
			local h = rng:NextNumber(6, 14)
			part("Part", { Name = "Pillar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 2.5, 2.5), CFrame = base * CFrame.new(math.cos(a) * 7, h / 2, math.sin(a) * 7) * CFrame.Angles(0, 0, math.pi / 2), Color = col, Material = Enum.Material.Cobblestone, Parent = folder })
		end
		part("Part", { Name = "Floor", Size = Vector3.new(18, 1, 18), CFrame = base * CFrame.new(0, 0.5, 0), Color = col, Material = Enum.Material.Slate, Parent = folder })
	else
		-- Plataforma elevada con rampa
		local h = rng:NextNumber(6, 12)
		part("Part", { Name = "Platform", Size = Vector3.new(16, 2, 16), CFrame = base * CFrame.new(0, h, 0), Color = col, Material = Enum.Material.Slate, Parent = folder })
		for _, c in { { 7, 7 }, { -7, 7 }, { 7, -7 }, { -7, -7 } } do
			part("Part", { Name = "Leg", Size = Vector3.new(2, h, 2), CFrame = base * CFrame.new(c[1], h / 2, c[2]), Color = col, Material = Enum.Material.Cobblestone, Parent = folder })
		end
		local length = h * 2.2
		part("WedgePart", { Name = "Ramp", Size = Vector3.new(8, h + 1, length), CFrame = base * CFrame.new(0, (h + 1) / 2, 8 + length / 2) * CFrame.Angles(0, math.pi, 0), Color = col, Material = Enum.Material.Slate, Parent = folder })
	end
end

-- Genera el mapa y devuelve su información básica.
function MapGen.generate(map, seed: number)
	MapGen.clear()
	local rng = Random.new(seed)
	local biome = map.biome
	local size = map.size
	local half = size / 2
	local terrain = workspace.Terrain
	local groundMaterial = Enum.Material[biome.ground]
	local hillMaterial = Enum.Material[biome.hillMaterial]

	Lighting.FogColor = rgb(biome.fog)
	Lighting.FogStart = 120
	Lighting.FogEnd = 420
	Lighting.Ambient = rgb(biome.ambient)
	Lighting.OutdoorAmbient = rgb(biome.ambient)
	Lighting.ClockTime = 14

	terrain:SetMaterialColor(groundMaterial, rgb(biome.groundColor))
	terrain:FillBlock(CFrame.new(0, -8, 0), Vector3.new(size + 80, 16, size + 80), groundMaterial)

	local folder = Instance.new("Folder")
	folder.Name = "Map"

	-- Colinas
	for _ = 1, 26 do
		local r = rng:NextNumber(16, 42)
		local x, z = rng:NextNumber(-half, half), rng:NextNumber(-half, half)
		if Vector2.new(x, z).Magnitude > 40 then
			terrain:FillBall(Vector3.new(x, -r * rng:NextNumber(0.5, 0.75), z), r, hillMaterial)
		end
	end
	-- Mesetas de roca con escalones
	for _ = 1, 8 do
		local x, z = rng:NextNumber(-half + 30, half - 30), rng:NextNumber(-half + 30, half - 30)
		if Vector2.new(x, z).Magnitude > 50 then
			local h = rng:NextNumber(8, 16)
			local w = rng:NextNumber(20, 40)
			local yaw = rng:NextNumber(0, math.pi * 2)
			local cf = CFrame.new(x, h / 2 - 1, z) * CFrame.Angles(0, yaw, 0)
			terrain:FillBlock(cf, Vector3.new(w, h, w), Enum.Material.Rock)
			-- Rampa de acceso
			local length = h * 2.4
			part("WedgePart", {
				Name = "Ramp",
				Size = Vector3.new(10, h, length),
				CFrame = cf * CFrame.new(0, 0, w / 2 + length / 2) * CFrame.Angles(0, math.pi, 0),
				Color = rgb(biome.rock),
				Material = Enum.Material.Slate,
				Parent = folder,
			})
		end
	end

	-- Límites invisibles
	for _, dir in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local isX = dir.X ~= 0
		part("Part", {
			Name = "Boundary",
			Size = if isX then Vector3.new(4, 200, size + 8) else Vector3.new(size + 8, 200, 4),
			CFrame = CFrame.new(dir * (half + 2) + Vector3.new(0, 80, 0)),
			Transparency = 1,
			CanQuery = false,
			Parent = folder,
		})
	end

	folder.Parent = workspace

	-- Árboles y ruinas sobre la superficie resultante
	local function surface(x, z)
		local result = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0))
		return if result then result.Position.Y else 0
	end
	for _ = 1, biome.trees do
		local x, z = rng:NextNumber(-half + 8, half - 8), rng:NextNumber(-half + 8, half - 8)
		if Vector2.new(x, z).Magnitude > 25 then
			tree(folder, biome, rng, x, surface(x, z), z)
		end
	end
	for _ = 1, biome.ruins do
		local x, z = rng:NextNumber(-half + 20, half - 20), rng:NextNumber(-half + 20, half - 20)
		if Vector2.new(x, z).Magnitude > 40 then
			ruin(folder, biome, rng, x, surface(x, z), z)
		end
	end

	return { halfSize = half, folder = folder }
end

-- Posición aleatoria sobre suelo poco inclinado, lejos de `avoid`.
function MapGen.randomSpot(rng: Random, half: number, avoid: { Vector3 }, minGap: number, exclude: { Instance }?): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude or {}
	local fallback = Vector3.new(0, 1, 0)
	for _ = 1, 40 do
		local x, z = rng:NextNumber(-half + 10, half - 10), rng:NextNumber(-half + 10, half - 10)
		local result = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), params)
		if result and result.Normal.Y > 0.8 then
			local pos = result.Position
			fallback = pos
			local ok = true
			for _, other in avoid do
				if (other - pos).Magnitude < minGap then
					ok = false
					break
				end
			end
			if ok then
				return pos
			end
		end
	end
	return fallback
end

return MapGen
