-- Importa los modelos de personaje de un lugar de Roblox (.rbxl/.rbxlx) a src/shared/Personajes.
--
-- Uso (Lune 0.11 o posterior, por el formato reciente de los archivos de Studio):
--   lune run tools/importar_personajes <lugar.rbxl>
--
-- Cada modelo se guarda como src/shared/Personajes/<IdDelPersonaje>.rbxm. Se quitan los scripts y
-- herramientas (el juego pone sus propias armas), se fija HumanoidRootPart como PrimaryPart y las
-- piezas de adorno quedan sin colisión ni masa para no estorbar al movimiento.
--
-- Para que caminen bien con las animaciones de Roblox se arregla el esqueleto: las articulaciones
-- se orientan como en el R6 estándar (los diseños las traen sin girar, y la animación de andar
-- movía brazos y piernas hacia los lados), el HumanoidRootPart se centra bajo el torso y la
-- HipHeight se calcula para que los pies (o la patineta) toquen el suelo.

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3

-- Nombre del modelo en el lugar → id del personaje en Data/Characters
local MAPPING = {
	["Lobo Mago"] = "Fox",
	["Samurai de Hierro"] = "SirOofie",
	["Esqueleto Skater"] = "Calcium",
	["Toro Musculoso Voxel"] = "Megachad",
	["Vikingo Voxel"] = "Ogre",
	["Vaquero Espacial Voxel"] = "CL4NK",
	["Guerrero Espartano Voxel"] = "Athena",
	["Hawkeye Morado"] = "Robinette",
	["Lagartija Ancha con Lentes"] = "Monke",
	["Gato Voxel Skater"] = "TonyMcZoom",
}

local BODY = {
	HumanoidRootPart = true,
	Torso = true,
	Head = true,
	["Left Arm"] = true,
	["Right Arm"] = true,
	["Left Leg"] = true,
	["Right Leg"] = true,
}

-- Orientación de cada articulación en el R6 estándar. Con ella las animaciones (que giran sobre el
-- eje Z de la articulación) balancean las extremidades hacia delante y hacia atrás.
local JOINT_ROTATION = {
	["Right Shoulder"] = CFrame.Angles(0, math.pi / 2, 0),
	["Right Hip"] = CFrame.Angles(0, math.pi / 2, 0),
	["Left Shoulder"] = CFrame.Angles(0, -math.pi / 2, 0),
	["Left Hip"] = CFrame.Angles(0, -math.pi / 2, 0),
	Neck = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
	RootJoint = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
}

local function unrotated(cf): boolean
	local x, y, z = cf.XVector, cf.YVector, cf.ZVector
	return x.X > 0.999 and y.Y > 0.999 and z.Z > 0.999
end

-- Orienta las articulaciones del cuerpo como en el R6 estándar sin mover ninguna pieza: girar C0 y
-- C1 por igual deja la postura de reposo (C0 · C1⁻¹) intacta.
local function orientJoints(model): number
	local fixed = 0
	for _, joint in model:GetDescendants() do
		local rotation = JOINT_ROTATION[joint.Name]
		if rotation and joint:IsA("Motor6D") and unrotated(joint.C0) and unrotated(joint.C1) then
			joint.C0 = joint.C0 * rotation
			joint.C1 = joint.C1 * rotation
			fixed += 1
		end
	end
	return fixed
end

-- Lleva el HumanoidRootPart bajo el torso si el diseño lo dejó desplazado (el personaje giraba
-- alrededor de un punto fuera del cuerpo).
local function centerRoot(model, root)
	local joint = root:FindFirstChild("RootJoint")
	if not (joint and joint:IsA("Motor6D")) then
		return
	end
	local rel = (joint.C0 * joint.C1:Inverse()).Position
	local delta = Vector3.new(rel.X, 0, rel.Z)
	if delta.Magnitude < 0.01 then
		return
	end
	root.CFrame = root.CFrame * CFrame.new(delta)
	joint.C0 = CFrame.new(-delta) * joint.C0
	for _, d in model:GetDescendants() do
		if d:IsA("JointInstance") and d ~= joint then
			if d.Part0 == root then
				d.C0 = CFrame.new(-delta) * d.C0
			elseif d.Part1 == root then
				d.C1 = CFrame.new(-delta) * d.C1
			end
		elseif d:IsA("Attachment") and d.Parent == root then
			d.CFrame = CFrame.new(-delta) * d.CFrame
		end
	end
