-- Números de daño flotantes con reserva de piezas. Su opacidad sigue la opción del jugador.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Net = require(ReplicatedStorage.Shared.Net)
local ClientState = require(script.Parent.Parent.ClientState)

local DamageNumbers = {}

local POOL_SIZE = 90
local pool = {}
local folder: Folder

local STYLE = {
	normal = { Color3.fromRGB(255, 255, 255), 18 },
	crit = { Color3.fromRGB(255, 210, 60), 24 },
	overcrit = { Color3.fromRGB(255, 120, 40), 28 },
	execute = { Color3.fromRGB(255, 60, 60), 26 },
	bonk = { Color3.fromRGB(255, 240, 80), 34 },
	poison = { Color3.fromRGB(170, 90, 230), 16 },
	burn = { Color3.fromRGB(255, 140, 40), 16 },
	bloodmark = { Color3.fromRGB(170, 0, 30), 22 },
	curse = { Color3.fromRGB(150, 60, 200), 16 },
	thorns = { Color3.fromRGB(200, 255, 200), 16 },
	player = { Color3.fromRGB(255, 70, 70), 22 },
	evade = { Color3.fromRGB(180, 220, 255), 20 },
}

local function make()
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.1
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 40)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	return { anchor = anchor, label = label, busy = false }
end

local function show(x, y, z, amount, kind)
	local entry
	for _, e in pool do
		if not e.busy then
			entry = e
			break
		end
	end
	if not entry then
		return
	end
	entry.busy = true
	local style = STYLE[kind] or STYLE.normal
	local opacity = ClientState.settings.effectOpacity
	entry.label.Text = if kind == "evade" then "Evadido" elseif kind == "bonk" then "BONK " .. amount else tostring(amount)
	entry.label.TextColor3 = style[1]
	entry.label.TextSize = style[2]
	entry.label.TextTransparency = 1 - opacity
	entry.label.TextStrokeTransparency = 1 - opacity * 0.7
	local start = Vector3.new(x + (math.random() - 0.5) * 1.5, y, z + (math.random() - 0.5) * 1.5)
	entry.anchor.Position = start
	entry.anchor.Parent = folder
	local tween = TweenService:Create(entry.anchor, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = start + Vector3.new(0, 3, 0) })
	local fade = TweenService:Create(entry.label, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, TextStrokeTransparency = 1 })
	tween:Play()
	fade:Play()
	task.delay(0.72, function()
		entry.anchor.Parent = nil
		entry.busy = false
	end)
end

function DamageNumbers.init()
	folder = Instance.new("Folder")
	folder.Name = "DamageNumbers"
	folder.Parent = workspace.CurrentCamera
	for i = 1, POOL_SIZE do
		pool[i] = make()
	end
	Net.get("Fx").OnClientEvent:Connect(function(list)
		for _, n in list do
			show(n[1], n[2], n[3], n[4], n[5])
		end
	end)
end

return DamageNumbers
