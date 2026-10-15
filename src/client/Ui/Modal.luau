-- Ventana de elección: subida de nivel (con Refresh, Skip y Banish), objeto de cofre, Charge
-- Shrine, Microwave y Shady Guy. La simulación del servidor está en pausa mientras se muestra.
-- Se ignoran las entradas durante un instante tras abrirla para evitar elecciones accidentales.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Net = require(ReplicatedStorage.Shared.Net)
local ClientState = require(script.Parent.Parent.ClientState)
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Spanish = require(ReplicatedStorage.Shared.Data.Spanish)

local Modal = {}

local C = Theme.Colors
local INPUT_LOCK = 0.35

local gui: ScreenGui
local panel: Frame
local titleLabel: TextLabel
local cards: ScrollingFrame
local actions: Frame
local current = nil
local openedAt = 0
local banishMode = false

local function send(action: string, index: number?)
	if not current or os.clock() - openedAt < INPUT_LOCK then
		return
	end
	if action == "pick" and banishMode then
		action = "banish"
		banishMode = false
	end
	Net.get("ModalChoice"):FireServer(action, index)
	if action == "pick" or action == "skip" then
		-- Evita dobles envíos hasta que llegue el siguiente estado
		current = nil
		gui.Enabled = false
	end
end

local KIND_HINT = {
	LevelUp = "Elige una mejora (1, 2, 3)",
	Item = "Has encontrado un objeto",
	Shrine = "Elige una bonificación",
	Microwave = "Duplicar cuesta oro y sacrifica otro objeto aleatorio de la misma rareza",
	Shop = "Compra un objeto con oro",
}

local function render(data)
	for _, child in cards:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	for _, child in actions:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	titleLabel.Text = string.format("%s\n<font size=\"14\" color=\"#%s\">%s%s</font>", data.title or "", C.Muted:ToHex(), KIND_HINT[data.kind] or "", if (data.remaining or 0) > 0 then string.format(" · %d más en cola", data.remaining) else "")
	local first
	for i, choice in data.choices do
		local rarityColor = Theme.Rarity[choice.rarity] or C.Text
		local card = Theme.button({
			Text = "",
			Size = UDim2.fromOffset(230, 300),
			LayoutOrder = i,
			BackgroundColor3 = C.Panel,
			AutoButtonColor = true,
			Parent = cards,
		}, function()
			send("pick", i)
		end)
		Theme.stroke(card, rarityColor, 3)
		Theme.padding(card, 10)
		local lines = {}
		for _, change in choice.changes or {} do
			table.insert(lines, "• " .. change.text)
		end
		-- Tomos: su icono arriba y el nombre en español
		local isTome = (choice.type == "TomeUp" or choice.type == "TomeNew") and choice.id ~= nil
		local top = 0
		local name = choice.name or ""
		if isTome then
			Icons.tome(Theme.frame({ Name = "TomeIcon", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(64, 64), Parent = card }), choice.id)
			top = 68
			name = Spanish.tomeName(choice.id, name)
		end
		local desc = if isTome then Spanish.tomeDescription(choice.id, choice.desc) else choice.desc or ""
		Theme.label({
			RichText = true,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(0, top),
			Size = UDim2.new(1, 0, 1, -top),
			TextSize = 14,
			Font = Theme.FontBody,
			Text = string.format(
				"<font size=\"12\" color=\"#%s\">%s</font>\n<b><font size=\"20\">%s</font></b>\n<font color=\"#%s\">%s</font>\n\n%s\n\n<font color=\"#%s\">%s</font>\n\n<font size=\"12\" color=\"#%s\">[%d]</font>",
				rarityColor:ToHex(),
				Theme.RarityName[choice.rarity] or "",
				name,
				C.Accent:ToHex(),
				choice.subtitle or "",
				desc,
				C.Good:ToHex(),
				table.concat(lines, "\n"),
				C.Muted:ToHex(),
				i
			),
			Parent = card,
		})
		first = first or card
	end

	local charges = data.charges
	if data.kind == "LevelUp" and charges then
		if charges.Refresh > 0 then
			Theme.button({ Text = string.format("Refresh (%d)", charges.Refresh), Size = UDim2.fromOffset(150, 40), Parent = actions }, function()
				send("refresh")
			end)
		end
		if charges.Skip > 0 then
			Theme.button({ Text = string.format("Skip (%d)", charges.Skip), Size = UDim2.fromOffset(150, 40), Parent = actions }, function()
				send("skip")
			end)
		end
		if charges.Banish > 0 then
			local b
			b = Theme.button({ Text = string.format("Banish (%d)", charges.Banish), Size = UDim2.fromOffset(150, 40), Parent = actions }, function()
				banishMode = not banishMode
				b.BackgroundColor3 = if banishMode then C.Bad else C.PanelLight
				b.Text = if banishMode then "Elige qué excluir" else string.format("Banish (%d)", charges.Banish)
			end)
		end
	elseif data.canSkip then
		Theme.button({ Text = if data.kind == "Item" then "Descartar" else "Cerrar", Size = UDim2.fromOffset(150, 40), Parent = actions }, function()
			send("skip")
		end)
	end
	if UserInputService.GamepadEnabled and first then
		GuiService.SelectedObject = first
	end
	-- Elección automática (opción del jugador; adaptación de la recreación)
	if data.kind == "LevelUp" and ClientState.settings.autoPick and #data.choices > 0 then
		task.delay(INPUT_LOCK + 0.05, function()
			if current == data then
				send("pick", 1)
			end
		end)
	end
end

function Modal.init()
	gui = ClientState.screen("Modal", 20)
	gui.Enabled = false
	local shade = Theme.frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Parent = gui })
	panel = Theme.frame({ Size = UDim2.new(0, 780, 0, 460), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Parent = shade })
	titleLabel = Theme.label({ Text = "", FontFace = Theme.HudFontFace, RichText = true, TextSize = 28, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 64), Parent = panel })
	cards = Instance.new("ScrollingFrame")
	cards.Size = UDim2.new(1, 0, 0, 320)
	cards.Position = UDim2.new(0, 0, 0, 70)
	cards.BackgroundTransparency = 1
	cards.ScrollBarThickness = 6
	cards.ScrollingDirection = Enum.ScrollingDirection.X
	cards.AutomaticCanvasSize = Enum.AutomaticSize.X
	cards.CanvasSize = UDim2.new()
	cards.Parent = panel
	Theme.list(cards, Enum.FillDirection.Horizontal, 14, Enum.HorizontalAlignment.Center)
	actions = Theme.frame({ Size = UDim2.new(1, 0, 0, 44), Position = UDim2.new(0, 0, 0, 400), BackgroundTransparency = 1, Parent = panel })
	Theme.list(actions, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center)

	Net.get("Modal").OnClientEvent:Connect(function(data)
		current = data
		banishMode = false
		if not data then
			gui.Enabled = false
			GuiService.SelectedObject = nil
			return
		end
		openedAt = os.clock()
		gui.Enabled = true
		render(data)
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not current or not gui.Enabled then
			return
		end
		for i, action in { "Choice1", "Choice2", "Choice3" } do
			if ClientState.matches(action, input.KeyCode) and current.choices[i] then
				send("pick", i)
				return
			end
		end
	end)
end

function Modal.isOpen(): boolean
	return gui.Enabled
end

return Modal
