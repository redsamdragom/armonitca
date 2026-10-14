--!nolint
-- Prueba de humo del cliente con Lune:  lune run tests/client
-- Ejecuta a la vez el servidor real (Main.server) y el cliente real (Main.client) en el entorno
-- simulado, con las propiedades de las instancias validadas como en Roblox, y comprueba que:
--   * se crean las pantallas, la escena del menú toma la cámara y llegan el perfil y la clasificación
--   * todos los botones del menú principal y de cada ventana responden (foco, compras, pestañas,
--     opciones, teclas, idioma, Discord, créditos y salir)
--   * una partida real arranca desde el menú y el HUD, el minimapa y los números de daño la siguen
--   * las ventanas de elección (subida de nivel, objeto, santuario, microondas, vendedor), los
--     avisos, la pausa y los resultados funcionan, y se vuelve al menú
--   * ningún hilo del cliente ni del servidor lanza errores y los mensajes son serializables

local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Harness = require("./Harness")

local Enum = roblox.Enum
local V2 = roblox.Vector2

Harness.build(process.cwd)
local player = Harness.setupClient(4242)
local req = Harness.require
local Catalog = req(Harness.shared.Catalog)
local Config = req(Harness.shared.Config)
local services = Harness.services
local RunService = services.RunService
local UserInputService = services.UserInputService
local GuiService = services.GuiService

local failures = 0
local function check(ok, message)
	if ok then
		print("  ok   " .. message)
	else
		failures += 1
		print("  FAIL " .. message)
	end
end

-- Ejecuta una acción del jugador; un error cuenta como fallo y la prueba sigue.
local function attempt(label, fn, ...)
	local ok, err = xpcall(fn, debug.traceback, ...)
	if not ok then
		Harness.onError(label .. ": " .. tostring(err))
	end
	return ok
end

-- Avanza el juego: fotogramas de render y de física, y el planificador de tareas.
local DT = 1 / 30
local function frames(seconds)
	local t = 0
	while t < seconds - 1e-9 do
		t += DT
		attempt("RenderStepped", function()
			RunService.RenderStepped:Fire(DT)
		end)
		attempt("Heartbeat", function()
			RunService.Heartbeat:Fire(DT)
		end)
		Harness.advance(DT)
	end
end

