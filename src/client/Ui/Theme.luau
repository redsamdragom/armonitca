-- Estilo y constructores de interfaz compartidos por todas las pantallas.
-- Estética del juego de referencia: letra gótica gruesa, botones de "losa de piedra" (cara gris,
-- borde superior claro y canto inferior oscuro), paneles oscuros con marco metálico y pernos.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage.Shared.Catalog)

local Theme = {}

Theme.Colors = {
	Background = Color3.fromRGB(20, 26, 23),
	Panel = Color3.fromRGB(38, 46, 41),
	PanelLight = Color3.fromRGB(61, 61, 61), -- cara de las losas (Modal la usa para restaurar botones)
	Accent = Color3.fromRGB(255, 213, 74),
	Text = Color3.fromRGB(245, 245, 240),
	Muted = Color3.fromRGB(165, 170, 165),
	Health = Color3.fromRGB(225, 60, 70),
	Shield = Color3.fromRGB(90, 170, 255),
	XP = Color3.fromRGB(80, 220, 255),
	Gold = Color3.fromRGB(255, 213, 74),
	Silver = Color3.fromRGB(210, 220, 235),
	Good = Color3.fromRGB(62, 209, 62),
	Bad = Color3.fromRGB(230, 80, 80),
	-- Menú principal (medidos sobre la captura de referencia)
	Yellow = Color3.fromRGB(242, 250, 36), -- títulos de misión, cuenta atrás y bajas
	BarGreen = Color3.fromRGB(44, 253, 2),
	BarYellow = Color3.fromRGB(255, 255, 0),
	TextGreen = Color3.fromRGB(160, 245, 145),
	TextYellow = Color3.fromRGB(245, 245, 140),
	Card = Color3.fromRGB(36, 59, 70),
	CardBorder = Color3.fromRGB(224, 225, 215),
	Stone = Color3.fromRGB(61, 61, 61), -- cara de la losa; el canto y el borde claro salen de ella
	Outline = Color3.fromRGB(11, 13, 15),
	Header = Color3.fromRGB(42, 74, 61),
	TabOff = Color3.fromRGB(28, 34, 27),
	Row = Color3.fromRGB(61, 69, 78),
	Me = Color3.fromRGB(48, 91, 122),
	MeRank = Color3.fromRGB(64, 100, 131),
	Metal = Color3.fromRGB(118, 112, 108),
	Bolt = Color3.fromRGB(180, 177, 171),
}
Theme.Rarity = Catalog.RarityColor
Theme.RarityName = Catalog.RarityName
Theme.Font = Enum.Font.GrenzeGotisch
Theme.FontBody = Enum.Font.Merriweather
-- Gótica en negrita para títulos, botones y etiquetas; redondeada muy gruesa para el título del juego.
Theme.FontFace = Font.new("rbxasset://fonts/families/GrenzeGotisch.json", Enum.FontWeight.Bold)
Theme.TitleFontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json")

function Theme.corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 8)
	c.Parent = parent
	return c
end

-- Contorno del borde. Reutiliza el UIStroke que ya tenga el objeto (los botones traen uno) para que
-- nunca haya dos trazos compitiendo.
function Theme.stroke(parent: Instance, color: Color3?, thickness: number?)
	local s = parent:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	s.Color = color or Color3.new(0, 0, 0)
	s.Thickness = thickness or 1.5
	s.Transparency = 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

-- Contorno del texto (letras blancas con borde negro del juego de referencia).
function Theme.outlined(parent: Instance, thickness: number?, color: Color3?, transparency: number?)
	local s = parent:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	s.Color = color or Color3.new(0, 0, 0)
	s.Thickness = thickness or 2
	s.Transparency = transparency or 0
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Parent = parent
	return s
end

function Theme.padding(parent: Instance, px: number)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.Parent = parent
	return p
end

function Theme.list(parent: Instance, direction: Enum.FillDirection?, gap: number?, align: Enum.HorizontalAlignment?)
	local l = Instance.new("UIListLayout")
	l.FillDirection = direction or Enum.FillDirection.Vertical
	l.Padding = UDim.new(0, gap or 6)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	if align then
		l.HorizontalAlignment = align
	end
	l.Parent = parent
	return l
end

