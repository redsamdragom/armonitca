-- Aspecto del personaje en la partida.
-- Con diseño hecho a mano (src/shared/Personajes/<Id>.rbxm) el jugador aparece con ese modelo:
-- se pone como StarterPlayer.StarterCharacter justo antes de LoadCharacter, así Roblox le añade
-- sus animaciones. Sin diseño, se usa el avatar con el atuendo provisional de primitivas soldadas
-- (una reconstrucción a partir de las descripciones, ver docs/MATRIZ.md).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Costumes = {}

-- Diseño del personaje, o nil si todavía no tiene.
function Costumes.design(characterId: string): Model?
	local folder = ReplicatedStorage.Shared:FindFirstChild("Personajes")
	local design = folder and folder:FindFirstChild(characterId)
	if design and design:IsA("Model") and design:FindFirstChild("HumanoidRootPart") and design:FindFirstChildOfClass("Humanoid") then
		return design
	end
	return nil
end

-- Prepara el siguiente LoadCharacter: con diseño lo deja como StarterCharacter (devuelve true);
-- sin diseño quita el que hubiera, para volver al avatar del jugador.
function Costumes.prepare(characterId: string): boolean
	local old = StarterPlayer:FindFirstChild("StarterCharacter")
	if old then
		old:Destroy()
	end
	local design = Costumes.design(characterId)
	if not design then
		return false
	end
	local starter = design:Clone()
	starter.Name = "StarterCharacter"
	starter.PrimaryPart = starter:FindFirstChild("HumanoidRootPart") :: BasePart
	starter.Parent = StarterPlayer
	return true
end

local SHAPES = { Block = Enum.PartType.Block, Ball = Enum.PartType.Ball, Cylinder = Enum.PartType.Cylinder }

local function attachPart(model: Model, attach: string): BasePart?
	if attach == "Head" then
		return model:FindFirstChild("Head") :: BasePart?
	elseif attach == "Torso" then
		return (model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso")) :: BasePart?
	end
	return model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function Costumes.apply(model: Model, character)
	local old = model:FindFirstChild("Costume")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Costume"
	for _, piece in character.costume or {} do
		local target = attachPart(model, piece.attach)
		if not target then
			continue
		end
		local p = Instance.new(if piece.shape == "Wedge" then "WedgePart" else "Part") :: BasePart
		if piece.shape ~= "Wedge" then
			(p :: Part).Shape = SHAPES[piece.shape] or Enum.PartType.Block
		end
		p.Size = Vector3.new(piece.size[1], piece.size[2], piece.size[3])
		p.Color = Color3.fromRGB(piece.color[1], piece.color[2], piece.color[3])
		p.Material = if piece.material then Enum.Material[piece.material] else Enum.Material.SmoothPlastic
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.Anchored = false
		local rot = piece.rot or { 0, 0, 0 }
		p.CFrame = target.CFrame
			* CFrame.new(piece.offset[1], piece.offset[2], piece.offset[3])
			* CFrame.Angles(math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3]))
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = target
		weld.Part1 = p
		weld.Parent = p
		p.Parent = folder
	end
	folder.Parent = model
end

return Costumes
