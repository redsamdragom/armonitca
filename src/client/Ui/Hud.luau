-- HUD de combate con la composición de la referencia:
--   arriba del todo, la barra de experiencia (arcoíris en movimiento al subir de nivel);
--   arriba a la izquierda, tiempo de partida, plata, oro y bajas; debajo la vida, las armas y los
--   tomos en dos filas de casillas y la misión actual;
--   en el centro, la cuenta atrás de la etapa (y la barra del jefe);
--   arriba a la derecha, el precio del próximo cofre, el nivel y el minimapa con la brújula.
-- Abajo a la derecha, los objetos; M abre el mapa completo. Diseño a 1080 de alto con UIScale.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Net = require(ReplicatedStorage.Shared.Net)
local ClientState = require(script.Parent.Parent.ClientState)
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)

local Hud = {}

local C = Theme.Colors
local WHITE = Color3.new(1, 1, 1)
local DESIGN_H = 1080
local MIN_W = 1280
local GOLD = Color3.fromRGB(255, 200, 30)
local SILVER = Color3.fromRGB(200, 214, 228)
local HP_RED = Color3.fromRGB(226, 22, 22)
local XP_BLUE = Color3.fromRGB(70, 200, 255)
local CELL_BG = Color3.fromRGB(28, 44, 52)
local MINIMAP_SIZE = 200
local SLOT, SLOT_GAP = 55, 6

local gui: ScreenGui
local designRoot: Frame
local designScale: UIScale
local refs = {}

local function outlined<T>(label: T, thickness: number?): T
	Theme.outlined(label :: any, thickness or 2)
	return label
end

-- Texto grande del HUD en la letra gótica del juego.
local function label(props): TextLabel
	return Theme.label(props)
end

-- Texto de palo seco (misión, ayuda y leyenda): más legible en tamaños pequeños.
local function sans(props): TextLabel
	props.FontFace = props.FontFace or Theme.HudFontFace
	return Theme.label(props)
end

local function helpText(): string
	local b = ClientState.bindings
	return string.format("[%s] Pausa · [%s] Mapa · [E] Interactuar", b.Pause[1].Name, b.Map[1].Name)
end
local markers = {}
local halfSize = 260
local lastHud = nil

local MARKER_COLOR = {
	Chest = Color3.fromRGB(230, 180, 60),
	FreeChest = Color3.fromRGB(90, 220, 120),
	ChargeShrine = Color3.fromRGB(90, 200, 255),
	GoldenChargeShrine = Color3.fromRGB(255, 210, 60),
	GreedShrine = Color3.fromRGB(255, 230, 120),
	BossCurse = Color3.fromRGB(170, 30, 50),
	ShrineOfSucc = Color3.fromRGB(120, 240, 255),
	Microwave = Color3.fromRGB(230, 230, 235),
	ShadyGuy = Color3.fromRGB(150, 150, 160),
	BossPortal = Color3.fromRGB(255, 50, 70),
	ExitPortal = Color3.fromRGB(80, 255, 140),
	Boss = Color3.fromRGB(255, 0, 0),
}
local MARKER_NAMES = {
	Chest = "Cofre",
	FreeChest = "Cofre gratis",
	ChargeShrine = "Charge Shrine",
	GoldenChargeShrine = "Golden Shrine",
	GreedShrine = "Greed Shrine",
	BossCurse = "Boss Curse",
	ShrineOfSucc = "Shrine of Succ",
	Microwave = "Microwave",
	ShadyGuy = "Shady Guy",
	BossPortal = "Portal del jefe",
	ExitPortal = "Salida",
	Boss = "Jefe",
}

-- Colores de la barra arcoíris (franjas de bordes duros, como en la referencia)
local RAINBOW = {
	Color3.fromRGB(20, 210, 40),
	Color3.fromRGB(0, 235, 255),
	Color3.fromRGB(230, 0, 230),
	Color3.fromRGB(240, 0, 0),
	Color3.fromRGB(255, 170, 0),
	Color3.fromRGB(255, 240, 0),
}

