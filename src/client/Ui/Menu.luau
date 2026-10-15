-- Menú principal con la composición del juego de referencia: tarjetas de misión arriba a la
-- izquierda, título, cuatro losas centrales (Jugar, Desbloqueos, Misiones, Tienda), columna de
-- ajustes abajo a la izquierda, plata arriba a la derecha, clasificación semanal a la derecha y
-- versión abajo a la derecha. Cada botón abre una ventana centrada con un botón VOLVER.
-- Diseño a 1920×1080 escalado con UIScale; la escena 3D de fondo la pone MenuScene.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local ClientState = require(script.Parent.Parent.ClientState)
local Theme = require(script.Parent.Theme)
local Preview = require(script.Parent.Preview)
local Icons = require(script.Parent.Icons)
local Spanish = require(ReplicatedStorage.Shared.Data.Spanish)
local Images = require(ReplicatedStorage.Shared.Data.Images)

local Menu = {}

local C = Theme.Colors
local WHITE = Color3.new(1, 1, 1)
local DESIGN_W, DESIGN_H = 1920, 1080
-- Ancho mínimo de diseño: por debajo, tarjetas, título y clasificación se solaparían y la escala pasa
-- a seguir al ancho en lugar de al alto.
local MIN_W = 1720
-- Letra de palo seco para la cuenta atrás, la versión y los nombres (como en la referencia).
local SANS = Theme.HudFontFace

local gui: ScreenGui
local root: Frame
local designScale: UIScale
local home: Frame
local shade: Frame
local windowLayer: Frame
local cardsFrame: Frame
local silverLabel: TextLabel
local statusLabel: TextLabel
local playButton: TextButton
local focus = Theme.focusGroup()
local waitingRebind: string? = nil -- acción de Ajustes que espera una tecla nueva
local selected = { character = "Fox", map = "Forest", tier = 1 }

local STATUS_COLOR = { owned = C.Good, available = C.Yellow, locked = C.Muted }

local function outlined<T>(label: T, thickness: number?): T
	Theme.outlined(label :: any, thickness or 2)
	return label
end

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

local function setStatus(text: string, color: Color3?)
	statusLabel.Text = text
	statusLabel.TextColor3 = color or C.Text
end

local function buy(key: string)
	local ok, message = Net.get("Purchase"):InvokeServer(key)
	setStatus(message or "", if ok then C.Good else C.Bad)
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

local function scrollList(parent: Instance, props): ScrollingFrame
	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 8
	list.ScrollBarImageColor3 = C.Bolt
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Size = UDim2.fromScale(1, 1)
	for k, v in props or {} do
		(list :: any)[k] = v
	end
	Theme.list(list, nil, 8)
	-- Margen para que los contornos de las filas no queden recortados por el borde del scroll
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 3)
	pad.PaddingLeft = UDim.new(0, 3)
	pad.PaddingBottom = UDim.new(0, 3)
	pad.Parent = list
	list.Parent = parent
	return list
end

-- Iconos dibujados con primitivas -------------------------------------------------------------
-- Coordenadas en escala del contenedor (centro x, y; tamaño w, h). Con square = true el tamaño se
-- mide sobre el alto del contenedor (círculos redondos aunque el contenedor sea apaisado).

local function shape(parent: Instance, color: Color3, x: number, y: number, w: number, h: number, z: number?, rotation: number?, square: boolean?): Frame
	return Theme.frame({
		BackgroundColor3 = color,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(w, h),
		SizeConstraint = if square then Enum.SizeConstraint.RelativeYY else Enum.SizeConstraint.RelativeXY,
		Rotation = rotation or 0,
		ZIndex = z or 1,
		Parent = parent,
	})
end

local function round(frame: Frame, radius: number?): Frame
	local c = Instance.new("UICorner")
	c.CornerRadius = if radius then UDim.new(0, radius) else UDim.new(0.5, 0)
	c.Parent = frame
	return frame
end

local function edged(frame: Frame, thickness: number?): Frame
	Theme.stroke(frame, C.Outline, thickness or 1.5)
	return frame
end

-- Busto (o cuerpo entero) del personaje en un ViewportFrame estático.
local function characterIcon(holder: GuiObject, characterId: string, fullBody: boolean?): ViewportFrame
	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundTransparency = 1
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.Ambient = Color3.fromRGB(165, 165, 175)
	viewport.LightColor = Color3.fromRGB(255, 250, 240)
	viewport.LightDirection = Vector3.new(0.5, -0.8, 1)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.CFrame = if fullBody
		then CFrame.lookAt(Vector3.new(-3, 4.2, -13), Vector3.new(0, 3.2, 0))
		else CFrame.lookAt(Vector3.new(-1.8, 5.1, -6), Vector3.new(0, 4.6, 0))
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	Preview.build(characterId).Parent = viewport
	viewport.Parent = holder
	return viewport
end

local function drawSword(holder: GuiObject)
	edged(shape(holder, Color3.fromRGB(205, 214, 224), 0.61, 0.39, 0.13, 0.67, 1, 45))
	edged(shape(holder, Color3.fromRGB(150, 105, 50), 0.36, 0.64, 0.42, 0.1, 2, 45))
	edged(shape(holder, Color3.fromRGB(95, 62, 35), 0.255, 0.745, 0.09, 0.2, 1, 45))
	edged(round(shape(holder, C.Gold, 0.165, 0.835, 0.14, 0.14, 2)))
end

local function drawGem(holder: GuiObject, color: Color3)
	edged(shape(holder, color, 0.5, 0.5, 0.6, 0.6, 1, 45), 2)
	shape(holder, color:Lerp(WHITE, 0.45), 0.5, 0.5, 0.3, 0.3, 2, 45)
	shape(holder, WHITE, 0.42, 0.38, 0.08, 0.08, 3, 45)
end

local function drawHat(holder: GuiObject)
	edged(round(shape(holder, Color3.fromRGB(38, 38, 42), 0.5, 0.48, 0.52, 0.5, 1), 3))
	shape(holder, Color3.fromRGB(190, 45, 45), 0.5, 0.64, 0.52, 0.1, 2)
	edged(round(shape(holder, Color3.fromRGB(30, 30, 34), 0.5, 0.77, 0.86, 0.12, 3), 3))
end

local MAP_ART = {
	Forest = { sky = Color3.fromRGB(105, 185, 235), ground = Color3.fromRGB(86, 150, 70) },
	Desert = { sky = Color3.fromRGB(245, 205, 140), ground = Color3.fromRGB(222, 186, 120) },
	Graveyard = { sky = Color3.fromRGB(48, 44, 82), ground = Color3.fromRGB(58, 70, 58) },
}

-- Paisaje en miniatura de cada mapa (cielo, suelo y dos o tres siluetas reconocibles).
local function drawMap(holder: GuiObject, mapId: string?)
	local art = MAP_ART[mapId or ""] or MAP_ART.Forest
	edged(round(shape(holder, art.sky, 0.5, 0.5, 1, 1, 1), 4), 2)
	round(shape(holder, art.ground, 0.5, 0.84, 1, 0.32, 4), 4)
	if mapId == "Desert" then
		round(shape(holder, Color3.fromRGB(255, 240, 165), 0.8, 0.26, 0.22, 0.22, 2, 0, true))
		edged(shape(holder, Color3.fromRGB(200, 155, 90), 0.62, 0.72, 0.42, 0.42, 3, 45, true))
		local cactus = Color3.fromRGB(70, 150, 70)
		edged(round(shape(holder, cactus, 0.28, 0.62, 0.09, 0.4, 5, 0, true), 4))
		edged(round(shape(holder, cactus, 0.23, 0.58, 0.07, 0.16, 5, 0, true), 3))
		edged(round(shape(holder, cactus, 0.33, 0.54, 0.07, 0.14, 5, 0, true), 3))
	elseif mapId == "Graveyard" then
		round(shape(holder, Color3.fromRGB(236, 235, 216), 0.78, 0.24, 0.2, 0.2, 2, 0, true))
		local stone = Color3.fromRGB(150, 150, 160)
		edged(round(shape(holder, stone, 0.25, 0.68, 0.16, 0.26, 5, 0, true), 6))
		edged(round(shape(holder, stone, 0.5, 0.72, 0.13, 0.2, 5, 0, true), 5))
		edged(shape(holder, stone, 0.75, 0.68, 0.045, 0.3, 5, 0, true))
		edged(shape(holder, stone, 0.75, 0.6, 0.16, 0.045, 5, 0, true))
	else
		local trunk, leaves = Color3.fromRGB(100, 70, 45), Color3.fromRGB(60, 140, 60)
		edged(shape(holder, Color3.fromRGB(150, 145, 135), 0.55, 0.52, 0.16, 0.46, 2, 0, true))
		shape(holder, Color3.fromRGB(80, 130, 70), 0.55, 0.34, 0.16, 0.08, 3, 0, true)
		for _, x in { 0.22, 0.8 } do
			edged(shape(holder, trunk, x, 0.68, 0.07, 0.26, 5, 0, true))
			edged(round(shape(holder, leaves, x, 0.45, 0.34, 0.3, 6, 0, true), 6))
		end
	end
end

local function drawWrench(holder: GuiObject)
	local metal = Color3.fromRGB(140, 175, 200)
	edged(shape(holder, metal, 0.4, 0.6, 0.16, 0.66, 1, 45))
	edged(round(shape(holder, metal, 0.72, 0.28, 0.42, 0.42, 2)))
	shape(holder, C.Stone, 0.83, 0.17, 0.2, 0.24, 3, 45)
end

local function drawLanguage(holder: GuiObject)
	local yellow = Color3.fromRGB(242, 226, 58)
	shape(holder, yellow, 0.24, 0.66, 0.16, 0.16, 1, 45)
	local bubble = edged(round(shape(holder, yellow, 0.4, 0.38, 0.72, 0.6, 2), 6))
	Theme.label({ Text = "A", FontFace = SANS, TextScaled = true, TextColor3 = Color3.fromRGB(150, 40, 40), TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = bubble })
	local red = edged(round(shape(holder, Color3.fromRGB(226, 60, 60), 0.68, 0.7, 0.5, 0.42, 3), 5))
	Theme.label({ Text = "ñ", FontFace = SANS, TextScaled = true, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = red })
end

local function drawDiscord(holder: GuiObject)
	local blurple = Color3.fromRGB(88, 101, 242)
	edged(round(shape(holder, blurple, 0.5, 0.5, 0.9, 0.9, 1)))
	round(shape(holder, WHITE, 0.5, 0.55, 0.56, 0.34, 2), 4)
	shape(holder, WHITE, 0.33, 0.41, 0.14, 0.14, 2, 30)
	shape(holder, WHITE, 0.67, 0.41, 0.14, 0.14, 2, -30)
	round(shape(holder, blurple, 0.41, 0.54, 0.1, 0.13, 3))
	round(shape(holder, blurple, 0.59, 0.54, 0.1, 0.13, 3))
end

local function drawCoin(holder: GuiObject)
	local silver = Color3.fromRGB(170, 181, 188)
	edged(round(shape(holder, silver, 0.5, 0.5, 1, 1, 1)), 2)
	local ring = round(shape(holder, silver, 0.5, 0.5, 0.56, 0.56, 2))
	ring.BackgroundTransparency = 1
	Theme.stroke(ring, Color3.fromRGB(238, 243, 245), 3)
	shape(holder, silver, 0.74, 0.5, 0.22, 0.2, 3)
end

-- Candado centrado sobre un contenido bloqueado.
local function drawLock(parent: GuiObject)
	local lock = Theme.frame({ BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(40, 46), ZIndex = 5, Parent = parent })
	local shackle = round(shape(lock, WHITE, 0.5, 0.32, 0.62, 0.56, 1))
	shackle.BackgroundTransparency = 1
	Theme.stroke(shackle, Color3.fromRGB(205, 205, 210), 4)
	local body = edged(round(shape(lock, Color3.fromRGB(215, 175, 60), 0.5, 0.7, 1, 0.56, 2), 4), 2)
	round(shape(body, Color3.fromRGB(60, 45, 20), 0.5, 0.45, 0.16, 0.34, 3))
	return lock
