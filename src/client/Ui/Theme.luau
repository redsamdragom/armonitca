-- Estilo y constructores de interfaz compartidos por todas las pantallas.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage.Shared.Catalog)

local Theme = {}

Theme.Colors = {
	Background = Color3.fromRGB(18, 20, 28),
	Panel = Color3.fromRGB(30, 33, 45),
	PanelLight = Color3.fromRGB(44, 48, 64),
	Accent = Color3.fromRGB(255, 196, 60),
	Text = Color3.fromRGB(240, 240, 245),
	Muted = Color3.fromRGB(160, 165, 180),
	Health = Color3.fromRGB(225, 60, 70),
	Shield = Color3.fromRGB(90, 170, 255),
	XP = Color3.fromRGB(80, 220, 255),
	Gold = Color3.fromRGB(255, 210, 60),
	Silver = Color3.fromRGB(210, 220, 235),
	Good = Color3.fromRGB(90, 210, 110),
	Bad = Color3.fromRGB(230, 80, 80),
}
Theme.Rarity = Catalog.RarityColor
Theme.RarityName = Catalog.RarityName
Theme.Font = Enum.Font.GothamBold
Theme.FontBody = Enum.Font.Gotham

function Theme.corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 8)
	c.Parent = parent
	return c
end

function Theme.stroke(parent: Instance, color: Color3?, thickness: number?)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.new(0, 0, 0)
	s.Thickness = thickness or 1.5
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
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
	l.Font = Theme.Font
	l.TextColor3 = Theme.Colors.Text
	l.TextSize = 16
	l.TextXAlignment = Enum.TextXAlignment.Left
	for k, v in props do
		(l :: any)[k] = v
	end
	return l
end

function Theme.button(props, onClick: (() -> ())?): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = Theme.Colors.PanelLight
	b.BorderSizePixel = 0
	b.Font = Theme.Font
	b.TextColor3 = Theme.Colors.Text
	b.TextSize = 16
	b.AutoButtonColor = true
	for k, v in props do
		(b :: any)[k] = v
	end
	Theme.corner(b, 8)
	if onClick then
		b.Activated:Connect(onClick)
	end
	return b
end

function Theme.bar(parent: Instance, color: Color3, props): (Frame, Frame, TextLabel)
	local back = Theme.frame({ BackgroundColor3 = Color3.fromRGB(15, 15, 20), BackgroundTransparency = 0.2 })
	for k, v in props do
		(back :: any)[k] = v
	end
	Theme.corner(back, 6)
	local fill = Theme.frame({ BackgroundColor3 = color, Size = UDim2.fromScale(0, 1), Parent = back })
	Theme.corner(fill, 6)
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

return Theme
