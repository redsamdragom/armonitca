--!nolint
-- Pruebas de simulación del servidor con Lune:  lune run tests/simulate
-- Ejecuta partidas reales del código del juego en un entorno simulado y comprueba que:
--   * el catálogo es coherente (21/30/23/85, referencias, objetos con comportamiento)
--   * cada personaje puede jugar sin errores y su arma ataca
--   * todas las armas y todos los objetos se ejecutan sin errores
--   * cofres, santuarios, microondas, vendedor, jefe, cambio de etapa y final funcionan
--   * el progreso de la cuenta (contadores, desbloqueos, compras) se aplica bien
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
	Harness.isStudio = opts.unlockAll == true
	local session = RunSession.new(player, profile, { character = characterId, map = opts.map or "Forest", tier = opts.tier or 1, seed = nextUserId * 101 })
	session:start()
	Harness.isStudio = false
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
	check(profile:status("char:Fox") == "owned" and profile:status("char:SirOofie") == "owned", "Fox y Sir Oofie disponibles desde el inicio")
	check(profile:status("char:Calcium") == "locked", "Calcium bloqueado al inicio")
	profile:applyRun({ counters = { ["kills.enemy.Skeleton"] = 1000 }, maxes = {}, silver = 500, character = "Fox", minutes = 5 })
	check(profile:status("char:Calcium") == "available", "Calcium pasa a disponible tras 1.000 esqueletos (sin comprar)")
	local okBuy = SaveService.purchase(player, "char:Calcium")
	check(okBuy and profile:status("char:Calcium") == "owned", "comprar Calcium con plata")
	check(profile.data.Silver == 500 - Catalog.Content["char:Calcium"].price, "se descuenta el precio")
	local okAgain = SaveService.purchase(player, "char:Calcium")
	check(not okAgain, "no se puede comprar dos veces")
	local okSlot = SaveService.purchase(player, "shop:WeaponSlot3")
	check(not okSlot, "la 3.ª ranura de arma exige 25 quests")
	check(profile:weaponSlots() == 2 and profile:tomeSlots() == 2, "ranuras iniciales: 2 armas y 2 tomos")
	local migrated = req(Server.Save.Profile).migrate({ v = 0, Silver = 7 })
	check(migrated.Silver == 7 and migrated.Settings ~= nil and migrated.Shop ~= nil, "la migración conserva el progreso y rellena campos nuevos")
end

print("== Serialización de mensajes al cliente")
local serializationProblems = 0
for _ in Harness.serializationErrors do
	serializationProblems += 1
end
check(serializationProblems == 0, "todos los mensajes al cliente son serializables")

print(string.format("\n%s: %d fallos", if failures == 0 then "OK" else "FALLOS", failures))
process.exit(if failures == 0 then 0 else 1)