end

local function drawIcon(holder: GuiObject, kind: string, id: string?)
	if kind == "char" and id and Catalog.Character[id] then
		characterIcon(holder, id)
	elseif kind == "weapon" then
		drawSword(holder)
	elseif kind == "tome" then
		if id then
			Icons.tome(holder, id)
		else
			Icons.book(holder)
		end
	elseif kind == "item" then
		local item = id and Catalog.Item[id]
		drawGem(holder, if item then Theme.Rarity[item.rarity] else C.Text)
	elseif kind == "map" then
		drawMap(holder, id)
	else
		drawHat(holder)
	end
end

-- Misiones -------------------------------------------------------------------------------------
-- Cada condición de desbloqueo (contenido y cosméticos) con su progreso y un estado:
--   buy       condición cumplida; falta comprar el contenido
--   progress  rastreable y sin cumplir
--   pending   todavía no rastreable en la recreación
--   done      conseguida (comprada o cosmético obtenido)

local function missionsOf(profile)
	local list = {}
	for _, entry in profile.content do
		local start = not entry.pending and (entry.target or 0) == 0
		if not start then
			local state = if entry.status == "available"
				then "buy"
				elseif entry.status == "owned" then "done"
				elseif entry.pending then "pending"
				else "progress"
			table.insert(list, {
				name = entry.name,
				text = entry.text,
				current = entry.current or 0,
				target = entry.target or 0,
				kind = entry.kind,
				id = entry.id,
				state = state,
				entry = entry,
			})
		end
	end
	for _, c in profile.cosmetics do
		table.insert(list, {
			name = c.name,
			text = c.text,
			current = c.current or 0,
			target = c.target or 0,
			kind = if c.character then "char" else "hat",
			id = c.character,
			state = if c.met then "done" elseif c.pending then "pending" else "progress",
		})
	end
	return list
end

local function fraction(m): number
	return if m.target > 0 then math.clamp(m.current / m.target, 0, 1) else 0
end

-- Tarjeta de misión: icono, título dorado, descripción, barra (verde desde el 75 %) y cifras.
-- reserve: ancho libre a la derecha para un botón o estado.
local function missionCard(m, props, barWidth: number, reserve: number?): Frame
	local card = Theme.frame({ BackgroundColor3 = C.Card, BackgroundTransparency = 0.04 })
	for k, v in props do
		(card :: any)[k] = v
	end
	Theme.corner(card, 3)
	Theme.stroke(card, C.CardBorder, 2)
	-- Filos negros de 1 px a ambos lados del borde claro: uno por fuera y otro sobre el relleno
	for _, edge in { { -3, 6, 6 }, { 1, -2, 2 } } do
		local line = Theme.frame({ Name = "Edge", BackgroundTransparency = 1, Position = UDim2.fromOffset(edge[1], edge[1]), Size = UDim2.new(1, edge[2], 1, edge[2]), Parent = card })
		Theme.corner(line, edge[3])
		Theme.stroke(line, Color3.new(0, 0, 0), 1)
	end
	local icon = Theme.frame({ BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(58, 58), Parent = card })
	drawIcon(icon, m.kind, m.id)
	local right = 90 + (reserve or 0)
	outlined(Theme.label({ Text = m.name, TextColor3 = C.Yellow, TextSize = 23, Position = UDim2.fromOffset(80, 4), Size = UDim2.new(1, -right, 0, 26), TextTruncate = Enum.TextTruncate.AtEnd, Parent = card }), 1.5)
	outlined(Theme.label({ Text = m.text or "", TextSize = 19, Position = UDim2.fromOffset(80, 29), Size = UDim2.new(1, -right, 0, 24), TextTruncate = Enum.TextTruncate.AtEnd, Parent = card }), 1.5)
	if m.state ~= "pending" and m.target > 0 then
		local done = m.state == "done" or m.state == "buy"
		local f = if done then 1 else fraction(m)
		local good = f >= 0.75
		local bar = Theme.frame({ BackgroundColor3 = Color3.new(0, 0, 0), Position = UDim2.fromOffset(80, 58), Size = UDim2.fromOffset(barWidth, 7), Parent = card })
		Theme.frame({ BackgroundColor3 = if good then C.BarGreen else C.BarYellow, Size = UDim2.fromScale(f, 1), Parent = bar })
		local current = if done then math.min(m.current, m.target) else m.current
		outlined(Theme.label({
			Text = string.format("%d / %d", math.floor(current), math.floor(m.target)),
			TextColor3 = if good then C.TextGreen else C.TextYellow,
			TextSize = 18,
			Position = UDim2.fromOffset(90 + barWidth, 51),
			Size = UDim2.fromOffset(170, 20),
			Parent = card,
		}), 1.5)
	end
	return card
end

-- Botón de compra y etiqueta de estado alineados a la derecha de una fila.
local function buyButton(row: GuiObject, price: number, onClick: () -> ()): TextButton
	return Theme.button({
		Text = string.format("COMPRAR · %d", price),
		TextSize = 22,
		TextColor3 = C.Yellow,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, -1),
		Size = UDim2.fromOffset(220, 46),
		Parent = row,
	}, onClick)
end

local function statusTag(row: GuiObject, text: string, color: Color3): TextLabel
	return outlined(Theme.label({
		Text = text,
		TextSize = 22,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 0),
		Size = UDim2.new(0, 240, 1, 0),
		Parent = row,
	}), 1.5)
end

-- Ventanas -------------------------------------------------------------------------------------
-- Cada ventana se dibuja en un panel centrado: `render(content, footer)` rellena el contenido y
-- puede añadir botones a la derecha del pie (VOLVER va siempre a la izquierda). Devuelve el botón
-- que debe seleccionar el mando al abrirla.

-- Con fullscreen = true la ventana ocupa toda la pantalla sobre la escena (sin velo, panel ni pie):
-- `render` recibe footer = nil y dibuja sus propios paneles y su botón de cierre.
type WindowSpec = {
	title: string,
	size: Vector2,
	back: string?,
	fullscreen: boolean?,
	render: (content: Frame, footer: Frame?) -> GuiObject?,
}

local WINDOWS: { [string]: WindowSpec } = {}
local window: { name: string, panel: Frame, content: Frame, footer: Frame? }? = nil
local openWindow: (name: string) -> ()
local closeWindow: (select: boolean?) -> ()
local renderWindow: (mode: string) -> ()
local applyScale: () -> ()

local function goBack()
	if not window then
		return
	end
	local back = WINDOWS[window.name].back
	if back then
		openWindow(back)
	else
		closeWindow(true)
	end
end

local function footerButton(footer: Frame, text: string, onClick: () -> (), color: Color3?): TextButton
	return Theme.stoneButton({
		Text = text,
		TextSize = 32,
		TextColor3 = color or WHITE,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(250, 60),
		Parent = footer,
	}, onClick, focus, { gap = 8 })
end

-- Restaura el desplazamiento de una lista recién reconstruida (el lienzo crece al calcular el layout).
local function restoreScroll(list: ScrollingFrame, position: Vector2)
	list.CanvasPosition = position
	local connection
	connection = list:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(function()
		list.CanvasPosition = position
		connection:Disconnect()
	end)
	task.delay(0.5, function()
		connection:Disconnect()
	end)
end

-- mode: "open" (selecciona el botón principal), "refresh" (conserva el desplazamiento) o "reset".
renderWindow = function(mode: string)
	local w = window
	if not w then
		return
	end
	local spec = WINDOWS[w.name]
	local oldList = w.content:FindFirstChild("List", true)
	local saved = if oldList and oldList:IsA("ScrollingFrame") and mode == "refresh" then oldList.CanvasPosition else nil
	w.content:ClearAllChildren()
	local back: GuiObject? = nil
	if w.footer then
		w.footer:ClearAllChildren()
		back = Theme.stoneButton({ Name = "Back", Text = "VOLVER", TextSize = 32, Size = UDim2.fromOffset(200, 60), Parent = w.footer }, goBack, focus, { gap = 8 })
	end
	local first = spec.render(w.content, w.footer)
	local newList = w.content:FindFirstChild("List", true)
	if saved and newList and newList:IsA("ScrollingFrame") then
		restoreScroll(newList, saved)
	end
	if UserInputService.GamepadEnabled then
		local current = GuiService.SelectedObject
		if mode == "open" or not (current and current:IsDescendantOf(gui)) then
			GuiService.SelectedObject = first or back
		end
	end
end

openWindow = function(name: string)
	local spec = WINDOWS[name]
	if window then
		window.panel:Destroy()
	end
	home.Visible = false
	if spec.fullscreen then
		shade.Visible = false
		local screen = Theme.frame({ Name = name, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = windowLayer })
		window = { name = name, panel = screen, content = screen, footer = nil }
		renderWindow("open")
		return
	end
	shade.Visible = true
	local panel, body = Theme.panel({
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		-- El marco metálico va por dentro: se suma para que el contenido conserve su tamaño
		Size = UDim2.fromOffset(spec.size.X + 16, spec.size.Y + 21),
		Parent = windowLayer,
	}, spec.title)
	local content = Theme.frame({ Name = "Content", BackgroundTransparency = 1, Position = UDim2.fromOffset(22, 18), Size = UDim2.new(1, -44, 1, -116), Parent = body })
	local footer = Theme.frame({ Name = "Footer", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 22, 1, -22), Size = UDim2.new(1, -44, 0, 60), Parent = body })
	window = { name = name, panel = panel, content = content, footer = footer }
	renderWindow("open")
end

closeWindow = function(select: boolean?)
	waitingRebind = nil
	if window then
		window.panel:Destroy()
		window = nil
	end
	shade.Visible = false
	home.Visible = true
	if select then
		Theme.focus(focus, playButton)
		if UserInputService.GamepadEnabled then
			GuiService.SelectedObject = playButton
		end
	end
end

-- Jugar: selección de personaje -----------------------------------------------------------------
-- Pantalla completa sobre la escena, con la composición de la referencia: panel "SELECCIÓN DE
-- PERSONAJE" a la izquierda (cuadrícula de 4 columnas con desplazamiento), el personaje en 3D en el
-- centro, la ficha a la derecha (retrato, rango, partidas, frase, arma, pasiva, skins y CONFIRMAR) y
-- el sombrero debajo. Medidas en píxeles de diseño (captura de 2000×1194 escalada a 1080 de alto).

local PORTRAIT_BG = Color3.fromRGB(44, 50, 60)
local LOCKED_BG = Color3.fromRGB(30, 31, 34)
local CELL_BORDER = Color3.fromRGB(150, 146, 140)
local CONFIRM_BLUE = Color3.fromRGB(52, 132, 214)
local RANK_BLUE = Color3.fromRGB(60, 150, 235)

-- Elecciones visuales del selector (las skins y los sombreros todavía no tienen modelos).
local chosenSkin: { [string]: string } = {}
local chosenHat: string? = nil
local hatListOpen = false

local function characterName(id: string): string
	return Spanish.characterName(id, Catalog.Character[id].name)
end

-- Pernos pequeños en las cuatro esquinas de un marco.
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
		Theme.corner(b, 2)
		Theme.stroke(b, C.Outline, 1)
	end
end

-- Retrato del personaje: la imagen subida (Data/Images) o, si no hay, el busto del modelo.
-- Bloqueado: silueta negra (la imagen de silueta o el retrato teñido de negro).
local function portrait(holder: GuiObject, id: string, locked: boolean)
	local image = Images.get(Images.Portraits, id)
	if image then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.ScaleType = Enum.ScaleType.Crop
		local silhouette = Images.get(Images.Silhouettes, id)
		img.Image = if locked and silhouette then silhouette else image
		if locked and not silhouette then
			img.ImageColor3 = Color3.new(0, 0, 0)
		end
		img.Parent = holder
		return
	end
	local viewport = characterIcon(holder, id)
	if locked then
		viewport.ImageColor3 = Color3.new(0, 0, 0)
	end
end

-- Recuadro con borde metálico y pernos (retratos e iconos de la ficha).
local function framedBox(parent: Instance, props): Frame
	local box = Theme.frame({ BackgroundColor3 = PORTRAIT_BG })
	for k, v in props do
		(box :: any)[k] = v
	end
	Theme.stroke(box, CELL_BORDER, 2)
	cornerBolts(box, 7)
	box.Parent = parent
	return box