local function rainbowSequence(): ColorSequence
	-- Dos vueltas de colores en un marco del doble de ancho: al desplazarlo medio ancho el dibujo
	-- vuelve a coincidir y el movimiento no tiene saltos.
	local keys = {}
	local bands = #RAINBOW * 2
	for i = 0, bands - 1 do
		local color = RAINBOW[i % #RAINBOW + 1]
		local a, b = i / bands, (i + 1) / bands
		table.insert(keys, ColorSequenceKeypoint.new(a, color))
		table.insert(keys, ColorSequenceKeypoint.new(math.max(a, b - 0.0001), color))
	end
	return ColorSequence.new(keys)
end

local function applyScale()
	local size = gui.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		return
	end
	local scale = size.Y / DESIGN_H
	if size.X / scale < MIN_W then
		scale = size.X / MIN_W
	end
	designScale.Scale = scale
	designRoot.Size = UDim2.fromOffset(size.X / scale, size.Y / scale)
end

local function drawMap(frame: Frame, dotSize: number)
	for _, child in frame:GetChildren() do
		if child.Name == "Dot" then
			child:Destroy()
		end
	end
	for _, m in markers do
		local dot = Theme.frame({
			Name = "Dot",
			Size = UDim2.fromOffset(dotSize, dotSize),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 + m.x / (halfSize * 2), 0.5 + m.z / (halfSize * 2)),
			BackgroundColor3 = MARKER_COLOR[m.kind] or WHITE,
			ZIndex = 3,
			Parent = frame,
		})
		Theme.corner(dot, dotSize)
		Theme.stroke(dot, C.Outline, 1)
	end
end

local function buildMinimap(parent: Instance)
	-- Círculo bajo el nivel, con la brújula (N, E, S, W) girando con la cámara
	local holder = Theme.frame({ Name = "Minimap", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -26, 0, 116), Size = UDim2.fromOffset(MINIMAP_SIZE, MINIMAP_SIZE), Parent = parent })
	local mini = Theme.frame({ Name = "Map", BackgroundColor3 = Color3.fromRGB(16, 26, 30), BackgroundTransparency = 0.15, Size = UDim2.fromScale(1, 1), ClipsDescendants = true, Parent = holder })
	Theme.corner(mini, 999)
	Theme.stroke(mini, Color3.fromRGB(10, 12, 14), 3)
	local arrow = outlined(sans({ Name = "Player", Text = "▲", TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(20, 20), TextColor3 = WHITE, ZIndex = 5, Parent = mini }), 1.5)
	local compass = {}
	for _, letter in { "N", "E", "S", "W" } do
		compass[letter] = outlined(sans({ Name = "Compass" .. letter, Text = letter, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(24, 24), ZIndex = 6, Parent = holder }), 2)
	end
	refs.mini, refs.miniArrow, refs.compass = mini, arrow, compass

	local full = Theme.frame({ Size = UDim2.fromOffset(560, 560), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(20, 30, 25), BackgroundTransparency = 0.1, Visible = false, ZIndex = 20, Parent = parent })
	Theme.corner(full, 12)
	local fullArrow = sans({ Name = "Player", Text = "▲", TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(22, 22), ZIndex = 25, Parent = full })
	local legend = Theme.frame({ Size = UDim2.new(0, 190, 1, 0), Position = UDim2.new(1, 8, 0, 0), BackgroundTransparency = 0.2, BackgroundColor3 = C.Panel, Parent = full })
	Theme.corner(legend, 8)
	Theme.padding(legend, 8)
	Theme.list(legend, nil, 2)
	for kind, name in MARKER_NAMES do
		sans({ Text = "● " .. name, TextSize = 18, TextColor3 = MARKER_COLOR[kind], Size = UDim2.new(1, 0, 0, 20), Parent = legend })
	end
	refs.full, refs.fullArrow = full, fullArrow
end

local function redrawMarkers()
	if refs.mini then
		drawMap(refs.mini, 8)
		drawMap(refs.full, 10)
	end
end

-- Icono pequeño + número grande (fila superior izquierda).
local function counter(parent: Instance, name: string, x: number, icon: (holder: GuiObject) -> ()): TextLabel
	local holder = Theme.frame({ Name = name, BackgroundTransparency = 1, Position = UDim2.fromOffset(x, 36), Size = UDim2.fromOffset(160, 44), Parent = parent })
	icon(Theme.frame({ BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(28, 28), Parent = holder }))
	return outlined(label({ Name = "Value", Text = "0", TextSize = 38, Position = UDim2.fromOffset(36, 0), Size = UDim2.new(1, -36, 1, 0), Parent = holder }), 2.5)
end

