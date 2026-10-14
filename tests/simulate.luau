--!nolint
-- Pruebas de simulación del servidor con Lune:  lune run tests/simulate
-- Ejecuta partidas reales del código del juego en un entorno simulado y comprueba que:
--   * el catálogo es coherente (21/30/23/85, referencias, objetos con comportamiento)
--   * cada personaje puede jugar sin errores y su arma ataca
--   * todas las armas y todos los objetos se ejecutan sin errores
--   * cofres, santuarios, microondas, vendedor, jefe, cambio de etapa y final funcionan
--   * el progreso de la cuenta (contadores, desbloqueos, compras) se aplica bien
--   * la clasificación semanal ordena, conserva la mejor marca y responde según el contrato
--   * los mensajes al cliente son serializables

local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Harness = require("./Harness")

local V3, CF = roblox.Vector3, roblox.CFrame
local ROOT = process.cwd

Harness.build(ROOT)
local S = Harness.shared
local Server = Harness.server
local req = Harness.require

local Catalog = req(S.Catalog)
local Config = req(S.Config)
local Net = req(S.Net)
Net.setup()
local Fx = req(Server.Combat.Fx)
Fx.init()
local Items = req(Server.Combat.Items)
local SaveService = req(Server.Save.SaveService)
local RunSession = req(Server.Run.RunSession)

local failures = 0
local function check(ok, message)
	if ok then
		print("  ok   " .. message)
	else
		failures += 1
		print("  FAIL " .. message)
	end
end

print("== Catálogo")
local problems = Catalog.validate()
for _, p in problems do
	print("  - " .. p)
