-- Escena 3D de fondo del menú principal: claro de bosque de baja poligonización con torre en ruinas,
-- mesa con microondas, cabeza de piedra, antorcha y farol, vista con cámara fija y desenfoque.
-- Sólo existe en el cliente (no se replica) y se construye lejos del mapa que genera el servidor.

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local MenuScene = {}

-- Centro de la escena (suelo en y = 0 local). Todo lo demás se coloca relativo a este punto.
local ORIGIN = CFrame.new(0, 1000, 0)
-- Cámara casi horizontal un poco por encima del microondas, mirando hacia -Z.
local CAMERA = CFrame.new(0, 7.5, 0) * CFrame.Angles(math.rad(-1), 0, 0)
local FOV = 70
-- Distancia de la cámara a la mesa y la antorcha: es el plano enfocado; lo demás queda borroso.
local FOCUS = 18

local L = Lighting :: any

-- Ajustes de Lighting mientras la escena está visible (se guardan y restauran al ocultarla).
local LIGHTING = {
	Ambient = Color3.fromRGB(66, 88, 96),
	OutdoorAmbient = Color3.fromRGB(108, 136, 140),
	Brightness = 2.4,
	ClockTime = 14.6,
	ColorShift_Top = Color3.fromRGB(255, 238, 210),
	ColorShift_Bottom = Color3.fromRGB(0, 0, 0),
	EnvironmentDiffuseScale = 0.4,
	EnvironmentSpecularScale = 0.2,
	ExposureCompensation = 0.1,
	GlobalShadows = true,
	ShadowSoftness = 0.4,
	FogStart = 0,
	FogEnd = 100000,
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local GRASS = rgb(64, 104, 42)
local LEAVES = { rgb(72, 132, 48), rgb(58, 116, 42), rgb(88, 146, 56), rgb(50, 100, 38), rgb(98, 152, 60) }
local BLADES = { rgb(46, 82, 30), rgb(58, 98, 36), rgb(70, 112, 42), rgb(40, 72, 28) }
local BARK = rgb(112, 72, 42)
local BARK_DARK = rgb(84, 56, 34)
local STONE = rgb(134, 136, 130)
local STONE_DARK = rgb(104, 106, 100)
local MOSS = rgb(70, 122, 46)
local TABLE = rgb(122, 124, 122)
local TABLE_TOP = rgb(138, 140, 138)
local MICRO = rgb(36, 94, 192)
local MICRO_LIGHT = rgb(46, 110, 212)
local MICRO_DARK = rgb(26, 70, 150)
local IRON = rgb(40, 42, 48)

local folder: Folder? = nil
local effects: { Instance } = {}
local torchLight: PointLight? = nil
local connection: RBXScriptConnection? = nil
local shown = false
local clock = 0
local savedFov: number? = nil
local savedLighting = {}
local appliedLighting = {}
-- Cielos, atmósferas y efectos del lugar apartados mientras se muestra la escena.
local displaced = {}

-- Piezas --------------------------------------------------------------------------------------

-- Pieza anclada, sin colisión ni consultas (los raycasts del juego nunca la tocan). `cf` es relativo al centro.
local function piece(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, shape: string?): BasePart
	local p: BasePart
	if shape == "Wedge" then
		p = Instance.new("WedgePart")
	else
		local part = Instance.new("Part")
		if shape == "Ball" then
			part.Shape = Enum.PartType.Ball
		elseif shape == "Cylinder" then
			part.Shape = Enum.PartType.Cylinder
		end
		p = part
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = ORIGIN * cf
	p.Color = color
	p.Material = material
	p.Parent = parent
	return p
end

local function group(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Giro aleatorio completo en Y con una inclinación de hasta `degrees` en X y Z.
local function tilt(rng: Random, degrees: number): CFrame
	local d = math.rad(degrees)
	return CFrame.Angles(rng:NextNumber(-d, d), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-d, d))
end

local function leaf(rng: Random): Color3
	return LEAVES[rng:NextInteger(1, #LEAVES)]
end

-- Posición sobre el suelo a `distance` studs de la cámara y `angle` radianes a su derecha.
local function polar(angle: number, distance: number): Vector3
	return Vector3.new(math.sin(angle) * distance, 0, -math.cos(angle) * distance)
end

-- Marco en `pos` girado en Y para que su frente (-Z) mire hacia la cámara, más `yaw` grados.
local function facingCamera(pos: Vector3, yaw: number): CFrame
	return CFrame.new(pos) * CFrame.Angles(0, math.atan2(pos.X, pos.Z) + math.rad(yaw), 0)
end

-- Árboles -------------------------------------------------------------------------------------

-- Copa cúbica: tronco y dos o tres bloques de hojas girados.
local function cubeTree(parent: Instance, rng: Random, pos: Vector3, height: number, crown: number)
	local base = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local width = math.max(0.7, crown * 0.15)
	piece(parent, Vector3.new(width, height, width), base * CFrame.new(0, height / 2, 0), BARK, Enum.Material.Wood)
	local color = leaf(rng)
	local top = base * CFrame.new(0, height + crown * 0.25, 0)
	piece(parent, Vector3.new(crown, crown * 0.85, crown), top * tilt(rng, 10), color, Enum.Material.Grass)
	for _ = 1, rng:NextInteger(1, 2) do
		local s = crown * rng:NextNumber(0.45, 0.65)
		local offset = CFrame.new(rng:NextNumber(-0.4, 0.4) * crown, rng:NextNumber(0.1, 0.4) * crown, rng:NextNumber(-0.4, 0.4) * crown)
		piece(parent, Vector3.new(s, s, s), top * offset * tilt(rng, 25), if rng:NextNumber() < 0.5 then color else leaf(rng), Enum.Material.Grass)
	end
end

-- Copa cónica: capas de bloques que se estrechan hacia arriba, cada una girada.
local function pineTree(parent: Instance, rng: Random, pos: Vector3, height: number, crown: number)
	local base = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi / 2), 0)
	local trunk = height * 0.3
	local width = math.max(0.6, crown * 0.14)
	piece(parent, Vector3.new(width, trunk + 1, width), base * CFrame.new(0, (trunk + 1) / 2, 0), BARK, Enum.Material.Wood)
	local color = leaf(rng)
	local layer = (height - trunk) / 3
	for i = 0, 2 do
		local s = crown * (1 - i * 0.3)
		local cf = base * CFrame.new(0, trunk + layer * (i + 0.5), 0) * CFrame.Angles(0, math.rad(i * 30), 0)
		piece(parent, Vector3.new(s, layer * 1.2, s), cf, color, Enum.Material.Grass)
	end
	piece(parent, Vector3.new(crown * 0.2, layer * 0.7, crown * 0.2), base * CFrame.new(0, height + layer * 0.2, 0), color, Enum.Material.Grass)
end

-- Copa redondeada: una o varias bolas de hojas.
local function roundTree(parent: Instance, rng: Random, pos: Vector3, height: number, crown: number)
	local base = CFrame.new(pos)
	local width = math.max(0.6, crown * 0.14)
	piece(parent, Vector3.new(width, height, width), base * CFrame.new(0, height / 2, 0), BARK_DARK, Enum.Material.Wood)
	local color = leaf(rng)
	piece(parent, Vector3.one * crown, base * CFrame.new(0, height + crown * 0.2, 0), color, Enum.Material.Grass, "Ball")
	for _ = 1, rng:NextInteger(0, 2) do
		local s = crown * rng:NextNumber(0.5, 0.7)
		local offset = CFrame.new(rng:NextNumber(-0.45, 0.45) * crown, height + rng:NextNumber(-0.1, 0.3) * crown, rng:NextNumber(-0.45, 0.45) * crown)
		piece(parent, Vector3.one * s, base * offset, color, Enum.Material.Grass, "Ball")
	end
end

local TREES = { cubeTree, cubeTree, pineTree, roundTree }

-- Bosque: árboles colocados a mano según la composición y relleno aleatorio más lejos.
local function buildForest(parent: Instance, rng: Random)
	local f = group(parent, "Bosque")
	-- Primer plano y plano medio (alineados con la captura de referencia)
	cubeTree(f, rng, Vector3.new(-19.3, 0, -18.8), 6.2, 7.6)
	cubeTree(f, rng, Vector3.new(-17.5, 0, -25), 4.2, 5.6)
	cubeTree(f, rng, Vector3.new(23, 0, -24.5), 7, 10.5)
	pineTree(f, rng, Vector3.new(8.2, 0, -30), 9.5, 4.6)
	pineTree(f, rng, Vector3.new(19, 0, -42), 10.5, 5.2)
	pineTree(f, rng, Vector3.new(2, 0, -42), 11, 5)
	roundTree(f, rng, Vector3.new(-11, 0, -38), 6, 5)
	cubeTree(f, rng, Vector3.new(30, 0, -36), 8, 8)
	cubeTree(f, rng, Vector3.new(-33, 0, -30), 7, 9)

	-- Relleno: dos franjas de árboles; se deja despejada la línea de visión a la torre y a las ruinas
	local placed = 0
	local tries = 0
	while placed < 56 and tries < 400 do
		tries += 1
		local far = placed >= 28
		local angle = rng:NextNumber(math.rad(-66), math.rad(66))
		local distance = if far then rng:NextNumber(75, 130) else rng:NextNumber(40, 75)
		local blocksTower = angle > math.rad(-42) and angle < math.rad(-22) and distance < 58
		local blocksRuins = angle > math.rad(14) and angle < math.rad(34) and distance < 42
		if not blocksTower and not blocksRuins then
			placed += 1
			local height = if far then rng:NextNumber(9, 15) else rng:NextNumber(6, 10)
			local crown = height * rng:NextNumber(0.5, 0.75)
			TREES[rng:NextInteger(1, #TREES)](f, rng, polar(angle, distance), height, crown)
		end
	end

	-- Copas gigantes muy al fondo, sobre todo a la derecha: la atmósfera las deja como siluetas
	-- azuladas contra el cielo y el bosque cercano tapa sus troncos (ángulo, distancia, tronco, copa)
	for _, g in { { -12, 340, 44, 80 }, { 6, 300, 42, 84 }, { 22, 290, 46, 92 }, { 38, 320, 48, 96 }, { 54, 280, 44, 88 }, { 66, 300, 40, 80 } } do
		cubeTree(f, rng, polar(math.rad(g[1]), g[2]), g[3], g[4])
	end
end

-- Suelo y vegetación baja ---------------------------------------------------------------------

-- Zonas que la vegetación baja no debe invadir: x, z y radio.
local CLEAR = {
	{ -8.9, -16.4, 4.6 }, -- mesa
	{ 5.9, -15.3, 1.2 }, -- antorcha
	{ -6.2, -23, 2.6 }, -- cabeza de piedra
	{ -3.4, -24.6, 1.4 }, -- barril
	{ 3.9, -26, 1 }, -- farol
	{ -4, -31.5, 3.2 }, -- muro
}

local function isClear(pos: Vector3, margin: number): boolean
	for _, c in CLEAR do
		if Vector2.new(pos.X - c[1], pos.Z - c[2]).Magnitude < c[3] + margin then
			return false
		end
	end
	return true
end

local function buildGround(parent: Instance, rng: Random)
	local f = group(parent, "Suelo")
	piece(f, Vector3.new(1600, 2, 1600), CFrame.new(0, -1, -400), GRASS, Enum.Material.Grass)
	-- Lomas suaves al fondo para romper la línea del horizonte
	for _, m in { { -62, -42, -105, 100 }, { 58, -45, -98, 100 }, { -5, -64, -175, 140 }, { 120, -50, -170, 120 }, { -130, -50, -160, 120 } } do
		piece(f, Vector3.one * m[4], CFrame.new(m[1], m[2], m[3]), GRASS, Enum.Material.Grass, "Ball")
	end

	-- Matas de hierba alta: hojas finas en cuña, más densas cerca de la cámara
	local tufts = group(parent, "Hierba")
	local placed = 0
	while placed < 64 do
		local pos = polar(rng:NextNumber(math.rad(-58), math.rad(58)), 10.5 + rng:NextNumber() ^ 1.6 * 22)
		if isClear(pos, 0.3) then
			placed += 1
			local color = BLADES[rng:NextInteger(1, #BLADES)]
			for _ = 1, rng:NextInteger(2, 4) do
				local h = rng:NextNumber(0.7, 1.6)
				local cf = CFrame.new(pos + Vector3.new(rng:NextNumber(-0.3, 0.3), h / 2 - 0.05, rng:NextNumber(-0.3, 0.3)))
					* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
					* CFrame.Angles(math.rad(rng:NextNumber(-12, 12)), 0, math.rad(rng:NextNumber(-12, 12)))
				local blade = piece(tufts, Vector3.new(0.12, h, rng:NextNumber(0.4, 0.8)), cf, color, Enum.Material.Grass, "Wedge")
				blade.CastShadow = false
			end
		end
	end

	-- Arbustos de bloques
	local bushes = group(parent, "Arbustos")
	placed = 0
	while placed < 18 do
		local pos = polar(rng:NextNumber(math.rad(-62), math.rad(62)), rng:NextNumber(16, 40))
		if isClear(pos, 1.2) then
			placed += 1
			local color = BLADES[rng:NextInteger(1, #BLADES)]:Lerp(leaf(rng), 0.5)
			for _ = 1, rng:NextInteger(2, 4) do
				local s = rng:NextNumber(0.9, 2)
				local cf = CFrame.new(pos + Vector3.new(rng:NextNumber(-0.9, 0.9), s * 0.3, rng:NextNumber(-0.9, 0.9))) * tilt(rng, 15)
				piece(bushes, Vector3.new(s, s * 0.8, s), cf, color, Enum.Material.Grass)
			end
		end
	end

	-- Rocas sueltas
	placed = 0
	while placed < 8 do
		local pos = polar(rng:NextNumber(math.rad(-60), math.rad(60)), rng:NextNumber(24, 45))
		if isClear(pos, 1) then
			placed += 1
			local s = rng:NextNumber(0.6, 1.6)
			local shade = if rng:NextNumber() < 0.5 then STONE else STONE_DARK
			piece(bushes, Vector3.new(s * 1.3, s * 0.7, s), CFrame.new(pos + Vector3.new(0, s * 0.2, 0)) * tilt(rng, 14), shade, Enum.Material.Slate)
		end
	end
end

-- Construcciones ------------------------------------------------------------------------------

-- Torre de ladrillo en ruinas con musgo, al fondo a la izquierda.
local function buildTower(parent: Instance, rng: Random)
	local f = group(parent, "Torre")
	local base = CFrame.new(-28.5, 0, -47) * CFrame.Angles(0, math.rad(-8), 0)
	local W, H = 11, 14
	piece(f, Vector3.new(W, H, W), base * CFrame.new(0, H / 2, 0), STONE, Enum.Material.Brick)
	piece(f, Vector3.new(W + 1, 2, W + 1), base * CFrame.new(0, 1, 0), STONE_DARK, Enum.Material.Cobblestone)
	piece(f, Vector3.new(W + 0.8, 0.8, W + 0.8), base * CFrame.new(0, H + 0.4, 0), STONE_DARK, Enum.Material.Brick)
	-- Almenas de alturas irregulares; las que faltan dejan la cima rota
	for _, m in { { -4.6, -4.6, 2.2 }, { 0, -4.6, 1.4 }, { 4.6, -4.6, 2.6 }, { 4.6, 4.6, 1.8 }, { 0, 4.6, 2.4 }, { -4.6, 4.6, 0.9 }, { -4.6, 0, 2 } } do
		piece(f, Vector3.new(2, m[3], 2), base * CFrame.new(m[1], H + 0.8 + m[3] / 2, m[2]), STONE, Enum.Material.Brick)
	end
	-- Ventana oscura en la cara que mira a la cámara
	piece(f, Vector3.new(1.4, 2.6, 0.2), base * CFrame.new(1.5, 9.5, W / 2 + 0.05), rgb(36, 40, 38), Enum.Material.Slate)
	-- Musgo: losas pegadas a las caras visibles (cara, x, y, ancho, alto) y matas en la cima
	for _, m in { { 2, -2.5, 10, 4.5, 6 }, { 2, 3, 4, 3.5, 5 }, { 2, -1, 2.5, 6, 3 }, { 3, 1, 8, 5, 7 }, { 3, -3, 3, 3, 4 } } do
		local face = base * CFrame.Angles(0, m[1] * math.pi / 2, 0)
		piece(f, Vector3.new(m[4], m[5], 0.7), face * CFrame.new(m[2], m[3], -W / 2 - 0.15), MOSS, Enum.Material.Grass)
	end
	for _ = 1, 3 do
		local s = rng:NextNumber(2.5, 4.5)
		local cf = base * CFrame.new(rng:NextNumber(-3, 3), H + 1, rng:NextNumber(-3, 3)) * tilt(rng, 12)
		piece(f, Vector3.new(s, s * 0.5, s), cf, MOSS, Enum.Material.Grass)
	end
end

-- Ruina escalonada de piedra con escudo de madera, a la derecha detrás de la antorcha.
local function buildRuins(parent: Instance, rng: Random)
	local f = group(parent, "Ruinas")
	local base = facingCamera(Vector3.new(15, 0, -33), 25)
	for _, t in { { 11, 2.2, 9, 1.1 }, { 8.5, 2, 7, 3.2 }, { 6, 1.8, 5, 5.1 }, { 3.2, 1.4, 3, 6.7 } } do
		local cf = base * CFrame.new(rng:NextNumber(-0.4, 0.4), t[4], rng:NextNumber(-0.3, 0.3)) * CFrame.Angles(0, math.rad(rng:NextNumber(-6, 6)), 0)
		piece(f, Vector3.new(t[1], t[2], t[3]), cf, if rng:NextNumber() < 0.5 then STONE else STONE_DARK, Enum.Material.Cobblestone)
		piece(f, Vector3.new(t[1] * rng:NextNumber(0.4, 0.7), 0.5, t[3] * 0.6), cf * CFrame.new(rng:NextNumber(-1, 1), t[2] / 2, 0), MOSS, Enum.Material.Grass)
	end
	-- Escudo redondo de madera con remache
	local shield = base * CFrame.new(0, 3.4, -3.55) * CFrame.Angles(0, math.pi / 2, 0)
	piece(f, Vector3.new(0.3, 2.3, 2.3), shield, BARK, Enum.Material.Wood, "Cylinder")
	piece(f, Vector3.new(0.4, 0.6, 0.6), shield, IRON, Enum.Material.Metal, "Cylinder")
	-- Muro bajo derruido detrás de la cabeza de piedra
	local wall = CFrame.new(-4, 0, -31.5) * CFrame.Angles(0, math.rad(12), 0)
	piece(f, Vector3.new(4.6, 2.2, 1.1), wall * CFrame.new(0, 1.1, 0), STONE_DARK, Enum.Material.Cobblestone)
	piece(f, Vector3.new(1.6, 0.9, 1.1), wall * CFrame.new(-1.5, 2.65, 0), STONE, Enum.Material.Cobblestone)
	piece(f, Vector3.new(1.2, 0.5, 1.1), wall * CFrame.new(0.6, 2.45, 0), STONE, Enum.Material.Cobblestone)
	piece(f, Vector3.new(1.1, 0.9, 1), wall * CFrame.new(2.5, 0.4, -1.4) * CFrame.Angles(0, 0.5, 0.2), STONE, Enum.Material.Cobblestone)
	piece(f, Vector3.new(2.2, 0.4, 1.2), wall * CFrame.new(-0.8, 2.3, 0), MOSS, Enum.Material.Grass)
end

-- Accesorios ----------------------------------------------------------------------------------

-- Mesa gris de patas algo abiertas con travesaños; devuelve el centro de su tablero.
local function buildTable(parent: Instance): CFrame
	local f = group(parent, "Mesa")
	local base = CFrame.new(-8.9, 0, -16.4) * CFrame.Angles(0, math.rad(6), 0)
	local W, D, H = 5.2, 4.6, 3.1
	piece(f, Vector3.new(W, 0.45, D), base * CFrame.new(0, H - 0.225, 0), TABLE_TOP, Enum.Material.Wood)
	local lx, lz = W / 2 - 0.55, D / 2 - 0.55
	for _, s in { -1, 1 } do
		-- Faldón bajo el tablero y travesaños bajos
		piece(f, Vector3.new(W - 1.1, 0.4, 0.25), base * CFrame.new(0, H - 0.65, s * lz), TABLE, Enum.Material.Wood)
		piece(f, Vector3.new(0.25, 0.4, D - 1.1), base * CFrame.new(s * lx, H - 0.65, 0), TABLE, Enum.Material.Wood)
		piece(f, Vector3.new(W - 0.9, 0.3, 0.3), base * CFrame.new(0, 0.55, s * (lz + 0.05)), TABLE, Enum.Material.Wood)
		piece(f, Vector3.new(0.3, 0.3, D - 0.9), base * CFrame.new(s * (lx + 0.05), 0.55, 0), TABLE, Enum.Material.Wood)
	end
	local legLength = H - 0.45
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local cf = base * CFrame.new(sx * (lx + 0.05), legLength / 2, sz * (lz + 0.05)) * CFrame.Angles(-sz * math.rad(3), 0, sx * math.rad(3))
			piece(f, Vector3.new(0.5, legLength, 0.5), cf, TABLE, Enum.Material.Wood)
		end
	end
	return base * CFrame.new(0, H, 0)
end

-- Microondas azul con puerta de cristal oscuro, girado para que se vea su costado.
local function buildMicrowave(parent: Instance, top: CFrame)
	local f = group(parent, "Microondas")
	local base = CFrame.new(top.Position + Vector3.new(-0.1, 1.26, 0)) * CFrame.Angles(0, math.rad(-113), 0)
	piece(f, Vector3.new(4, 2.2, 2.6), base, MICRO, Enum.Material.Metal)
	-- Puerta (marco, cristal oscuro y asa vertical) en la cara frontal (-Z)
	piece(f, Vector3.new(3, 1.95, 0.12), base * CFrame.new(0.35, 0, -1.33), MICRO_LIGHT, Enum.Material.Metal)
	local glass = piece(f, Vector3.new(2.2, 1.3, 0.1), base * CFrame.new(0.25, 0.05, -1.4), rgb(54, 56, 56), Enum.Material.Glass)
	glass.Reflectance = 0.12
	piece(f, Vector3.new(0.32, 1.85, 0.3), base * CFrame.new(-1.62, 0, -1.38), MICRO_LIGHT, Enum.Material.Metal)
	-- Panel en relieve del costado visible y rejilla trasera
	piece(f, Vector3.new(0.12, 1.4, 1.8), base * CFrame.new(2.04, 0.05, 0.05), MICRO_DARK, Enum.Material.Metal)
	piece(f, Vector3.new(2.4, 0.6, 0.1), base * CFrame.new(0, 0.4, 1.33), MICRO_DARK, Enum.Material.Metal)
	-- Patas
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			piece(f, Vector3.new(0.45, 0.16, 0.45), base * CFrame.new(sx * 1.6, -1.18, sz * 1), IRON, Enum.Material.Metal)
		end
	end
end

-- Cabeza de piedra tipo moai sobre un pedestal con collar dorado, mirando a la cámara.
local function buildMoai(parent: Instance)
	local f = group(parent, "CabezaDePiedra")
	local base = facingCamera(Vector3.new(-6.2, 0, -23), -10)
	-- Medidas a escala 1, agrandadas un poco para que la cara se lea a esta distancia
	local k = 1.15
	local function block(size: Vector3, x: number, y: number, z: number, color: Color3, material: Enum.Material, shape: string?)
		piece(f, size * k, base * CFrame.new(x * k, y * k, z * k), color, material, shape)
	end
	block(Vector3.new(3.6, 0.5, 3), 0, 0.25, 0, STONE_DARK, Enum.Material.Cobblestone)
	block(Vector3.new(3, 1, 2.3), 0, 1, 0, STONE, Enum.Material.Slate)
	block(Vector3.new(3.15, 0.32, 2.45), 0, 1.35, 0, rgb(214, 132, 44), Enum.Material.Metal)
	for _, x in { -0.8, 0, 0.8 } do
		block(Vector3.new(0.3, 0.3, 0.1), x, 1.35, -1.27, rgb(190, 64, 40), Enum.Material.Metal)
	end
	-- Cabeza: bloque con la cima rebajada, frente saliente, cuencas oscuras, nariz, labios, mentón y orejas
	block(Vector3.new(2.5, 2.9, 2.3), 0, 2.95, 0, STONE, Enum.Material.Slate)
	block(Vector3.new(2.2, 0.3, 2), 0, 4.55, 0, STONE, Enum.Material.Slate)
	block(Vector3.new(2.6, 0.45, 0.6), 0, 3.65, -1.3, STONE, Enum.Material.Slate)
	for _, x in { -0.55, 0.55 } do
		block(Vector3.new(0.62, 0.34, 0.08), x, 3.28, -1.17, rgb(70, 72, 70), Enum.Material.Slate)
		block(Vector3.new(0.25, 1.2, 0.6), x * 2.47, 3, -0.2, STONE_DARK, Enum.Material.Slate)
	end
	block(Vector3.new(0.7, 1.2, 0.65), 0, 2.7, -1.475, STONE, Enum.Material.Slate, "Wedge")
	block(Vector3.new(1.1, 0.25, 0.2), 0, 1.95, -1.22, rgb(80, 82, 78), Enum.Material.Slate)
	block(Vector3.new(1.8, 0.4, 0.25), 0, 1.6, -1.2, STONE, Enum.Material.Slate)
	piece(f, Vector3.new(1.4, 0.4, 1.1), base * CFrame.new(-0.4, 4.8 * k + 0.1, 0.3) * CFrame.Angles(0, 0.4, 0), MOSS, Enum.Material.Grass)
end

-- Antorcha de madera con fuego y luz naranja; devuelve la luz para hacerla parpadear.
local function buildTorch(parent: Instance): PointLight
	local f = group(parent, "Antorcha")
	local base = CFrame.new(5.9, 0, -15.3) * CFrame.Angles(0, math.rad(20), math.rad(-3))
	piece(f, Vector3.new(0.5, 3.1, 0.5), base * CFrame.new(0, 1.35, 0), BARK, Enum.Material.Wood)
	piece(f, Vector3.new(0.58, 0.16, 0.58), base * CFrame.new(0, 2.1, 0), BARK_DARK, Enum.Material.Wood)
	piece(f, Vector3.new(0.62, 0.35, 0.62), base * CFrame.new(0, 2.85, 0), rgb(58, 40, 26), Enum.Material.Wood)
	local flame = piece(f, Vector3.new(0.34, 0.5, 0.34), base * CFrame.new(0, 3.2, 0), rgb(255, 150, 50), Enum.Material.Neon)
	flame.CastShadow = false
	local fire = Instance.new("Fire")
	fire.Size = 2
	fire.Heat = 9
	fire.Color = rgb(255, 120, 30)
	fire.SecondaryColor = rgb(255, 205, 80)
	fire.Parent = flame
	local light = Instance.new("PointLight")
	light.Color = rgb(255, 150, 70)
	light.Range = 16
	light.Brightness = 2.4
	light.Shadows = true
	light.Parent = flame
	return light
end

-- Farol azul pequeño sobre un poste y barril amarillo con franjas oscuras, en el plano medio.
local function buildLanternAndBarrel(parent: Instance)
	local f = group(parent, "Farol")
	local base = CFrame.new(3.9, 0, -26)
	piece(f, Vector3.new(0.2, 1.05, 0.2), base * CFrame.new(0, 0.5, 0), BARK_DARK, Enum.Material.Wood)
	piece(f, Vector3.new(0.55, 0.12, 0.55), base * CFrame.new(0, 1, 0), IRON, Enum.Material.Metal)
	piece(f, Vector3.new(0.6, 0.12, 0.6), base * CFrame.new(0, 1.62, 0), IRON, Enum.Material.Metal)
	local glow = piece(f, Vector3.new(0.42, 0.5, 0.42), base * CFrame.new(0, 1.31, 0), rgb(90, 200, 255), Enum.Material.Neon)
	glow.CastShadow = false
	local light = Instance.new("PointLight")
	light.Color = rgb(100, 190, 255)
	light.Range = 10
	light.Brightness = 2.2
	light.Parent = glow

	local barrel = CFrame.new(-3.4, 0.58, -24.6) * CFrame.Angles(0, math.rad(25), 0)
	piece(f, Vector3.new(1.8, 1.16, 1.16), barrel, rgb(236, 196, 40), Enum.Material.Wood, "Cylinder")
	for _, x in { -0.55, 0, 0.55 } do
		piece(f, Vector3.new(0.16, 1.2, 1.2), barrel * CFrame.new(x, 0, 0), rgb(44, 38, 32), Enum.Material.Metal, "Cylinder")
	end
end

-- Cielo, luz y desenfoque ---------------------------------------------------------------------

local function buildEffects()
	local sky = Instance.new("Sky")
	sky.Name = "MenuSceneSky"
	sky.CelestialBodiesShown = false
	sky.StarCount = 0
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "MenuSceneAtmosphere"
	atmosphere.Density = 0.34
	atmosphere.Offset = 0.2
	atmosphere.Color = rgb(92, 186, 222)
	atmosphere.Decay = rgb(24, 112, 150)
	atmosphere.Glare = 0
	atmosphere.Haze = 1.6
	-- Profundidad de campo: la mesa queda casi nítida y el fondo muy borroso, como en la captura
	local depth = Instance.new("DepthOfFieldEffect")
	depth.Name = "MenuSceneDepth"
	depth.FocusDistance = FOCUS
	depth.InFocusRadius = 5
	depth.NearIntensity = 0.35
	depth.FarIntensity = 0.75
	local color = Instance.new("ColorCorrectionEffect")
	color.Name = "MenuSceneColor"
	color.Brightness = 0.02
	color.Contrast = 0.08
	color.Saturation = 0.12
	color.TintColor = rgb(236, 252, 248)
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "MenuSceneBloom"
	bloom.Intensity = 0.35
	bloom.Size = 22
	bloom.Threshold = 1.5
	effects = { sky, atmosphere, depth, color, bloom }
end

-- Aparta el cielo y la atmósfera del lugar (sólo puede haber uno activo) y apaga los efectos del mismo tipo.
local function displaceConflicts()
	for _, child in Lighting:GetChildren() do
		if table.find(effects, child) then
			continue
		end
		if child:IsA("Sky") or child:IsA("Atmosphere") then
			table.insert(displaced, { instance = child })
			child.Parent = nil
		elseif child:IsA("DepthOfFieldEffect") or child:IsA("ColorCorrectionEffect") or child:IsA("BloomEffect") then
			local effect = child :: PostEffect
			table.insert(displaced, { instance = effect, enabled = effect.Enabled })
			effect.Enabled = false
		end
	end
end

local function restoreConflicts()
	for _, entry in displaced do
		pcall(function()
			if entry.enabled ~= nil then
				entry.instance.Enabled = entry.enabled
			elseif entry.instance.Parent == nil then
				entry.instance.Parent = Lighting
			end
		end)
	end
	table.clear(displaced)
end

local function applyLighting()
	for prop, value in LIGHTING do
		savedLighting[prop] = L[prop]
		L[prop] = value
		-- Se guarda lo que realmente quedó (las propiedades se almacenan con menos precisión)
		appliedLighting[prop] = L[prop]
	end
end

local function restoreLighting()
	for prop, value in savedLighting do
		-- Si el servidor cambió la propiedad mientras tanto (al generar el mapa), se respeta su valor
		if L[prop] == appliedLighting[prop] then
			L[prop] = value
		end
	end
	table.clear(savedLighting)
	table.clear(appliedLighting)
end

-- Cámara --------------------------------------------------------------------------------------

-- Cámara fija con un balanceo lento muy leve y parpadeo de la antorcha.
local function step(dt: number)
	clock += dt
	local camera = workspace.CurrentCamera
	if camera then
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Scriptable
		end
		local sway = CFrame.new(math.sin(clock * 0.21) * 0.12, math.sin(clock * 0.34) * 0.05, 0)
			* CFrame.Angles(math.sin(clock * 0.27) * math.rad(0.25), math.sin(clock * 0.18) * math.rad(0.5), 0)
		local cf = ORIGIN * CAMERA * sway
		camera.CFrame = cf
		camera.Focus = cf * CFrame.new(0, 0, -FOCUS)
	end
	if torchLight then
		torchLight.Brightness = 2.4 + math.noise(clock * 3.1, 0.5) * 1.6
	end
end

-- API -----------------------------------------------------------------------------------------

-- Construye la escena una sola vez (sin mostrarla).
function MenuScene.init()
	if folder then
		return
	end
	local root = Instance.new("Folder")
	root.Name = "MenuScene"
	local rng = Random.new(1069)
	buildGround(root, rng)
	buildForest(root, rng)
	buildTower(root, rng)
	buildRuins(root, rng)
	buildMicrowave(root, buildTable(root))
	buildMoai(root)
	torchLight = buildTorch(root)
	buildLanternAndBarrel(root)
	buildEffects()
	folder = root
end

-- Muestra u oculta la escena; al mostrarla toma la cámara y ajusta la luz, al ocultarla lo devuelve todo.
function MenuScene.show(visible: boolean)
	if visible == shown then
		return
	end
	shown = visible
	local camera = workspace.CurrentCamera
	if visible then
		MenuScene.init()
		local root = folder :: Folder
		root.Parent = workspace
		displaceConflicts()
		for _, effect in effects do
			effect.Parent = Lighting
		end
		applyLighting()
		if camera then
			savedFov = camera.FieldOfView
			camera.CameraType = Enum.CameraType.Scriptable
			camera.FieldOfView = FOV
		end
		step(0)
		connection = RunService.RenderStepped:Connect(step)
	else
		if connection then
			connection:Disconnect()
			connection = nil
		end
		if folder then
			folder.Parent = nil
		end
		for _, effect in effects do
			effect.Parent = nil
		end
		restoreConflicts()
		restoreLighting()
		if camera then
			camera.CameraType = Enum.CameraType.Custom
			if savedFov then
				camera.FieldOfView = savedFov
			end
		end
		savedFov = nil
	end
end

return MenuScene