local function slotRow(parent: Instance, name: string, y: number): Frame
	local row = Theme.frame({ Name = name, BackgroundTransparency = 1, Position = UDim2.fromOffset(22, y), Size = UDim2.fromOffset(4 * SLOT + 3 * SLOT_GAP, SLOT), Parent = parent })
	for i = 1, 4 do
		Theme.frame({ Name = "Empty" .. i, BackgroundColor3 = CELL_BG, BackgroundTransparency = 0.45, Position = UDim2.fromOffset((i - 1) * (SLOT + SLOT_GAP), 0), Size = UDim2.fromOffset(SLOT, SLOT), Parent = row })
	end
	return row
end

-- Rellena una fila de casillas con armas o tomos (icono + "LVL n").
local function fillRow(row: Frame, list, icon: (holder: GuiObject, id: string) -> ())
	for _, child in row:GetChildren() do
		if child:GetAttribute("Filled") then
			child:Destroy()
		end
	end
	for i, entry in list do
		if i > 4 then
			break
		end
		local cell = Theme.frame({ Name = entry.id, BackgroundTransparency = 1, Position = UDim2.fromOffset((i - 1) * (SLOT + SLOT_GAP), 0), Size = UDim2.fromOffset(SLOT, SLOT), ZIndex = 2, Parent = row })
		cell:SetAttribute("Filled", true)
		icon(Theme.frame({ BackgroundTransparency = 1, Position = UDim2.fromOffset(3, 2), Size = UDim2.new(1, -6, 1, -12), ZIndex = 2, Parent = cell }), entry.id)
		outlined(label({ Name = "Level", Text = "LVL " .. entry.level, TextSize = 19, FontFace = Theme.FontFaceDense, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 2), Size = UDim2.new(1, 4, 0, 18), ZIndex = 4, Parent = cell }), 1.5)
	end
end