end

-- Icono de arma sustituto: losa con el color del arma y una espada estilizada.
local function weaponIcon(holder: GuiObject, weaponId: string)
	local image = Images.get(Images.Weapons, weaponId)
	if image then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.Image = image
		img.Parent = holder
		return
	end
	local weapon = Catalog.Weapon[weaponId]
	local color = Color3.fromRGB(weapon.color[1], weapon.color[2], weapon.color[3])
	holder.BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.55)
	drawSword(Theme.frame({ BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.8, 0.8), Parent = holder }))
end

-- Icono de pasiva sustituto: estrella verde sobre fondo oscuro.
local function passiveIcon(holder: GuiObject, characterId: string)
	local image = Images.get(Images.Passives, characterId)
	if image then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.Image = image
		img.Parent = holder
		return
	end
	holder.BackgroundColor3 = Color3.fromRGB(40, 22, 40)
	outlined(Theme.label({
		Text = "★",
		FontFace = SANS,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(110, 220, 90),
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Parent = holder,
	}), 2)
end

-- Escudo pequeño del rango y figura corriendo de las partidas.
local function rankIcon(holder: GuiObject)
	edged(round(shape(holder, Color3.fromRGB(120, 150, 175), 0.5, 0.45, 0.8, 0.8, 1), 4), 2)
	shape(holder, Color3.fromRGB(70, 95, 120), 0.5, 0.45, 0.12, 0.6, 2)
	shape(holder, Color3.fromRGB(70, 95, 120), 0.5, 0.45, 0.6, 0.12, 2)
end

local function runsIcon(holder: GuiObject)
	outlined(Theme.label({ Text = "🏃", FontFace = SANS, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = holder }), 1)
end

-- Rango y progreso hacia el siguiente (el rango sube cada 3 minutos jugados) [Pendiente: curva].
local function rankOf(id: string): (number, number, number)
	local profile = ClientState.profile
	local r = profile and profile.ranks and profile.ranks[id]
	if not r then
		return 0, 0, 0
	end
	local minutes = r.minutes or 0
	return r.rank or 0, r.runs or 0, if (r.rank or 0) >= 100 then 1 else (minutes % 3) / 3
end

local function skinsOf(id: string)
	local list = {}
	for _, skin in Catalog.Cosmetics.Skins do
		if skin.character == id then
			table.insert(list, skin)
		end
	end
	return list
end

local function cosmeticMet(cosmeticId: string): boolean
	local profile = ClientState.profile
	if not profile then
		return false
	end
	if profile.studioUnlockAll then
		return true
	end
	for _, c in profile.cosmetics or {} do
		if c.id == cosmeticId then
			return c.met == true
		end
	end
	return false
end

local function cosmeticText(cosmeticId: string): string
	local profile = ClientState.profile
	for _, c in (profile and profile.cosmetics) or {} do
		if c.id == cosmeticId then
			if c.pending then
				return c.text .. " · [no rastreable aún]"
			end
			if (c.target or 0) > 0 then
				return string.format("%s (%s / %s)", c.text, Theme.formatNumber(c.current or 0), Theme.formatNumber(c.target))
			end
			return c.text
		end
	end
	return ""
end

local function hatName(hatId: string?): string
	if not hatId then
		return "Sin sombrero"
	end
	for _, hat in Catalog.Cosmetics.Hats do
		if hat.id == hatId then
			return hat.name
		end
	end
	return "Sin sombrero"
end

-- Qué falta para desbloquear un personaje: su misión y, si no la tiene, comprar su arma inicial.
local function lockedText(entry): string
	local text = progressText(entry)
	for _, required in (entry and entry.requires) or {} do
		if not required.owned then
			local isWeapon = required.kind == "weapon"
			text ..= string.format("\nComprar: %s - %s", if isWeapon then "Arma" else required.kind, if isWeapon then Spanish.weaponName(required.id, required.name) else required.name)
		end
	end
	return text
end

-- Personaje en 3D sobre la escena: de frente con un leve balanceo; se gira arrastrando.
local function mountModel(content: Frame, id: string)
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Model"
	viewport.BackgroundTransparency = 1
	viewport.AnchorPoint = Vector2.new(0.5, 0)
	viewport.Position = UDim2.new(0.53, 0, 0, 380)
	viewport.Size = UDim2.fromOffset(420, 560)
	viewport.Ambient = Color3.fromRGB(150, 160, 170)
	viewport.LightColor = Color3.fromRGB(255, 248, 235)
	viewport.LightDirection = Vector3.new(-0.4, -0.7, -1)
	viewport.Parent = content
	local camera = Instance.new("Camera")
	camera.FieldOfView = 32
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 3.4, -13.5), Vector3.new(0, 3, 0))
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local model = Preview.build(id)
	model.Parent = viewport

	local yaw, drag, dragging = 0, 0, false
	local t = 0
	viewport.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
		end
	end)
	local ended = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	local moved = UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			drag += input.Delta.X * 0.012
		end
	end)
	local stepped
	stepped = game:GetService("RunService").RenderStepped:Connect(function(dt)
		if not viewport.Parent then
			stepped:Disconnect()
			ended:Disconnect()
			moved:Disconnect()
			return
		end
		t += dt
		yaw = drag + math.sin(t * 0.8) * 0.12
		model:PivotTo(CFrame.new(0, 3, 0) * CFrame.Angles(0, yaw, 0))
	end)
	model:PivotTo(CFrame.new(0, 3, 0))
end

