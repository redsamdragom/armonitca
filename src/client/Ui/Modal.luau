-- Ventana de elección con la composición de la referencia: panel "OFERTAS DE MEJORA" en el centro
-- con las cartas apiladas (rareza, icono, nombre, nivel y cambios "antes → después") y los botones
-- DESTERRAR, SALTAR y REFRESCAR con sus cargas; a la izquierda el inventario (armas, tomos y
-- objetos) y a la derecha las estadísticas, sobre rayos de luz que giran detrás. La usan la subida
-- de nivel, el cofre, los santuarios, el microondas y el vendedor.
-- La simulación del servidor está en pausa mientras se muestra. Se ignoran las entradas durante un
-- instante tras abrirla para evitar elecciones accidentales.
-- Medidas en píxeles de diseño (captura de 2000×1226 escalada a 1080 de alto).

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Stats = require(ReplicatedStorage.Shared.Stats)
local ClientState = require(script.Parent.Parent.ClientState)
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Spanish = require(ReplicatedStorage.Shared.Data.Spanish)

local Modal = {}

local C = Theme.Colors
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local INPUT_LOCK = 0.35
local DESIGN_H = 1080
local MIN_W = 1500

local CARD_W, CARD_H, CARD_GAP = 596, 136, 19
local CARDS_TOP, CARDS_BOTTOM, FOOTER_H = 24, 50, 74
local PANEL_W = 685

local NEW_BG = Color3.fromRGB(42, 45, 45)
local NEW_BORDER = Color3.fromRGB(120, 122, 120)
local SLOT_BG = Color3.fromRGB(30, 35, 33)
local LABEL_TAN = Color3.fromRGB(232, 200, 120)
local VALUE_GREEN = Color3.fromRGB(90, 230, 70)
local LEVEL_YELLOW = Color3.fromRGB(255, 214, 40)
local BANISH_RED = Color3.fromRGB(200, 52, 46)
local SKIP_GREEN = Color3.fromRGB(58, 154, 58)
local REFRESH_BLUE = Color3.fromRGB(47, 111, 208)

-- Nombres de rareza como los muestra la referencia
local RARITY_TAG = { Common = "Common", Uncommon = "Uncommon", Rare = "Rare", Epic = "Epic", Legendary = "Legendary" }

local gui: ScreenGui
local root: Frame
local designScale: UIScale
local rays: Frame
local offerHolder: Frame
local inventoryHolder: Frame
local statsHolder: Frame
local current = nil
local openedAt = 0
local banishMode = false
local getHud: () -> any = function()
	return nil
end
local cards: { TextButton } = {}
local cardBrackets: { [TextButton]: { Frame } } = {}
local focusedCard: TextButton? = nil

local raysConnection: RBXScriptConnection? = nil

-- Abre o cierra la ventana; los rayos sólo giran mientras está abierta.
local function setOpen(open: boolean)
	gui.Enabled = open
	if open and not raysConnection then
		raysConnection = RunService.RenderStepped:Connect(function(dt)
			rays.Rotation = (rays.Rotation + dt * 6) % 360
		end)
	elseif not open and raysConnection then
		raysConnection:Disconnect()
		raysConnection = nil
	end
end

local function outlined<T>(label: T, thickness: number?): T
	Theme.outlined(label :: any, thickness or 2)
	return label
end

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
		setOpen(false)
	end
end

-- Pernos pequeños en las esquinas de un marco.
local function cornerBolts(frame: GuiObject, size: number)
	for _, corner in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
		local b = Theme.frame({
			Name = "Bolt",
			BackgroundColor3 = C.Bolt,
			AnchorPoint = corner,
			Position = UDim2.new(corner.X, if corner.X == 0 then 1 else -1, corner.Y, if corner.Y == 0 then 1 else -1),
			Size = UDim2.fromOffset(size, size),
			ZIndex = 6,
			Parent = frame,
		})
		Theme.stroke(b, C.Outline, 1)
	end
end

-- Escala de diseño: 1080 de alto (o MIN_W de ancho en pantallas estrechas).
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
	root.Size = UDim2.fromOffset(size.X / scale, size.Y / scale)