function Hud.init()
	gui = ClientState.screen("Hud", 5)
	gui.Enabled = false
	designRoot = Theme.frame({ Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromOffset(1920, DESIGN_H), Parent = gui })
	designScale = Instance.new("UIScale")
	designScale.Name = "DesignScale"
	designScale.Parent = designRoot
	local root = designRoot

	-- Barra de experiencia a todo el ancho (arcoíris en movimiento al subir de nivel)
	local xpBack = Theme.frame({ Name = "XP", BackgroundColor3 = Color3.fromRGB(12, 16, 20), BackgroundTransparency = 0.25, Size = UDim2.new(1, 0, 0, 23), ClipsDescendants = true, Parent = root })
	refs.xpFill = Theme.frame({ Name = "Fill", BackgroundColor3 = XP_BLUE, Size = UDim2.fromScale(0, 1), Parent = xpBack })
	local rainbow = Theme.frame({ Name = "Rainbow", BackgroundColor3 = WHITE, Size = UDim2.fromScale(2, 1), Visible = false, ZIndex = 2, Parent = xpBack })
	local gradient = Instance.new("UIGradient")
	gradient.Color = rainbowSequence()
	gradient.Parent = rainbow
	refs.rainbow = rainbow
	Theme.stroke(xpBack, Color3.fromRGB(0, 0, 0), 1)

	-- Fila superior izquierda: tiempo de partida, plata, oro y bajas
	refs.runTime = counter(root, "RunTime", 30, Icons.clock)
	refs.silver = counter(root, "Silver", 182, function(h)
		Icons.coin(h, SILVER, "S")
	end)
	refs.gold = counter(root, "Gold", 352, function(h)
		Icons.coin(h, GOLD, "G")
	end)
	refs.kills = counter(root, "Kills", 526, Icons.skull)

	-- Vida (y escudo, si lo hay)
	local hpBack = Theme.frame({ Name = "Health", BackgroundColor3 = Color3.fromRGB(14, 22, 30), Position = UDim2.fromOffset(22, 100), Size = UDim2.fromOffset(232, 26), Parent = root })
	Theme.stroke(hpBack, Color3.fromRGB(0, 0, 0), 1)
	refs.hpFill = Theme.frame({ Name = "Fill", BackgroundColor3 = HP_RED, Size = UDim2.fromScale(1, 1), Parent = hpBack })
	refs.hpText = outlined(label({ Name = "Text", Text = "", TextSize = 27, FontFace = Theme.FontFaceDense, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = hpBack }), 2)
	local shBack = Theme.frame({ Name = "Shield", BackgroundColor3 = Color3.fromRGB(14, 22, 30), Position = UDim2.fromOffset(22, 128), Size = UDim2.fromOffset(232, 14), Visible = false, Parent = root })
	refs.shFill = Theme.frame({ Name = "Fill", BackgroundColor3 = C.Shield, Size = UDim2.fromScale(1, 1), Parent = shBack })
	refs.shText = outlined(sans({ Name = "Text", Text = "", TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = shBack }), 1)
	refs.shBack = shBack
	refs.momentum = outlined(sans({ Name = "Momentum", Text = "", TextSize = 18, Position = UDim2.fromOffset(262, 102), Size = UDim2.fromOffset(160, 22), Parent = root }), 1.5)

	-- Armas y tomos de la partida
	refs.weaponRow = slotRow(root, "Weapons", 150)
	refs.tomeRow = slotRow(root, "Tomes", 150 + SLOT + SLOT_GAP)

	-- Misión actual
	local quest = Theme.frame({ Name = "Quest", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.05, Position = UDim2.fromOffset(22, 284), Size = UDim2.fromOffset(380, 66), Parent = root })
	local check = Theme.frame({ Name = "Check", BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 13), Size = UDim2.fromOffset(22, 22), Parent = quest })
	Theme.stroke(check, WHITE, 2)
	refs.questText = sans({ Name = "Text", Text = "", TextSize = 26, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(46, 6), Size = UDim2.fromOffset(326, 58), Parent = quest })

	-- Centro: cuenta atrás de la etapa
	refs.clock = outlined(label({ Name = "Clock", Text = "10:00", TextSize = 54, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 30), Size = UDim2.fromOffset(300, 56), Parent = root }), 3)
	refs.clockLabel = outlined(label({ Name = "ClockLabel", Text = "", TextSize = 27, TextColor3 = C.Bad, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 86), Size = UDim2.fromOffset(500, 30), Parent = root }), 2)

	-- Jefe
	local bossBack = Theme.frame({ Name = "Boss", BackgroundColor3 = Color3.fromRGB(14, 16, 20), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 118), Size = UDim2.fromOffset(620, 26), Visible = false, Parent = root })
	Theme.stroke(bossBack, Color3.fromRGB(0, 0, 0), 2)
	refs.bossFill = Theme.frame({ Name = "Fill", BackgroundColor3 = Color3.fromRGB(200, 30, 50), Size = UDim2.fromScale(1, 1), Parent = bossBack })
	refs.bossText = outlined(label({ Name = "Text", Text = "", TextSize = 25, FontFace = Theme.FontFaceDense, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = bossBack }), 2)
	refs.bossBack = bossBack

	-- Arriba a la derecha: precio del próximo cofre y nivel
	local chest = Theme.frame({ Name = "ChestCost", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -230, 0, 36), Size = UDim2.fromOffset(150, 44), Parent = root })
	Icons.chest(Theme.frame({ BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(26, 22), Parent = chest }))
	Icons.coin(Theme.frame({ BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 30, 0.5, 0), Size = UDim2.fromOffset(24, 24), Parent = chest }), GOLD, "G")
	refs.chestCost = outlined(label({ Name = "Value", Text = "", TextSize = 34, Position = UDim2.fromOffset(58, 0), Size = UDim2.new(1, -58, 1, 0), Parent = chest }), 2.5)
	refs.level = outlined(label({ Name = "Level", Text = "LVL 1", TextSize = 56, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 28), Size = UDim2.fromOffset(220, 60), Parent = root }), 3)

	-- Objetos (abajo a la derecha)
	local items = Theme.frame({ Name = "Items", Size = UDim2.fromOffset(480, 160), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -16), BackgroundTransparency = 1, Parent = root })
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(48, 48)
	grid.CellPadding = UDim2.fromOffset(5, 5)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Right
	grid.VerticalAlignment = Enum.VerticalAlignment.Bottom
	grid.SortOrder = Enum.SortOrder.Name
	grid.Parent = items
	refs.items = items

	-- Avisos
	refs.toasts = Theme.frame({ Name = "Toasts", Size = UDim2.fromOffset(700, 160), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 160), BackgroundTransparency = 1, Parent = root })
	Theme.list(refs.toasts, nil, 4, Enum.HorizontalAlignment.Center)

	refs.help = outlined(sans({ Name = "Help", Text = helpText(), TextSize = 18, TextColor3 = Color3.fromRGB(220, 220, 215), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 22, 1, -14), Size = UDim2.fromOffset(500, 20), Parent = root }), 1)

	buildMinimap(root)

	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyScale)
	applyScale()

	Net.get("Hud").OnClientEvent:Connect(Hud.update)
	Net.get("Toast").OnClientEvent:Connect(Hud.toast)
	Net.get("MapMarkers").OnClientEvent:Connect(function(list)
		markers = list
		redrawMarkers()
	end)
	Net.get("RunStarted").OnClientEvent:Connect(function(info)
		halfSize = info.halfSize
		markers = {}
		redrawMarkers()
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not gui.Enabled then
			return
		end
		if ClientState.matches("Map", input.KeyCode) then
			refs.full.Visible = not refs.full.Visible
		end
	end)

	local rainbowTime = 0
	RunService.RenderStepped:Connect(function(dt)
		if not gui.Enabled then
			return
		end
		-- Arcoíris en movimiento mientras se elige mejora (o la barra está llena)
		local full = lastHud ~= nil and lastHud.xp >= lastHud.xpToNext
		local leveling = ClientState.levelUpOpen == true or full
		refs.rainbow.Visible = leveling
		if leveling then
			rainbowTime = (rainbowTime + dt * 0.35) % 1
			refs.rainbow.Position = UDim2.fromScale(-rainbowTime, 0)
		end

		local character = Players.LocalPlayer.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hrp then
			return
		end
		local pos = hrp.Position
		local look = workspace.CurrentCamera.CFrame.LookVector
		local heading = math.atan2(look.X, -look.Z)
		local rotation = math.deg(heading)
		local u, v = 0.5 + pos.X / (halfSize * 2), 0.5 + pos.Z / (halfSize * 2)
		refs.fullArrow.Position = UDim2.fromScale(u, v)
		refs.fullArrow.Rotation = rotation
		-- Minimapa centrado en el jugador (zoom 3×); los puntos fuera del círculo se ocultan
		local zoom = 3
		refs.miniArrow.Rotation = rotation
		for _, dot in refs.mini:GetChildren() do
			if dot.Name == "Dot" then
				if dot:GetAttribute("x") == nil then
					dot:SetAttribute("x", dot.Position.X.Scale - 0.5)
					dot:SetAttribute("z", dot.Position.Y.Scale - 0.5)
				end
				local du = ((dot:GetAttribute("x") :: number) - (u - 0.5)) * zoom
				local dv = ((dot:GetAttribute("z") :: number) - (v - 0.5)) * zoom
				dot.Position = UDim2.fromScale(0.5 + du, 0.5 + dv)
				dot.Visible = du * du + dv * dv < 0.21
			end
		end
		-- Brújula en el borde del círculo, girando con la cámara
		local radius = MINIMAP_SIZE / 2 + 4
		for letter, angle in { N = 0, E = math.pi / 2, S = math.pi, W = -math.pi / 2 } do
			local a = angle - heading
			refs.compass[letter].Position = UDim2.new(0.5, math.sin(a) * radius, 0.5, -math.cos(a) * radius)
		end
	end)