WINDOWS.Characters = {
	title = "SELECCIÓN DE PERSONAJE",
	size = Vector2.new(0, 0),
	fullscreen = true,
	render = function(content)
		if not Catalog.Character[selected.character] then
			selected.character = Catalog.Characters[1].id
		end
		local id = selected.character
		local character = Catalog.Character[id]
		local status, entry = statusOf("char:" .. id)
		local owned = status == "owned"

		-- Izquierda: cuadrícula ----------------------------------------------------------------
		local _, rosterBody, header = Theme.panel({
			Name = "Roster",
			Position = UDim2.fromOffset(59, 149),
			Size = UDim2.fromOffset(613, 824),
			Parent = content,
		}, "SELECCIÓN DE PERSONAJE", 54)
		local close = Instance.new("TextButton")
		close.Name = "Close"
		close.Text = "X"
		close.FontFace = SANS
		close.TextSize = 44
		close.TextColor3 = Color3.fromRGB(235, 35, 35)
		close.BackgroundTransparency = 1
		close.AnchorPoint = Vector2.new(1, 0.5)
		close.Position = UDim2.new(1, -8, 0.5, 0)
		close.Size = UDim2.fromOffset(44, 44)
		close.Parent = header
		outlined(close, 2)
		close.Activated:Connect(goBack)

		local grid = scrollList(rosterBody, { Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -18, 1, -12) })
		grid:FindFirstChildOfClass("UIListLayout"):Destroy()
		local pad = grid:FindFirstChildOfClass("UIPadding") :: UIPadding
		pad.PaddingLeft = UDim.new(0, 26)
		pad.PaddingTop = UDim.new(0, 26)
		pad.PaddingBottom = UDim.new(0, 20)
		local layout = Instance.new("UIGridLayout")
		layout.CellSize = UDim2.fromOffset(127, 127)
		layout.CellPadding = UDim2.fromOffset(13, 13)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = grid

		local selectedCell: TextButton? = nil
		for i, c in ipairs(Catalog.Characters) do
			local cStatus = statusOf("char:" .. c.id)
			local cell = Instance.new("TextButton")
			cell.Name = c.id
			cell.Text = ""
			cell.AutoButtonColor = false
			cell.BackgroundColor3 = if cStatus == "owned" then PORTRAIT_BG else LOCKED_BG
			cell.BorderSizePixel = 0
			cell.LayoutOrder = i
			cell.Parent = grid
			Theme.stroke(cell, CELL_BORDER, 2)
			cornerBolts(cell, 8)
			local holder = Theme.frame({ BackgroundTransparency = 1, Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -30), ClipsDescendants = true, Parent = cell })
			portrait(holder, c.id, cStatus ~= "owned")
			local strip = Theme.frame({ BackgroundColor3 = Color3.fromRGB(38, 38, 40), Position = UDim2.new(0, 2, 1, -27), Size = UDim2.new(1, -4, 0, 25), ZIndex = 3, Parent = cell })
			outlined(Theme.label({
				Text = characterName(c.id),
				TextSize = 22,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 4,
				Parent = strip,
			}), 1.5)
			if cStatus == "available" then
				-- Estrella: condición cumplida, listo para comprar
				outlined(Theme.label({
					Name = "Star",
					Text = "★",
					FontFace = SANS,
					TextSize = 44,
					TextColor3 = Color3.fromRGB(255, 220, 40),
					TextXAlignment = Enum.TextXAlignment.Center,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(1, -8, 0, 8),
					Size = UDim2.fromOffset(40, 40),
					ZIndex = 7,
					Parent = cell,
				}), 2)
			end
			local brackets = Theme.brackets(cell, 9)
			if c.id == id then
				for _, b in brackets do
					b.Visible = true
				end
				selectedCell = cell
			end
			cell.Activated:Connect(function()
				if selected.character ~= c.id then
					selected.character = c.id
					hatListOpen = false
					renderWindow("refresh")
				end
			end)
		end

		-- Centro: personaje en 3D ---------------------------------------------------------------
		mountModel(content, id)

		-- Derecha: ficha --------------------------------------------------------------------------
		local _, body = Theme.panel({
			Name = "Info",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -54, 0, 206),
			Size = UDim2.fromOffset(541, 712),
			Parent = content,
		})
		local face = framedBox(body, { Name = "Portrait", Position = UDim2.fromOffset(19, 15), Size = UDim2.fromOffset(116, 116), ClipsDescendants = true })
		portrait(face, id, not owned)
		outlined(Theme.label({ Name = "Name", Text = characterName(id), TextSize = 36, Position = UDim2.fromOffset(152, 14), Size = UDim2.fromOffset(360, 42), Parent = body }), 2)

		local rank, runs, progress = rankOf(id)
		rankIcon(Theme.frame({ BackgroundTransparency = 1, Position = UDim2.fromOffset(152, 62), Size = UDim2.fromOffset(28, 28), Parent = body }))
		outlined(Theme.label({ Text = "Rango " .. rank, TextSize = 26, Position = UDim2.fromOffset(188, 60), Size = UDim2.fromOffset(300, 30), Parent = body }), 1.5)
		local rankBar = Theme.frame({ BackgroundColor3 = Color3.fromRGB(10, 12, 14), Position = UDim2.fromOffset(152, 94), Size = UDim2.fromOffset(112, 5), Parent = body })
		Theme.frame({ BackgroundColor3 = RANK_BLUE, Size = UDim2.fromScale(progress, 1), Parent = rankBar })
		runsIcon(Theme.frame({ BackgroundTransparency = 1, Position = UDim2.fromOffset(152, 104), Size = UDim2.fromOffset(28, 28), Parent = body }))
		outlined(Theme.label({ Text = runs .. (if runs == 1 then " Carrera" else " Carreras"), TextSize = 26, Position = UDim2.fromOffset(188, 102), Size = UDim2.fromOffset(300, 30), Parent = body }), 1.5)

		local tagline = Spanish.Characters[id] and Spanish.Characters[id].tagline or character.look
		outlined(Theme.label({
			Name = "Tagline",
			Text = if owned then tagline else lockedText(entry),
			TextSize = 23,
			TextColor3 = if owned then Color3.fromRGB(225, 225, 220) else C.TextYellow,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(19, 152),
			Size = UDim2.fromOffset(500, 80),
			Parent = body,
		}), 1.5)
		if not owned and entry and not entry.pending and (entry.target or 0) > 0 then
			local bar = Theme.frame({ BackgroundColor3 = Color3.fromRGB(10, 12, 14), Position = UDim2.fromOffset(19, 234), Size = UDim2.fromOffset(500, 7), Parent = body })
			local f = math.clamp((entry.current or 0) / entry.target, 0, 1)
			Theme.frame({ BackgroundColor3 = if f >= 0.75 then C.BarGreen else C.BarYellow, Size = UDim2.fromScale(f, 1), Parent = bar })
		end

		-- Arma inicial y pasiva
		local weapon = Catalog.Weapon[character.weapon]
		local rows = {
			{ y = 262, icon = function(h) weaponIcon(h, character.weapon) end, name = Spanish.weaponName(weapon.id, weapon.name), desc = weapon.desc },
			{ y = 360, icon = function(h) passiveIcon(h, id) end, name = Spanish.Characters[id] and Spanish.Characters[id].passive or character.passive.name, desc = character.passive.desc },
		}
		for _, row in rows do
			local box = framedBox(body, { Position = UDim2.fromOffset(19, row.y), Size = UDim2.fromOffset(76, 76), ClipsDescendants = true })
			row.icon(box)
			outlined(Theme.label({ Text = row.name, TextSize = 30, TextColor3 = C.Yellow, Position = UDim2.fromOffset(110, row.y - 2), Size = UDim2.fromOffset(410, 36), Parent = body }), 1.5)
			outlined(Theme.label({
				Text = row.desc,
				TextSize = 19,
				TextWrapped = true,
				TextYAlignment = Enum.TextYAlignment.Top,
				Position = UDim2.fromOffset(110, row.y + 36),
				Size = UDim2.fromOffset(410, 46),
				Parent = body,
			}), 1)
		end

		-- Skins: la predeterminada y las documentadas del personaje (sólo visuales por ahora)
		outlined(Theme.label({ Text = "Skin", TextSize = 30, TextColor3 = C.Yellow, Position = UDim2.fromOffset(19, 452), Size = UDim2.fromOffset(200, 36), Parent = body }), 1.5)
		local skins = skinsOf(id)
		local current = chosenSkin[id] or ""
		local slots = { { id = "", name = "Predeterminada" } }
		for _, skin in skins do
			table.insert(slots, skin)
		end
		for i, skin in slots do
			local met = skin.id == "" or cosmeticMet(skin.id)
			local slot = Instance.new("TextButton")
			slot.Name = "Skin" .. i
			slot.Text = ""
			slot.AutoButtonColor = met
			slot.BackgroundColor3 = Color3.fromRGB(28, 28, 30)
			slot.BorderSizePixel = 0
			slot.Position = UDim2.fromOffset(19 + (i - 1) * 68, 492)
			slot.Size = UDim2.fromOffset(60, 60)
			slot.Parent = body
			Theme.stroke(slot, if skin.id == current then C.Yellow else CELL_BORDER, if skin.id == current then 3 else 2)
			if skin.id == "" then
				-- Orbe bicolor de la skin por defecto
				local orb = edged(round(shape(slot, Color3.fromRGB(235, 150, 40), 0.5, 0.5, 0.72, 0.72, 1)), 2)
				local half = Theme.frame({ BackgroundColor3 = Color3.fromRGB(60, 140, 220), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0.5, 1), Parent = orb })
				round(half)
			elseif met then
				local skinImage = Images.get(Images.Skins, skin.id)
				if skinImage then
					local img = Instance.new("ImageLabel")
					img.BackgroundTransparency = 1
					img.Size = UDim2.fromScale(1, 1)
					img.Image = skinImage
					img.Parent = slot
				else
					characterIcon(slot, id)
				end
			else
				drawLock(slot).Size = UDim2.fromOffset(30, 36)
			end
			slot.Activated:Connect(function()
				if met then
					chosenSkin[id] = skin.id
					setStatus(skin.name .. (if skin.id ~= "" then " · (vista previa pendiente de modelo)" else ""), C.Muted)
					renderWindow("refresh")
				else
					setStatus(skin.name .. ": " .. cosmeticText(skin.id), C.Muted)
				end
			end)
		end

		-- CONFIRMAR (o comprar / bloqueado)
		local confirmText, confirmColor = "CONFIRMAR", CONFIRM_BLUE
		if status == "available" and entry then
			confirmText, confirmColor = string.format("COMPRAR · %d", entry.price), Color3.fromRGB(196, 150, 30)
		elseif not owned then
			confirmText, confirmColor = "BLOQUEADO", Color3.fromRGB(70, 70, 74)
		end
		local confirm = Theme.button({
			Name = "Confirm",
			Text = confirmText,
			TextSize = 34,
			TextColor3 = WHITE,
			BackgroundColor3 = confirmColor,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 618),
			Size = UDim2.fromOffset(238, 66),
			Parent = body,
		}, function()
			if owned then
				openWindow("Maps")
			elseif status == "available" then
				buy("char:" .. id)
			else
				setStatus(characterName(id) .. ": " .. progressText(entry), C.Muted)
			end
		end, { edge = 6, radius = 6 })
		Theme.outlined(confirm, 2)

		-- Abajo a la derecha: sombrero ------------------------------------------------------------
		local _, hatBody = Theme.panel({
			Name = "HatPanel",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -90, 0, 941),
			Size = UDim2.fromOffset(470, 98),
			Parent = content,
		})
		local hatButton = Theme.stoneButton({
			Name = "Hat",
			Text = hatName(chosenHat),
			TextSize = 28,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(250, 54),
			Parent = hatBody,
		}, function()
			hatListOpen = not hatListOpen
			renderWindow("refresh")
		end, focus, { gap = 6 })
		drawHat(Theme.frame({ BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, -3), Size = UDim2.fromOffset(32, 32), ZIndex = 4, Parent = hatButton }))
		for _, name in { "TextShadow", "Label" } do
			local text = hatButton:FindFirstChild(name) :: TextLabel?
			if text then
				text.Position += UDim2.fromOffset(20, 0)
				text.Size -= UDim2.fromOffset(24, 0)
			end
		end

		-- Lista de sombreros (generales y los propios del personaje) sobre el panel
		if hatListOpen then
			local options = { { id = nil, name = "Sin sombrero" } }
			for _, hat in Catalog.Cosmetics.Hats do
				if not hat.character or hat.character == id then
					table.insert(options, hat)
				end
			end
			local listPanel, listBody = Theme.panel({
				Name = "HatList",
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -90, 0, 935),
				Size = UDim2.fromOffset(470, 420),
				ZIndex = 5,
				Parent = content,
			}, "SOMBRERO", 46)
			local list = scrollList(listBody, { Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -20, 1, -16) })
			for i, hat in options do
				local met = hat.id == nil or cosmeticMet(hat.id)
				local b = Theme.button({
					Name = "HatOption" .. i,
					Text = (if met then "" else "🔒 ") .. hat.name,
					TextSize = 22,
					TextColor3 = if hat.id == chosenHat then C.Yellow elseif met then WHITE else C.Muted,
					Size = UDim2.new(1, -12, 0, 44),
					LayoutOrder = i,
					Parent = list,
				}, function()
					if met then
						chosenHat = hat.id
						hatListOpen = false
						setStatus(hat.name .. (if hat.id then " · (modelo pendiente)" else ""), C.Muted)
						renderWindow("refresh")
					else
						setStatus(hat.name .. ": " .. cosmeticText(hat.id), C.Muted)
					end
				end)
				b.TextXAlignment = Enum.TextXAlignment.Left
				local pad = Instance.new("UIPadding")
				pad.PaddingLeft = UDim.new(0, 12)
				pad.Parent = b
			end
			listPanel.ZIndex = 5
		end
		return selectedCell or confirm
	end,
}

-- Jugar: mapa y tier ----------------------------------------------------------------------------

local function mapPlayable(map): boolean
	return map.playable and statusOf("map:" .. map.id) == "owned"
end

WINDOWS.Maps = {
	title = "ELIGE MAPA",
	size = Vector2.new(1180, 780),
	back = "Characters",
	render = function(content, footer)
		local current = Catalog.Map[selected.map]
		if not current or not mapPlayable(current) then
			selected.map = "Forest"
		end
		local cards: { [string]: TextButton } = {}
		local tierRow = Theme.frame({ BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 424), Size = UDim2.new(1, 0, 0, 100), Parent = content })

		local refresh
		-- Botones de tier del mapa elegido, con el jefe final de cada uno.
		local function buildTiers()
			tierRow:ClearAllChildren()
			local map = Catalog.Map[selected.map]
			selected.tier = math.clamp(selected.tier, 1, #map.tiers)
			outlined(Theme.label({ Text = "TIER", TextSize = 34, Size = UDim2.fromOffset(100, 56), Parent = tierRow }), 2)
			for t, tier in map.tiers do
				local active = t == selected.tier
				local b = Theme.button({
					Text = "TIER " .. t,
					TextSize = 28,
					TextColor3 = if active then C.Yellow else WHITE,
					Position = UDim2.fromOffset(110 + (t - 1) * 230, 0),
					Size = UDim2.fromOffset(210, 56),
					Parent = tierRow,
				}, function()
					selected.tier = t
					refresh()
				end)
				if active then
					Theme.stroke(b, C.Yellow, 3)
				end
				local boss = Catalog.Enemies[tier.boss]
				Theme.label({
					Text = if boss then "Jefe: " .. boss.name else "",
					Font = Theme.FontBody,
					TextSize = 15,
					TextColor3 = C.Muted,
					TextXAlignment = Enum.TextXAlignment.Center,
					Position = UDim2.fromOffset(110 + (t - 1) * 230, 62),
					Size = UDim2.fromOffset(210, 22),
					Parent = tierRow,
				})
			end
		end
		refresh = function()
			for id, card in cards do
				Theme.stroke(card, if id == selected.map then C.Yellow else C.Outline, if id == selected.map then 3 else 2)
			end
			buildTiers()
		end

		for i, map in ipairs(Catalog.Maps) do
			local mapStatus, mapEntry = statusOf("map:" .. map.id)
			local card = Theme.button({ Name = map.id, Text = "", Position = UDim2.fromOffset((i - 1) * 388, 0), Size = UDim2.fromOffset(360, 400), Parent = content }, function()
				if mapPlayable(map) then
					selected.map = map.id
					refresh()
				elseif map.playable and mapStatus == "available" then
					buy("map:" .. map.id)
				else
					setStatus(if not map.playable then map.desc else progressText(mapEntry), C.Muted)
				end
			end, { edge = 6, radius = 5 })
			local picture = Theme.frame({ BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 12), Size = UDim2.new(1, -24, 0, 190), Parent = card })
			drawMap(picture, map.id)
			if not mapPlayable(map) then
				local veil = Theme.frame({ BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, Size = UDim2.fromScale(1, 1), ZIndex = 10, Parent = picture })
				Theme.corner(veil, 4)
				if map.playable then
					drawLock(veil)
				else
					outlined(Theme.label({ Text = "PRÓXIMAMENTE", TextSize = 30, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = veil }), 2)
				end
			end
			outlined(Theme.label({ Text = map.name, TextSize = 36, Position = UDim2.fromOffset(16, 208), Size = UDim2.new(1, -32, 0, 40), Parent = card }), 2)
			Theme.label({
				Text = map.desc,
				Font = Theme.FontBody,
				TextSize = 14,
				TextColor3 = C.Muted,
				TextWrapped = true,
				TextYAlignment = Enum.TextYAlignment.Top,
				Position = UDim2.fromOffset(16, 252),
				Size = UDim2.new(1, -32, 0, 76),
				Parent = card,
			})
			local stateText, stateColor
			if not map.playable then
				stateText, stateColor = "PENDIENTE DE IMPLEMENTAR", C.Muted
			elseif mapStatus == "owned" or mapPlayable(map) then
				stateText, stateColor = "DISPONIBLE", C.Good
			elseif mapStatus == "available" then
				stateText, stateColor = "¡PULSA PARA DESBLOQUEAR!", C.Yellow
			else
				stateText, stateColor = progressText(mapEntry), C.TextYellow
			end
			outlined(Theme.label({
				Text = stateText,
				TextSize = 18,
				TextColor3 = stateColor,
				TextWrapped = true,
				TextYAlignment = Enum.TextYAlignment.Top,
				Position = UDim2.fromOffset(16, 332),
				Size = UDim2.new(1, -32, 0, 50),
				Parent = card,
			}), 1.5)
			cards[map.id] = card
		end
		refresh()

		return footerButton(footer, "JUGAR", function()
			if statusOf("char:" .. selected.character) ~= "owned" then
				setStatus("Ese personaje está bloqueado", C.Bad)
				return
			end
			local map = Catalog.Map[selected.map]
			if not map or not mapPlayable(map) then
				setStatus("Ese mapa no está disponible", C.Bad)
				return
			end
			Net.get("StartRun"):FireServer({ character = selected.character, map = selected.map, tier = selected.tier })
			setStatus("Cargando partida...", C.Muted)
		end)
	end,
}