end

-- Nombre en español de una elección (tomos y armas); el resto, tal cual.
local function choiceName(choice): string
	local name = choice.name or ""
	if (choice.type == "TomeUp" or choice.type == "TomeNew") and choice.id then
		return Spanish.tomeName(choice.id, name)
	elseif (choice.type == "WeaponUp" or choice.type == "WeaponNew") and choice.id then
		return Spanish.weaponName(choice.id, name)
	end
	return name
end

local function choiceIcon(holder: GuiObject, choice)
	if (choice.type == "TomeUp" or choice.type == "TomeNew") and choice.id then
		Icons.tome(holder, choice.id)
	elseif (choice.type == "WeaponUp" or choice.type == "WeaponNew") and choice.id then
		Icons.weapon(holder, choice.id)
	else
		Icons.item(holder, choice.rarity)
	end
end

local function focusCard(card: TextButton?)
	if focusedCard and cardBrackets[focusedCard] then
		for _, b in cardBrackets[focusedCard] do
			b.Visible = false
		end
	end
	focusedCard = card
	if card and cardBrackets[card] then
		for _, b in cardBrackets[card] do
			b.Visible = true
		end
	end
end

-- Línea "Daño: 6 → 7.4": etiqueta en tostado, flecha blanca y valor nuevo en verde.
local function changeText(change): string
	if change.from and change.to then
		local label = if change.stat and Stats.Display[change.stat] then Spanish.statName(change.stat, change.label) else change.label or ""
		return string.format(
			"<font color=\"#%s\">%s: %s</font> → <font color=\"#%s\">%s</font>",
			LABEL_TAN:ToHex(),
			label,
			change.from,
			VALUE_GREEN:ToHex(),
			change.to
		)
	end
	return string.format("<font color=\"#%s\">%s</font>", LABEL_TAN:ToHex(), change.text or "")
end

local function buildCard(parent: Instance, choice, index: number, y: number): TextButton
	local isNew = choice.type == "WeaponNew" or choice.type == "TomeNew"
	local rarityColor = Theme.Rarity[choice.rarity] or C.Text
	local card = Instance.new("TextButton")
	card.Name = "Card" .. index
	card.Text = ""
	card.AutoButtonColor = false
	card.BorderSizePixel = 0
	card.BackgroundColor3 = if isNew then NEW_BG else rarityColor:Lerp(BLACK, 0.86)
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.new(0.5, 0, 0, y)
	card.Size = UDim2.fromOffset(CARD_W, CARD_H)
	card.Parent = parent
	Theme.stroke(card, if isNew then NEW_BORDER else rarityColor:Lerp(BLACK, 0.2), 2)
	cornerBolts(card, 6)

	-- Rareza (o "New") sobre el icono
	outlined(Theme.label({
		Name = "Rarity",
		Text = if isNew then "New" else RARITY_TAG[choice.rarity] or Theme.RarityName[choice.rarity] or "",
		TextSize = 22,
		TextColor3 = if isNew then WHITE else rarityColor,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(14, 4),
		Size = UDim2.fromOffset(109, 24),
		Parent = card,
	}), 1.5)
	local iconBox = Theme.frame({ Name = "Icon", BackgroundColor3 = if isNew then Color3.fromRGB(200, 200, 200) else Color3.fromRGB(18, 24, 20), Position = UDim2.fromOffset(21, 30), Size = UDim2.fromOffset(95, 95), ClipsDescendants = true, Parent = card })
	Theme.stroke(iconBox, if isNew then Color3.fromRGB(230, 230, 230) else rarityColor, 3)
	local iconInner = Theme.frame({ Name = if choice.type == "TomeUp" or choice.type == "TomeNew" then "TomeIcon" else "ChoiceIcon", BackgroundTransparency = 1, Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -8), Parent = iconBox })
	choiceIcon(iconInner, choice)

	outlined(Theme.label({ Name = "Name", Text = choiceName(choice), TextSize = 31, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(138, 18), Size = UDim2.new(1, -270, 0, 40), Parent = card }), 2)
	local tag = if isNew then "NEW" elseif choice.level then "LVL " .. choice.level else nil
	if tag then
		outlined(Theme.label({ Name = "Tag", Text = tag, TextSize = 28, TextColor3 = LEVEL_YELLOW, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -24, 0, 14), Size = UDim2.fromOffset(130, 34), Parent = card }), 2)
	end

	-- Cambios "antes → después" o, si no hay, la descripción (y el subtítulo de cofres y tiendas)
	local changes = choice.changes or {}
	if #changes > 0 then
		local step = if #changes > 2 then 22 else 31
		for k, change in changes do
			if k > 3 then
				break
			end
			outlined(Theme.label({
				Name = "Change" .. k,
				Text = changeText(change),
				RichText = true,
				TextSize = if #changes > 2 then 20 else 24,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(138, 62 + (k - 1) * step),
				Size = UDim2.new(1, -160, 0, 30),
				Parent = card,
			}), 1.5)
		end
	else
		local desc = if (choice.type == "TomeUp" or choice.type == "TomeNew") and choice.id then Spanish.tomeDescription(choice.id, choice.desc) else choice.desc or ""
		if choice.subtitle and choice.subtitle ~= "" and not (choice.type == "WeaponNew" or choice.type == "TomeNew") then
			desc = choice.subtitle .. (if desc ~= "" then " · " .. desc else "")
		end
		outlined(Theme.label({
			Name = "Description",
			Text = desc,
			TextSize = 22,
			TextColor3 = Color3.fromRGB(215, 215, 210),
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(138, 60),
			Size = UDim2.new(1, -160, 0, 70),
			Parent = card,
		}), 1.5)
	end

	cardBrackets[card] = Theme.brackets(card, 22)
	card.MouseEnter:Connect(function()
		focusCard(card)
	end)
	card.SelectionGained:Connect(function()
		focusCard(card)
	end)
	card.Activated:Connect(function()
		send("pick", index)
	end)
	return card