end

function Hud.show(visible: boolean)
	gui.Enabled = visible
	if visible then
		applyScale()
		refs.help.Text = helpText() -- las teclas pueden haberse reasignado en Ajustes
	end
	if not visible then
		refs.full.Visible = false
	end
end

function Hud.toast(text: string)
	local toast = outlined(label({
		Text = text,
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 34),
		TextColor3 = C.Yellow,
		Parent = refs.toasts,
	}), 2)
	task.delay(3, function()
		toast:Destroy()
	end)
end

local function itemCell(item)
	local cell = Theme.frame({ Name = item.name, BackgroundColor3 = CELL_BG, BackgroundTransparency = 0.35 })
	Theme.stroke(cell, Theme.Rarity[item.rarity], 2)
	Icons.item(Theme.frame({ BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = cell }), item.rarity)
	if item.count > 1 then
		outlined(label({ Text = "×" .. item.count, TextSize = 20, FontFace = Theme.FontFaceDense, Size = UDim2.new(1, -3, 0, 18), Position = UDim2.new(0, 0, 1, -17), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 5, Parent = cell }), 1.5)
	end
	return cell
end

-- Misión que se muestra en el recuadro según el momento de la etapa.
local function questText(data): string
	if data.swarm then
		return "¡Sobrevive al Final Swarm!"
	elseif data.boss then
		return "¡Derrota al jefe!"
	end
	for _, m in markers do
		if m.kind == "ExitPortal" then
			return "¡Ve al portal de salida!"
		end
	end
	return "¡Encuentra el portal del jefe!"
end

