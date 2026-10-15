-- Importa los modelos de personaje de un lugar de Roblox (.rbxl/.rbxlx) a src/shared/Personajes.
--
-- Uso (Lune 0.11 o posterior, por el formato reciente de los archivos de Studio):
--   lune run tools/importar_personajes <lugar.rbxl>
--
-- Cada modelo se guarda como src/shared/Personajes/<IdDelPersonaje>.rbxm. Se quitan los scripts y
-- herramientas (el juego pone sus propias armas), se fija HumanoidRootPart como PrimaryPart y las
-- piezas de adorno quedan sin colisión ni masa para no estorbar al movimiento.

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local CFrame = roblox.CFrame

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
	assert(root and model:FindFirstChildOfClass("Humanoid"), name .. ": le falta HumanoidRootPart o Humanoid")
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
	model.PrimaryPart = root
	model:SetAttribute("Diseno", name)
	fs.writeFile("src/shared/Personajes/" .. id .. ".rbxm", roblox.serializeModel({ model }))
	print(string.format("%-28s → %-11s %3d piezas, %d scripts/herramientas quitados", name, id, parts, removed))
end