end

-- Botón de acción del pie con su número de cargas encima.
local function actionButton(parent: Instance, name: string, text: string, color: Color3, width: number, count: number?, order: number, onClick: () -> ()): TextButton
	local holder = Theme.frame({ Name = name .. "Holder", BackgroundTransparency = 1, Size = UDim2.fromOffset(width, 46), LayoutOrder = order, Parent = parent })
	local enabled = count == nil or count > 0
	local b = Theme.button({
		Name = name,
		Text = text,
		TextSize = 26,
		TextColor3 = if enabled then WHITE else Color3.fromRGB(170, 170, 170),
		BackgroundColor3 = if enabled then color else Color3.fromRGB(70, 72, 74),
		AutoButtonColor = enabled,
		Size = UDim2.fromScale(1, 1),
		Parent = holder,
	}, function()
		if enabled then
			onClick()
		end
	end, { edge = 5, radius = 6 })
	outlined(b, 2)
	if count then
		outlined(Theme.label({ Name = "Count", Text = tostring(count), TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, -3), Size = UDim2.fromOffset(40, 24), ZIndex = 4, Parent = holder }), 1.5)
	end
	return b
end

local function renderOffer(data)
	offerHolder:ClearAllChildren()
	cards = {}
	cardBrackets = {}
	focusedCard = nil
	local n = #data.choices
	local cardsH = n * CARD_H + math.max(0, n - 1) * CARD_GAP
	local footerTop = CARDS_TOP + cardsH + CARDS_BOTTOM
	local bodyH = footerTop + 9 + FOOTER_H
	local title = if data.kind == "LevelUp" then "OFERTAS DE MEJORA" else string.upper(data.title or "")
	local panel, body = Theme.panel({
		Name = "Offer",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 17),
		Size = UDim2.fromOffset(PANEL_W, bodyH + 73 + 8),
		Parent = offerHolder,
	}, title, 56)
	local header = panel:FindFirstChild("Header", true)
	local titleLabel = header and header:FindFirstChild("Title") :: TextLabel?
	if titleLabel then
		titleLabel.Position = UDim2.fromOffset(28, 0)
		titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
	end
	if (data.remaining or 0) > 0 and header then
		outlined(Theme.label({ Name = "Queue", Text = string.format("+%d", data.remaining), TextSize = 26, TextColor3 = LEVEL_YELLOW, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 0), Size = UDim2.new(0, 80, 1, 0), Parent = header }), 1.5)
	end

	for i, choice in data.choices do
		table.insert(cards, buildCard(body, choice, i, CARDS_TOP + (i - 1) * (CARD_H + CARD_GAP)))
	end

	Theme.divider(panel, body, footerTop)
	local footer = Theme.frame({ Name = "Footer", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, footerTop + 9), Size = UDim2.new(1, 0, 0, FOOTER_H), Parent = body })
	local list = Theme.list(footer, Enum.FillDirection.Horizontal, 37, Enum.HorizontalAlignment.Center)
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	local charges = data.charges
	if data.kind == "LevelUp" and charges then
		local b
		b = actionButton(footer, "Banish", "DESTERRAR", BANISH_RED, 167, charges.Banish, 1, function()
			banishMode = not banishMode
			b.Text = if banishMode then "ELIGE UNA" else "DESTERRAR"
			b.BackgroundColor3 = if banishMode then Color3.fromRGB(120, 24, 20) else BANISH_RED
		end)
		actionButton(footer, "Skip", "SALTAR", SKIP_GREEN, 117, charges.Skip, 2, function()
			send("skip")
		end)
		actionButton(footer, "Refresh", "REFRESCAR", REFRESH_BLUE, 166, charges.Refresh, 3, function()
			send("refresh")
		end)
	elseif data.canSkip then
		actionButton(footer, "Skip", if data.kind == "Item" then "DESCARTAR" else "CERRAR", SKIP_GREEN, 190, nil, 1, function()
			send("skip")
		end)
	end
	focusCard(cards[1])