-- Desbloqueos -----------------------------------------------------------------------------------
-- Panel centrado sobre la escena con la composición de la referencia: cabecera "DESBLOQUEOS" con la
-- X roja, pestañas (Personajes, Armas, Tomos, Objetos, Sombreros), cuadrícula de 9 columnas con
-- siluetas negras para lo bloqueado y, bajo un separador, la ficha del elemento elegido con sus
-- requisitos marcados (misión con su progreso, arma necesaria y compra con plata).
-- Medidas en píxeles de diseño (captura de 2000×1249 escalada a 1080 de alto).

local UNLOCK_TABS = {
	{ kind = "char", text = "PERSONAJES" },
	{ kind = "weapon", text = "ARMAS" },
	{ kind = "tome", text = "TOMOS" },
	{ kind = "item", text = "OBJETOS" },
	{ kind = "hat", text = "SOMBREROS" },
}
local KIND_NAME = { weapon = "Arma", tome = "Tomo", item = "Objeto", char = "Personaje", map = "Mapa" }
local unlockTab = "char"
local unlockChoice: { [string]: string } = {}

local TAB_STRIP = Color3.fromRGB(29, 35, 32)
local TAB_ACTIVE = Color3.fromRGB(45, 55, 50)
local REQUIREMENT_ROW = Color3.fromRGB(26, 31, 29)

local function contentName(kind: string, id: string, fallback: string): string
	if kind == "char" then
		return characterName(id)
	elseif kind == "weapon" then
		return Spanish.weaponName(id, fallback)
	elseif kind == "tome" then
		return Spanish.tomeName(id, fallback)
	end
	return fallback
end

-- Elementos de una pestaña en el orden del catálogo: { key, kind, id, name, owned, available,
-- requirements = { { text, done, current?, target? } }, price? }
local function unlockEntries(kind: string)
	local profile = ClientState.profile
	local list = {}
	if kind == "hat" then
		local byId = {}
		for _, c in (profile and profile.cosmetics) or {} do
			byId[c.id] = c
		end
		for _, hat in Catalog.Cosmetics.Hats do
			local c = byId[hat.id]
			local owned = (profile and profile.studioUnlockAll) or (c ~= nil and c.met == true)
			table.insert(list, {
				key = "hat:" .. hat.id,
				kind = "hat",
				id = hat.id,
				name = hat.name,
				owned = owned,
				requirements = {
					{ text = hat.unlock.text, done = owned, pending = c and c.pending, current = c and c.current or 0, target = c and c.target or 0 },
				},
			})
		end
		return list
	end
	local byKey = {}
	for _, entry in (profile and profile.content) or {} do
		byKey[entry.key] = entry
	end
	local source = ({ char = Catalog.Characters, weapon = Catalog.Weapons, tome = Catalog.Tomes, item = Catalog.Items })[kind]
	for _, data in ipairs(source) do
		local key = kind .. ":" .. data.id
		local entry = byKey[key]
		local status = statusOf(key)
		local owned = status == "owned"
		local requirements = {}
		if data.unlock.kind == "start" then
			table.insert(requirements, { text = "Disponible desde el inicio", done = true })
		else
			table.insert(requirements, {
				text = data.unlock.text,
				done = owned or (entry ~= nil and entry.met == true),
				pending = data.unlock.kind == "pending",
				current = entry and entry.current or 0,
				target = entry and entry.target or 0,
			})
			for _, required in (entry and entry.requires) or {} do
				table.insert(requirements, {
					text = string.format("Comprar: %s - %s", KIND_NAME[required.kind] or "", contentName(required.kind, required.id, required.name)),
					done = owned or required.owned,
				})
			end
			if kind ~= "char" and entry and entry.price > 0 then
				table.insert(requirements, { text = string.format("Comprar con %d de plata", entry.price), done = owned, buy = status == "available" })
			end
		end
		table.insert(list, {
			key = key,
			kind = kind,
			id = data.id,
			name = contentName(kind, data.id, data.name),
			desc = if kind == "tome" then Spanish.tomeDescription(data.id, data.desc) else data.desc,
			owned = owned,
			available = status == "available",
			price = entry and entry.price,
			requirements = requirements,
		})
	end
	return list
end

-- Icono de un elemento: retrato (personajes) o dibujo; lo bloqueado se ve como silueta oscura.
local function unlockIcon(holder: GuiObject, e)
	if e.kind == "char" then
		portrait(holder, e.id, not e.owned)
		return
	end
	if e.kind == "tome" then
		local inner = Theme.frame({ BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.94, 0.94), Parent = holder })
		Icons.tome(inner, e.id, not e.owned)
		return
	end
	local image = if e.kind == "weapon" then Images.get(Images.Weapons, e.id) elseif e.kind == "hat" then Images.get(Images.Hats, e.id) else nil
	if image then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.Image = image
		img.ImageColor3 = if e.owned then WHITE else Color3.new(0, 0, 0)
		img.Parent = holder
		return
	end
	drawIcon(Theme.frame({ BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.78, 0.78), Parent = holder }), e.kind, e.id)
	if not e.owned then
		Theme.frame({ Name = "Shadow", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.2, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = holder })
	end
end

-- Fila de requisito: casilla (marcada si se cumple), texto y, a la derecha, el progreso o la compra.
local function requirementRow(parent: Instance, y: number, req, onBuy: () -> ()): (Frame, TextButton?)
	local row = Theme.frame({ Name = "Requirement", BackgroundColor3 = REQUIREMENT_ROW, Position = UDim2.fromOffset(137, y), Size = UDim2.new(1, -159, 0, 28), Parent = parent })
	local box = Theme.frame({ Name = "Check", BackgroundColor3 = Color3.fromRGB(16, 18, 17), Position = UDim2.fromOffset(2, 2), Size = UDim2.fromOffset(24, 24), Parent = row })
	Theme.stroke(box, CELL_BORDER, 2)
	if req.done then
		outlined(Theme.label({ Name = "Tick", Text = "✓", FontFace = SANS, TextSize = 24, TextColor3 = C.Good, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = box }), 1.5)
	end
	local text = req.text .. (if req.pending and not req.done then " (aún no disponible)" else "")
	outlined(Theme.label({ Text = text, TextSize = 24, TextColor3 = if req.pending and not req.done then C.Muted else WHITE, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(36, 0), Size = UDim2.new(1, -250, 1, 0), Parent = row }), 1.5)
	if req.buy then
		local b = Theme.button({
			Name = "Buy",
			Text = "COMPRAR",
			TextSize = 22,
			TextColor3 = C.Yellow,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -4, 0.5, 0),
			Size = UDim2.fromOffset(170, 34),
			ZIndex = 3,
			Parent = row,
		}, onBuy)
		return row, b
	end
	if not req.done and not req.pending and (req.target or 0) > 0 then
		local f = math.clamp(req.current / req.target, 0, 1)
		outlined(Theme.label({
			Text = string.format("%s / %s", Theme.formatNumber(math.floor(req.current)), Theme.formatNumber(req.target)),
			FontFace = SANS,
			TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, -2),
			Size = UDim2.fromOffset(198, 26),
			Parent = row,
		}), 1.5)
		local bar = Theme.frame({ BackgroundColor3 = Color3.fromRGB(8, 9, 9), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, 2), Size = UDim2.fromOffset(198, 5), Parent = row })
		Theme.frame({ BackgroundColor3 = C.BarYellow, Size = UDim2.fromScale(f, 1), Parent = bar })
	end
	return row, nil
end

WINDOWS.Unlocks = {
	title = "DESBLOQUEOS",
	size = Vector2.new(0, 0),
	fullscreen = true,
	render = function(content)
		local panel, body, header = Theme.panel({
			Name = "UnlocksPanel",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(1078, 761),
			Parent = content,
		}, "DESBLOQUEOS", 56)
		local headerBar = header :: Frame
		local title = headerBar:FindFirstChild("Title") :: TextLabel
		title.TextSize = 34
		title.Position = UDim2.fromOffset(28, 0)
		local close = Instance.new("TextButton")
		close.Name = "Close"
		close.Text = "X"
		close.FontFace = SANS
		close.TextSize = 40
		close.TextColor3 = Color3.fromRGB(235, 35, 35)
		close.BackgroundTransparency = 1
		close.AnchorPoint = Vector2.new(1, 0.5)
		close.Position = UDim2.new(1, -14, 0.5, 0)
		close.Size = UDim2.fromOffset(40, 40)
		close.Parent = headerBar
		outlined(close, 2)
		close.Activated:Connect(goBack)

		-- Pestañas
		local strip = Theme.frame({ Name = "Tabs", BackgroundColor3 = TAB_STRIP, Size = UDim2.new(1, 0, 0, 54), Parent = body })
		Theme.list(strip, Enum.FillDirection.Horizontal, 0)
		local first: GuiObject? = nil
		for i, tab in UNLOCK_TABS do
			local active = tab.kind == unlockTab
			local b = Instance.new("TextButton")
			b.Name = "Tab" .. i
			b.Text = tab.text
			b.FontFace = Theme.FontFace
			b.TextSize = 26
			b.TextColor3 = WHITE
			b.AutoButtonColor = false
			b.BorderSizePixel = 0
			b.BackgroundColor3 = TAB_ACTIVE
			b.BackgroundTransparency = if active then 0 else 1
			b.AutomaticSize = Enum.AutomaticSize.X
			b.Size = UDim2.fromOffset(0, 54)
			b.LayoutOrder = i
			b.Parent = strip
			Theme.outlined(b, 1.5)
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft = UDim.new(0, 18)
			pad.PaddingRight = UDim.new(0, 18)
			pad.Parent = b
			b.Activated:Connect(function()
				if unlockTab ~= tab.kind then
					unlockTab = tab.kind
					renderWindow("reset")
				end
			end)
			if active then
				first = b
			end
		end

		-- Cuadrícula
		local GRID_TOP, GRID_H = 54, 485
		local entries = unlockEntries(unlockTab)
		local chosen = nil
		for _, e in entries do
			if e.key == unlockChoice[unlockTab] then
				chosen = e
			end
		end
		chosen = chosen or entries[1]
		local grid = scrollList(body, { Position = UDim2.fromOffset(4, GRID_TOP + 2), Size = UDim2.new(1, -8, 0, GRID_H - 4) })
		grid:FindFirstChildOfClass("UIListLayout"):Destroy()
		local pad = grid:FindFirstChildOfClass("UIPadding") :: UIPadding
		pad.PaddingLeft = UDim.new(0, 18)
		pad.PaddingTop = UDim.new(0, 17)
		pad.PaddingBottom = UDim.new(0, 17)
		local layout = Instance.new("UIGridLayout")
		layout.CellSize = UDim2.fromOffset(96, 96)
		layout.CellPadding = UDim2.fromOffset(18, 18)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = grid
		local selectedCell: GuiObject? = nil
		for i, e in entries do
			local cell = Instance.new("TextButton")
			cell.Name = e.id
			cell.Text = ""
			cell.AutoButtonColor = false
			cell.BackgroundColor3 = if e.owned then PORTRAIT_BG else LOCKED_BG
			cell.BorderSizePixel = 0
			cell.LayoutOrder = i
			cell.Parent = grid
			Theme.stroke(cell, CELL_BORDER, 2)
			cornerBolts(cell, 6)
			unlockIcon(Theme.frame({ BackgroundTransparency = 1, Position = UDim2.fromOffset(2, 2), Size = UDim2.new(1, -4, 1, -4), ClipsDescendants = true, Parent = cell }), e)
			if e.available then
				outlined(Theme.label({
					Name = "Star",
					Text = "★",
					FontFace = SANS,
					TextSize = 34,
					TextColor3 = Color3.fromRGB(255, 220, 40),
					TextXAlignment = Enum.TextXAlignment.Center,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(1, -6, 0, 6),
					Size = UDim2.fromOffset(32, 32),
					ZIndex = 7,
					Parent = cell,
				}), 2)
			end
			local brackets = Theme.brackets(cell, 12)
			if chosen and e.key == chosen.key then
				for _, b in brackets do
					b.Visible = true
				end
				selectedCell = cell
			end
			cell.Activated:Connect(function()
				if unlockChoice[unlockTab] ~= e.key then
					unlockChoice[unlockTab] = e.key
					renderWindow("refresh")
				end
			end)
		end

		-- Ficha del elemento elegido bajo el separador
		local sep = Theme.divider(panel, body, GRID_TOP + GRID_H)
		local detail = Theme.frame({ Name = "Detail", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, GRID_TOP + GRID_H + sep), Size = UDim2.new(1, 0, 1, -(GRID_TOP + GRID_H + sep)), Parent = body })
		if not chosen then
			return first
		end
		local face = framedBox(detail, { Name = "Portrait", BackgroundColor3 = if chosen.owned then PORTRAIT_BG else LOCKED_BG, Position = UDim2.fromOffset(22, 15), Size = UDim2.fromOffset(102, 102), ClipsDescendants = true })
		unlockIcon(face, chosen)
		outlined(Theme.label({ Name = "Name", Text = chosen.name, TextSize = 32, Position = UDim2.fromOffset(137, 4), Size = UDim2.new(1, -160, 0, 38), TextTruncate = Enum.TextTruncate.AtEnd, Parent = detail }), 2)
		-- Caben tres filas; con dos se separan como en la referencia
		-- Qué hace (tomos y armas) bajo el nombre; los requisitos debajo
		local top = 44
		if chosen.desc and chosen.desc ~= "" then
			local description = outlined(Theme.label({
				Name = "Description",
				Text = chosen.desc,
				TextScaled = true,
				TextColor3 = C.TextYellow,
				Position = UDim2.fromOffset(137, 39),
				Size = UDim2.new(1, -160, 0, 24),
				Parent = detail,
			}), 1.5)
			-- Las descripciones largas se encogen para caber en una línea
			local limit = Instance.new("UITextSizeConstraint")
			limit.MaxTextSize = 20
			limit.MinTextSize = 12
			limit.Parent = description
			top = 66
		end
		local step = if #chosen.requirements > 2 then 29 elseif top > 44 then 32 else 35
		for i, req in chosen.requirements do
			if i > 3 or top + (i - 1) * step + 28 > 136 then
				break
			end
			requirementRow(detail, top + (i - 1) * step, req, function()
				buy(chosen.key)
			end)
		end
		return selectedCell or first
	end,
}

