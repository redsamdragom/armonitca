-- HUD de combate: vida y escudo, experiencia y nivel, reloj de la fase, oro y bajas, armas y
-- tomos con nivel, objetos, barra de jefe, avisos, minimapa y mapa completo (mismos datos).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Net = require(ReplicatedStorage.Shared.Net)
local ClientState = require(script.Parent.Parent.ClientState)
local Theme = require(script.Parent.Theme)

local Hud = {}

local C = Theme.Colors
local gui: ScreenGui
local refs = {}
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

local function drawMap(frame: Frame, dotSize: number)
	for _, child in frame:GetChildren() do
		if child.Name == "Dot" then
			child:Destroy()
		end
	end
	local function place(x: number, z: number, color: Color3, size: number)
		local dot = Theme.frame({
			Name = "Dot",
			Size = UDim2.fromOffset(size, size),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 + x / (halfSize * 2), 0.5 + z / (halfSize * 2)),
			BackgroundColor3 = color,
			Parent = frame,
		})
		Theme.corner(dot, size)
		return dot
	end
	for _, m in markers do
		place(m.x, m.z, MARKER_COLOR[m.kind] or Color3.new(1, 1, 1), dotSize)
	end
	return place
end

local function buildMinimap(parent)
	local mini = Theme.frame({ Size = UDim2.fromOffset(170, 170), Position = UDim2.new(1, -184, 0, 40), BackgroundColor3 = Color3.fromRGB(20, 30, 25), BackgroundTransparency = 0.25, ClipsDescendants = true, Parent = parent })
	Theme.corner(mini, 10)
	Theme.stroke(mini, Color3.fromRGB(0, 0, 0), 2)
	local arrow = Theme.label({ Name = "Player", Text = "▲", TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(16, 16), TextColor3 = Color3.new(1, 1, 1), ZIndex = 5, Parent = mini })
	refs.mini, refs.miniArrow = mini, arrow

	local full = Theme.frame({ Size = UDim2.fromOffset(560, 560), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(20, 30, 25), BackgroundTransparency = 0.1, Visible = false, ZIndex = 20, Parent = parent })
	Theme.corner(full, 12)
	local fullArrow = Theme.label({ Name = "Player", Text = "▲", TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(22, 22), ZIndex = 25, Parent = full })
	local legend = Theme.frame({ Size = UDim2.new(0, 170, 1, 0), Position = UDim2.new(1, 8, 0, 0), BackgroundTransparency = 0.2, BackgroundColor3 = C.Panel, Parent = full })
	Theme.corner(legend, 8)
	Theme.padding(legend, 8)
	Theme.list(legend, nil, 2)
	for kind, name in MARKER_NAMES do
		Theme.label({ Text = "● " .. name, TextSize = 13, TextColor3 = MARKER_COLOR[kind], Size = UDim2.new(1, 0, 0, 18), Parent = legend })
	end
	refs.full, refs.fullArrow = full, fullArrow
end

local function redrawMarkers()
	if refs.mini then
		drawMap(refs.mini, 6)
		drawMap(refs.full, 10)
	end
end

