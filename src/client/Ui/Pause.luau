-- Pausa: reanudar, estadísticas, inventario y abandonar la partida.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Stats = require(ReplicatedStorage.Shared.Stats)
local Net = require(ReplicatedStorage.Shared.Net)
local ClientState = require(script.Parent.Parent.ClientState)
local Theme = require(script.Parent.Theme)
local Spanish = require(ReplicatedStorage.Shared.Data.Spanish)

local Pause = {}

local C = Theme.Colors
local gui: ScreenGui
local body: TextLabel
local getHud: () -> any
local view = "Stats"

local STAT_ORDER = {
	"MaxHealth", "Regen", "Shield", "Overheal", "Armor", "Evasion", "Lifesteal", "Thorns",
	"Damage", "CritChance", "CritDamage", "AttackSpeed", "Quantity", "Bounces",
	"Size", "ProjectileSpeed", "Duration", "Knockback", "EliteDamage",
	"MoveSpeed", "ExtraJumps", "JumpHeight",
	"Luck", "PickupRange", "PickupMult", "XPGain", "GoldGain", "SilverGain",
	"Difficulty", "EliteSpawn", "PowerupMult", "PowerupChance",
}

local function refresh()
	local hud = getHud()
	if not hud then
		body.Text = ""
		return
	end
	local lines = {}
	if view == "Stats" then
		for _, stat in STAT_ORDER do
			local value = hud.stats[stat]
			if value ~= nil then
				table.insert(lines, string.format("%s: <b>%s</b>", Stats.label(stat), Stats.format(stat, value)))
			end
		end
	else
		table.insert(lines, "<b>Armas</b>")
		for _, w in hud.weapons do
			table.insert(lines, string.format("  %s (Nv %d) — %s", w.name, w.level, Catalog.Weapon[w.id].desc))
		end
		table.insert(lines, "<b>Tomos</b>")
		for _, t in hud.tomes do
			table.insert(lines, string.format("  %s (Nv %d) — %s", Spanish.tomeName(t.id, t.name), t.level, Spanish.tomeDescription(t.id, Catalog.Tome[t.id].desc)))
		end
		table.insert(lines, "<b>Objetos</b>")
		for _, item in hud.items do
			table.insert(lines, string.format("  <font color=\"#%s\">%s</font> ×%d — %s", Theme.Rarity[item.rarity]:ToHex(), item.name, item.count, Catalog.Item[item.id].desc))
		end
	end
	body.Text = table.concat(lines, "\n")
end

function Pause.set(open: boolean)
	gui.Enabled = open
	Net.get("Pause"):FireServer(open)
	if open then
		refresh()
	end
end

function Pause.init(hudGetter)
	getHud = hudGetter
	gui = ClientState.screen("Pause", 30)
	gui.Enabled = false
	local shade = Theme.frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.4, Parent = gui })
	local panel = Theme.frame({ Size = UDim2.new(0, 720, 0, 520), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = shade })
	Theme.corner(panel, 12)
	Theme.label({ Text = "PAUSA", TextSize = 30, Size = UDim2.new(1, 0, 0, 44), Position = UDim2.new(0, 16, 0, 8), TextColor3 = C.Accent, Parent = panel })
	local buttons = Theme.frame({ Size = UDim2.new(0, 190, 1, -70), Position = UDim2.new(0, 16, 0, 60), BackgroundTransparency = 1, Parent = panel })
	Theme.list(buttons, nil, 8)
	Theme.button({ Text = "Reanudar", Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = C.Good }, function()
		Pause.set(false)
	end).Parent = buttons
	Theme.button({ Text = "Estadísticas", Size = UDim2.new(1, 0, 0, 42) }, function()
		view = "Stats"
		refresh()
	end).Parent = buttons
	Theme.button({ Text = "Inventario", Size = UDim2.new(1, 0, 0, 42) }, function()
		view = "Inventory"
		refresh()
	end).Parent = buttons
	Theme.button({ Text = "Abandonar partida", Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = C.Bad }, function()
		gui.Enabled = false
		Net.get("QuitRun"):FireServer()
	end).Parent = buttons

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -230, 1, -70)
	scroll.Position = UDim2.new(0, 220, 0, 60)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 6
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = panel
	body = Theme.label({ RichText = true, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Font = Theme.FontBody, TextSize = 14, Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = scroll })

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not ClientState.inRun then
			return
		end
		if ClientState.matches("Pause", input.KeyCode) then
			Pause.set(not gui.Enabled)
		end
	end)
end

function Pause.close()
	if gui.Enabled then
		gui.Enabled = false
	end
end

return Pause