local function noNewErrors(before, message)
	check(#Harness.errors == before, message .. string.format(" (%d errores)", #Harness.errors - before))
end

local function find(parent, predicate)
	for _, d in parent:GetDescendants() do
		if predicate(d) then
			return d
		end
	end
	return nil
end

local function texts(parent, visibleOnly)
	local list = {}
	for _, d in parent:GetDescendants() do
		if d:IsA("TextLabel") and d.Text ~= "" and (not visibleOnly or d.Visible) then
			table.insert(list, d.Text)
		end
	end
	return list
end

local function hasText(parent, text)
	return find(parent, function(d)
		return (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text == text
	end) ~= nil
end

local function key(code, inputType)
	return { KeyCode = code, UserInputType = inputType or Enum.UserInputType.Keyboard, UserInputState = Enum.UserInputState.Begin }
end

local function press(code, inputType)
	attempt("InputBegan " .. tostring(code), function()
		UserInputService.InputBegan:Fire(key(code, inputType), false)
	end)
	attempt("InputEnded " .. tostring(code), function()
		UserInputService.InputEnded:Fire(key(code, inputType), false)
	end)
end

-- Pulsa un botón como el jugador: pasa el ratón por encima, lo selecciona y lo activa.
local function click(button, label)
	return attempt("botón " .. (label or button.Name), function()
		button.MouseEnter:Fire()
		button.SelectionGained:Fire()
		button.Activated:Fire()
		button.MouseLeave:Fire()
	end)
end

local function brackets(button)
	local visible = 0
	for _, child in button:GetChildren() do
		if child.Name == "Focus" and child.Visible then
			visible += 1
		end
	end
	return visible
end

-- Textos por defecto de Roblox ("Label", "Button") que quedarían a la vista en una pantalla activa.
local function placeholders(gui)
	local found = {}
	if not gui.Enabled then
		return found
	end
	for _, d in gui:GetDescendants() do
		if (d:IsA("TextLabel") and d.Text == "Label") or (d:IsA("TextButton") and d.Text == "Button") or (d:IsA("TextBox") and d.Text == "TextBox") then
			local visible = d.TextTransparency < 1
			local p = d
			while visible and p and p ~= gui do
				if p:IsA("GuiObject") and not p.Visible then
					visible = false
				end
				p = p.Parent
			end
			if visible then
				table.insert(found, d:GetFullName())
			end
		end
	end
	return found
end

local function noPlaceholders(gui, message)
	local found = placeholders(gui)
	check(#found == 0, message .. (if #found > 0 then ": " .. table.concat(found, ", ") else ""))
end

print("== Arnés")
do
	local Instance = Harness.Instance
	local frame = Instance.new("Frame")
	check(not pcall(function()
		frame.Bogus = 1
	end), "propiedad inexistente: error")
	check(not pcall(function()
		frame.Size = 5
	end), "tipo incorrecto: error")
	check(not pcall(function()
		frame.AbsoluteSize = roblox.Vector2.zero
	end), "propiedad de sólo lectura: error")
	check(not pcall(function()
		return frame.Bogus
	end), "lectura de un miembro inexistente: error")
	local label = Instance.new("TextLabel")
	check(label.TextXAlignment == Enum.TextXAlignment.Center and label.Text == "Label", "valores por defecto de Roblox")
	label:Destroy()
	check(not pcall(function()
		label.Parent = frame
	end), "Parent bloqueado tras Destroy")
	check(not pcall(function()
		Instance.new("GuiObject")
	end), "clase no creable: error")
end

-- Servidor ---------------------------------------------------------------------------------------

print("== Arranque")
local errorsAtStart = #Harness.errors
Harness.run(Harness.server.Main)
Harness.advance(0)

-- Perfil con progreso variado: condiciones cumplidas (listas para comprar), cerca de cumplirse
-- (barras verdes y amarillas) y sin empezar; plata para algunas compras y no para todas.
local SaveService = req(Harness.server.Save.SaveService)
local profile = SaveService.get(player)
check(profile ~= nil, "el servidor carga el perfil del jugador")
profile.data.Silver = 1687
local contentKeys = {}
for contentKey in Catalog.Content do
	table.insert(contentKeys, contentKey)
end
table.sort(contentKeys)
local FRACTIONS = { 1, 1, 0.92, 0.8, 0.5, 0.1, 0 }
local n = 0
for _, contentKey in contentKeys do
	local unlock = Catalog.Content[contentKey].unlock
	if (unlock.kind == "counter" and unlock.key ~= "quests") or unlock.kind == "max" then
		n += 1
		local store = if unlock.kind == "max" then profile.data.Max else profile.data.Counters
		store[unlock.key] = math.max(store[unlock.key] or 0, math.floor(unlock.target * FRACTIONS[(n - 1) % #FRACTIONS + 1]))
	end
end
profile.data.Ranks.Fox = { runs = 4, minutes = 30, rank = 10 }
profile.data.Records.runs = 4
profile.data.Records.bestKills = 1337
profile:invalidate()

-- Clasificación de la semana: once rivales y el jugador local, con un rival sin miniatura.
local Leaderboard = req(Harness.server.Save.Leaderboard)
local RIVALS = { 1330000, 989210, 987000, 500000, 120500, 99999, 4200, 1000, 512, 80, 40 }
for i, kills in RIVALS do
	local rival = Harness.new("Player", { Name = "Rival" .. i, UserId = 9000 + i })
	Leaderboard.submit(rival, kills, if i % 3 == 0 then nil else Catalog.Characters[i].id)
end
Harness.thumbnailFailures[9003] = true
Leaderboard.submit(player, 35, "Fox")

local Net = req(Harness.shared.Net)
local boardRequests = {}
local serverBoard = Net.get("GetLeaderboard").OnServerInvoke
Net.get("GetLeaderboard").OnServerInvoke = function(who, scope)
	table.insert(boardRequests, scope)
	return serverBoard(who, scope)
end
local modalChoices = {}
Net.get("ModalChoice").OnServerEvent:Connect(function(_, action, index)
	table.insert(modalChoices, { action = action, index = index })
end)

-- Cliente ----------------------------------------------------------------------------------------

Harness.run(Harness.client.Main)
frames(1)
noNewErrors(errorsAtStart, "servidor y cliente arrancan sin errores")

local ClientState = req(Harness.client.ClientState)
local playerGui = player.PlayerGui
for _, name in { "Menu", "Hud", "Modal", "Pause", "Results" } do
	check(playerGui:FindFirstChild(name) ~= nil, "pantalla " .. name .. " creada")
end
local menuGui = playerGui.Menu
check(menuGui.Enabled == true and playerGui.Hud.Enabled == false, "el menú se muestra y el HUD no")
check(Harness.coreGui.Health == false and Harness.coreGui.Backpack == false, "vida y mochila de Roblox ocultas")
local camera = Harness.workspace.CurrentCamera
check(Harness.workspace:FindFirstChild("MenuScene") ~= nil, "escena del menú en workspace")
check(camera.CameraType == Enum.CameraType.Scriptable, "la escena del menú toma la cámara")
check(services.Lighting:FindFirstChildWhichIsA("DepthOfFieldEffect") ~= nil, "desenfoque activo con el menú")
local sceneY = camera.CFrame.Position.Y
check(sceneY > 900, string.format("cámara en la escena lejos del mapa (y = %.0f)", sceneY))
check(ClientState.profile ~= nil and ClientState.profile.silver == 1687, "el cliente recibe el perfil real del servidor")

print("== Pantalla principal")
local root = menuGui.Root
local home = root.Home
check(root.DesignScale.Scale == 1, "escala 1 a 1920×1080")
check(hasText(root.Silver, "1,687"), "plata con separador de miles")
local cards = home.Missions:GetChildren()
check(#cards == 4, string.format("4 tarjetas de misión (hay %d)", #cards))
for _, card in cards do
	print("     tarjeta: " .. table.concat(texts(card), " | "))
end
check(hasText(home, Config.GameTitle), "título del juego")
check(hasText(root, "version " .. Config.GameVersion), "versión abajo a la derecha")
local playButton = home.Main.Characters
check(brackets(playButton) == 4, "JUGAR enfocado por defecto (corchetes visibles)")
local Theme = req(Harness.client.Ui.Theme)
local shopButton = home.Main.Shop
check(playButton.BackgroundColor3 == Theme.Colors.StoneFocus and shopButton.BackgroundColor3 == Theme.Colors.Stone, "la losa enfocada es más oscura que las demás")
check(playButton.AutoButtonColor == false, "las losas no usan el tinte automático de Roblox")
shopButton.MouseEnter:Fire()
check(shopButton.BackgroundColor3 == Theme.Colors.StoneFocus and playButton.BackgroundColor3 == Theme.Colors.Stone and brackets(shopButton) == 4, "el foco pasa a la losa con el ratón encima")
playButton.MouseEnter:Fire()
check(Theme.formatCompact(1100000) == "1.10M" and Theme.formatCompact(927020) == "927.02K" and Theme.formatCompact(987000) == "987K", "formato compacto con dos decimales")
noPlaceholders(menuGui, "sin textos por defecto de Roblox en el menú")
check(hasText(root, "Aviso: el guardado no está disponible (activa el acceso a la API en Studio)."), "aviso de guardado no disponible")

print("== Clasificación")
local board = home.Leaderboard
local boardTexts = texts(board, true)
print("     " .. table.concat(boardTexts, " · "))
check(boardRequests[1] == "global", "pide la clasificación global al mostrar el menú")
for _, expected in { "#1", "1.33M", "989.21K", "987K", "#12", "35" } do
	check(table.find(boardTexts, expected) ~= nil, "la clasificación muestra " .. expected)
end
local countdown = find(board, function(d)
	return d:IsA("TextLabel") and string.match(d.Text, "^%d+:%d%d:%d%d$") ~= nil
end)
check(countdown ~= nil, "cuenta atrás h:mm:ss hasta el reinicio")
local avatars, unknowns = 0, 0
for _, d in board:GetDescendants() do
	if d:IsA("ImageLabel") and string.find(d.Image, "rbxthumb://", 1, true) then
		avatars += 1
	end
	if d:IsA("TextLabel") and d.Text == "?" and d.Visible and d.Parent.Parent.Visible then
		unknowns += 1
	end
end
check(avatars == 9, string.format("miniaturas de los avatares (%d)", avatars))
check(unknowns >= 1, "\"?\" en la miniatura que no carga")
local before = #Harness.errors
local friendsTab = find(board, function(d)
	return d:IsA("TextButton") and d.Name == "friends"
end)
local globalTab = find(board, function(d)
	return d:IsA("TextButton") and d.Name == "global"
end)
click(friendsTab)
frames(0.2)
check(boardRequests[#boardRequests] == "friends", "la pestaña AMIGOS pide scope friends")
check(friendsTab.BackgroundColor3 ~= globalTab.BackgroundColor3, "pestaña activa resaltada")
Net.get("GetLeaderboard").OnServerInvoke = function()
	error("servidor caído")
end
click(globalTab)
frames(0.2)
check(table.find(texts(board, true), "Sin conexión") ~= nil, "\"Sin conexión\" si la petición falla")
Net.get("GetLeaderboard").OnServerInvoke = function(who, scope)
	table.insert(boardRequests, scope)
	return serverBoard(who, scope)
end
local requestsBefore = #boardRequests
Harness.advance(61)
frames(0.2)
check(#boardRequests > requestsBefore, "se refresca sola cada 60 s")
noNewErrors(before, "pestañas y refresco sin errores")

print("== Botones del menú principal")
before = #Harness.errors
for _, button in home.Main:GetChildren() do
	if button:IsA("TextButton") then
		button.MouseEnter:Fire()
		check(brackets(button) == 4 and brackets(playButton) == (if button == playButton then 4 else 0), "foco con el ratón en " .. button.Name)
	end
end
for _, button in home:GetChildren() do
	if button:IsA("TextButton") then
		button.SelectionGained:Fire()
		check(brackets(button) == 4, "foco con el mando en " .. button.Name)
	end
end
noNewErrors(before, "foco de los botones sin errores")

-- Ventanas --------------------------------------------------------------------------------------

local windows = root.Windows

local function currentWindow()
	local w = windows:GetChildren()[1]
	return w and w.Name
end

local function windowButton(predicate)
	return find(windows, function(d)
		return d:IsA("GuiButton") and predicate(d)
	end)
end

local function byText(text)
	return windowButton(function(d)
		return d.Text == text
	end)
end

local function openHome(name)
	return function()
		if currentWindow() then
			local back = byText("VOLVER")
			while back do
				click(back, "VOLVER")
				back = currentWindow() and byText("VOLVER")
			end
		end
		local button = find(home, function(d)
			return d:IsA("GuiButton") and d.Name == name
		end)
		click(button, name)
		frames(0.1)
	end
end

local OPENERS = {
	Characters = openHome("Characters"),
	Unlocks = openHome("Unlocks"),
	Missions = openHome("Missions"),
	Shop = openHome("Shop"),
	Settings = openHome("Settings"),
	Language = openHome("Language"),
	Discord = openHome("Discord"),
	Credits = openHome("Credits"),
	Quit = openHome("Quit"),
}
OPENERS.Maps = function()
	OPENERS.Characters()
	local fox = windowButton(function(d)
		return d.Name == "Fox"
	end)
	click(fox, "Fox")
	-- El botón azul de la ficha (CONFIRMAR, COMPRAR o BLOQUEADO según el personaje)
	click(windowButton(function(d)
		return d.Name == "Confirm"
	end), "CONFIRMAR")
	frames(0.1)
end

-- Pulsa uno a uno todos los botones de una ventana; antes de cada pulsación la vuelve a abrir
-- desde la pantalla principal, así cada botón se prueba en el estado inicial de la ventana.
local function crawl(name, skip, opener)
	local errorsBefore = #Harness.errors
	local label = name
	if opener then
		label = name .. " (" .. opener .. ")"
		local base = OPENERS[name]
		local filter = opener
		OPENERS[label] = function()
			base()
			click(byText(filter), filter)
			frames(0.1)
		end
	end
	local open = OPENERS[label]
	open()
	check(currentWindow() == name, "abre " .. name)
	if currentWindow() == name and UserInputService.GamepadEnabled then
		local selected = GuiService.SelectedObject
		check(selected ~= nil and selected:IsDescendantOf(menuGui), "con mando queda seleccionado un botón de " .. name)
	end
	local pressed, i = 0, 0
	while i < 400 do
		i += 1
		open()
		local buttons = {}
		for _, d in windows:GetDescendants() do
			if d:IsA("GuiButton") then
				table.insert(buttons, d)
			end
		end
		local button = buttons[i]
		if not button then
			break
		end
		if not (skip and skip(button)) then
			click(button, name .. " › " .. (if button.Text ~= "" then button.Text else button.Name))
			frames(0.15)
			pressed += 1
		end
	end
	open()
	noPlaceholders(menuGui, "sin textos por defecto de Roblox en " .. label)
	print(string.format("     %s: %d botones pulsados", label, pressed))
	noNewErrors(errorsBefore, "todos los botones de " .. label .. " sin errores")
	return pressed
end

print("== Selección de personaje")
OPENERS.Characters()
do
	local screen = windows:GetChildren()[1]
	local cells = 0
	for _, c in ipairs(Catalog.Characters) do
		if find(screen, function(d)
			return d:IsA("GuiButton") and d.Name == c.id
		end) then
			cells += 1
		end
	end
	check(cells == #Catalog.Characters, string.format("la cuadrícula muestra los %d personajes", cells))
	check(screen:FindFirstChild("Roster", true) ~= nil and screen:FindFirstChild("Info", true) ~= nil and screen:FindFirstChild("HatPanel", true) ~= nil, "paneles de cuadrícula, ficha y sombrero")
	check(screen:FindFirstChild("Model", true) ~= nil, "personaje en 3D en el centro")
	check(hasText(screen, "SELECCIÓN DE PERSONAJE") and hasText(screen, "Zorro") and hasText(screen, "Bastón de Fuego") and hasText(screen, "Bendición de Suerte"), "textos en español de la ficha de Zorro")
	check(hasText(screen, "CONFIRMAR") and hasText(screen, "Sin sombrero") and hasText(screen, "Skin"), "CONFIRMAR, sombrero y skins")
	local locked = find(screen, function(d)
		return d:IsA("GuiButton") and d.Name == "CL4NK"
	end)
	local silhouette = locked and find(locked, function(d)
		local c = d:IsA("ViewportFrame") and d.ImageColor3
		return c and c.R == 0 and c.G == 0 and c.B == 0
	end)
	check(silhouette ~= nil, "los personajes bloqueados se ven como silueta negra")
	click(find(screen, function(d)
		return d:IsA("GuiButton") and d.Name == "Hat"
	end), "Sin sombrero")
	check(windows:GetChildren()[1]:FindFirstChild("HatList", true) ~= nil, "el botón de sombrero abre la lista")
end

print("== Desbloqueos")
OPENERS.Unlocks()
do
	for _, tab in { "PERSONAJES", "ARMAS", "TOMOS", "OBJETOS", "SOMBREROS" } do
		check(byText(tab) ~= nil, "pestaña " .. tab)
	end
	click(byText("PERSONAJES"), "PERSONAJES")
	local screen = windows:GetChildren()[1]
	local cells = 0
	for _, c in ipairs(Catalog.Characters) do
		if find(screen, function(d)
			return d:IsA("GuiButton") and d.Name == c.id
		end) then
			cells += 1
		end
	end
	check(cells == #Catalog.Characters, "la cuadrícula de desbloqueos muestra los 21 personajes")
	click(windowButton(function(d)
		return d.Name == "TonyMcZoom"
	end), "Tony McVeloz")
	screen = windows:GetChildren()[1]
	check(hasText(screen, "Tony McVeloz") and hasText(screen, "Derrotar 2 minijefes") and hasText(screen, "Comprar: Arma - Daga Inalámbrica"), "ficha de Tony McVeloz con su misión y su arma")
	click(windowButton(function(d)
		return d.Name == "Close"
	end), "X")
	check(currentWindow() == nil, "la X cierra los desbloqueos")
end

print("== Ventanas")
local silverBefore = profile.data.Silver
crawl("Characters")
crawl("Maps", function(b)
	return b.Text == "JUGAR"
end)
for _, filter in { "PERSONAJES", "ARMAS", "TOMOS", "OBJETOS", "SOMBREROS" } do
	crawl("Unlocks", nil, filter)
end
crawl("Missions")
crawl("Shop")
check(profile.data.Silver < silverBefore, string.format("las compras gastan plata (%d → %d)", silverBefore, profile.data.Silver))
check(ClientState.profile.silver == profile.data.Silver, "el perfil del cliente se actualiza tras comprar")
crawl("Settings")
crawl("Language")
crawl("Discord")
Config.DiscordInvite = "https://discord.gg/armonitca"
crawl("Discord")
local box = find(windows, function(d)
	return d:IsA("TextBox")
end)
check(box ~= nil and box.Text == Config.DiscordInvite, "invitación de Discord para copiar")
if box then
	attempt("Discord › Focused", function()
		box.Focused:Fire()
	end)
	check(box.SelectionStart == 1 and box.CursorPosition == #Config.DiscordInvite + 1, "al enfocar el enlace se selecciona entero")
end
Config.DiscordInvite = ""
crawl("Credits")
crawl("Quit")
check(Harness.kicked == "¡Gracias por jugar!", "SALIR expulsa con mensaje")

print("== Opciones, teclas y mando")
before = #Harness.errors
OPENERS.Settings()
local scaleBefore = ClientState.settings.uiScale
local plus = windowButton(function(d)
	return d.Text == "+"
end)
click(plus, "+")
check(ClientState.settings.master <= 1, "el volumen no pasa de 1")
local pauseButton = byText(ClientState.bindings.Pause[1].Name)
click(pauseButton, "tecla de pausa")
check(byText("Pulsa una tecla...") ~= nil, "espera la nueva tecla")
press(Enum.KeyCode.K)
check(ClientState.bindings.Pause[1] == Enum.KeyCode.K and byText("K") ~= nil, "tecla de pausa reasignada a K")
click(byText("K"), "tecla de pausa")
press(Enum.KeyCode.Escape)
check(ClientState.bindings.Pause[1] == Enum.KeyCode.K and byText("K") ~= nil, "Escape cancela la reasignación")
click(byText("K"), "tecla de pausa")
press(Enum.KeyCode.ButtonB, Enum.UserInputType.Gamepad1)
check(currentWindow() == nil and home.Visible, "B del mando vuelve a la pantalla principal")
check(GuiService.SelectedObject == playButton, "al volver se selecciona JUGAR")
press(Enum.KeyCode.W)
check(ClientState.bindings.Pause[1] == Enum.KeyCode.K, "cerrar Ajustes cancela la tecla pendiente")
camera._props.ViewportSize = V2.new(2000, 1245)
attempt("cambio de resolución", function()
	menuGui:GetPropertyChangedSignal("AbsoluteSize"):Fire()
end)
check(math.abs(root.DesignScale.Scale - 1245 / 1080 * ClientState.settings.uiScale) < 1e-6, "en 16:10 la escala sigue al alto")
camera._props.ViewportSize = V2.new(1280, 720)
attempt("cambio de resolución", function()
	menuGui:GetPropertyChangedSignal("AbsoluteSize"):Fire()
end)
local expected = math.max(0.2, 1280 / 1920 * ClientState.settings.uiScale)
check(math.abs(root.DesignScale.Scale - expected) < 1e-6, string.format("la escala sigue a la ventana (%.3f)", root.DesignScale.Scale))
camera._props.ViewportSize = V2.new(1920, 1080)
attempt("cambio de resolución", function()
	menuGui:GetPropertyChangedSignal("AbsoluteSize"):Fire()
end)
print(string.format("     escala de interfaz %.2f → %.2f", scaleBefore, ClientState.settings.uiScale))
noNewErrors(before, "opciones, teclas y mando sin errores")

-- Partida ---------------------------------------------------------------------------------------

print("== Partida")
before = #Harness.errors
local started = {}
Net.get("StartRun").OnServerEvent:Connect(function(_, request)
	table.insert(started, request)
end)
OPENERS.Maps()
click(windowButton(function(d)
	return d.Name == "Forest"
end), "Forest")
click(byText("TIER 3"), "TIER 3")
click(byText("JUGAR"), "JUGAR")
frames(0.2)
check(started[#started] and started[#started].tier == 3, "JUGAR envía StartRun")
check(menuGui.Enabled and hasText(root, "Completa Forest Tier 2 primero"), "el aviso del servidor sale en el menú")
click(byText("TIER 1"), "TIER 1")
click(byText("JUGAR"), "JUGAR")
local hudGui = playerGui.Hud
for _ = 1, 30 do
	frames(DT)
	if hudGui.Enabled then
		break
	end
end
noPlaceholders(hudGui, "sin textos por defecto de Roblox al aparecer el HUD")
frames(0.5)
local request = started[#started]
check(request and request.character == "Fox" and request.map == "Forest" and request.tier == 1, "StartRun con Fox, Forest, tier 1")
check(menuGui.Enabled == false and playerGui.Hud.Enabled == true, "al empezar la partida se oculta el menú y sale el HUD")
check(ClientState.inRun == true, "estado de partida en el cliente")
check(Harness.workspace:FindFirstChild("MenuScene") == nil, "la escena del menú se retira")
check(camera.CameraType == Enum.CameraType.Custom and camera.FieldOfView == 70, "la cámara vuelve a Custom con su campo de visión")
check(services.Lighting:FindFirstChildWhichIsA("DepthOfFieldEffect") == nil, "se quita el desenfoque")
local character = player.Character
check(character ~= nil and camera.CameraSubject == character:FindFirstChildOfClass("Humanoid"), "la cámara sigue al humanoide")

local hudCount = Harness.remoteLog.Hud and Harness.remoteLog.Hud.count or 0
frames(4)
check((Harness.remoteLog.Hud and Harness.remoteLog.Hud.count or 0) > hudCount, "llegan actualizaciones del HUD")
noPlaceholders(hudGui, "sin textos por defecto de Roblox en el HUD")
local realDots = 0
for _, d in hudGui:GetDescendants() do
	if d.Name == "Dot" then
		realDots += 1
	end
end
check(realDots > 0, string.format("marcadores reales del mapa en el minimapa (%d)", realDots))
local hudTexts = table.concat(texts(hudGui), " | ")
check(string.find(hudTexts, "Nivel %d") ~= nil and string.find(hudTexts, "Etapa 1/") ~= nil, "el HUD muestra nivel y etapa")
print("     HUD: " .. string.sub(string.gsub(hudTexts, "\n", " "), 1, 300))
check((Harness.remoteLog.Aim and Harness.remoteLog.Aim.count or 0) == 0, "la dirección de mira va al servidor, no se reenvía")
noNewErrors(before, "partida real sin errores")

print("== Movimiento")
before = #Harness.errors
local humanoid = character.Humanoid
local rootPart = character.HumanoidRootPart
player:SetAttribute("ExtraJumps", 1)
humanoid._props.State = Enum.HumanoidStateType.Freefall
attempt("JumpRequest", function()
	UserInputService.JumpRequest:Fire()
end)
check(rootPart.AssemblyLinearVelocity.Y > 0, "salto extra en el aire")
player:SetAttribute("LowGravity", true)
player:SetAttribute("CanFloat", true)
player:SetAttribute("CanClimb", true)
humanoid._props.MoveDirection = roblox.Vector3.new(1, 0, 0)
attempt("InputBegan Space", function()
	UserInputService.InputBegan:Fire(key(Enum.KeyCode.Space), false)
end)
frames(0.5)
check(rootPart:FindFirstChildOfClass("VectorForce") ~= nil, "fuerza de baja gravedad")
attempt("InputEnded Space", function()
	UserInputService.InputEnded:Fire(key(Enum.KeyCode.Space), false)
end)
humanoid._props.State = nil
humanoid._props.MoveDirection = roblox.Vector3.zero
player:SetAttribute("LowGravity", false)
player:SetAttribute("CanFloat", false)
player:SetAttribute("CanClimb", false)
frames(0.2)
noNewErrors(before, "movimiento sin errores")

print("== HUD, avisos, minimapa y números de daño")
before = #Harness.errors
local lastHud = Harness.remoteLog.Hud.last[1]
local hud = table.clone(lastHud)
local itemIds = {}
for i = 1, 4 do
	local item = Catalog.Items[i * 7]
	table.insert(itemIds, { id = item.id, name = item.name, rarity = item.rarity, count = i })
end
hud.items = itemIds
hud.boss = { name = "Jefe de prueba", hp = 1500, max = 3000 }
hud.swarm = true
hud.swarmTime = 42
hud.momentum = 0.35
hud.hp = hud.maxHp + 25
hud.maxShield = 40
hud.shield = 12
hud.tomes = { { id = Catalog.Tomes[1].id, name = Catalog.Tomes[1].name, level = 3 } }
attempt("Hud", function()
	Net.get("Hud").OnClientEvent:Fire(hud)
end)
hudTexts = table.concat(texts(hudGui), " | ")
check(string.find(hudTexts, "FINAL SWARM", 1, true) ~= nil and string.find(hudTexts, "Jefe de prueba", 1, true) ~= nil, "HUD con jefe y Final Swarm")
check(string.find(hudTexts, "(+25)", 1, true) ~= nil and string.find(hudTexts, "Escudo 12", 1, true) ~= nil, "HUD con sobrevida y escudo")
check(hasText(hudGui, "×4"), "objetos con recuento")

attempt("Toast", function()
	Net.get("Toast").OnClientEvent:Fire("¡Aviso de prueba!")
end)
check(hasText(hudGui, "¡Aviso de prueba!"), "aviso en el HUD")
frames(3.2)
check(not hasText(hudGui, "¡Aviso de prueba!"), "el aviso desaparece a los 3 s")

local markers = {}
for _, kind in { "Chest", "FreeChest", "ChargeShrine", "GoldenChargeShrine", "GreedShrine", "BossCurse", "ShrineOfSucc", "Microwave", "ShadyGuy", "BossPortal", "ExitPortal", "Boss", "Desconocido" } do
	table.insert(markers, { kind = kind, x = #markers * 10 - 60, z = 30 - #markers * 5 })
end
attempt("MapMarkers", function()
	Net.get("MapMarkers").OnClientEvent:Fire(markers)
end)
frames(0.2)
local dots = 0
for _, d in hudGui:GetDescendants() do
	if d.Name == "Dot" then
		dots += 1
	end
end
check(dots == #markers * 2, string.format("marcadores en el minimapa y el mapa (%d)", dots))
local fullMap = find(hudGui, function(d)
	return d:IsA("Frame") and d.Size == roblox.UDim2.fromOffset(560, 560)
end)
press(ClientState.bindings.Map[1])
check(fullMap and fullMap.Visible == true, "M abre el mapa completo")
press(ClientState.bindings.Map[1])
check(fullMap and fullMap.Visible == false, "M lo cierra")

local fx = {}
for _, kind in { "normal", "crit", "overcrit", "execute", "bonk", "poison", "burn", "bloodmark", "curse", "thorns", "player", "evade", "desconocido" } do
	table.insert(fx, { 1, 3, 2, 123, kind })
end
for i = 1, 100 do
	table.insert(fx, { i, 3, -i, i * 10, "normal" })
end
attempt("Fx", function()
	Net.get("Fx").OnClientEvent:Fire(fx)
end)
local damageFolder = camera:FindFirstChild("DamageNumbers")
check(damageFolder and #damageFolder:GetChildren() == 90, "números de daño con reserva de 90 piezas")
check(damageFolder and find(damageFolder, function(d)
	return d:IsA("TextLabel") and d.Text == "Evadido"
end) ~= nil, "\"Evadido\" al esquivar")
frames(1)
check(damageFolder and #damageFolder:GetChildren() == 0, "los números de daño se recogen al terminar")
noNewErrors(before, "HUD, avisos, minimapa y daño sin errores")

print("== Ventanas de elección")
before = #Harness.errors
local modalGui = playerGui.Modal
local function choice(i, kindName)
	local weapon = Catalog.Weapons[i]
	return {
		type = kindName or "Weapon",
		id = weapon.id,
		rarity = ({ "Common", "Rare", "Epic", "Legendary" })[(i - 1) % 4 + 1],
		name = weapon.name,
		subtitle = "Nivel " .. i,
		desc = weapon.desc,
		changes = { { text = "Daño 10 → 12" }, { text = "Cantidad 1 → 2" } },
	}
end
local function modal(data)
	attempt("Modal " .. (if data then data.kind else "nil"), function()
		Net.get("Modal").OnClientEvent:Fire(data)
	end)
end
local function cardsOf()
	local list = {}
	for _, d in modalGui:GetDescendants() do
		if d:IsA("TextButton") and d.Text == "" then
			table.insert(list, d)
		end
	end
	return list
end
ClientState.settings.autoPick = false
local levelUp = { kind = "LevelUp", title = "¡Subiste de nivel!", choices = { choice(1), choice(2), choice(3) }, canSkip = false, charges = { Refresh = 1, Skip = 1, Banish = 1 }, remaining = 2 }
modal(levelUp)
check(modalGui.Enabled and #cardsOf() == 3, "subida de nivel con 3 cartas")
check(GuiService.SelectedObject == cardsOf()[1], "con mando se selecciona la primera carta")
check(hasText(modalGui, "Refresh (1)") and hasText(modalGui, "Skip (1)") and hasText(modalGui, "Banish (1)"), "botones Refresh, Skip y Banish")
local choicesBefore = #modalChoices
click(cardsOf()[1], "carta 1 al abrir")
frames(0.1)
check(#modalChoices == choicesBefore and modalGui.Enabled, "se ignora la elección inmediata al abrir")
frames(0.3)
local banish = find(modalGui, function(d)
	return d:IsA("TextButton") and d.Text == "Banish (1)"
end)
click(banish, "Banish")
check(banish.Text == "Elige qué excluir", "modo Banish")
click(cardsOf()[2], "carta 2 en modo Banish")
frames(0.1)
check(modalChoices[#modalChoices] and modalChoices[#modalChoices].action == "banish" and modalChoices[#modalChoices].index == 2, "Banish envía la carta elegida")
click(find(modalGui, function(d)
	return d:IsA("TextButton") and d.Text == "Refresh (1)"
end), "Refresh")
frames(0.1)
check(modalChoices[#modalChoices].action == "refresh", "Refresh enviado")
click(find(modalGui, function(d)
	return d:IsA("TextButton") and d.Text == "Skip (1)"
end), "Skip")
frames(0.1)
check(modalChoices[#modalChoices].action == "skip" and not modalGui.Enabled, "Skip enviado y ventana cerrada")
modal(levelUp)
frames(0.4)
press(ClientState.bindings.Choice3[1])
frames(0.1)
check(modalChoices[#modalChoices].action == "pick" and modalChoices[#modalChoices].index == 3, "tecla 3 elige la tercera carta")
modal(levelUp)
frames(0.4)
click(cardsOf()[1], "carta 1")
frames(0.1)
check(modalChoices[#modalChoices].action == "pick" and modalChoices[#modalChoices].index == 1 and not modalGui.Enabled, "clic en una carta la elige")
local item = Catalog.Items[3]
local itemChoice = { type = "Item", id = item.id, rarity = item.rarity, name = item.name, subtitle = "Común · tienes 0", desc = item.desc, changes = {} }
modal({ kind = "Item", title = "Cofre", choices = { itemChoice }, canSkip = true, remaining = 0 })
check(modalGui.Enabled and #cardsOf() == 1 and hasText(modalGui, "Descartar"), "objeto de cofre con Descartar")
frames(0.4)
click(find(modalGui, function(d)
	return d:IsA("TextButton") and d.Text == "Descartar"
end), "Descartar")
frames(0.1)
check(modalChoices[#modalChoices].action == "skip", "Descartar envía skip")
local shrineChoices = {}
for i, stat in { "Damage", "MaxHealth", "MoveSpeed" } do
	table.insert(shrineChoices, { type = "Shrine", rarity = "Rare", name = stat, subtitle = "Raro", changes = { { text = "10 → 12" } } })
end
modal({ kind = "Shrine", title = "Charge Shrine", choices = shrineChoices, canSkip = true, remaining = 1 })
check(#cardsOf() == 3 and hasText(modalGui, "Cerrar"), "santuario con 3 bonificaciones y Cerrar")
modal({ kind = "Microwave", title = "Microwave: elige el objeto que quieres duplicar", choices = { itemChoice, itemChoice }, canSkip = true, remaining = 0 })
check(#cardsOf() == 2, "microondas con los objetos")
modal({ kind = "Shop", title = "Shady Guy", choices = { itemChoice }, canSkip = true, remaining = 0 })
check(#cardsOf() == 1, "vendedor con su oferta")
modal(nil)
check(not modalGui.Enabled, "la ventana se cierra cuando el servidor lo indica")
ClientState.settings.autoPick = true
modal(levelUp)
frames(0.6)
check(modalChoices[#modalChoices].action == "pick" and modalChoices[#modalChoices].index == 1 and not modalGui.Enabled, "elección automática")
ClientState.settings.autoPick = false
noNewErrors(before, "ventanas de elección sin errores")

print("== Pausa y resultados")
before = #Harness.errors
local pauseGui = playerGui.Pause
local pauses = {}
Net.get("Pause").OnServerEvent:Connect(function(_, paused)
	table.insert(pauses, paused)
end)
press(ClientState.bindings.Pause[1])
frames(0.1)
check(pauseGui.Enabled and pauses[#pauses] == true, "la tecla de pausa abre la pausa y avisa al servidor")
for _, label in { "Estadísticas", "Inventario" } do
	click(find(pauseGui, function(d)
		return d:IsA("TextButton") and d.Text == label
	end), label)
end
local pauseText = table.concat(texts(pauseGui), "\n")
check(string.find(pauseText, "Armas", 1, true) ~= nil, "el inventario lista las armas")
click(find(pauseGui, function(d)
	return d:IsA("TextButton") and d.Text == "Reanudar"
end), "Reanudar")
frames(0.1)
check(not pauseGui.Enabled and pauses[#pauses] == false, "Reanudar cierra la pausa")
press(ClientState.bindings.Pause[1])
click(find(pauseGui, function(d)
	return d:IsA("TextButton") and d.Text == "Abandonar partida"
end), "Abandonar partida")
frames(0.5)
local resultsGui = playerGui.Results
check(resultsGui.Enabled and not hudGui.Enabled, "al abandonar llegan los resultados reales")
local resultsText = table.concat(texts(resultsGui), "\n")
check(string.find(resultsText, "FIN DE LA PARTIDA", 1, true) ~= nil and string.find(resultsText, "Partida abandonada", 1, true) ~= nil, "resultados de la partida abandonada")
check(ClientState.inRun == false, "fin del estado de partida")
attempt("Results", function()
	local damage = {}
	for i = 1, 20 do
		table.insert(damage, { name = "Fuente " .. i, amount = 1000 * (21 - i) })
	end
	Net.get("Results").OnClientEvent:Fire({
		victory = true, reason = "Jefe final derrotado", time = 1234, swarmTime = 60, kills = 15000, level = 42,
		character = "Fox", map = "Forest", tier = 1, stage = 3, bosses = 3, silver = 250, gold = 9999,
		damage = damage, unlocked = { "Calcium", "Desert" },
	})
end)
resultsText = table.concat(texts(resultsGui), "\n")
check(string.find(resultsText, "¡VICTORIA!", 1, true) ~= nil and string.find(resultsText, "Desert", 1, true) ~= nil, "resultados de victoria con contenido nuevo")
click(find(resultsGui, function(d)
	return d:IsA("TextButton") and d.Text == "Volver al menú"
end), "Volver al menú")
frames(0.5)
check(menuGui.Enabled and home.Visible and not resultsGui.Enabled, "vuelta al menú")
check(Harness.workspace:FindFirstChild("MenuScene") ~= nil and camera.CameraType == Enum.CameraType.Scriptable, "la escena del menú vuelve a tomar la cámara")
attempt("Toast en el menú", function()
	Net.get("Toast").OnClientEvent:Fire("Aviso en el menú")
end)
check(hasText(root, "Aviso en el menú"), "los avisos fuera de partida salen en el menú")
noNewErrors(before, "pausa, resultados y vuelta al menú sin errores")

print("== Segunda partida y reaparición")
before = #Harness.errors
OPENERS.Maps()
click(byText("JUGAR"), "JUGAR")
frames(1)
check(playerGui.Hud.Enabled and not menuGui.Enabled, "segunda partida")
attempt("RunStarted de la etapa 2", function()
	local info = table.clone(Harness.remoteLog.RunStarted.last[1])
	info.stage = 2
	Net.get("RunStarted").OnClientEvent:Fire(info)
end)
attempt("reaparición", function()
	player:LoadCharacter()
end)
frames(1)
attempt("Results", function()
	Net.get("QuitRun"):FireServer()
end)
frames(0.5)
check(playerGui.Results.Enabled, "abandonar desde el servidor muestra resultados")
click(find(playerGui.Results, function(d)
	return d:IsA("TextButton") and d.Text == "Volver al menú"
end), "Volver al menú")
frames(0.5)
check(menuGui.Enabled and home.Visible, "vuelta al menú tras la segunda partida")
noNewErrors(before, "segunda partida sin errores")

print("== Casos límite del menú")
before = #Harness.errors
-- Clasificación vacía, jugador de Studio (UserId negativo) sin rango y personaje desconocido
local stub = { scope = "friends", entries = {}, me = { userId = -1, name = "Player1", kills = 0 }, resetsIn = 1, persistent = true }
Net.get("GetLeaderboard").OnServerInvoke = function(_, scope)
	table.insert(boardRequests, scope)
	stub.scope = scope
	return stub
end
click(if friendsTab.BackgroundColor3 == globalTab.BackgroundColor3 then friendsTab else (if boardRequests[#boardRequests] == "friends" then globalTab else friendsTab), "pestaña")
frames(0.2)
boardTexts = texts(board, true)
check(table.find(boardTexts, "Aún no hay marcas esta semana") ~= nil, "aviso de clasificación vacía")
check(table.find(boardTexts, "?") ~= nil and table.find(boardTexts, "Player1") ~= nil, "jugador sin rango con \"?\"")
requestsBefore = #boardRequests
Harness.advance(4)
frames(0.2)
check(#boardRequests > requestsBefore, "al terminar la semana se vuelve a pedir la clasificación")
stub.entries = {
	{ rank = 1, userId = 1, name = "Raro", kills = 7, character = "NoExiste" },
	{ rank = 2, userId = 2, name = "SinPersonaje", kills = 3 },
}
stub.resetsIn = 3600
Harness.advance(61)
frames(0.2)
boardTexts = texts(board, true)
check(table.find(boardTexts, "Raro") ~= nil and table.find(boardTexts, "SinPersonaje") ~= nil, "filas con personaje desconocido o sin personaje")
Net.get("GetLeaderboard").OnServerInvoke = function(who, scope)
	table.insert(boardRequests, scope)
	return serverBoard(who, scope)
end

-- Ventanas antes de que llegue el perfil (el servidor aún no ha respondido a GetProfile)
local savedProfile = ClientState.profile
ClientState.profile = nil
for _, name in { "Characters", "Maps", "Unlocks", "Missions", "Shop" } do
	attempt("ventana " .. name .. " sin perfil", OPENERS[name])
end
check(currentWindow() ~= "Maps", "sin perfil no se puede pasar de personaje a mapa")
ClientState.profile = savedProfile
OPENERS.Characters()
-- La selección de personaje ocupa toda la pantalla y se cierra con la X de su panel
click(windowButton(function(d)
	return d.Name == "Close"
end), "X")
check(currentWindow() == nil, "la X cierra la selección de personaje")

-- Todo listo para comprar y sin plata: las compras fallan con su mensaje
local savedData = profile.data
profile.data = table.clone(savedData)
profile.data.Silver = 0
profile.data.Counters = table.clone(savedData.Counters)
profile.data.Max = table.clone(savedData.Max)
for _, contentKey in contentKeys do
	local unlock = Catalog.Content[contentKey].unlock
	if unlock.kind == "counter" and unlock.key ~= "quests" then
		profile.data.Counters[unlock.key] = math.max(profile.data.Counters[unlock.key] or 0, unlock.target)
	elseif unlock.kind == "max" then
		profile.data.Max[unlock.key] = math.max(profile.data.Max[unlock.key] or 0, unlock.target)
	end
end
profile:invalidate()
local function pushProfile()
	local summary = profile:summary()
	summary.persistent = SaveService.persistent
	attempt("Profile", function()
		Net.get("Profile").OnClientEvent:Fire(summary)
	end)
	frames(0.1)
end
pushProfile()
crawl("Unlocks", nil, "ARMAS")
-- Revólver con su misión cumplida: se elige en la cuadrícula y se intenta comprar sin plata
OPENERS.Unlocks()
click(byText("ARMAS"), "ARMAS")
click(windowButton(function(d)
	return d.Name == "Revolver"
end), "Revolver")
click(windowButton(function(d)
	return d.Name == "Buy"
end), "COMPRAR Revolver")
frames(0.1)
check(profile.data.Silver == 0, "sin plata no se compra nada")
check(hasText(root, "Plata insuficiente"), "aviso de plata insuficiente")
-- Los mapas cuestan 0: la compra sale bien y después llega el perfil nuevo del servidor; el
-- mensaje de la compra no debe quedar tapado por otro aviso
OPENERS.Characters()
click(windowButton(function(d)
	return d.Name == "Fox"
end), "Fox")
click(windowButton(function(d)
	return d.Name == "Confirm"
end), "CONFIRMAR")
frames(0.1)
local freeMap = windowButton(function(d)
	return d.Name == "Desert"
end)
check(freeMap ~= nil, "mapa listo para comprar")
if freeMap then
	click(freeMap, "COMPRAR mapa")
	frames(0.3)
	check(find(root, function(d)
		return d:IsA("TextLabel") and string.find(d.Text, " comprado$") ~= nil
	end) ~= nil, "el mensaje de compra sigue a la vista tras recibir el perfil")
end
crawl("Missions")
crawl("Shop")
profile.data = savedData
profile:invalidate()

-- Sin mando conectado: las ventanas y las elecciones no tocan la selección
UserInputService._props.GamepadEnabled = false
GuiService.SelectedObject = nil
for _, name in { "Characters", "Settings", "Quit" } do
	attempt("ventana " .. name .. " sin mando", OPENERS[name])
end
click(byText("VOLVER"), "VOLVER")
-- El último perfil del servidor trae las opciones guardadas por las pruebas de Ajustes
ClientState.settings.autoPick = false
modal(levelUp)
frames(0.4)
click(cardsOf()[2], "carta 2 sin mando")
frames(0.1)
check(GuiService.SelectedObject == nil and modalChoices[#modalChoices].index == 2, "sin mando no se fuerza ninguna selección")
UserInputService._props.GamepadEnabled = true

-- Studio con todo desbloqueado (opción de depuración): cualquier personaje, mapa y tier
Harness.isStudio = true
Config.Debug.StudioUnlockAll = true
pushProfile()
check(ClientState.profile.studioUnlockAll == true, "perfil de Studio con todo desbloqueado")
crawl("Characters")
crawl("Maps", function(b)
	return b.Text == "JUGAR"
end)
OPENERS.Characters()
local lastCharacter = Catalog.Characters[#Catalog.Characters].id
click(windowButton(function(d)
	return d.Name == lastCharacter
end), lastCharacter)
click(byText("CONFIRMAR"), "CONFIRMAR")
frames(0.1)
check(currentWindow() == "Maps", "en Studio cualquier personaje pasa a elegir mapa")
click(windowButton(function(d)
	return d.Name == "Desert"
end), "Desert")
click(byText("TIER 3"), "TIER 3")
click(byText("JUGAR"), "JUGAR")
frames(1)
check(hudGui.Enabled and started[#started].map == "Desert" and started[#started].tier == 3 and started[#started].character == lastCharacter, "en Studio se juega Desert tier 3 con " .. lastCharacter)
frames(2)
attempt("QuitRun", function()
	Net.get("QuitRun"):FireServer()
end)
frames(0.5)
click(find(playerGui.Results, function(d)
	return d:IsA("TextButton") and d.Text == "Volver al menú"
end), "Volver al menú")
frames(0.5)
check(menuGui.Enabled and home.Visible, "vuelta al menú tras la partida de Studio")
Harness.isStudio = false
Config.Debug.StudioUnlockAll = false
noNewErrors(before, "casos límite sin errores")

print("== Conexiones")
local function connected(signal)
	local n = 0
	for _, c in signal.handlers do
		if c.Connected then
			n += 1
		end
	end
	return n
end
frames(0.1)
-- En el menú: la escena (cámara) y el HUD (minimapa) escuchan RenderStepped; las vistas de los
-- personajes de ventanas ya cerradas se desconectan solas.
local renderConnections = connected(RunService.RenderStepped)
check(renderConnections == 2, string.format("sin conexiones de RenderStepped perdidas (%d)", renderConnections))
local heartbeatConnections = connected(RunService.Heartbeat)
check(heartbeatConnections == 2, string.format("sin conexiones de Heartbeat perdidas (%d)", heartbeatConnections))

print("== Serialización de mensajes")
local serializationProblems = 0
for _ in Harness.serializationErrors do
	serializationProblems += 1
end
check(serializationProblems == 0, "todos los mensajes entre cliente y servidor son serializables")

print("== Errores")
for i, message in Harness.errors do
	print(string.format("  [%d] %s", i, message))
end
check(#Harness.errors == 0, string.format("ningún error de ejecución (%d)", #Harness.errors))

print(string.format("\n%s: %d fallos", if failures == 0 then "OK" else "FALLOS", failures))
process.exit(if failures == 0 then 0 else 1)
