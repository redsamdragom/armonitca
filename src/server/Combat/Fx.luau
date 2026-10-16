-- Efectos visuales del servidor: piezas reutilizables (pool), destellos temporales y
-- números de daño agrupados que se envían al cliente.

local Debris = game:GetService("Debris")
local Net = require(game:GetService("ReplicatedStorage").Shared.Net)

local Fx = {}

local folder: Folder
local pool: { [string]: { BasePart } } = {}
local FxRemote

function Fx.init()
	folder = Instance.new("Folder")
	folder.Name = "Effects"
	folder.Parent = workspace
	FxRemote = Net.get("Fx")
end

function Fx.folder(): Folder
	return folder
end

local SHAPES = {
	Ball = Enum.PartType.Ball,
	Block = Enum.PartType.Block,
	Cylinder = Enum.PartType.Cylinder,
}

function Fx.acquire(shape: string, color: Color3, size: Vector3, material: Enum.Material?): BasePart
	local list = pool[shape]
	local p: BasePart
	if list and #list > 0 then
		p = table.remove(list) :: BasePart
	else
		if shape == "Wedge" then
			p = Instance.new("WedgePart")
		else
			local part = Instance.new("Part")
			part.Shape = SHAPES[shape] or Enum.PartType.Block
			p = part
		end
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.CastShadow = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p:SetAttribute("PoolShape", shape)
	end
	p.Color = color
	p.Size = size
	p.Material = material or Enum.Material.Neon
	p.Transparency = 0
	p.Parent = folder
	return p
end

function Fx.release(p: BasePart)
	local shape = p:GetAttribute("PoolShape")
	if not shape then
		p:Destroy()
		return
	end
	p.Parent = nil
	local list = pool[shape]
	if not list then
		list = {}
		pool[shape] = list
	end
	if #list < 400 then
		table.insert(list, p)
	else
		p:Destroy()
	end
end

-- Destello que desaparece solo (explosiones, tajos, rayos).
function Fx.flash(shape: string, cframe: CFrame, size: Vector3, color: Color3, lifetime: number, transparency: number?)
	local p = Instance.new(if shape == "Wedge" then "WedgePart" else "Part") :: BasePart
	if shape ~= "Wedge" then
		(p :: Part).Shape = SHAPES[shape] or Enum.PartType.Block
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.CFrame = cframe
	p.Transparency = transparency or 0.35
	p.Parent = folder
	Debris:AddItem(p, lifetime)
	return p
end

function Fx.ring(position: Vector3, radius: number, color: Color3, lifetime: number?)
	return Fx.flash(
		"Cylinder",
		CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2),
		Vector3.new(0.4, radius * 2, radius * 2),
		color,
		lifetime or 0.18,
		0.55
	)
end

function Fx.beam(from: Vector3, to: Vector3, width: number, color: Color3, lifetime: number?)
	local length = (to - from).Magnitude
	if length < 0.05 then
		return
	end
	return Fx.flash(
		"Block",
		CFrame.lookAt((from + to) / 2, to),
		Vector3.new(width, width, length),
		color,
		lifetime or 0.12,
		0.2
	)
end

-- Números de daño: se agrupan y se envían a 10 Hz para no saturar la red.
local pending: { [Player]: { any } } = {}

function Fx.damageNumber(player: Player, position: Vector3, amount: number, kind: string?)
	local list = pending[player]
	if not list then
		list = {}
		pending[player] = list
	end
	if #list < 60 then
		table.insert(list, { position.X, position.Y, position.Z, math.floor(amount + 0.5), kind or "normal" })
	end
end

function Fx.flushNumbers()
	for player, list in pending do
		if #list > 0 and player.Parent then
			FxRemote:FireClient(player, list)
		end
	end
	table.clear(pending)
end

return Fx
