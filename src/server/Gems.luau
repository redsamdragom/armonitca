-- Gemas de experiencia que sueltan los enemigos y que el jugador atrae al acercarse.

local Gems = {}

local list = {}
local folder: Folder

local MAGNET_SPEED = 60
local COLLECT_DISTANCE = 2.5

function Gems.init()
	folder = Instance.new("Folder")
	folder.Name = "XPGems"
	folder.Parent = workspace
end

function Gems.spawn(position: Vector3, value: number)
	local p = Instance.new("Part")
	p.Name = "XPGem"
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.one * (if value >= 5 then 1.6 else 1)
	p.Color = if value >= 5 then Color3.fromRGB(255, 80, 200) else Color3.fromRGB(80, 220, 255)
	p.Material = Enum.Material.Neon
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Position = position
	p.Parent = folder
	table.insert(list, { Part = p, Value = value, Target = nil })
end

-- collectors: { { player: Player, root: BasePart, pickupRadius: number } }
function Gems.step(dt: number, collectors, onCollect: (Player, number) -> ())
	for i = #list, 1, -1 do
		local gem = list[i]
		local position = gem.Part.Position

		if gem.Target and not gem.Target.root.Parent then
			gem.Target = nil
		end
		if not gem.Target then
			for _, collector in collectors do
				if (collector.root.Position - position).Magnitude <= collector.pickupRadius then
					gem.Target = collector
					break
				end
			end
		end

		if gem.Target then
			local delta = gem.Target.root.Position - position
			local distance = delta.Magnitude
			if distance <= COLLECT_DISTANCE then
				onCollect(gem.Target.player, gem.Value)
				gem.Part:Destroy()
				table.remove(list, i)
			else
				gem.Part.Position = position + delta.Unit * math.min(distance, MAGNET_SPEED * dt)
			end
		end
	end
end

function Gems.clear()
	for _, gem in list do
		gem.Part:Destroy()
	end
	table.clear(list)
end

return Gems
