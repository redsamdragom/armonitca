-- Menú principal: Jugar (personaje, mapa y tier), Desbloqueos, Tienda, Colección y Opciones.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Net = require(ReplicatedStorage.Shared.Net)
local ClientState = require(script.Parent.Parent.ClientState)
local Theme = require(script.Parent.Theme)
local Preview = require(script.Parent.Preview)

local Menu = {}

local C = Theme.Colors
local gui: ScreenGui
local content: Frame
local tabs = {}
local selected = { character = "Fox", map = "Forest", tier = 1 }
local renderers = {}
local currentTab = "Play"
local statusLabel: TextLabel

local STATUS_TEXT = { owned = "Disponible", available = "¡Listo para comprar!", locked = "Bloqueado" }
local STATUS_COLOR = { owned = C.Good, available = C.Accent, locked = C.Muted }

local function statusOf(key: string)
	local profile = ClientState.profile
	if not profile then
		return "locked", nil
	end
	if profile.studioUnlockAll then
		return "owned", nil
	end
	for _, entry in profile.content do
		if entry.key == key then
			return entry.status, entry
		end
	end
	return "locked", nil
end

local function entryOf(key: string)
	local _, entry = statusOf(key)
	return entry
end

local function clear(frame: Instance)
	for _, child in frame:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIGridLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function buy(key: string)
	local ok, message = Net.get("Purchase"):InvokeServer(key)
	statusLabel.Text = message or ""
	statusLabel.TextColor3 = if ok then C.Good else C.Bad
end

local function progressText(entry): string
	if not entry then
		return ""
	end
	if entry.pending then
		return entry.text .. "  · [no rastreable aún]"
	end
	if entry.target and entry.target > 0 then
		return string.format("%s  (%s / %s)", entry.text, Theme.formatNumber(entry.current), Theme.formatNumber(entry.target))
	end
	return entry.text or ""
end

-- Jugar ---------------------------------------------------------------------------------------

local setPreview