-- Barrita de vida bajo los pies del personaje (como en la referencia)
local function characterBar(fraction: number)
	local character = Players.LocalPlayer.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end
	local bar = rootPart:FindFirstChild("HealthBar") :: BillboardGui?
	if not bar then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "HealthBar"
		billboard.Size = UDim2.fromOffset(100, 10)
		billboard.StudsOffset = Vector3.new(0, -3.4, 0)
		billboard.AlwaysOnTop = true
		billboard.LightInfluence = 0
		billboard.Parent = rootPart
		local back = Theme.frame({ Name = "Back", BackgroundColor3 = Color3.fromRGB(20, 20, 22), Size = UDim2.fromScale(1, 1), Parent = billboard })
		Theme.frame({ Name = "Fill", BackgroundColor3 = Color3.fromRGB(225, 20, 20), Size = UDim2.fromScale(1, 1), Parent = back })
		bar = billboard
	end
	local fill = (bar :: BillboardGui).Back.Fill :: Frame
	fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
end

function Hud.update(data)
	lastHud = data
	characterBar(data.hp / math.max(1, data.maxHp))
	local overheal = math.max(0, data.hp - data.maxHp)
	refs.hpFill.Size = UDim2.fromScale(math.clamp(data.hp / data.maxHp, 0, 1), 1)
	refs.hpText.Text = string.format("%d/%d%s", math.ceil(math.min(data.hp, data.maxHp)), math.ceil(data.maxHp), if overheal > 0 then string.format(" (+%d)", overheal) else "")
	refs.shBack.Visible = data.maxShield > 0
	if data.maxShield > 0 then
		refs.shFill.Size = UDim2.fromScale(math.clamp(data.shield / data.maxShield, 0, 1), 1)
		refs.shText.Text = string.format("Escudo %d", math.ceil(data.shield))
	end
	refs.momentum.Text = if data.momentum then string.format("Impulso %d%%", math.floor(data.momentum * 100)) else ""
	refs.xpFill.Size = UDim2.fromScale(math.clamp(data.xp / data.xpToNext, 0, 1), 1)
	refs.level.Text = "LVL " .. data.level

	refs.runTime.Text = Theme.formatTime(data.runTime or 0)
	local silver = (ClientState.profile and ClientState.profile.silver or 0) + (data.silverRun or 0)
	refs.silver.Text = Theme.formatThousands(silver)
	refs.gold.Text = Theme.formatThousands(data.gold)
	refs.kills.Text = Theme.formatThousands(data.kills)
	refs.chestCost.Text = if data.chestCost then tostring(data.chestCost) else ""

	if data.swarm then
		refs.clock.Text = Theme.formatTime(data.swarmTime)
		refs.clock.TextColor3 = C.Bad
		refs.clockLabel.Text = "FINAL SWARM"
	else
		refs.clock.Text = Theme.formatTime(data.stageTime)
		refs.clock.TextColor3 = WHITE
		refs.clockLabel.Text = ""
	end
	refs.bossBack.Visible = data.boss ~= nil
	if data.boss then
		refs.bossFill.Size = UDim2.fromScale(math.clamp(data.boss.hp / data.boss.max, 0, 1), 1)
		refs.bossText.Text = string.format("%s  %s / %s", data.boss.name, Theme.formatNumber(data.boss.hp), Theme.formatNumber(data.boss.max))
	end
	refs.questText.Text = questText(data)

	-- Armas y tomos: sólo se redibujan si cambian
	local keys = {}
	for _, w in data.weapons do
		table.insert(keys, "w" .. w.id .. ":" .. w.level)
	end
	for _, t in data.tomes do
		table.insert(keys, "t" .. t.id .. ":" .. t.level)
	end
	local loadoutKey = table.concat(keys, ",")
	if loadoutKey ~= refs.loadoutKey then
		refs.loadoutKey = loadoutKey
		fillRow(refs.weaponRow, data.weapons, Icons.weapon)
		fillRow(refs.tomeRow, data.tomes, function(holder, id)
			Icons.tome(holder, id)
		end)
	end

	local signature = {}
	for _, item in data.items do
		table.insert(signature, item.id .. item.count)
	end
	table.sort(signature)
	local key = table.concat(signature, ",")
	if key ~= refs.itemKey then
		refs.itemKey = key
		for _, child in refs.items:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		for _, item in data.items do
			itemCell(item).Parent = refs.items
		end
	end
end

function Hud.last()
	return lastHud
end

return Hud