end

-- Altura del punto visible más bajo del modelo (pies, zapatos o patineta).
local function lowestPoint(model): number
	local lowest = math.huge
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 then
			local cf, size = part.CFrame, part.Size
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local corner = cf * Vector3.new(sx * size.X / 2, sy * size.Y / 2, sz * size.Z / 2)
						lowest = math.min(lowest, corner.Y)
					end
				end
			end
		end
	end
	return lowest
end

local path = process.args[1]
assert(path, "uso: lune run tools/importar_personajes <lugar.rbxl>")
local game = roblox.deserializePlace(fs.readFile(path))

local found = {}
for _, service in game:GetChildren() do
	for _, model in service:GetChildren() do
		local id = MAPPING[model.Name]
		if id and model:IsA("Model") and not found[id] then
			found[id] = model
		end
	end
end

fs.writeDir("src/shared/Personajes")
for name, id in MAPPING do
	local source = found[id]
	if not source then
		print("falta en el lugar: " .. name)
		continue
	end
	local model = source:Clone()
	model.Name = id
	local root = model:FindFirstChild("HumanoidRootPart")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	assert(root and humanoid, name .. ": le falta HumanoidRootPart o Humanoid")
	centerRoot(model, root)
	-- Patinetas: la herramienta pasa a ser parte del modelo, soldada bajo los pies. Si en el lugar
	-- está en la mano, se coloca en la postura de patinar de su script (0, -2.88, -0.25 del root).
	for _, tool in model:GetChildren() do
		if tool:IsA("Tool") and string.find(tool.Name, "Patineta") then
			local handle = tool:FindFirstChild("Handle")
			local leg = model:FindFirstChild("Left Leg")
			local inHand = handle and leg and handle.CFrame.Position.Y > leg.CFrame.Position.Y - leg.Size.Y / 2 + 0.5
			local board = roblox.Instance.new("Model")
			board.Name = "Patineta"
			local deck = root.CFrame * CFrame.new(0, -2.88, -0.25)
			for _, part in tool:GetDescendants() do
				if part:IsA("BasePart") then
					if inHand then
						part.CFrame = deck * handle.CFrame:ToObjectSpace(part.CFrame)
					end
					for _, w in part:GetChildren() do
						if w:IsA("WeldConstraint") then
							w:Destroy()
						end
					end
					local weld = roblox.Instance.new("WeldConstraint")
					weld.Part0 = root
					weld.Part1 = part
					weld.Parent = part
					part.Parent = board
				end
			end
			board.Parent = model
			tool:Destroy()
		end
	end
	local removed = 0
	for _, d in model:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("Tool") then
			d:Destroy()
			removed += 1
		end
	end
	local parts = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
			d.Anchored = false
			if not (d.Parent == model and BODY[d.Name]) then
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				d.Massless = true
			end
		end
	end
	local joints = orientJoints(model)
	-- R6: altura del root = pierna izquierda + mitad del root + HipHeight
	local leg = model:FindFirstChild("Left Leg")
	if leg then
		local height = root.CFrame.Position.Y - lowestPoint(model)
		humanoid.HipHeight = math.max(0, height - leg.Size.Y - root.Size.Y / 2)
	end
	model.PrimaryPart = root
	model:SetAttribute("Diseno", name)
	fs.writeFile("src/shared/Personajes/" .. id .. ".rbxm", roblox.serializeModel({ model }))
	print(string.format("%-28s → %-11s %3d piezas, %d scripts/herramientas quitados, %d articulaciones orientadas, HipHeight %.2f", name, id, parts, removed, joints, humanoid.HipHeight))
end