renderers.Play = function()
	clear(content)
	local grid = Instance.new("ScrollingFrame")
	grid.Size = UDim2.new(0.34, -8, 1, 0)
	grid.BackgroundTransparency = 1
	grid.ScrollBarThickness = 6
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.Parent = content
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(104, 54)
	layout.CellPadding = UDim2.fromOffset(6, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	for i, character in ipairs(Catalog.Characters) do
		local status = statusOf("char:" .. character.id)
		local b = Theme.button({
			Text = character.name,
			TextSize = 13,
			TextWrapped = true,
			LayoutOrder = i,
			BackgroundColor3 = if character.id == selected.character then C.Accent elseif status == "owned" then C.PanelLight else C.Panel,
			TextColor3 = if character.id == selected.character then C.Background elseif status == "owned" then C.Text else C.Muted,
			Parent = grid,
		}, function()
			selected.character = character.id
			renderers.Play()
		end)
		if status ~= "owned" then
			b.Text = "🔒 " .. character.name
		end
	end

	-- Centro: vista 3D giratoria y ficha
	local center = Theme.frame({ Size = UDim2.new(0.36, -8, 1, 0), Position = UDim2.new(0.34, 4, 0, 0), BackgroundColor3 = C.Background, Parent = content })
	Theme.corner(center, 10)
	local viewport = Instance.new("ViewportFrame")
	viewport.Size = UDim2.new(1, 0, 0.5, 0)
	viewport.BackgroundTransparency = 1
	viewport.Parent = center
	setPreview = Preview.mount(viewport)
	setPreview(selected.character)

	local character = Catalog.Character[selected.character]
	local weapon = Catalog.Weapon[character.weapon]
	local status, entry = statusOf("char:" .. character.id)
	local profile = ClientState.profile
	local rank = profile and profile.ranks and profile.ranks[character.id]
	local info = Theme.label({
		Size = UDim2.new(1, -16, 0.5, -60),
		Position = UDim2.new(0, 8, 0.5, 0),
		TextWrapped = true,
		RichText = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextSize = 14,
		Font = Theme.FontBody,
		Text = string.format(
			"<b><font size=\"22\">%s</font></b>\n<i>%s</i>\n\n<b>Arma inicial:</b> %s\n<b>Pasiva %s:</b> %s\n<b>Rango:</b> %d · <b>Partidas:</b> %d\n\n<font color=\"#%s\">%s</font>",
			character.name,
			character.look,
			weapon.name,
			character.passive.name,
			character.passive.desc,
			rank and rank.rank or 0,
			rank and rank.runs or 0,
			STATUS_COLOR[status]:ToHex(),
			if status == "owned" then "Disponible" else progressText(entry)
		),
		Parent = center,
	})
	info.Name = "Info"
	if status == "available" then
		Theme.button({
			Text = string.format("Comprar por %d de plata", entry.price),
			Size = UDim2.new(1, -16, 0, 40),
			Position = UDim2.new(0, 8, 1, -48),
			BackgroundColor3 = C.Accent,
			TextColor3 = C.Background,
			Parent = center,
		}, function()
			buy("char:" .. character.id)
		end)
	end

	-- Derecha: mapa, tier y empezar
	local right = Theme.frame({ Size = UDim2.new(0.3, 0, 1, 0), Position = UDim2.new(0.7, 4, 0, 0), BackgroundTransparency = 1, Parent = content })
	Theme.list(right, nil, 8)
	Theme.label({ Text = "Mapa", Size = UDim2.new(1, 0, 0, 24), TextSize = 20, LayoutOrder = 0, Parent = right })
	for i, map in ipairs(Catalog.Maps) do
		local mapStatus = statusOf("map:" .. map.id)
		local playable = map.playable and mapStatus == "owned"
		local mapEntry = entryOf("map:" .. map.id)
		local b = Theme.button({
			Text = map.name .. (if not map.playable then " (pendiente)" elseif mapStatus ~= "owned" then " 🔒" else ""),
			Size = UDim2.new(1, 0, 0, 40),
			LayoutOrder = i,
			BackgroundColor3 = if selected.map == map.id then C.Accent else C.PanelLight,
			TextColor3 = if selected.map == map.id then C.Background elseif playable then C.Text else C.Muted,
			Parent = right,
		}, function()
			if playable then
				selected.map = map.id
				renderers.Play()
			else
				statusLabel.Text = if not map.playable then map.desc else progressText(mapEntry)
				statusLabel.TextColor3 = C.Muted
			end
		end)
		b.Name = map.id
	end
	Theme.label({ Text = "Tier", Size = UDim2.new(1, 0, 0, 24), TextSize = 20, LayoutOrder = 10, Parent = right })
	local tiersRow = Theme.frame({ Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = 11, Parent = right })
	Theme.list(tiersRow, Enum.FillDirection.Horizontal, 6)
	for tier = 1, 3 do
		Theme.button({
			Text = "Tier " .. tier,
			Size = UDim2.new(1 / 3, -4, 1, 0),
			BackgroundColor3 = if selected.tier == tier then C.Accent else C.PanelLight,
			TextColor3 = if selected.tier == tier then C.Background else C.Text,
			Parent = tiersRow,
		}, function()
			selected.tier = tier
			renderers.Play()
		end)
	end
	Theme.button({
		Text = "¡JUGAR!",
		TextSize = 26,
		Size = UDim2.new(1, 0, 0, 64),
		LayoutOrder = 20,
		BackgroundColor3 = if status == "owned" then C.Good else C.Panel,
		Parent = right,
	}, function()
		if status ~= "owned" then
			statusLabel.Text = "Ese personaje está bloqueado"
			statusLabel.TextColor3 = C.Bad
			return
		end
		Net.get("StartRun"):FireServer({ character = selected.character, map = selected.map, tier = selected.tier })
		statusLabel.Text = "Cargando partida..."
		statusLabel.TextColor3 = C.Muted
	end)
end

-- Desbloqueos ---------------------------------------------------------------------------------

local unlockFilter = "char"

renderers.Unlocks = function()
	clear(content)
	local filters = Theme.frame({ Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, Parent = content })
	Theme.list(filters, Enum.FillDirection.Horizontal, 6)
	for _, f in { { "char", "Personajes" }, { "weapon", "Armas" }, { "tome", "Tomos" }, { "item", "Objetos" }, { "map", "Mapas" } } do
		Theme.button({
			Text = f[2],
			Size = UDim2.new(0, 120, 1, 0),
			BackgroundColor3 = if unlockFilter == f[1] then C.Accent else C.PanelLight,
			TextColor3 = if unlockFilter == f[1] then C.Background else C.Text,
			Parent = filters,
		}, function()
			unlockFilter = f[1]
			renderers.Unlocks()
		end)
	end
	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, 0, 1, -44)
	list.Position = UDim2.new(0, 0, 0, 44)
	list.BackgroundTransparency = 1
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = content
	Theme.list(list, nil, 4)

	local profile = ClientState.profile
	if not profile then
		return
	end
	local entries = {}
	for _, entry in profile.content do
		if entry.kind == unlockFilter then
			table.insert(entries, entry)
		end
	end
	local order = { available = 1, locked = 2, owned = 3 }
	table.sort(entries, function(a, b)
		if order[a.status] ~= order[b.status] then
			return order[a.status] < order[b.status]
		end
		return a.name < b.name
	end)
	for i, entry in entries do
		local row = Theme.frame({ Size = UDim2.new(1, -10, 0, 46), LayoutOrder = i, Parent = list })
		Theme.corner(row, 6)
		local extra = ""
		if entry.kind == "item" then
			local item = Catalog.Item[entry.id]
			extra = string.format("  <font color=\"#%s\">%s</font>", Theme.Rarity[item.rarity]:ToHex(), Theme.RarityName[item.rarity])
		end
		Theme.label({
			Text = string.format("<b>%s</b>%s\n<font size=\"12\" color=\"#%s\">%s</font>", entry.name, extra, C.Muted:ToHex(), if entry.status == "owned" then "Disponible" else progressText(entry)),
			RichText = true,
			TextSize = 15,
			Size = UDim2.new(1, -170, 1, 0),
			Position = UDim2.new(0, 10, 0, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = row,
		})
		if entry.status == "available" then
			Theme.button({ Text = string.format("Comprar · %d", entry.price), Size = UDim2.new(0, 150, 0, 32), Position = UDim2.new(1, -158, 0.5, -16), BackgroundColor3 = C.Accent, TextColor3 = C.Background, Parent = row }, function()
				buy(entry.key)
			end)
		else
			Theme.label({ Text = STATUS_TEXT[entry.status], TextColor3 = STATUS_COLOR[entry.status], Size = UDim2.new(0, 150, 1, 0), Position = UDim2.new(1, -158, 0, 0), TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
		end
	end
end

-- Tienda --------------------------------------------------------------------------------------

renderers.Shop = function()
	clear(content)
	local profile = ClientState.profile
	if not profile then
		return
	end
	local list = Theme.frame({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = content })
	Theme.list(list, nil, 6)
	Theme.label({
		Text = string.format("Quests completadas: %d · Ranuras: %d armas, %d tomos", profile.quests, profile.weaponSlots, profile.tomeSlots),
		Size = UDim2.new(1, 0, 0, 30),
		TextColor3 = C.Muted,
		Parent = list,
	})
	for i, entry in profile.shop do
		local row = Theme.frame({ Size = UDim2.new(1, -10, 0, 44), LayoutOrder = i, Parent = list })
		Theme.corner(row, 6)
		Theme.label({ Text = string.format("<b>%s</b>   <font color=\"#%s\" size=\"12\">Requiere %d quests</font>", entry.name, C.Muted:ToHex(), entry.quests), RichText = true, Size = UDim2.new(1, -170, 1, 0), Position = UDim2.new(0, 10, 0, 0), Parent = row })
		if entry.status == "available" then
			Theme.button({ Text = string.format("Comprar · %d", entry.price), Size = UDim2.new(0, 150, 0, 32), Position = UDim2.new(1, -158, 0.5, -16), BackgroundColor3 = C.Accent, TextColor3 = C.Background, Parent = row }, function()
				buy(entry.key)
			end)
		else
			Theme.label({ Text = if entry.status == "owned" then "Comprado" else "Bloqueado", TextColor3 = STATUS_COLOR[entry.status], Size = UDim2.new(0, 150, 1, 0), Position = UDim2.new(1, -158, 0, 0), TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
		end
	end
end

-- Colección -----------------------------------------------------------------------------------

renderers.Collection = function()
	clear(content)
	local profile = ClientState.profile
	if not profile then
		return
	end
	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.fromScale(1, 1)
	list.BackgroundTransparency = 1
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = content
	Theme.list(list, nil, 4)
	local records = profile.records or {}
	Theme.label({
		Text = string.format("Partidas: %d · Mejor tiempo: %.1f min · Más bajas: %d", records.runs or 0, records.bestMinutes or 0, records.bestKills or 0),
		Size = UDim2.new(1, 0, 0, 30),
		TextColor3 = C.Accent,
		Parent = list,
	})
	Theme.label({ Text = "Sombreros y skins (visuales; los modelos están pendientes)", Size = UDim2.new(1, 0, 0, 26), TextColor3 = C.Muted, LayoutOrder = 1, Parent = list })
	for i, c in profile.cosmetics do
		local state = if c.met then "Conseguido" elseif c.pending then "Pendiente de implementar" else string.format("%s / %s", Theme.formatNumber(c.current), Theme.formatNumber(c.target))
		Theme.label({
			Text = string.format("<b>%s</b>%s — %s  <font color=\"#%s\">[%s]</font>", c.name, if c.character then " (" .. c.character .. ")" else "", c.text, (if c.met then C.Good else C.Muted):ToHex(), state),
			RichText = true,
			TextSize = 14,
			Font = Theme.FontBody,
			Size = UDim2.new(1, -10, 0, 22),
			LayoutOrder = 10 + i,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = list,
		})
	end
end

-- Opciones ------------------------------------------------------------------------------------

local OPTIONS = {
	{ key = "master", label = "Volumen general", step = 0.1, min = 0, max = 1 },
	{ key = "music", label = "Música", step = 0.1, min = 0, max = 1 },
	{ key = "sfx", label = "Efectos", step = 0.1, min = 0, max = 1 },
	{ key = "sensitivity", label = "Sensibilidad de cámara", step = 0.1, min = 0.2, max = 3 },
	{ key = "cameraDistance", label = "Distancia de cámara", step = 2, min = 8, max = 40 },
	{ key = "uiScale", label = "Escala de interfaz", step = 0.1, min = 0.6, max = 1.6 },
	{ key = "shake", label = "Sacudida de cámara", step = 0.25, min = 0, max = 1 },
	{ key = "effectOpacity", label = "Opacidad de efectos", step = 0.1, min = 0.1, max = 1 },
	{ key = "invertY", label = "Invertir eje Y", toggle = true },
	{ key = "autoPick", label = "Elegir mejoras automáticamente", toggle = true },
	{ key = "disableSilverTome", label = "Desactivar Silver Tome en ofertas", toggle = true },
}

local waitingRebind: string? = nil

renderers.Options = function()
	clear(content)
	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.fromScale(1, 1)
	list.BackgroundTransparency = 1
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = content
	Theme.list(list, nil, 6)
	local s = ClientState.settings
	for i, option in OPTIONS do
		local row = Theme.frame({ Size = UDim2.new(1, -10, 0, 40), LayoutOrder = i, Parent = list })
		Theme.corner(row, 6)
		Theme.label({ Text = option.label, Size = UDim2.new(0.6, 0, 1, 0), Position = UDim2.new(0, 10, 0, 0), Parent = row })
		if option.toggle then
			Theme.button({ Text = if s[option.key] then "Sí" else "No", Size = UDim2.new(0, 90, 0, 30), Position = UDim2.new(1, -100, 0.5, -15), Parent = row }, function()
				s[option.key] = not s[option.key]
				ClientState.saveSettings()
				renderers.Options()
			end)
		else
			local value = Theme.label({ Text = string.format("%.2f", s[option.key]), Size = UDim2.new(0, 70, 1, 0), Position = UDim2.new(1, -150, 0, 0), TextXAlignment = Enum.TextXAlignment.Center, Parent = row })
			local function change(sign)
				s[option.key] = math.clamp(math.round((s[option.key] + sign * option.step) * 100) / 100, option.min, option.max)
				value.Text = string.format("%.2f", s[option.key])
				ClientState.saveSettings()
			end
			Theme.button({ Text = "−", Size = UDim2.new(0, 36, 0, 30), Position = UDim2.new(1, -190, 0.5, -15), Parent = row }, function()
				change(-1)
			end)
			Theme.button({ Text = "+", Size = UDim2.new(0, 36, 0, 30), Position = UDim2.new(1, -78, 0.5, -15), Parent = row }, function()
				change(1)
			end)
		end
	end
	-- Reasignación de teclas
	for j, action in { "Pause", "Map" } do
		local row = Theme.frame({ Size = UDim2.new(1, -10, 0, 40), LayoutOrder = 100 + j, Parent = list })
		Theme.corner(row, 6)
		Theme.label({ Text = if action == "Pause" then "Tecla de pausa" else "Tecla de mapa", Size = UDim2.new(0.6, 0, 1, 0), Position = UDim2.new(0, 10, 0, 0), Parent = row })
		local key = ClientState.bindings[action][1]
		Theme.button({ Text = if waitingRebind == action then "Pulsa una tecla..." else key.Name, Size = UDim2.new(0, 160, 0, 30), Position = UDim2.new(1, -170, 0.5, -15), Parent = row }, function()
			waitingRebind = action
			renderers.Options()
		end)
	end
end

game:GetService("UserInputService").InputBegan:Connect(function(input)
	if waitingRebind and input.UserInputType == Enum.UserInputType.Keyboard then
		ClientState.bindings[waitingRebind][1] = input.KeyCode
		waitingRebind = nil
		if currentTab == "Options" then
			renderers.Options()
		end
	end
end)

-- Estructura ----------------------------------------------------------------------------------

local silverLabel: TextLabel

local function selectTab(name: string)
	currentTab = name
	for key, button in tabs do
		button.BackgroundColor3 = if key == name then C.Accent else C.PanelLight
		button.TextColor3 = if key == name then C.Background else C.Text
	end
	renderers[name]()
end

function Menu.init()
	gui = ClientState.screen("Menu", 10)
	local root = Theme.frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Background, BackgroundTransparency = 0.05, Parent = gui })
	Theme.label({ Text = "ARMONITCA", TextSize = 34, Size = UDim2.new(0, 400, 0, 50), Position = UDim2.new(0, 24, 0, 14), TextColor3 = C.Accent, Parent = root })
	silverLabel = Theme.label({ Text = "Plata: —", TextSize = 20, Size = UDim2.new(0, 300, 0, 50), Position = UDim2.new(1, -324, 0, 14), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.Silver, Parent = root })
	statusLabel = Theme.label({ Text = "", TextSize = 15, Size = UDim2.new(1, -48, 0, 24), Position = UDim2.new(0, 24, 1, -34), TextColor3 = C.Muted, Parent = root })

	local tabBar = Theme.frame({ Size = UDim2.new(1, -48, 0, 40), Position = UDim2.new(0, 24, 0, 70), BackgroundTransparency = 1, Parent = root })
	Theme.list(tabBar, Enum.FillDirection.Horizontal, 8)
	for i, t in { { "Play", "Jugar" }, { "Unlocks", "Desbloqueos" }, { "Shop", "Tienda" }, { "Collection", "Colección" }, { "Options", "Opciones" } } do
		tabs[t[1]] = Theme.button({ Text = t[2], Size = UDim2.new(0, 150, 1, 0), LayoutOrder = i, Parent = tabBar }, function()
			selectTab(t[1])
		end)
	end
	content = Theme.frame({ Size = UDim2.new(1, -48, 1, -170), Position = UDim2.new(0, 24, 0, 122), BackgroundTransparency = 1, Parent = root })

	ClientState.onProfile(function(profile)
		silverLabel.Text = string.format("Plata: %s", Theme.formatNumber(profile.silver))
		if profile.persistent == false then
			statusLabel.Text = "Aviso: el guardado no está disponible (activa el acceso a la API en Studio)."
			statusLabel.TextColor3 = C.Bad
		end
		if gui.Enabled then
			selectTab(currentTab)
		end
	end)
	selectTab("Play")
end

function Menu.show(visible: boolean)
	gui.Enabled = visible
	if visible then
		statusLabel.Text = ""
		selectTab(currentTab)
	end
end

function Menu.setStatus(text: string)
	statusLabel.Text = text
end

return Menu