-- Misiones --------------------------------------------------------------------------------------

local SECTIONS = {
	{ "buy", "LISTAS PARA COMPRAR" },
	{ "progress", "EN PROGRESO" },
	{ "pending", "PENDIENTES DE IMPLEMENTAR" },
	{ "done", "CONSEGUIDAS" },
}

WINDOWS.Missions = {
	title = "MISIONES",
	size = Vector2.new(1300, 820),
	render = function(content)
		local profile = ClientState.profile
		if not profile then
			return nil
		end
		local records = profile.records or {}
		outlined(Theme.label({
			Text = string.format(
				"Misiones completadas: %d    ·    Partidas: %d    ·    Mejor tiempo: %.1f min    ·    Más bajas: %s",
				profile.quests or 0,
				records.runs or 0,
				records.bestMinutes or 0,
				Theme.formatThousands(records.bestKills or 0)
			),
			TextSize = 22,
			TextColor3 = C.Muted,
			Size = UDim2.new(1, 0, 0, 30),
			Parent = content,
		}), 1.5)
		local list = scrollList(content, { Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 1, -42) })

		local groups = { buy = {}, progress = {}, pending = {}, done = {} }
		for _, m in missionsOf(profile) do
			table.insert(groups[m.state], m)
		end
		table.sort(groups.progress, function(a, b)
			local fa, fb = fraction(a), fraction(b)
			if fa ~= fb then
				return fa > fb
			end
			return a.name < b.name
		end)
		for _, key in { "buy", "pending", "done" } do
			table.sort(groups[key], function(a, b)
				return a.name < b.name
			end)
		end

		local order = 0
		local first
		for _, section in SECTIONS do
			local items = groups[section[1]]
			if #items > 0 then
				order += 1
				outlined(Theme.label({ Text = string.format("%s  (%d)", section[2], #items), TextSize = 28, Size = UDim2.new(1, -16, 0, 36), LayoutOrder = order, Parent = list }), 2)
				for _, m in items do
					order += 1
					local card = missionCard(m, { Size = UDim2.new(1, -16, 0, 74), LayoutOrder = order, Parent = list }, 420, 250)
					if m.state == "buy" then
						local b = buyButton(card, m.entry.price, function()
							buy(m.entry.key)
						end)
						first = first or b
					elseif m.state == "pending" then
						statusTag(card, "Pendiente", C.Muted)
					elseif m.state == "done" then
						statusTag(card, "¡CONSEGUIDA!", C.Good)
					elseif m.current >= m.target then
						statusTag(card, "Requiere otro contenido", C.Muted)
					end
				end
			end
		end
		return first
	end,
}

-- Tienda ----------------------------------------------------------------------------------------

WINDOWS.Shop = {
	title = "TIENDA",
	size = Vector2.new(1100, 780),
	render = function(content)
		local profile = ClientState.profile
		if not profile then
			return nil
		end
		outlined(Theme.label({
			Text = string.format("Misiones completadas: %d    ·    Ranuras: %d armas, %d tomos", profile.quests, profile.weaponSlots, profile.tomeSlots),
			TextSize = 22,
			TextColor3 = C.Muted,
			Size = UDim2.new(1, 0, 0, 30),
			Parent = content,
		}), 1.5)
		local list = scrollList(content, { Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 1, -42) })
		local first
		for i, entry in profile.shop do
			local row = Theme.frame({ BackgroundColor3 = C.Row, Size = UDim2.new(1, -16, 0, 66), LayoutOrder = i, Parent = list })
			Theme.corner(row, 3)
			outlined(Theme.label({ Text = entry.name, TextSize = 26, TextColor3 = if entry.status == "available" then C.Yellow else WHITE, Position = UDim2.fromOffset(16, 4), Size = UDim2.new(1, -290, 0, 32), Parent = row }), 1.5)
			Theme.label({
				Text = string.format("Requiere %d misiones completadas", entry.quests),
				Font = Theme.FontBody,
				TextSize = 15,
				TextColor3 = if profile.quests >= entry.quests then C.TextGreen else C.Muted,
				Position = UDim2.fromOffset(16, 37),
				Size = UDim2.new(1, -290, 0, 22),
				Parent = row,
			})
			if entry.status == "available" then
				local b = buyButton(row, entry.price, function()
					buy(entry.key)
				end)
				first = first or b
			else
				statusTag(row, if entry.status == "owned" then "Comprado" else "Bloqueado", STATUS_COLOR[entry.status])
			end
		end
		return first
	end,
}

-- Ajustes ---------------------------------------------------------------------------------------

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

local function settingRow(list: Instance, order: number, text: string): Frame
	local row = Theme.frame({ BackgroundColor3 = C.Row, Size = UDim2.new(1, -16, 0, 56), LayoutOrder = order, Parent = list })
	Theme.corner(row, 3)
	outlined(Theme.label({ Text = text, TextSize = 26, Position = UDim2.fromOffset(16, 0), Size = UDim2.new(0.6, 0, 1, 0), Parent = row }), 1.5)
	return row
end

WINDOWS.Settings = {
	title = "AJUSTES",
	size = Vector2.new(1000, 820),
	render = function(content)
		local list = scrollList(content)
		local s = ClientState.settings
		local first
		for i, option in OPTIONS do
			local row = settingRow(list, i, option.label)
			if option.toggle then
				local b = Theme.button({
					Text = if s[option.key] then "SÍ" else "NO",
					TextSize = 26,
					TextColor3 = if s[option.key] then C.Good else WHITE,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -12, 0.5, -1),
					Size = UDim2.fromOffset(120, 44),
					Parent = row,
				}, function()
					s[option.key] = not s[option.key]
					ClientState.saveSettings()
					renderWindow("refresh")
				end)
				first = first or b
			else
				local value = outlined(Theme.label({
					Text = string.format("%.2f", s[option.key]),
					TextSize = 26,
					TextXAlignment = Enum.TextXAlignment.Center,
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -64, 0, 0),
					Size = UDim2.new(0, 88, 1, 0),
					Parent = row,
				}), 1.5)
				local function change(sign: number)
					s[option.key] = math.clamp(math.round((s[option.key] + sign * option.step) * 100) / 100, option.min, option.max)
					value.Text = string.format("%.2f", s[option.key])
					ClientState.saveSettings()
					if option.key == "uiScale" then
						applyScale()
					end
				end
				local minus = Theme.button({ Text = "−", TextSize = 32, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -158, 0.5, -1), Size = UDim2.fromOffset(48, 44), Parent = row }, function()
					change(-1)
				end)
				Theme.button({ Text = "+", TextSize = 32, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, -1), Size = UDim2.fromOffset(48, 44), Parent = row }, function()
					change(1)
				end)
				first = first or minus
			end
		end
		-- Reasignación de teclas
		for j, action in { "Pause", "Map" } do
			local row = settingRow(list, 100 + j, if action == "Pause" then "Tecla de pausa" else "Tecla de mapa")
			local key = ClientState.bindings[action][1]
			Theme.button({
				Text = if waitingRebind == action then "Pulsa una tecla..." else key.Name,
				TextSize = 24,
				TextColor3 = if waitingRebind == action then C.Yellow else WHITE,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, -1),
				Size = UDim2.fromOffset(220, 44),
				Parent = row,
			}, function()
				waitingRebind = action
				renderWindow("refresh")
			end)
		end
		return first
	end,
}

-- La espera de tecla sólo vale con Ajustes abierto y el menú a la vista; Escape la cancela.
UserInputService.InputBegan:Connect(function(input)
	if not waitingRebind or input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end
	local action = waitingRebind
	waitingRebind = nil
	if not (gui and gui.Enabled and window and window.name == "Settings") then
		return
	end
	if input.KeyCode ~= Enum.KeyCode.Escape then
		ClientState.bindings[action][1] = input.KeyCode
	end
	renderWindow("refresh")
end)

-- Idioma, Discord, créditos y salir -------------------------------------------------------------

WINDOWS.Language = {
	title = "IDIOMA",
	size = Vector2.new(680, 440),
	render = function(content)
		Theme.list(content, nil, 16)
		local es = Theme.button({ Text = "Español", TextSize = 34, TextColor3 = C.Yellow, Size = UDim2.new(1, 0, 0, 72), LayoutOrder = 1, Parent = content }, function()
			setStatus("El idioma ya es Español", C.Muted)
		end, { edge = 6 })
		Theme.stroke(es, C.Yellow, 3)
		drawLanguage(Theme.frame({ BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 16, 0.5, -3), Size = UDim2.fromOffset(42, 42), Parent = es }))
		Theme.button({ Text = "English  ·  próximamente", TextSize = 30, TextColor3 = C.Muted, Size = UDim2.new(1, 0, 0, 72), LayoutOrder = 2, Parent = content }, function()
			setStatus("English llegará próximamente", C.Muted)
		end, { edge = 6 })
		return es
	end,
}

-- Las normas de Roblox sólo permiten mencionar enlaces externos a quien su política se lo admite
-- (AllowedExternalLinkReferences). nil: sin consultar o la consulta falló (se reintenta al abrir).
local discordAllowed: boolean? = nil
local policyPending = false