end

-- Inventario --------------------------------------------------------------------------------------

local SLOT, SLOT_GAP = 55, 5

local function slotRow(parent: Instance, y: number, count: number, fill: (index: number, slot: Frame) -> ())
	for i = 1, count do
		local slot = Theme.frame({ Name = "Slot" .. i, BackgroundColor3 = SLOT_BG, Position = UDim2.fromOffset(22 + (i - 1) * (SLOT + SLOT_GAP), y), Size = UDim2.fromOffset(SLOT, SLOT), Parent = parent })
		fill(i, slot)
	end
end

local function levelBadge(slot: Frame, level: number)
	outlined(Theme.label({ Name = "Level", Text = "LVL " .. level, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 2), Size = UDim2.new(1, 0, 0, 18), ZIndex = 6, Parent = slot }), 1.5)
end

local function renderInventory(hud)
	inventoryHolder:ClearAllChildren()
	local weapons = hud and hud.weapons or {}
	local tomes = hud and hud.tomes or {}
	local items = hud and hud.items or {}
	local itemRows = math.max(1, math.ceil(#items / 7))
	local bodyH = 290 + 30 + itemRows * (SLOT - 7 + SLOT_GAP) + 14
	local _, body = Theme.panel({
		Name = "Inventory",
		Position = UDim2.fromOffset(16, 352),
		Size = UDim2.fromOffset(467, bodyH + 81),
		Parent = inventoryHolder,
	}, "Inventario", 56)
	outlined(Theme.label({ Text = "Armas", TextSize = 32, Position = UDim2.fromOffset(24, 18), Size = UDim2.fromOffset(300, 36), Parent = body }), 2)
	slotRow(body, 58, math.max(4, #weapons), function(i, slot)
		local w = weapons[i]
		if w then
			slot.Name = "Weapon_" .. w.id
			Icons.weapon(Theme.frame({ BackgroundTransparency = 1, Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6), Parent = slot }), w.id)
			levelBadge(slot, w.level)
		end
	end)
	outlined(Theme.label({ Text = "Tomos", TextSize = 32, Position = UDim2.fromOffset(24, 140), Size = UDim2.fromOffset(300, 36), Parent = body }), 2)
	slotRow(body, 182, math.max(4, #tomes), function(i, slot)
		local t = tomes[i]
		if t then
			slot.Name = "Tome_" .. t.id
			Icons.tome(Theme.frame({ BackgroundTransparency = 1, Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6), Parent = slot }), t.id)
			levelBadge(slot, t.level)
		end
	end)
	outlined(Theme.label({ Text = "Objetos", TextSize = 32, Position = UDim2.fromOffset(24, 262), Size = UDim2.fromOffset(300, 36), Parent = body }), 2)
	for i, item in items do
		local size = SLOT - 7
		local cell = Theme.frame({
			Name = "Item_" .. item.id,
			BackgroundColor3 = SLOT_BG,
			Position = UDim2.fromOffset(22 + ((i - 1) % 7) * (size + SLOT_GAP), 304 + math.floor((i - 1) / 7) * (size + SLOT_GAP)),
			Size = UDim2.fromOffset(size, size),
			Parent = body,
		})
		Theme.stroke(cell, Theme.Rarity[item.rarity] or C.Outline, 2)
		Icons.item(Theme.frame({ BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = cell }), item.rarity)
		if item.count > 1 then
			outlined(Theme.label({ Text = "×" .. item.count, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -2, 1, 0), Size = UDim2.fromOffset(40, 16), ZIndex = 6, Parent = cell }), 1.5)
		end
	end
end

-- Estadísticas --------------------------------------------------------------------------------------
-- Grupos y formato como en la referencia: multiplicadores "1.0x", porcentajes y cifras.

local function mult(v: number): string
	return string.format("%.1fx", 1 + v)
end
local function pct(v: number): string
	local p = v * 100
	if math.abs(p - math.round(p)) < 0.05 then
		return string.format("%d%%", math.round(p))
	end
	return string.format("%.1f%%", p)
end
local function flat(v: number): string
	if math.abs(v - math.round(v)) < 1e-6 then
		return tostring(math.round(v))
	end
	return string.format("%.1f", v)
end

local STAT_GROUPS = {
	{
		{ "MaxHealth", Spanish.statName("MaxHealth"), flat },
		{ "Regen", Spanish.statName("Regen"), flat },
		{ "Overheal", Spanish.statName("Overheal"), flat },
		{ "Shield", Spanish.statName("Shield"), flat },
		{ "Armor", Spanish.statName("Armor"), function(v) return pct(Stats.diminishing(v)) end },
		{ "Evasion", Spanish.statName("Evasion"), function(v) return pct(Stats.diminishing(v)) end },
		{ "Lifesteal", Spanish.statName("Lifesteal"), pct },
		{ "Thorns", Spanish.statName("Thorns"), flat },
	},
	{
		{ "Damage", Spanish.statName("Damage"), mult },
		{ "CritChance", Spanish.statName("CritChance"), pct },
		{ "CritDamage", Spanish.statName("CritDamage"), function(v) return string.format("%.1fx", (Config.Player.BaseCritDamage or 2) + v) end },
		{ "AttackSpeed", Spanish.statName("AttackSpeed"), function(v) return pct(1 + v) end },
		{ "Quantity", Spanish.statName("Quantity"), flat },
		{ "Bounces", Spanish.statName("Bounces"), flat },
	},
	{
		{ "Size", Spanish.statName("Size"), mult },
		{ "ProjectileSpeed", Spanish.statName("ProjectileSpeed"), mult },
		{ "Duration", Spanish.statName("Duration"), mult },
		{ "EliteDamage", Spanish.statName("EliteDamage"), mult },
		{ "Knockback", Spanish.statName("Knockback"), mult },
		{ "MoveSpeed", Spanish.statName("MoveSpeed"), mult },
	},
	{
		{ "ExtraJumps", Spanish.statName("ExtraJumps"), flat },
		{ "JumpHeight", Spanish.statName("JumpHeight"), flat },
		{ "Luck", Spanish.statName("Luck"), pct },
		{ "Difficulty", Spanish.statName("Difficulty"), pct },
	},
	{
		{ "PickupRange", Spanish.statName("PickupRange"), flat },
		{ "XPGain", Spanish.statName("XPGain"), mult },
		{ "GoldGain", Spanish.statName("GoldGain"), mult },
		{ "SilverGain", Spanish.statName("SilverGain"), mult },
		{ "EliteSpawn", Spanish.statName("EliteSpawn"), mult },
		{ "PowerupMult", Spanish.statName("PowerupMult"), mult },
		{ "PowerupChance", Spanish.statName("PowerupChance"), mult },
	},
}
Modal.StatGroups = STAT_GROUPS

local LINE_H, GROUP_GAP = 18.5, 17

local function renderStats(hud)
	statsHolder:ClearAllChildren()
	local stats = hud and hud.stats or {}
	local lines = 0
	for _, group in STAT_GROUPS do
		lines += #group
	end
	local bodyH = 16 + lines * LINE_H + (#STAT_GROUPS - 1) * GROUP_GAP + 16
	local _, body = Theme.panel({
		Name = "Stats",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -13, 0, 182),
		Size = UDim2.fromOffset(342, bodyH + 81),
		Parent = statsHolder,
	}, "Estadísticas", 56)
	local y = 16
	for g, group in STAT_GROUPS do
		for _, entry in group do
			local stat, label, format = entry[1], entry[2], entry[3]
			local value = stats[stat] or Stats.Defaults[stat] or 0
			local name = Theme.label({ Name = stat, Text = label, TextScaled = true, Position = UDim2.fromOffset(16, y), Size = UDim2.fromOffset(250, LINE_H), Parent = body })
			local limit = Instance.new("UITextSizeConstraint")
			limit.MaxTextSize = 19
			limit.MinTextSize = 11
			limit.Parent = name
			outlined(name, 1)
			outlined(Theme.label({ Name = stat .. "Value", Text = format(value), TextSize = 19, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, y), Size = UDim2.fromOffset(70, LINE_H), Parent = body }), 1)
			y += LINE_H
		end
		if g < #STAT_GROUPS then
			y += GROUP_GAP
		end
	end