function Hud.init()
	gui = ClientState.screen("Hud", 5)
	gui.Enabled = false
	local root = Theme.frame({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })

	-- XP en la parte superior
	local _, xpFill, xpText = Theme.bar(root, C.XP, { Size = UDim2.new(1, -24, 0, 16), Position = UDim2.new(0, 12, 0, 8) })
	refs.xpFill, refs.xpText = xpFill, xpText

	-- Vida y escudo
	local hpBack, hpFill, hpText = Theme.bar(root, C.Health, { Size = UDim2.new(0, 300, 0, 24), Position = UDim2.new(0, 12, 0, 32) })
	refs.hpFill, refs.hpText = hpFill, hpText
	local _, shFill, shText = Theme.bar(root, C.Shield, { Size = UDim2.new(0, 300, 0, 12), Position = UDim2.new(0, 12, 0, 60) })
	refs.shFill, refs.shText = shFill, shText
	refs.hpBack = hpBack

	refs.info = Theme.label({ Text = "", TextSize = 16, RichText = true, Size = UDim2.new(0, 320, 0, 64), Position = UDim2.new(0, 12, 0, 78), TextYAlignment = Enum.TextYAlignment.Top, TextStrokeTransparency = 0.5, Parent = root })

	-- Reloj
	refs.clockLabel = Theme.label({ Text = "", TextSize = 13, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(0, 300, 0, 16), Position = UDim2.new(0.5, 0, 0, 30), TextStrokeTransparency = 0.5, Parent = root })
	refs.clock = Theme.label({ Text = "10:00", TextSize = 34, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(0, 300, 0, 40), Position = UDim2.new(0.5, 0, 0, 44), TextStrokeTransparency = 0.3, Parent = root })

	-- Jefe
	local bossBack, bossFill, bossText = Theme.bar(root, Color3.fromRGB(200, 30, 50), { Size = UDim2.new(0.5, 0, 0, 22), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 90), Visible = false })
	refs.bossBack, refs.bossFill, refs.bossText = bossBack, bossFill, bossText

	-- Armas y tomos
	refs.loadout = Theme.label({ Text = "", RichText = true, TextSize = 14, Size = UDim2.new(0, 360, 0, 200), Position = UDim2.new(0, 12, 1, -212), TextYAlignment = Enum.TextYAlignment.Bottom, TextStrokeTransparency = 0.4, Parent = root })
	-- Objetos
	local items = Theme.frame({ Size = UDim2.new(0, 420, 0, 120), Position = UDim2.new(1, -432, 1, -132), BackgroundTransparency = 1, Parent = root })
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(40, 40)
	grid.CellPadding = UDim2.fromOffset(4, 4)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Right
	grid.VerticalAlignment = Enum.VerticalAlignment.Bottom
	grid.SortOrder = Enum.SortOrder.Name
	grid.Parent = items
	refs.items = items

	-- Avisos
	refs.toasts = Theme.frame({ Size = UDim2.new(0, 500, 0, 140), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 130), BackgroundTransparency = 1, Parent = root })
	Theme.list(refs.toasts, nil, 4, Enum.HorizontalAlignment.Center)

	Theme.label({ Text = "[P] Pausa · [M] Mapa · [E] Interactuar", TextSize = 12, TextColor3 = C.Muted, Size = UDim2.new(0, 300, 0, 16), Position = UDim2.new(1, -312, 0, 216), TextXAlignment = Enum.TextXAlignment.Right, Parent = root })

	buildMinimap(root)

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

	RunService.RenderStepped:Connect(function()
		if not gui.Enabled then
			return
		end
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end
		local pos = root.Position
		local look = workspace.CurrentCamera.CFrame.LookVector
		local rotation = math.deg(math.atan2(look.X, -look.Z))
		local u, v = 0.5 + pos.X / (halfSize * 2), 0.5 + pos.Z / (halfSize * 2)
		refs.fullArrow.Position = UDim2.fromScale(u, v)
		refs.fullArrow.Rotation = rotation
		-- Minimapa centrado en el jugador (zoom 3×)
		local zoom = 3
		refs.miniArrow.Position = UDim2.fromScale(0.5, 0.5)
		refs.miniArrow.Rotation = rotation
		for _, dot in refs.mini:GetChildren() do
			if dot.Name == "Dot" then
				local m = dot:GetAttribute("x")
				if m == nil then
					local du = dot.Position.X.Scale - 0.5
					local dv = dot.Position.Y.Scale - 0.5
					dot:SetAttribute("x", du)
					dot:SetAttribute("z", dv)
				end
				local du = dot:GetAttribute("x") :: number
				local dv = dot:GetAttribute("z") :: number
				dot.Position = UDim2.fromScale(0.5 + (du - (u - 0.5)) * zoom, 0.5 + (dv - (v - 0.5)) * zoom)
			end
		end
	end)
end

function Hud.show(visible: boolean)
	gui.Enabled = visible
	if not visible then
		refs.full.Visible = false
	end