end
check(#problems == 0, "referencias y recuentos del catálogo")
local missing = 0
for _, item in ipairs(Catalog.Items) do
	if not Items.implemented(item.id) then
		missing += 1
		print("  sin comportamiento: " .. item.id)
	end
end
check(missing == 0, "los 85 objetos tienen comportamiento registrado")

local DT = 1 / 20
local nextUserId = 1

local function newSession(characterId, opts)
	opts = opts or {}
	local player = Harness.addPlayer(nextUserId)
	nextUserId += 1
	local profile = SaveService.load(player)
	-- Con unlockAll se juega como en Studio con todo desbloqueado
	Harness.isStudio = opts.unlockAll == true
	Config.Debug.StudioUnlockAll = opts.unlockAll == true
	local session = RunSession.new(player, profile, { character = characterId, map = opts.map or "Forest", tier = opts.tier or 1, seed = nextUserId * 101 })
	session:start()
	Harness.isStudio = false
	Config.Debug.StudioUnlockAll = false
	return session, player, profile
end

-- Mueve al jugador en círculo (kiting) y resuelve las elecciones automáticamente.
local function simulate(session, seconds, opts)
	opts = opts or {}
	local t = 0
	local radius = opts.radius or 22
	while t < seconds and not session.ended do
		t += DT
		local root = session.root
		if not root.Anchored then
			local a = t * (opts.speed or 0.6)
			local center = opts.center or V3.zero
			root.CFrame = CF.new(center + V3.new(math.cos(a) * radius, 3, math.sin(a) * radius))
		end
		local ok, err = pcall(session.update, session, DT)
		if not ok then
			return false, err
		end
		while session.modal do
			local action = "pick"
			if session.modal.kind == "LevelUp" and session.rng:NextNumber() < 0.2 then
				action = ({ "refresh", "banish", "skip" })[session.rng:NextInteger(1, 3)]
			end
			local okChoice, errChoice = pcall(session.onModalChoice, session, action, 1)
			if not okChoice then
				return false, errChoice
			end
			if action ~= "pick" and session.modal and session.modal.kind == "LevelUp" then
				pcall(session.onModalChoice, session, "pick", 1)
			end
		end
		if opts.crowd and session.director and math.floor(t / 3) ~= math.floor((t - DT) / 3) then
			-- Oleada cercana para que también actúen las armas de corto alcance
			for _ = 1, opts.crowd do
				session.director:spawnNear(session.director:basicEnemy(), session.root.Position, 4, 14)
			end
		end
		if opts.each then
			opts.each(session, t)
		end
		Harness.advance(DT)
		Fx.flushNumbers()
	end
	return true
end

print("== Los 21 personajes (90 s cada uno)")
for _, character in ipairs(Catalog.Characters) do
	local session = newSession(character.id)
	session.bonus.MaxHealth = 400
	session.statsDirty = true
	local ok, err = simulate(session, 90)
	local weaponDamage = session.damageBySource["weapon:" .. character.weapon] or 0
	check(ok, string.format("%-12s nivel %2d, %4d bajas, daño de %s %d%s", character.id, session.level, session.kills, character.weapon, weaponDamage, if ok then "" else "\n       " .. tostring(err)))
	check(weaponDamage > 0, character.id .. ": su arma inicial hace daño")
	session:quit()
	Harness.advance(DT)
end

print("== Las 30 armas a la vez")
do
	local session = newSession("Fox", { unlockAll = true })
	session.weaponSlots = 30
	session.bonus.MaxHealth = 2000
	session.statsDirty = true
	for _, weapon in ipairs(Catalog.Weapons) do
		if weapon.id ~= "Firestaff" then
			session:addWeapon(weapon.id)
		end
	end
	local ok, err = simulate(session, 60, { crowd = 25 })
	check(ok, "60 s con las 30 armas" .. (if ok then "" else "\n       " .. tostring(err)))
	local silent = {}
	for _, weapon in ipairs(Catalog.Weapons) do
		if (session.damageBySource["weapon:" .. weapon.id] or 0) <= 0 and weapon.behavior ~= "Aegis" then
			table.insert(silent, weapon.id)
		end
	end
	check(#silent == 0, "todas las armas hacen daño" .. (if #silent > 0 then ": faltan " .. table.concat(silent, ", ") else ""))
	session:quit()
	Harness.advance(DT)
end

print("== Los 85 objetos a la vez")
do
	local session = newSession("SirOofie", { unlockAll = true })
	session.bonus.MaxHealth = 3000
	for _, item in ipairs(Catalog.Items) do
		if item.id ~= "ZaWarudo" then
			session:addItem(item.id, if item.cap then 1 else 2)
		end
	end
	session:addItem("ZaWarudo", 1)
	local ok, err = simulate(session, 60, { crowd = 25 })
	check(ok, "60 s con los 85 objetos" .. (if ok then "" else "\n       " .. tostring(err)))
	local itemSources = 0
	for source in session.damageBySource do
		if string.sub(source, 1, 5) == "item:" then
			itemSources += 1
		end
	end
	check(itemSources >= 15, string.format("%d objetos distintos causaron daño", itemSources))
	session:quit()
	Harness.advance(DT)
end

print("== Interactuables, jefe, etapas y final")
do
	local session, player, profile = newSession("Fox", { unlockAll = true })
	session.bonus.MaxHealth = 5000
	session.bonus.Damage = 20
	session.statsDirty = true
	local kinds = {}
	local function useAll(s)
		s.gold = 100000
		for _, entry in table.clone(s.interactables.list) do
			if not entry.removed then
				kinds[entry.kind] = true
				if entry.kind == "Chest" or entry.kind == "FreeChest" then
					s.interactables:openChest(entry)
				elseif entry.kind == "GreedShrine" or entry.kind == "ShrineOfSucc" or entry.kind == "BossCurse" then
					s.interactables:useShrine(entry)
				elseif entry.kind == "Microwave" then
					s.interactables:useMicrowave(entry)
				elseif entry.kind == "ShadyGuy" then
					s.interactables:useShady(entry)
				elseif entry.kind == "ChargeShrine" or entry.kind == "GoldenChargeShrine" then
					s.interactables:completeChargeShrine(entry)
				end
			end
			while s.modal do
				s:onModalChoice("pick", 1)
			end
		end
	end
	local ok, err = simulate(session, 20, { each = function(s, t)
		if t < DT * 1.5 then
			useAll(s)
		end
	end })
	check(ok, "uso de todos los interactuables" .. (if ok then "" else "\n       " .. tostring(err)))
	check(session.chestsOpened > 5, string.format("cofres abiertos: %d", session.chestsOpened))
	local itemCount = 0
	for _, n in session.items do
		itemCount += n
	end
	check(itemCount > 5, string.format("objetos obtenidos: %d", itemCount))

	local stagesCleared = 0
	for stage = 1, 3 do
		local portal
		for _, entry in session.interactables.list do
			if entry.kind == "BossPortal" and not entry.removed then
				portal = entry
			end
		end
		if not portal then
			break
		end
		session.interactables:remove(portal)
		session:startBoss(portal.pos)
		check(session.bossActive, "jefe invocado en la etapa " .. stage)
		ok, err = simulate(session, 200, { center = portal.pos, radius = 10 })
		check(ok, "combate de jefe" .. (if ok then "" else "\n       " .. tostring(err)))
		if session.ended then
			stagesCleared = stage
			break
		end
		check(not session.bossActive, "jefe derrotado en la etapa " .. stage)
		local exit
		for _, entry in session.interactables.list do
			if entry.kind == "ExitPortal" and not entry.removed then
				exit = entry
			end
		end
		check(exit ~= nil, "aparece la salida tras el jefe")
		if exit then
			session:nextStage()
			check(session.stage == stage + 1, "avance a la etapa " .. (stage + 1))
		end
		stagesCleared = stage
	end
	check(session.ended, "la partida termina al vencer al jefe final")
	Harness.advance(DT)
	check((profile.data.Counters["complete.Forest.T1"] or 0) == 1, "se registra Forest Tier 1 completado")
	check(profile:status("char:CL4NK") == "locked", "CL4NK sigue bloqueado sin Revolver comprado (requisito)")
	local results = Harness.remoteLog.Results and Harness.remoteLog.Results.last[1]
	check(results ~= nil and results.victory == true, "pantalla de resultados con victoria")
	check(profile.data.Silver > 0, string.format("plata ganada: %d", profile.data.Silver))
end

print("== Final Swarm y muerte")
do
	local session, player, profile = newSession("Calcium")
	session.stageTime = 2
	local ok, err = simulate(session, 400)
	check(ok, "Final Swarm" .. (if ok then "" else "\n       " .. tostring(err)))
	check(session.swarm, "el Final Swarm empieza al acabarse la cuenta atrás")
	check(session.ended, "el personaje acaba muriendo en el Final Swarm")
	Harness.advance(DT)
	check((profile.data.Counters.deaths or 0) == 1, "se registra la muerte")
	check((profile.data.Max.swarmSeconds or 0) > 0, "se registra el tiempo de Final Swarm")
end

print("== Progreso de la cuenta")
do
	local player = Harness.addPlayer(999)
	local profile = SaveService.load(player)
	local starters = {}
	for _, c in Catalog.Characters do
		if profile:status("char:" .. c.id) == "owned" then
			table.insert(starters, c.id)
		end
	end
	check(table.concat(starters, ",") == "Fox,SirOofie,Calcium", "sólo Fox, Sir Oofie y Calcium al inicio (" .. table.concat(starters, ",") .. ")")
	-- Todos los demás personajes se pueden conseguir jugando: misión rastreable y arma conseguible
	for _, c in Catalog.Characters do
		local content = Catalog.Content["char:" .. c.id]
		local reachable = content.unlock.kind ~= "pending"
		for _, required in content.requires or {} do
			reachable = reachable and Catalog.Content[required].unlock.kind ~= "pending"
		end
		check(reachable, c.id .. " se puede desbloquear jugando")
	end
	-- Monke: la misión sola no basta; falta comprar su arma inicial. Con ambas se desbloquea solo.
	profile:applyRun({ counters = { ["kills.enemy.Boar"] = 1500 }, maxes = {}, silver = 500, character = "Fox", minutes = 5 })
	check(profile:status("char:Monke") == "locked", "Monke sigue bloqueado sin su arma (Bananarang)")
	local unlocked = profile:applyRun({ counters = { chestsBought = 30 }, maxes = {}, silver = 0, character = "Fox", minutes = 1 })
	check(profile:status("weapon:Bananarang") == "available", "Bananarang lista para comprar tras abrir 30 cofres")
	local okBuy = SaveService.purchase(player, "weapon:Bananarang")
	check(okBuy and profile:status("weapon:Bananarang") == "owned", "comprar Bananarang con plata")
	check(profile.data.Silver == 500 - Catalog.Content["weapon:Bananarang"].price, "se descuenta el precio")
	check(profile:status("char:Monke") == "owned", "Monke se desbloquea solo al tener misión y arma")
	check(not SaveService.purchase(player, "char:Monke"), "los personajes no se compran")
	local okAgain = SaveService.purchase(player, "weapon:Bananarang")
	check(not okAgain, "no se puede comprar dos veces")
	check(table.find(unlocked, "Bananarang") ~= nil, "la partida avisa del contenido recién conseguido")
	profile:applyRun({ counters = { ["kills.enemy.Wisp"] = 2000 }, maxes = { ["tome.Precision"] = 10 }, silver = 0, character = "Fox", minutes = 1 })
	check(profile:status("char:Bush") == "locked", "Bush necesita además comprar el Rifle de Francotirador")
	local okSlot = SaveService.purchase(player, "shop:WeaponSlot3")
	check(not okSlot, "la 3.ª ranura de arma exige 25 quests")
	check(profile:weaponSlots() == 2 and profile:tomeSlots() == 2, "ranuras iniciales: 2 armas y 2 tomos")
	local migrated = req(Server.Save.Profile).migrate({ v = 0, Silver = 7 })
	check(migrated.Silver == 7 and migrated.Settings ~= nil and migrated.Shop ~= nil, "la migración conserva el progreso y rellena campos nuevos")
end

print("== Clasificación")
do
	local Leaderboard = req(Server.Save.Leaderboard)
	check(Net.get("GetLeaderboard"):IsA("RemoteFunction"), "existe la RemoteFunction GetLeaderboard")
	local ana = Harness.addPlayer(7001)
	local beto = Harness.addPlayer(7002)
	local caro = Harness.addPlayer(7003)
	Leaderboard.submit(ana, 120, "Fox")
	Leaderboard.submit(beto, 300, "Calcium")
	Leaderboard.submit(caro, 50, "SirOofie")
	Leaderboard.submit(ana, 80, "Calcium") -- peor que la anterior: no debe bajar la marca
	Leaderboard.submit(caro, 200.7, "Fox") -- mejora (se redondea hacia abajo)
	Leaderboard.submit(caro, -5, "Fox")
	Leaderboard.submit(caro, 0 / 0, "Fox")
	Leaderboard.submit(caro, "999", "Fox")

	local board = Leaderboard.get(ana, "global")
	local entries = board.entries
	check(board.scope == "global" and #entries == 3, string.format("global: %d entradas", #entries))
	check(entries[1].userId == 7002 and entries[2].userId == 7003 and entries[3].userId == 7001, "orden por bajas de mayor a menor")
	check(entries[1].rank == 1 and entries[2].rank == 2 and entries[3].rank == 3, "rangos consecutivos")
	check(entries[1].name == beto.Name and entries[1].kills == 300 and entries[1].character == "Calcium", "nombre, bajas y personaje de cada entrada")
	check(entries[2].kills == 200 and entries[2].character == "Fox", "una marca mejor sustituye a la anterior (y su personaje)")
	check(entries[3].kills == 120 and entries[3].character == "Fox", "una marca peor no baja la mejor ni cambia el personaje")
	local me = board.me
	check(me.userId == 7001 and me.name == ana.Name and me.rank == 3 and me.kills == 120 and me.character == "Fox", "campo me del jugador local")
	check(board.resetsIn >= 0 and board.resetsIn <= 604800, string.format("reinicio en %d s", board.resetsIn))
	local utc = os.date("!*t", os.time())
	local sinceMonday = ((utc.wday + 5) % 7) * 86400 + utc.hour * 3600 + utc.min * 60 + utc.sec
	check(math.abs(604800 - sinceMonday - board.resetsIn) <= 2, "la semana se reinicia el lunes a las 00:00 UTC")
	check(board.persistent == false, "sin DataStore la clasificación es temporal (persistent = false)")
	check(Harness.validatePayload(board, "GetLeaderboard") == nil, "la respuesta global es serializable")

	local friends = Leaderboard.get(beto, "friends")
	check(friends.scope == "friends" and #friends.entries == 1 and friends.entries[1].userId == 7002, "amigos sin GetFriendsAsync: sólo el propio jugador")
	check(friends.me.rank == 1 and friends.me.kills == 300, "rango del jugador entre sus amigos")
	check(Harness.validatePayload(friends, "GetLeaderboard") == nil, "la respuesta de amigos es serializable")
	Harness.friends[caro.UserId] = { ana.UserId, beto.UserId }
	local caroFriends = Leaderboard.get(caro, "friends")
	check(#caroFriends.entries == 3 and caroFriends.entries[1].userId == 7002 and caroFriends.entries[3].userId == 7001, "amigos leídos con Players:GetFriendsAsync")
	check(caroFriends.me.rank == 2 and caroFriends.me.kills == 200, "rango del jugador entre sus amigos (con amigos)")
	check(Leaderboard.get(ana, "todos") == nil, "se rechaza un ámbito desconocido")

	-- Una segunda petición en menos de 3 s devuelve la respuesta anterior
	Leaderboard.submit(ana, 500, "Calcium")
	local again = Leaderboard.get(ana, "global")
	check(again.me.kills == 120 and #again.entries == 3, "límite de 1 petición cada 3 s por jugador y ámbito")

	-- Más de 9 participantes y un jugador sin marca
	local lowest
	for i = 1, 10 do
		local player = Harness.addPlayer(7100 + i)
		lowest = lowest or player
		Leaderboard.submit(player, 10 + i, "Fox")
	end
	local nobody = Harness.addPlayer(7200)
	local full = Leaderboard.get(nobody, "global")
	check(#full.entries == 9, string.format("máximo 9 entradas (%d)", #full.entries))
	local sorted = true
	for i, entry in full.entries do
		if entry.rank ~= i or (i > 1 and entry.kills > full.entries[i - 1].kills) then
			sorted = false
		end
	end
	check(sorted, "entradas ordenadas con rango = posición")
	check(full.entries[1].userId == 7001 and full.entries[1].kills == 500 and full.entries[1].character == "Calcium", "la nueva mejor marca encabeza la clasificación")
	check(full.me.rank == nil and full.me.kills == 0 and full.me.userId == 7200, "jugador sin marca: rango desconocido y 0 bajas")
	local last = Leaderboard.get(lowest, "global")
	check(last.me.rank == 13 and last.me.kills == 11, string.format("rango fuera del top 9 (%s)", tostring(last.me.rank)))
	check(Harness.validatePayload(full, "GetLeaderboard") == nil and Harness.validatePayload(last, "GetLeaderboard") == nil, "respuestas con top 9 serializables")
end

print("== Serialización de mensajes al cliente")
local serializationProblems = 0
for _ in Harness.serializationErrors do
	serializationProblems += 1
end
check(serializationProblems == 0, "todos los mensajes al cliente son serializables")

print(string.format("\n%s: %d fallos", if failures == 0 then "OK" else "FALLOS", failures))
process.exit(if failures == 0 then 0 else 1)
