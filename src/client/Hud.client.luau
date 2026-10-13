-- Interfaz del jugador: barra de XP, temporizador, contador de bajas y cartas de mejora.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local gui = Instance.new("ScreenGui")
gui.Name = "Hud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local function label(props): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.5
	for key, value in props do
		l[key] = value
	end
	l.Parent = props.Parent or gui
	return l
end

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

-- Barra de XP
local xpBack = Instance.new("Frame")
xpBack.AnchorPoint = Vector2.new(0.5, 0)
xpBack.Position = UDim2.new(0.5, 0, 0, 8)
xpBack.Size = UDim2.new(0.6, 0, 0, 18)
xpBack.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
xpBack.BackgroundTransparency = 0.3
xpBack.Parent = gui
corner(xpBack, 9)

local xpFill = Instance.new("Frame")
xpFill.Size = UDim2.new(0, 0, 1, 0)
xpFill.BackgroundColor3 = Color3.fromRGB(80, 220, 255)
xpFill.Parent = xpBack
corner(xpFill, 9)

local levelLabel = label({
	Position = UDim2.new(0, 0, 0, 0),
	Size = UDim2.new(1, 0, 1, 0),
	TextSize = 14,
	Text = "Nivel 1",
	ZIndex = 2,
	Parent = xpBack,
})

local timerLabel = label({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 30),
	Size = UDim2.new(0, 200, 0, 36),
	TextSize = 30,
	Text = "00:00",
})

local killsLabel = label({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 34),
	Size = UDim2.new(0, 200, 0, 24),
	TextSize = 18,
	TextXAlignment = Enum.TextXAlignment.Right,
	Text = "Bajas: 0",
})

local bannerLabel = label({
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.3, 0),
	Size = UDim2.new(1, 0, 0, 60),
	TextSize = 48,
	Text = "",
	Visible = false,
})

-- Panel de mejoras
local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.new(0.5, 0, 0.55, 0)
panel.Size = UDim2.new(0, 640, 0, 240)
panel.BackgroundTransparency = 1
panel.Visible = false
panel.Parent = gui

label({
	Size = UDim2.new(1, 0, 0, 40),
	TextSize = 30,
	Text = "¡Subiste de nivel! Elige una mejora (1, 2, 3)",
	Parent = panel,
})

local cards = Instance.new("Frame")
cards.Position = UDim2.new(0, 0, 0, 50)
cards.Size = UDim2.new(1, 0, 1, -50)
cards.BackgroundTransparency = 1
cards.Parent = panel

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Padding = UDim.new(0, 12)
layout.Parent = cards

local currentOffer = nil

local function choose(index: number)
	if not currentOffer or not currentOffer[index] then
		return
	end
	currentOffer = nil
	panel.Visible = false
	remotes.ChooseUpgrade:FireServer(index)
end

local function showOffer(offer)
	for _, child in cards:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	currentOffer = offer
	for index, choice in offer do
		local card = Instance.new("TextButton")
		card.Size = UDim2.new(0, 200, 1, 0)
		card.BackgroundColor3 = if choice.Kind == "Weapon" then Color3.fromRGB(40, 60, 110) else Color3.fromRGB(50, 90, 60)
		card.AutoButtonColor = true
		card.Text = ""
		card.LayoutOrder = index
		card.Parent = cards
		corner(card, 10)

		label({ Position = UDim2.new(0, 10, 0, 10), Size = UDim2.new(1, -20, 0, 30), TextSize = 20, Text = choice.Name, TextWrapped = true, Parent = card })
		label({ Position = UDim2.new(0, 10, 0, 44), Size = UDim2.new(1, -20, 0, 20), TextSize = 14, Text = "Nivel " .. choice.Level, TextColor3 = Color3.fromRGB(255, 220, 120), Parent = card })
		label({ Position = UDim2.new(0, 10, 0, 74), Size = UDim2.new(1, -20, 1, -110), TextSize = 15, Font = Enum.Font.Gotham, Text = choice.Description, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Parent = card })
		label({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(0, 30, 0, 24), TextSize = 18, Text = "[" .. index .. "]", Parent = card })

		card.Activated:Connect(function()
			choose(index)
		end)
	end
	panel.Visible = true
end

local function formatTime(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d", s // 60, s % 60)
end

remotes.LevelUpOffer.OnClientEvent:Connect(showOffer)

remotes.Hud.OnClientEvent:Connect(function(data)
	xpFill.Size = UDim2.new(math.clamp(data.XP / data.XPToNext, 0, 1), 0, 1, 0)
	levelLabel.Text = "Nivel " .. data.Level
	killsLabel.Text = "Bajas: " .. data.Kills
	if data.BossAlive then
		timerLabel.Text = "¡JEFE FINAL!"
		timerLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
	else
		timerLabel.Text = formatTime(data.Duration - data.Elapsed)
		timerLabel.TextColor3 = Color3.new(1, 1, 1)
	end
	bannerLabel.Visible = false
end)

remotes.RunEnded.OnClientEvent:Connect(function(victory: boolean, elapsed: number)
	currentOffer = nil
	panel.Visible = false
	bannerLabel.Text = if victory then "¡Victoria!" else "Has caído — sobreviviste " .. formatTime(elapsed)
	bannerLabel.TextColor3 = if victory then Color3.fromRGB(255, 220, 90) else Color3.fromRGB(255, 90, 90)
	bannerLabel.Visible = true
end)

local keys = { [Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3 }
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	local index = keys[input.KeyCode]
	if index then
		choose(index)
	end
end)