end

function Hud.toast(text: string)
	local label = Theme.label({
		Text = text,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 26),
		TextStrokeTransparency = 0.3,
		TextColor3 = C.Accent,
		Parent = refs.toasts,
	})
	task.delay(3, function()
		label:Destroy()
	end)
end

local function itemCell(item)
	local cell = Theme.frame({ Name = item.name, BackgroundColor3 = C.Panel, BackgroundTransparency = 0.15 })
	Theme.corner(cell, 6)
	Theme.stroke(cell, Theme.Rarity[item.rarity], 2)
	local initials = string.upper(string.sub(item.name, 1, 2))
	Theme.label({ Text = initials, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), TextColor3 = Theme.Rarity[item.rarity], Parent = cell })
	if item.count > 1 then
		Theme.label({ Text = "×" .. item.count, TextSize = 11, Size = UDim2.new(1, -2, 0, 12), Position = UDim2.new(0, 0, 1, -12), TextXAlignment = Enum.TextXAlignment.Right, Parent = cell })
	end
	return cell
end

function Hud.update(data)
	lastHud = data
	local overheal = math.max(0, data.hp - data.maxHp)
	refs.hpFill.Size = UDim2.fromScale(math.clamp(data.hp / data.maxHp, 0, 1), 1)
	refs.hpText.Text = string.format("%d / %d%s", math.ceil(data.hp), math.ceil(data.maxHp), if overheal > 0 then string.format(" (+%d)", overheal) else "")
	refs.shFill.Parent.Visible = data.maxShield > 0
	if data.maxShield > 0 then
		refs.shFill.Size = UDim2.fromScale(math.clamp(data.shield / data.maxShield, 0, 1), 1)
		refs.shText.Text = string.format("Escudo %d", math.ceil(data.shield))
	end
	refs.xpFill.Size = UDim2.fromScale(math.clamp(data.xp / data.xpToNext, 0, 1), 1)
	refs.xpText.Text = string.format("Nivel %d", data.level)
	refs.info.Text = string.format(
		"<font color=\"#%s\">Oro: %s</font>   Bajas: %s\nDificultad: %d%%%s",
		C.Gold:ToHex(),
		Theme.formatNumber(data.gold),
		Theme.formatNumber(data.kills),
		math.floor(data.difficulty * 100),
		if data.momentum then string.format("   Impulso: %d%%", math.floor(data.momentum * 100)) else ""
	)
	if data.swarm then
		refs.clockLabel.Text = string.format("FINAL SWARM · %s %d · Etapa %d/%d", data.mapName, data.tier, data.stage, data.stages)
		refs.clock.Text = Theme.formatTime(data.swarmTime)
		refs.clock.TextColor3 = C.Bad
	else
		refs.clockLabel.Text = string.format("Cuenta atrás de etapa · %s Tier %d · Etapa %d/%d", data.mapName, data.tier, data.stage, data.stages)
		refs.clock.Text = Theme.formatTime(data.stageTime)
		refs.clock.TextColor3 = C.Text
	end
	refs.bossBack.Visible = data.boss ~= nil
	if data.boss then
		refs.bossFill.Size = UDim2.fromScale(math.clamp(data.boss.hp / data.boss.max, 0, 1), 1)
		refs.bossText.Text = string.format("%s  %s / %s", data.boss.name, Theme.formatNumber(data.boss.hp), Theme.formatNumber(data.boss.max))
	end
	local lines = { "<b>Armas</b>" }
	for _, w in data.weapons do
		table.insert(lines, string.format("  %s  <font color=\"#%s\">Nv %d</font>", w.name, C.Accent:ToHex(), w.level))
	end
	table.insert(lines, "<b>Tomos</b>")
	for _, t in data.tomes do
		table.insert(lines, string.format("  %s  <font color=\"#%s\">Nv %d</font>", t.name, C.XP:ToHex(), t.level))
	end
	refs.loadout.Text = table.concat(lines, "\n")

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