local function queryPolicy()
	if discordAllowed ~= nil or policyPending then
		return
	end
	policyPending = true
	local answered = false
	task.spawn(function()
		local ok, info = pcall(function()
			return game:GetService("PolicyService"):GetPolicyInfoForPlayerAsync(Players.LocalPlayer)
		end)
		policyPending = false
		if ok and typeof(info) == "table" then
			discordAllowed = table.find(info.AllowedExternalLinkReferences or {}, "Discord") ~= nil
		end
		-- Si la respuesta llegó después de dibujar la ventana, se vuelve a dibujar
		if answered and window and window.name == "Discord" then
			renderWindow("refresh")
		end
	end)
	answered = true
end

WINDOWS.Discord = {
	title = "DISCORD",
	size = Vector2.new(780, 420),
	render = function(content)
		local invite = Config.DiscordInvite or ""
		if invite ~= "" then
			queryPolicy()
		end
		if invite ~= "" and discordAllowed ~= true then
			Theme.label({
				Text = if policyPending then "Cargando..." else "Busca los enlaces sociales en la página del juego.",
				TextWrapped = true,
				Font = Theme.FontBody,
				TextSize = 19,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.fromScale(1, 1),
				Parent = content,
			})
			return nil
		end
		if invite == "" then
			Theme.label({
				Text = "La invitación de Discord aún no está configurada.\nAñade el enlace en <b>Config.DiscordInvite</b> (src/shared/Config.luau) y aparecerá aquí para copiarlo.",
				RichText = true,
				TextWrapped = true,
				Font = Theme.FontBody,
				TextSize = 19,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.fromScale(1, 1),
				Parent = content,
			})
			return nil
		end
		outlined(Theme.label({ Text = "Únete a la comunidad:", TextSize = 30, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 40), Parent = content }), 2)
		local box = Instance.new("TextBox")
		box.Text = invite
		box.TextEditable = false
		box.ClearTextOnFocus = false
		box.Font = Theme.FontBody
		box.TextSize = 22
		box.TextColor3 = WHITE
		box.BackgroundColor3 = C.Background
		box.BorderSizePixel = 0
		box.Position = UDim2.fromOffset(0, 56)
		box.Size = UDim2.new(1, 0, 0, 56)
		box.Parent = content
		Theme.corner(box, 4)
		Theme.stroke(box, C.Metal, 2)
		-- Al enfocarlo se selecciona todo para copiarlo directamente
		box.Focused:Connect(function()
			box.SelectionStart = 1
			box.CursorPosition = #box.Text + 1
		end)
		Theme.label({
			Text = "Haz clic en el enlace y cópialo con Ctrl+C.",
			Font = Theme.FontBody,
			TextSize = 16,
			TextColor3 = C.Muted,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 124),
			Size = UDim2.new(1, 0, 0, 24),
			Parent = content,
		})
		return box
	end,
}

WINDOWS.Credits = {
	title = "CRÉDITOS",
	size = Vector2.new(860, 600),
	render = function(content)
		outlined(Theme.label({ Text = Config.GameTitle, FontFace = Theme.TitleFontFace, TextSize = 64, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 80), Parent = content }), 5)
		Theme.label({
			Text = table.concat({
				"Versión " .. Config.GameVersion,
				"",
				"Juego hecho con <b>Rojo</b> y <b>Luau</b> para Roblox.",
				"Inspirado en <b>MegaBonk</b>.",
				"Código generado con ayuda de IA.",
				"",
				"¡Gracias por jugar!",
			}, "\n"),
			RichText = true,
			TextWrapped = true,
			Font = Theme.FontBody,
			TextSize = 21,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(0, 100),
			Size = UDim2.new(1, 0, 1, -100),
			Parent = content,
		})
		return nil
	end,
}

WINDOWS.Quit = {
	title = "SALIR",
	size = Vector2.new(660, 380),
	render = function(content, footer)
		outlined(Theme.label({ Text = "¿Seguro que quieres salir?", TextSize = 38, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 60), Parent = content }), 2)
		Theme.label({
			Text = "Se cerrará la conexión con el servidor.",
			Font = Theme.FontBody,
			TextSize = 17,
			TextColor3 = C.Muted,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 96),
			Size = UDim2.new(1, 0, 0, 24),
			Parent = content,
		})
		footerButton(footer, "SALIR", function()
			Players.LocalPlayer:Kick("¡Gracias por jugar!")
		end, C.Bad)
		-- Con mando queda seleccionado VOLVER para no salir por accidente.
		return nil
	end,
}

-- Clasificación ---------------------------------------------------------------------------------
-- Pide GetLeaderboard al mostrar el menú, al cambiar de pestaña y cada 60 s mientras está visible.
-- La cuenta atrás hasta el reinicio semanal avanza cada segundo en el cliente.

local board = {
	rows = {} :: { any },
	me = nil :: any,
	message = nil :: TextLabel?,
	note = nil :: TextLabel?,
	countdown = nil :: TextLabel?,
	tabs = {} :: { [string]: TextButton },
	scope = "global",
	request = 0,
	fetchedAt = -math.huge,
	resetsAt = nil :: number?,
}
-- Miniaturas de avatar: la URL, o el momento del último fallo (se reintenta pasado THUMB_RETRY)
local thumbnails: { [number]: string | number } = {}
local THUMB_RETRY = 60

local function formatCountdown(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	return string.format("%d:%02d:%02d", s // 3600, (s // 60) % 60, s % 60)
end

local function updateCountdown()
	if board.countdown then
		board.countdown.Text = if board.resetsAt then formatCountdown(board.resetsAt - os.clock()) else "--:--:--"
	end
end

local function setAvatar(r, userId: number?)
	r.avatar.Image = ""
	r.unknown.Visible = true
	r.userId = userId
	if type(userId) ~= "number" or userId <= 0 then
		return
	end
	local cached = thumbnails[userId]
	if type(cached) == "string" then
		r.avatar.Image = cached
		r.unknown.Visible = false
		return
	elseif type(cached) == "number" and os.clock() - cached < THUMB_RETRY then
		return
	end
	thumbnails[userId] = os.clock() -- evita pedirla dos veces mientras llega
	task.spawn(function()
		local ok, url = pcall(function()
			return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
		end)
		thumbnails[userId] = if ok then url else os.clock()
		if ok and r.userId == userId then
			r.avatar.Image = url
			r.unknown.Visible = false
		end
	end)
end

local function setRow(r, data)
	r.rank.Text = if type(data.rank) == "number" then "#" .. data.rank else "?"
	r.name.Text = tostring(data.name or "?")
	r.kills.Text = Theme.formatCompact(tonumber(data.kills) or 0)
	setAvatar(r, data.userId)
	if r.characterId ~= data.character then
		r.characterId = data.character
		r.character:ClearAllChildren()
		if type(data.character) == "string" and Catalog.Character[data.character] then
			characterIcon(r.character, data.character)
		end
	end
end

local function boardRow(parent: Instance, y: number, isMe: boolean)
	local row = Theme.frame({ BackgroundColor3 = if isMe then C.Me else C.Row, Position = UDim2.new(0, 15, 0, y), Size = UDim2.new(1, -30, 0, 30), Visible = false, Parent = parent })
	if isMe then
		Theme.frame({ BackgroundColor3 = C.MeRank, Size = UDim2.new(0, 68, 1, 0), Parent = row })
	end
	local rank = outlined(Theme.label({ TextScaled = true, Position = UDim2.fromOffset(6, 3), Size = UDim2.new(0, 60, 1, -6), Parent = row }), 1.5)
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = 22
	constraint.Parent = rank
	local avatarBack = Theme.frame({ BackgroundColor3 = Color3.fromRGB(33, 33, 33), Position = UDim2.fromOffset(72, 1), Size = UDim2.fromOffset(28, 28), Parent = row })
	Theme.corner(avatarBack, 3)
	local unknown = Theme.label({ Text = "?", FontFace = SANS, TextSize = 20, TextColor3 = Color3.fromRGB(200, 200, 200), TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = avatarBack })
	local avatar = Instance.new("ImageLabel")
	avatar.BackgroundTransparency = 1
	avatar.Size = UDim2.fromScale(1, 1)
	avatar.Parent = avatarBack
	local name = outlined(Theme.label({ TextSize = 21, Position = UDim2.fromOffset(106, 0), Size = UDim2.new(1, -234, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd, Parent = row }), 1.5)
	local kills = outlined(Theme.label({
		TextSize = 21,
		TextColor3 = C.Yellow,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -40, 0, 0),
		Size = UDim2.new(0, 88, 1, 0),
		Parent = row,
	}), 1.5)
	local character = Theme.frame({ BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0), Size = UDim2.fromOffset(30, 30), Parent = row })
	return { frame = row, rank = rank, avatar = avatar, unknown = unknown, name = name, kills = kills, character = character, characterId = nil, userId = nil }
end

local function boardMessage(text: string)
	for _, r in board.rows do
		r.frame.Visible = false
	end
	board.me.frame.Visible = false
	board.message.Text = text
	board.message.Visible = true
end

local function renderBoard(data)
	board.message.Visible = false
	for i, r in board.rows do
		local entry = data.entries[i]
		r.frame.Visible = entry ~= nil
		if entry then
			setRow(r, entry)
		end
	end
	board.me.frame.Visible = true
	setRow(board.me, data.me)
	if #data.entries == 0 then
		board.message.Text = "Aún no hay marcas esta semana"
		board.message.Visible = true
	end
	board.resetsAt = os.clock() + (tonumber(data.resetsIn) or 0)
	board.note.Visible = data.persistent == false
	updateCountdown()
end

local function fetchBoard()
	board.request += 1
	local request = board.request
	local scope = board.scope
	board.fetchedAt = os.clock()
	task.spawn(function()
		local ok, data = pcall(function()
			return Net.get("GetLeaderboard"):InvokeServer(scope)
		end)
		if request ~= board.request then
			return -- llegó tarde: ya hay otra petición (p. ej. cambio de pestaña)
		end
		if ok and type(data) == "table" and type(data.entries) == "table" and type(data.me) == "table" then
			renderBoard(data)
		else
			boardMessage("Sin conexión")
		end
	end)
end

local function paintTabs()
	for key, tab in board.tabs do
		local active = key == board.scope
		tab.BackgroundColor3 = if active then C.Panel else C.TabOff
		tab.TextColor3 = if active then WHITE else Color3.fromRGB(210, 210, 205)
	end
end

local function setScope(scope: string)
	board.scope = scope
	paintTabs()
	boardMessage("Cargando...")
	fetchBoard()
end

local function buildLeaderboard(parent: Instance)
	local panel, body, header = Theme.panel({
		Name = "Leaderboard",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -22, 1, -65),
		Size = UDim2.fromOffset(408, 529),
		Parent = parent,
	}, "CLASIFICACIÓN", 54)
	assert(header)
	outlined(Theme.label({ Text = "Reset", FontFace = SANS, TextSize = 21, TextColor3 = C.Yellow, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 5), Size = UDim2.fromOffset(160, 22), Parent = header }), 1)
	board.countdown = outlined(Theme.label({ Text = "--:--:--", FontFace = SANS, TextSize = 25, TextColor3 = C.Yellow, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 27), Size = UDim2.fromOffset(160, 26), Parent = header }), 1)

	-- Pestañas: la activa toma el color del cuerpo y queda unida a la tabla.
	local strip = Theme.frame({ BackgroundColor3 = C.TabOff, Position = UDim2.fromOffset(13, 3), Size = UDim2.new(1, -26, 0, 48), Parent = body })
	for i, tab in { { "global", "GLOBAL", 111 }, { "friends", "AMIGOS", 114 } } do
		local b = Instance.new("TextButton")
		b.Name = tab[1]
		b.AutoButtonColor = false
		b.BorderSizePixel = 0
		b.FontFace = Theme.FontFace
		b.TextSize = 24
		b.Text = tab[2]
		b.TextColor3 = WHITE
		b.Position = UDim2.fromOffset(if i == 1 then 0 else 111, 0)
		b.Size = UDim2.new(0, tab[3], 1, 0)
		b.Parent = strip
		Theme.outlined(b, 1.5)
		b.Activated:Connect(function()
			if board.scope ~= tab[1] then
				setScope(tab[1])
			end
		end)
		board.tabs[tab[1]] = b
	end

	local headColor = Color3.fromRGB(215, 215, 208)
	outlined(Theme.label({ Text = "RANGO", TextSize = 22, TextColor3 = headColor, Position = UDim2.fromOffset(21, 63), Size = UDim2.fromOffset(90, 26), Parent = body }), 1.5)
	outlined(Theme.label({ Text = "JUGADOR", TextSize = 22, TextColor3 = headColor, Position = UDim2.fromOffset(121, 63), Size = UDim2.fromOffset(120, 26), Parent = body }), 1.5)
	outlined(Theme.label({ Text = "ELIMINACIONES", TextSize = 13, TextColor3 = headColor, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -55, 0, 63), Size = UDim2.fromOffset(140, 26), Parent = body }), 1)

	for i = 1, 9 do
		board.rows[i] = boardRow(body, 96 + (i - 1) * 34, false)
	end
	board.me = boardRow(body, 96 + 9 * 34, true)
	board.message = outlined(Theme.label({ Text = "", TextSize = 26, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(15, 96), Size = UDim2.new(1, -30, 0, 300), Visible = false, Parent = body }), 1.5)
	board.note = Theme.label({
		Text = "Clasificación temporal: el guardado no está disponible",
		FontFace = SANS,
		TextSize = 13,
		TextColor3 = C.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(15, 433),
		Size = UDim2.new(1, -30, 0, 16),
		Visible = false,
		Parent = body,
	})
	paintTabs()
	boardMessage("Cargando...")
	return panel
