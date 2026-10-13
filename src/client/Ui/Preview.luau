-- Maniquí de bloques con el atuendo del personaje para la vista giratoria del selector.

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

function Preview.build(characterId: string): Model
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