function Theme.frame(props): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = Theme.Colors.Panel
	f.BorderSizePixel = 0
	for k, v in props do
		(f :: any)[k] = v
	end
	return f
end

function Theme.label(props): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = Theme.FontFace
	l.TextColor3 = Theme.Colors.Text
	l.TextSize = 16
	l.TextXAlignment = Enum.TextXAlignment.Left
	for k, v in props do
		(l :: any)[k] = v
	end
	return l
end

-- Losa de piedra --------------------------------------------------------------------------------

-- Los adornos (borde claro y canto) son hijos del botón: si alguien le añade un UIPadding después
-- (p. ej. las cartas de Modal), se compensan para que sigan pegados a los bordes reales.
local function fitDecor(button: GuiObject, top: Frame, edge: Frame, radius: number, edgeSize: number)
	local pad = button:FindFirstChildOfClass("UIPadding")
	local l = if pad then pad.PaddingLeft.Offset else 0
	local r = if pad then pad.PaddingRight.Offset else 0
	local t = if pad then pad.PaddingTop.Offset else 0
	local b = if pad then pad.PaddingBottom.Offset else 0
	top.Position = UDim2.new(0, radius - l, 0, -t)
	top.Size = UDim2.new(1, l + r - radius * 2, 0, 2)
	edge.Position = UDim2.new(0, -l, 1, b - edgeSize)
	edge.Size = UDim2.new(1, l + r, 0, edgeSize)
end

local function shade(color: Color3)
	return color:Lerp(Color3.new(0, 0, 0), 0.52), color:Lerp(Color3.new(1, 1, 1), 0.1)
end

-- style (opcional): { edge = alto del canto inferior, radius = radio de las esquinas }
function Theme.button(props, onClick: (() -> ())?, style: { edge: number?, radius: number? }?): TextButton
	local edgeSize = style and style.edge or 5
	local radius = style and style.radius or 5
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = Theme.Colors.Stone
	b.BorderSizePixel = 0
	b.FontFace = Theme.FontFace
	b.TextColor3 = Theme.Colors.Text
	b.TextSize = 18
	b.TextStrokeColor3 = Theme.Colors.Outline
	b.TextStrokeTransparency = 0.35
	b.AutoButtonColor = true
	for k, v in props do
		(b :: any)[k] = v
	end
	Theme.corner(b, radius)
	Theme.stroke(b, Theme.Colors.Outline, 2)

	local edgeColor, topColor = shade(b.BackgroundColor3)
	local top = Theme.frame({ Name = "StoneTop", BackgroundColor3 = topColor, ZIndex = 0, Parent = b })
	local edge = Theme.frame({ Name = "StoneEdge", BackgroundColor3 = edgeColor, ZIndex = 0, Parent = b })
	Theme.corner(edge, radius)
	fitDecor(b, top, edge, radius, edgeSize)
	b.ChildAdded:Connect(function(child)
		if child:IsA("UIPadding") then
			fitDecor(b, top, edge, radius, edgeSize)
		end
	end)
	-- El color de la cara puede cambiar después (selección, modo Banish): el canto lo acompaña.
	b:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
		edge.BackgroundColor3, top.BackgroundColor3 = shade(b.BackgroundColor3)
	end)
	if onClick then
		b.Activated:Connect(onClick)
	end
	return b
end

-- Grupo de foco: el botón con el ratón encima o seleccionado con mando muestra los corchetes.
export type FocusGroup = { buttons: { [GuiObject]: { Frame } }, focused: GuiObject? }

function Theme.focusGroup(): FocusGroup
	return { buttons = {}, focused = nil }
end

function Theme.focus(group: FocusGroup, button: GuiObject?)
	if group.focused and group.buttons[group.focused] then
		for _, bracket in group.buttons[group.focused] do
			bracket.Visible = false
		end
	end
	group.focused = button
	if button and group.buttons[button] then
		for _, bracket in group.buttons[button] do
			bracket.Visible = true
		end
	end
end

local noSelection: Frame? = nil