end

-- Rayos de luz que giran detrás de la ventana
local function buildRays(parent: Instance): Frame
	local holder = Theme.frame({ Name = "Rays", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(10, 10), Parent = parent })
	for i = 0, 7 do
		local ray = Theme.frame({
			Name = "Ray",
			BackgroundColor3 = Color3.fromRGB(255, 246, 190),
			BackgroundTransparency = 0.55,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(3200, 70),
			Rotation = i * 22.5,
			Parent = holder,
		})
		local gradient = Instance.new("UIGradient")
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.35, 0.35),
			NumberSequenceKeypoint.new(0.5, 0.15),
			NumberSequenceKeypoint.new(0.65, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Parent = ray
	end
	return holder
end

local function render(data)
	renderOffer(data)
	local hud = getHud()
	renderInventory(hud)
	renderStats(hud)

	if UserInputService.GamepadEnabled and cards[1] then
		GuiService.SelectedObject = cards[1]
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

function Modal.init(hudGetter: (() -> any)?)
	if hudGetter then
		getHud = hudGetter
	end
	gui = ClientState.screen("Modal", 20)
	gui.Enabled = false
	Theme.frame({ Name = "Shade", Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 0.6, Parent = gui })
	root = Theme.frame({ Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromOffset(1920, DESIGN_H), Parent = gui })
	designScale = Instance.new("UIScale")
	designScale.Name = "DesignScale"
	designScale.Parent = root
	rays = buildRays(root)
	inventoryHolder = Theme.frame({ Name = "InventoryLayer", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = root })
	statsHolder = Theme.frame({ Name = "StatsLayer", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = root })
	offerHolder = Theme.frame({ Name = "OfferLayer", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = root })
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyScale)
	applyScale()

	Net.get("Modal").OnClientEvent:Connect(function(data)
		current = data
		banishMode = false
		if not data then
			setOpen(false)
			GuiService.SelectedObject = nil
			return
		end
		openedAt = os.clock()
		setOpen(true)
		applyScale()
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
