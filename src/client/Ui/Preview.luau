-- Vista del personaje para el menú: su diseño hecho a mano (src/shared/Personajes) o, si aún no
-- tiene, el maniquí de bloques con su atuendo de primitivas.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage.Shared.Catalog)

local Preview = {}

local SHAPES = { Block = Enum.PartType.Block, Ball = Enum.PartType.Ball, Cylinder = Enum.PartType.Cylinder }

local function block(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- Altura (en studs) a la que se ajustan los diseños para que quepan en las vistas del menú, con
-- los pies en el suelo y el pivote 3 studs por encima, como el maniquí.
local DESIGN_HEIGHT = 6

-- Modelo hecho a mano del personaje (src/shared/Personajes), o nil si todavía no tiene.
function Preview.design(characterId: string): Model?
	local folder = ReplicatedStorage.Shared:FindFirstChild("Personajes")
	local design = folder and folder:FindFirstChild(characterId)
	if design and design:IsA("Model") and design:FindFirstChild("HumanoidRootPart") then
		return design
	end
	return nil
end

-- Copia estática del diseño para un ViewportFrame: anclado, mirando a -Z, con los pies en y = 0 y el
-- pivote en (0, 3, 0).
local function buildDesign(design: Model): Model
	local model = design:Clone()
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local bottom, top = math.huge, -math.huge
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			bottom = math.min(bottom, d.Position.Y - d.Size.Y / 2)
			top = math.max(top, d.Position.Y + d.Size.Y / 2)
		elseif d:IsA("Humanoid") then
			d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
	end
	root.Transparency = 1
	model.PrimaryPart = nil
	local rotation = root.CFrame - root.Position
	model.WorldPivot = CFrame.new(root.Position.X, bottom, root.Position.Z) * rotation
	local height = top - bottom
	if height > 0 then
		local scale = math.clamp(DESIGN_HEIGHT / height, 0.4, 1.5)
		pcall(function()
			model:ScaleTo(scale)
		end)
	end
	-- Pivote 3 studs sobre los pies, como el del maniquí
	model.WorldPivot = model.WorldPivot * CFrame.new(0, 3, 0)
	model:PivotTo(CFrame.new(0, 3, 0))
	return model
end

function Preview.build(characterId: string): Model
	local design = Preview.design(characterId)
	if design then
		return buildDesign(design)
	end
	local character = Catalog.Character[characterId]
	local model = Instance.new("Model")
	local skin = Color3.fromRGB(230, 200, 170)
	local cloth = Color3.fromRGB(70, 80, 110)
	local root = block(model, "HumanoidRootPart", Vector3.new(2, 2, 1), CFrame.new(0, 3, 0), cloth)
	root.Transparency = 1
	local torso = block(model, "Torso", Vector3.new(2, 2, 1), CFrame.new(0, 3, 0), cloth)
	local head = block(model, "Head", Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, 4.6, 0), skin)
	block(model, "LeftArm", Vector3.new(1, 2, 1), CFrame.new(-1.5, 3, 0), skin)
	block(model, "RightArm", Vector3.new(1, 2, 1), CFrame.new(1.5, 3, 0), skin)
	block(model, "LeftLeg", Vector3.new(1, 2, 1), CFrame.new(-0.5, 1, 0), Color3.fromRGB(40, 40, 50))
	block(model, "RightLeg", Vector3.new(1, 2, 1), CFrame.new(0.5, 1, 0), Color3.fromRGB(40, 40, 50))
	local anchors = { Head = head, Torso = torso, Root = root }
	for _, piece in character.costume or {} do
		local target = anchors[piece.attach]
		local p = Instance.new(if piece.shape == "Wedge" then "WedgePart" else "Part") :: BasePart
		if piece.shape ~= "Wedge" then
			(p :: Part).Shape = SHAPES[piece.shape] or Enum.PartType.Block
		end
		p.Anchored = true
		p.Size = Vector3.new(piece.size[1], piece.size[2], piece.size[3])
		p.Color = Color3.fromRGB(piece.color[1], piece.color[2], piece.color[3])
		p.Material = if piece.material then Enum.Material[piece.material] else Enum.Material.SmoothPlastic
		local rot = piece.rot or { 0, 0, 0 }
		p.CFrame = target.CFrame
			* CFrame.new(piece.offset[1], piece.offset[2], piece.offset[3])
			* CFrame.Angles(math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3]))
		p.Parent = model
	end
	model.PrimaryPart = root
	return model
end

-- Monta un ViewportFrame giratorio y devuelve una función para cambiar de personaje.
function Preview.mount(viewport: ViewportFrame): (string) -> ()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	viewport.Ambient = Color3.fromRGB(180, 180, 190)
	viewport.LightColor = Color3.fromRGB(255, 255, 245)
	local current: Model? = nil
	local angle = 0
	local connection
	connection = game:GetService("RunService").RenderStepped:Connect(function(dt)
		if not viewport.Parent then
			connection:Disconnect()
			return
		end
		if current then
			angle += dt * 0.8
			current:PivotTo(CFrame.new(0, 3, 0) * CFrame.Angles(0, angle, 0))
			camera.CFrame = CFrame.lookAt(Vector3.new(0, 4, -11), Vector3.new(0, 3, 0))
		end
	end)
	return function(characterId: string)
		if current then
			current:Destroy()
		end
		current = Preview.build(characterId)
		current.Parent = viewport
	end
end

return Preview
