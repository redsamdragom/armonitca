-- Arranque del servidor: red, validación del catálogo, perfiles, inicio de partidas y bucle.
-- Diseñado para un jugador por servidor (configura Max Players = 1 en Game Settings); cada
-- jugador tiene su propia sesión aunque haya varios.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Catalog = require(Shared.Catalog)
local Config = require(Shared.Config)

Net.setup()

local Server = script.Parent
local Fx = require(Server.Combat.Fx)
local Items = require(Server.Combat.Items)
local SaveService = require(Server.Save.SaveService)
local Leaderboard = require(Server.Save.Leaderboard)
local RunSession = require(Server.Run.RunSession)

Players.CharacterAutoLoads = false
Fx.init()
SaveService.start()

-- Validación de referencias del catálogo al cargar
local problems = Catalog.validate()
for _, item in ipairs(Catalog.Items) do
	if not Items.implemented(item.id) then
		table.insert(problems, "Objeto sin comportamiento: " .. item.id)
	end
end
if #problems > 0 then
	warn("[Catálogo] Problemas encontrados:\n  " .. table.concat(problems, "\n  "))
else
	print(string.format("[Catálogo] OK: %d personajes, %d armas, %d tomos, %d objetos", #Catalog.Characters, #Catalog.Weapons, #Catalog.Tomes, #Catalog.Items))
end

local sessions: { [Player]: any } = {}

local function sendProfile(player: Player)
	local profile = SaveService.get(player)
	if profile then
		local summary = profile:summary()
		summary.persistent = SaveService.persistent
		Net.get("Profile"):FireClient(player, summary)
	end
end

Net.get("GetProfile").OnServerInvoke = function(player)
	local profile = SaveService.get(player)
	if not profile then
		return nil
	end
	local summary = profile:summary()
	summary.persistent = SaveService.persistent
	return summary
end

Net.get("Purchase").OnServerInvoke = function(player, key)
	if typeof(key) ~= "string" or sessions[player] then
		return false, "No disponible durante una partida"
	end
	local ok, message = SaveService.purchase(player, key)
	if ok then
		task.defer(sendProfile, player)
	end
	return ok, message
end

Net.get("GetLeaderboard").OnServerInvoke = function(player, scope)
	if scope ~= "global" and scope ~= "friends" then
		return nil
	end
	return Leaderboard.get(player, scope)
end

Net.get("StartRun").OnServerEvent:Connect(function(player, request)
	if sessions[player] or typeof(request) ~= "table" then
		return
	end
	local profile = SaveService.get(player)
	if not profile then
		return
	end
	local characterId, mapId, tier = request.character, request.map, request.tier
	local character = Catalog.Character[characterId]
	local map = Catalog.Map[mapId]
	if not character or not map or not map.playable or typeof(tier) ~= "number" or not map.tiers[tier] then
		return
	end
	local unlocked = profile:unlockedSet()
	if not unlocked["char:" .. characterId] or not unlocked["map:" .. mapId] then
		Net.get("Toast"):FireClient(player, "Ese contenido aún está bloqueado")
		return
	end
	-- Tiers: el 2 requiere completar el 1 y el 3 requiere el 2 [Pendiente: confirmar regla]
	if tier > 1 and not (Config.Debug.StudioUnlockAll and RunService:IsStudio()) then
		if (profile.data.Counters[string.format("complete.%s.T%d", mapId, tier - 1)] or 0) < 1 then
			Net.get("Toast"):FireClient(player, string.format("Completa %s Tier %d primero", map.name, tier - 1))
			return
		end
	end
	local session = RunSession.new(player, profile, { character = characterId, map = mapId, tier = tier })
	sessions[player] = session
	local ok, err = pcall(function()
		session:start()
	end)
	if not ok then
		warn("[Run] Error al iniciar la partida:", err)
		sessions[player] = nil
		session:cleanup()
		Net.get("Toast"):FireClient(player, "No se pudo iniciar la partida")
	end
end)

Net.get("ModalChoice").OnServerEvent:Connect(function(player, action, index)
	local session = sessions[player]
	if session and typeof(action) == "string" then
		session:onModalChoice(action, index)
	end
end)

Net.get("Pause").OnServerEvent:Connect(function(player, paused)
	local session = sessions[player]
	if session and typeof(paused) == "boolean" then
		session:setPaused(paused)
	end
end)

Net.get("QuitRun").OnServerEvent:Connect(function(player)
	local session = sessions[player]
	if session then
		session:quit()
	end
end)

Net.get("Aim").OnServerEvent:Connect(function(player, direction)
	local session = sessions[player]
	if session and typeof(direction) == "Vector3" and direction.Magnitude > 0.1 and direction.Magnitude < 10 then
		session.aimDir = direction.Unit
	end
end)

Net.get("SaveSettings").OnServerEvent:Connect(function(player, settings)
	local profile = SaveService.get(player)
	if not profile or typeof(settings) ~= "table" then
		return
	end
	for key, value in settings do
		local current = profile.data.Settings[key]
		if current ~= nil and typeof(value) == typeof(current) then
			profile.data.Settings[key] = value
		end
	end
	profile.dirty = true
end)

Players.PlayerAdded:Connect(function(player)
	SaveService.load(player)
	sendProfile(player)
end)
for _, player in Players:GetPlayers() do
	task.spawn(function()
		SaveService.load(player)
		sendProfile(player)
	end)
end

Players.PlayerRemoving:Connect(function(player)
	local session = sessions[player]
	if session then
		session:quit()
		sessions[player] = nil
		-- La partida abandonada al salir también cuenta para la clasificación
		task.spawn(Leaderboard.submit, player, session.kills, session.characterId)
	end
	SaveService.release(player)
end)

RunService.Heartbeat:Connect(function(dt)
	for player, session in sessions do
		local ok, err = pcall(session.update, session, dt)
		if not ok then
			warn("[Run] Error en la simulación:", err)
			session:finish(false, "Error interno")
		end
		if session.ended then
			sessions[player] = nil
			task.spawn(function()
				SaveService.save(player)
				sendProfile(player)
				Leaderboard.submit(player, session.kills, session.characterId)
			end)
		end
	end
	Fx.flushNumbers()
end)