-- Corchete en L blanco con contorno oscuro. sx/sy: hacia dónde se alejan los brazos del botón.
local function bracket(parent: GuiObject, anchor: Vector2, position: UDim2, sx: number, sy: number): Frame
	local arm, thick = 14, 3
	local holder = Theme.frame({ Name = "Focus", BackgroundTransparency = 1, AnchorPoint = anchor, Position = position, Size = UDim2.fromOffset(arm, arm), Visible = false, ZIndex = 5, Parent = parent })
	-- Brazo vertical en el lado del botón; brazo horizontal en el borde más cercano al botón.
	local vertical = Theme.frame({
		BackgroundColor3 = Color3.new(1, 1, 1),
		Position = UDim2.new(if sx < 0 then 1 else 0, if sx < 0 then -thick else 0, 0, 0),
		Size = UDim2.new(0, thick, 1, 0),
		Parent = holder,
	})
	local horizontal = Theme.frame({
		BackgroundColor3 = Color3.new(1, 1, 1),
		Position = UDim2.new(0, 0, if sy < 0 then 1 else 0, if sy < 0 then -thick else 0),
		Size = UDim2.new(1, 0, 0, thick),
		Parent = holder,
	})
	Theme.stroke(vertical, Theme.Colors.Outline, 1)
	Theme.stroke(horizontal, Theme.Colors.Outline, 1)
	return holder
end

-- Losa de piedra con corchetes de foco (los botones grandes del menú principal).
-- El texto se dibuja en dos etiquetas hijas ("TextShadow" y "Label") centradas en la cara, sin el
-- canto: sombra oscura desplazada, contorno grueso y degradado de blanco a gris claro. Text y
-- TextColor3 del botón se siguen pudiendo cambiar: las etiquetas los copian.
function Theme.stoneButton(props, onClick: (() -> ())?, group: FocusGroup?, style: { edge: number?, radius: number?, gap: number? }?): TextButton
	local edgeSize = style and style.edge or 7
	local b = Theme.button(props, onClick, { edge = edgeSize, radius = style and style.radius or 6 })
	local function textLabel(name: string, color: Color3, offset: number, z: number): TextLabel
		return Theme.label({
			Name = name,
			Text = b.Text,
			FontFace = b.FontFace,
			TextSize = b.TextSize,
			TextColor3 = color,
			TextXAlignment = b.TextXAlignment,
			Position = UDim2.fromOffset(offset, offset + 1),
			Size = UDim2.new(1, 0, 1, -edgeSize),
			ZIndex = z,
			Parent = b,
		})
	end
	local shadow = textLabel("TextShadow", Theme.Colors.Outline, 2, 2)
	shadow.TextTransparency = 0.25
	Theme.outlined(shadow, 2, Theme.Colors.Outline, 0.25)
	local label = textLabel("Label", b.TextColor3, 0, 3)
	Theme.outlined(label, 2, Theme.Colors.Outline)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 205))
	gradient.Parent = label
	b.TextTransparency = 1
	b.TextStrokeTransparency = 1
	b:GetPropertyChangedSignal("Text"):Connect(function()
		shadow.Text = b.Text
		label.Text = b.Text
	end)
	b:GetPropertyChangedSignal("TextColor3"):Connect(function()
		label.TextColor3 = b.TextColor3
	end)
	if not noSelection then
		noSelection = Theme.frame({ BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	end
	b.SelectionImageObject = noSelection
	local gx = style and style.gap or 12
	local gy = gx - 2
	local brackets = {
		bracket(b, Vector2.new(1, 1), UDim2.new(0, -gx, 0, -gy), -1, -1),
		bracket(b, Vector2.new(0, 1), UDim2.new(1, gx, 0, -gy), 1, -1),
		bracket(b, Vector2.new(1, 0), UDim2.new(0, -gx, 1, gy), -1, 1),
		bracket(b, Vector2.new(0, 0), UDim2.new(1, gx, 1, gy), 1, 1),
	}
	if group then
		group.buttons[b] = brackets
		b.MouseEnter:Connect(function()
			Theme.focus(group, b)
		end)
		b.SelectionGained:Connect(function()
			Theme.focus(group, b)
		end)
		b.Destroying:Connect(function()
			group.buttons[b] = nil
			if group.focused == b then
				group.focused = nil
			end
		end)
	end
	return b
end

-- Panel oscuro con marco metálico y pernos. Con título, añade la cabecera verde azulada.
-- Devuelve (panel, cuerpo, cabecera?): el cuerpo ocupa todo lo que queda bajo la cabecera.
local function bolt(parent: GuiObject, anchor: Vector2, position: UDim2)
	local b = Theme.frame({ Name = "Bolt", BackgroundColor3 = Theme.Colors.Bolt, AnchorPoint = anchor, Position = position, Size = UDim2.fromOffset(14, 14), ZIndex = 6, Parent = parent })
	Theme.corner(b, 3)
	Theme.stroke(b, Theme.Colors.Outline, 1)
	local dot = Theme.frame({ BackgroundColor3 = Color3.fromRGB(70, 66, 64), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(6, 6), ZIndex = 6, Parent = b })
	Theme.corner(dot, 3)
	return b
end

function Theme.panel(props, title: string?, headerHeight: number?): (Frame, Frame, Frame?)
	local panel = Theme.frame({ BackgroundColor3 = Theme.Colors.Panel })
	for k, v in props do
		(panel :: any)[k] = v
	end
	Theme.stroke(panel, Theme.Colors.Metal, 4)
	for _, corner in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
		bolt(panel, Vector2.new(0.5, 0.5), UDim2.new(corner.X, if corner.X == 0 then 2 else -2, corner.Y, if corner.Y == 0 then 2 else -2))
	end
	local header: Frame? = nil
	local top = 0
	if title then
		local h = headerHeight or 58
		header = Theme.frame({ Name = "Header", BackgroundColor3 = Theme.Colors.Header, Size = UDim2.new(1, 0, 0, h), Parent = panel })
		local text = Theme.label({ Name = "Title", Text = title, TextSize = 30, Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -32, 1, 0), Parent = header })
		Theme.outlined(text, 2)
		Theme.frame({ Name = "Separator", BackgroundColor3 = Theme.Colors.Metal, Position = UDim2.new(0, 0, 0, h), Size = UDim2.new(1, 0, 0, 4), Parent = panel })
		bolt(panel, Vector2.new(0.5, 0.5), UDim2.new(0, 2, 0, h + 2))
		bolt(panel, Vector2.new(0.5, 0.5), UDim2.new(1, -2, 0, h + 2))
		top = h + 4
	end
	local body = Theme.frame({ Name = "Body", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, top), Size = UDim2.new(1, 0, 1, -top), Parent = panel })
	return panel, body, header