end

-- Pantalla principal ----------------------------------------------------------------------------

-- Las 4 condiciones rastreables (no pendientes, sin cumplir) más cercanas a completarse.
local function refreshHome()
	local profile = ClientState.profile
	silverLabel.Text = if profile then Theme.formatThousands(profile.silver or 0) else "—"
	cardsFrame:ClearAllChildren()
	if not profile then
		return
	end
	local missions = {}
	for _, m in missionsOf(profile) do
		if m.state == "progress" and m.target > 0 and m.current < m.target then
			table.insert(missions, m)
		end
	end
	table.sort(missions, function(a, b)
		local fa, fb = fraction(a), fraction(b)
		if fa ~= fb then
			return fa > fb
		end
		return a.name < b.name
	end)
	for i = 1, math.min(4, #missions) do
		missionCard(missions[i], { Position = UDim2.fromOffset(0, (i - 1) * 86), Size = UDim2.fromOffset(434, 74), Parent = cardsFrame }, 195)
	end
end

-- Escala el diseño de 1920×1080 a la ventana: la raíz mide la pantalla en píxeles de diseño, así
-- que lo anclado a esquinas y bordes se reparte bien con cualquier proporción. Se escala por el
-- alto (las medidas salen de la captura según su alto) salvo en pantallas más estrechas que MIN_W.
applyScale = function()
	local size = gui.AbsoluteSize
	if size.X < 2 or size.Y < 2 then
		local camera = workspace.CurrentCamera
		size = if camera then camera.ViewportSize else Vector2.new(DESIGN_W, DESIGN_H)
	end
	local s = math.max(0.2, math.min(size.Y / DESIGN_H, size.X / MIN_W) * (ClientState.settings.uiScale or 1))
	designScale.Scale = s
	root.Size = UDim2.fromOffset(size.X / s, size.Y / s)
	-- Las tarjetas no deben quedar bajo la barra superior de Roblox
	local inset = GuiService:GetGuiInset()
	cardsFrame.Position = UDim2.fromOffset(42, math.max(54, inset.Y / s + 8))
end

local MAIN_BUTTONS = {
	{ text = "JUGAR", width = 213, height = 82, y = 0, size = 46, open = "Characters" },
	{ text = "DESBLOQUEOS", width = 321, height = 75, y = 110, size = 40, open = "Unlocks" },
	{ text = "MISIONES", width = 243, height = 75, y = 211, size = 40, open = "Missions" },
	{ text = "TIENDA", width = 204, height = 73, y = 313, size = 40, open = "Shop" },
}

local SIDE_BUTTONS = {
	{ text = "AJUSTES", icon = drawWrench, width = 182, open = "Settings" },
	{ text = "Español", icon = drawLanguage, width = 172, open = "Language" },
	{ text = "DISCORD", icon = drawDiscord, width = 182, open = "Discord" },
	{ text = "CRÉDITOS", width = 193, open = "Credits" },
	{ text = "SALIR", width = 154, open = "Quit" },
}

function Menu.init()
	gui = ClientState.screen("Menu", 10)
	-- La escala de las opciones se aplica dentro de la escala de diseño (no por duplicado)
	local settingsScale = gui:FindFirstChild("SettingsScale")
	if settingsScale then
		settingsScale:Destroy()
	end

	-- Viñeta verde oscura en la parte baja, sobre la escena 3D
	local vignette = Theme.frame({ Name = "Vignette", BackgroundColor3 = Color3.fromRGB(8, 24, 10), Size = UDim2.fromScale(1, 1), ZIndex = 0, Parent = gui })
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.85),
		NumberSequenceKeypoint.new(0.35, 1),
		NumberSequenceKeypoint.new(0.6, 1),
		NumberSequenceKeypoint.new(1, 0.3),
	})
	gradient.Parent = vignette

	root = Theme.frame({ Name = "Root", BackgroundTransparency = 1, ZIndex = 1, Parent = gui })
	designScale = Instance.new("UIScale")
	designScale.Name = "DesignScale"
	designScale.Parent = root

	home = Theme.frame({ Name = "Home", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = root })
	shade = Theme.frame({ Name = "Shade", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 2, Parent = root })
	windowLayer = Theme.frame({ Name = "Windows", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = root })

	-- Arriba a la izquierda: tarjetas de misión
	cardsFrame = Theme.frame({ Name = "Missions", BackgroundTransparency = 1, Position = UDim2.fromOffset(42, 54), Size = UDim2.fromOffset(434, 332), Parent = home })

	-- Título: letras blancas gruesas con contorno negro y una sombra desplazada
	local titleProps = {
		Text = Config.GameTitle,
		FontFace = Theme.TitleFontFace,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(820, 150),
		Parent = home,
	}
	local shadow = outlined(Theme.label(titleProps), 9)
	shadow.TextColor3 = Color3.new(0, 0, 0)
	shadow.Position = UDim2.new(0.5, 5, 0, 106)
	local title = outlined(Theme.label(titleProps), 9)
	title.Name = "Title"
	title.TextColor3 = WHITE
	title.ZIndex = 2
	title.Position = UDim2.new(0.5, 0, 0, 98)

	-- Centro: cuatro losas apiladas (el grupo sigue al centro vertical de la pantalla)
	local center = Theme.frame({ Name = "Main", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 91), Size = UDim2.fromOffset(330, 386), Parent = home })
	for _, spec in MAIN_BUTTONS do
		local b = Theme.stoneButton({
			Name = spec.open,
			Text = spec.text,
			TextSize = spec.size,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, spec.y),
			Size = UDim2.fromOffset(spec.width, spec.height),
			Parent = center,
		}, function()
			openWindow(spec.open)
		end, focus)
		playButton = playButton or b
	end

	-- Abajo a la izquierda: columna de losas pequeñas (con icono a la izquierda del texto)
	for i, spec in SIDE_BUTTONS do
		local b = Theme.stoneButton({
			Name = spec.open,
			Text = spec.text,
			TextSize = 30,
			TextXAlignment = if spec.icon then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 39, 1, -16 - (#SIDE_BUTTONS - i) * 81.5),
			Size = UDim2.fromOffset(spec.width, 68),
			Parent = home,
		}, function()
			openWindow(spec.open)
		end, focus, { gap = 8 })
		if spec.icon then
			spec.icon(Theme.frame({ BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 11, 0.5, -3), Size = UDim2.fromOffset(38, 38), ZIndex = 4, Parent = b }))
			-- El texto empieza a la derecha del icono
			for _, name in { "TextShadow", "Label" } do
				local text = b:FindFirstChild(name) :: TextLabel
				text.Position += UDim2.fromOffset(58, 0)
				text.Size -= UDim2.fromOffset(62, 0)
			end
		end
	end

	buildLeaderboard(home)

	-- Arriba a la derecha: moneda de plata y cantidad
	local silver = Theme.frame({ Name = "Silver", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -35, 0, 14), Size = UDim2.fromOffset(420, 62), ZIndex = 4, Parent = root })
	local silverRow = Theme.list(silver, Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Right)
	silverRow.VerticalAlignment = Enum.VerticalAlignment.Center
	drawCoin(Theme.frame({ BackgroundTransparency = 1, Size = UDim2.fromOffset(32, 32), LayoutOrder = 1, Parent = silver }))
	-- La cifra se dibuja como el texto de las losas: sombra desplazada, contorno y degradado. La
	-- etiqueta exterior (invisible) da el ancho y guarda el texto; las hijas lo copian.
	silverLabel = Theme.label({ Name = "SilverAmount", Text = "—", TextSize = 52, TextTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 62), LayoutOrder = 2, Parent = silver })
	local silverShadow = Theme.label({ Name = "TextShadow", Text = "—", TextSize = 52, TextColor3 = C.Outline, TextTransparency = 0.25, Position = UDim2.fromOffset(2, 3), Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = silverLabel })
	Theme.outlined(silverShadow, 3, C.Outline, 0.25)
	local silverText = outlined(Theme.label({ Name = "Label", Text = "—", TextSize = 52, TextColor3 = WHITE, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = silverLabel }), 3)
	local silverGradient = Instance.new("UIGradient")
	silverGradient.Rotation = 90
	silverGradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 205))
	silverGradient.Parent = silverText
	silverLabel:GetPropertyChangedSignal("Text"):Connect(function()
		silverShadow.Text = silverLabel.Text
		silverText.Text = silverLabel.Text
	end)

	-- Abajo a la derecha: versión
	outlined(Theme.label({
		Text = "version " .. Config.GameVersion,
		FontFace = SANS,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -10, 1, -12),
		Size = UDim2.fromOffset(300, 22),
		ZIndex = 4,
		Parent = root,
	}), 1.5)

	-- Abajo en el centro: avisos (compras, carga, servidor)
	statusLabel = outlined(Theme.label({
		Text = "",
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -22),
		Size = UDim2.fromOffset(1000, 32),
		ZIndex = 4,
		Parent = root,
	}), 2)

	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyScale)
	applyScale()

	ClientState.onProfile(function(profile)
		applyScale()
		-- El aviso no tapa otro mensaje: tras una compra, el perfil nuevo llega justo después del
		-- resultado y lo borraría al instante.
		if profile.persistent == false and statusLabel.Text == "" then
			setStatus("Aviso: el guardado no está disponible (activa el acceso a la API en Studio).", C.Bad)
		end
		if gui.Enabled then
			refreshHome()
			if window then
				renderWindow("refresh")
			end
		end
	end)

	-- Con mando, B vuelve atrás desde cualquier ventana
	UserInputService.InputBegan:Connect(function(input)
		if gui.Enabled and window and input.KeyCode == Enum.KeyCode.ButtonB then
			goBack()
		end
	end)

	-- Cuenta atrás de la clasificación y refresco cada 60 s mientras el menú está a la vista
	task.spawn(function()
		while true do
			task.wait(1)
			if gui.Enabled then
				updateCountdown()
				local now = os.clock()
				local weekOver = board.resetsAt ~= nil and now >= board.resetsAt + 2 and board.fetchedAt < board.resetsAt
				if home.Visible and (now - board.fetchedAt >= 60 or weekOver) then
					fetchBoard()
				end
			end
		end
	end)

	refreshHome()
	Theme.focus(focus, playButton)
end

function Menu.show(visible: boolean)
	gui.Enabled = visible
	if visible then
		setStatus("")
		closeWindow(true)
		refreshHome()
		fetchBoard()
	else
		closeWindow(false)
		local current = GuiService.SelectedObject
		if current and current:IsDescendantOf(gui) then
			GuiService.SelectedObject = nil
		end
	end
end

function Menu.setStatus(text: string)
	setStatus(text)
end

return Menu
