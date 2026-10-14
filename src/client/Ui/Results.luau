-- Pantalla de resultados: tiempo, bajas, nivel, personaje, mapa y tier, jefes, plata, daño por
-- fuente, motivo de finalización y contenido recién disponible.

local ClientState = require(script.Parent.Parent.ClientState)
local Theme = require(script.Parent.Theme)

local Results = {}

local C = Theme.Colors
local gui: ScreenGui
local body: TextLabel
local onBack: () -> ()

function Results.init(backCallback)
	onBack = backCallback
	gui = ClientState.screen("Results", 40)
	gui.Enabled = false
	local shade = Theme.frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Background, BackgroundTransparency = 0.1, Parent = gui })
	local panel = Theme.frame({ Size = UDim2.new(0, 760, 0, 560), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = shade })
	Theme.corner(panel, 12)
	Theme.padding(panel, 16)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, 0, 1, -56)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 6
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = panel
	body = Theme.label({ RichText = true, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Font = Theme.FontBody, TextSize = 16, Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = scroll })
	Theme.button({ Text = "Volver al menú", Size = UDim2.new(0, 240, 0, 44), Position = UDim2.new(0.5, -120, 1, -44), BackgroundColor3 = C.Accent, TextColor3 = C.Background, TextStrokeTransparency = 1, Parent = panel }, function()
		gui.Enabled = false
		onBack()
	end)
end

function Results.show(data)
	local lines = {
		string.format("<b><font size=\"32\" color=\"#%s\">%s</font></b>", (if data.victory then C.Good else C.Bad):ToHex(), if data.victory then "¡VICTORIA!" else "FIN DE LA PARTIDA"),
		string.format("<font color=\"#%s\">%s</font>", C.Muted:ToHex(), data.reason),
		"",
		string.format("Personaje: <b>%s</b> · Mapa: <b>%s Tier %d</b> · Etapa %d", data.character, data.map, data.tier, data.stage),
		string.format("Tiempo: <b>%s</b>%s · Nivel: <b>%d</b> · Bajas: <b>%s</b>", Theme.formatTime(data.time), if data.swarmTime > 0 then string.format(" (Final Swarm %s)", Theme.formatTime(data.swarmTime)) else "", data.level, Theme.formatNumber(data.kills)),
		string.format("Jefes derrotados: <b>%d</b> · Oro: <b>%s</b>", data.bosses, Theme.formatNumber(data.gold)),
		string.format("<font color=\"#%s\">Plata ganada: <b>%d</b></font>", C.Silver:ToHex(), data.silver),
		"",
		"<b>Daño por fuente</b>",
	}
	for i, entry in data.damage do
		if i > 15 then
			break
		end
		table.insert(lines, string.format("  %s: %s", entry.name, Theme.formatNumber(entry.amount)))
	end
	if #data.unlocked > 0 then
		table.insert(lines, "")
		table.insert(lines, string.format("<b><font color=\"#%s\">¡Nuevo contenido disponible para comprar!</font></b>", C.Accent:ToHex()))
		for _, name in data.unlocked do
			table.insert(lines, "  • " .. name)
		end
	end
	body.Text = table.concat(lines, "\n")
	gui.Enabled = true
end

return Results