end

function Theme.bar(parent: Instance, color: Color3, props): (Frame, Frame, TextLabel)
	local back = Theme.frame({ BackgroundColor3 = Color3.fromRGB(8, 10, 10), BackgroundTransparency = 0.15 })
	for k, v in props do
		(back :: any)[k] = v
	end
	Theme.corner(back, 3)
	local fill = Theme.frame({ BackgroundColor3 = color, Size = UDim2.fromScale(0, 1), Parent = back })
	Theme.corner(fill, 3)
	local text = Theme.label({
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 14,
		TextStrokeTransparency = 0.4,
		ZIndex = 3,
		Parent = back,
	})
	back.Parent = parent
	return back, fill, text
end

function Theme.formatTime(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d", s // 60, s % 60)
end

function Theme.formatNumber(n: number): string
	if n >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	elseif n >= 1e4 then
		return string.format("%.1fk", n / 1e3)
	end
	return tostring(math.floor(n))
end

-- 1687 → "1,687" (separador de miles con coma, como el contador de plata de la referencia)
function Theme.formatThousands(n: number): string
	local digits = string.format("%d", math.floor(math.abs(n)))
	local groups = {}
	for i = #digits, 1, -3 do
		table.insert(groups, 1, string.sub(digits, math.max(1, i - 2), i))
	end
	return (if n < 0 then "-" else "") .. table.concat(groups, ",")
end

-- 1330000 → "1.33M", 989210 → "989.21K", 987000 → "987K", 35 → "35". Trunca a dos decimales con
-- aritmética entera para no mostrar más de lo conseguido.
function Theme.formatCompact(n: number): string
	local value = math.floor(math.max(0, n))
	for _, unit in { { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do
		if value >= unit[1] then
			local hundredths = value // (unit[1] / 100)
			local whole, fraction = hundredths // 100, hundredths % 100
			if fraction == 0 then
				return string.format("%d%s", whole, unit[2])
			end
			local decimals = string.gsub(string.format("%02d", fraction), "0$", "")
			return string.format("%d.%s%s", whole, decimals, unit[2])
		end
	end
	return string.format("%d", value)
end

return Theme
