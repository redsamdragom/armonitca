-- Clasificación semanal: mejor número de bajas en UNA partida durante la semana UTC actual (empieza
-- el lunes a las 00:00). Cada semana usa almacenes nuevos:
--   ArmonitcaKills_W<semana>      OrderedDataStore con la mejor marca de cada jugador (sólo sube)
--   ArmonitcaKillsMeta_W<semana>  DataStore con el nombre y el personaje de esa marca
-- Las listas se guardan en caché 60 s por ámbito (la global, compartida; la de amigos, por jugador)
-- y cada jugador puede pedir una respuesta por ámbito cada 3 s. Si DataStore no está disponible
-- (Studio sin acceso a la API o el arnés de pruebas), la clasificación vive en memoria del servidor
-- y la respuesta lleva persistent = false.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Leaderboard = {}

local WEEK_SECONDS = 604800
local FIRST_MONDAY = 345600 -- 1970-01-05 00:00 UTC fue lunes
local TOP = 9
local PAGE_SIZE = 100 -- primera página de la global: da el top y el rango de quien esté en ella
local MAX_FRIENDS = 50
local CACHE_SECONDS = 60
local REQUEST_INTERVAL = 3
local PENDING_WAIT = 10 -- s que espera una petición repetida a que termine la que está en curso
local FRIENDS_LIST_SECONDS = 600
local META_SECONDS = 300
local BUDGET_RESERVE = 10 -- peticiones que se dejan libres para cargar y guardar perfiles

local EMPTY = table.freeze({})

local available = true -- pasa a false si DataStoreService no responde: todo queda en memoria
local week = -1
local ordered: OrderedDataStore? = nil
local meta: DataStore? = nil

-- Marcas que conoce este servidor esta semana: [userId] = { kills, name, character? }. Sin
-- DataStore son la clasificación entera; con él se superponen a lo leído (GetSortedAsync tarda en
-- reflejar las escrituras). character sólo se rellena si la marca salió de una partida de aquí.
local known: { [number]: any } = {}
local globalCache = nil -- { expires, page = { { userId, kills } }, persistent }
local friendsCache: { [Player]: any } = {} -- { expires, page, members, persistent }
local friendLists: { [Player]: any } = {} -- { expires, ids }
local values: { [number]: any } = {} -- lecturas del OrderedDataStore: { expires, kills? }
local metaCache: { [number]: any } = {} -- lecturas de metadatos: { expires, name?, character? }
local names: { [number]: string } = {}
local requests: { [Player]: any } = {} -- [scope] = { at, pending, response }

local function weekIndex(now: number): number
	return math.floor((now - FIRST_MONDAY) / WEEK_SECONDS)
end

local function resetsIn(): number
	local now = os.time()
	return FIRST_MONDAY + (weekIndex(now) + 1) * WEEK_SECONDS - now
end

-- Al cambiar de semana: almacenes nuevos y cachés vacías.
local function syncWeek()
	local current = weekIndex(os.time())
	if current == week then
		return
	end
	week = current
	table.clear(known)
	globalCache = nil
	table.clear(friendsCache)
	table.clear(values)
	table.clear(metaCache)
	table.clear(requests)
	ordered, meta = nil, nil
	if not available then
		return
	end
	local ok, err = pcall(function()
		ordered = DataStoreService:GetOrderedDataStore("ArmonitcaKills_W" .. current)
		meta = DataStoreService:GetDataStore("ArmonitcaKillsMeta_W" .. current)
	end)
	if not ok then
		available = false
		ordered, meta = nil, nil
		warn("[Clasificación] DataStore no disponible; la clasificación será temporal:", err)
	end
end

-- Margen de peticiones de DataStore: la clasificación nunca agota el de los perfiles.
local function hasBudget(requestType: string): boolean
	local ok, budget = pcall(function()
		return DataStoreService:GetRequestBudgetForRequestType((Enum.DataStoreRequestType :: any)[requestType])
	end)
	return not ok or budget > BUDGET_RESERVE
end

local function byKills(a, b): boolean
	if a.kills ~= b.kills then
		return a.kills > b.kills
	end
	return a.userId < b.userId
end

local function nameOf(userId: number, hint: string?): string
	local name = names[userId] or hint
	if name then
		names[userId] = name
		return name
	end
	local ok, result = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	if ok and typeof(result) == "string" then
		names[userId] = result
		return result
	end
	return "Jugador " .. userId
end

-- Nombre y personaje de la marca de un jugador (de este servidor o del DataStore de metadatos).
local function metaOf(userId: number)
	local mine = known[userId]
	if mine and mine.character then
		return mine
	end
	local now = os.clock()
	local cached = metaCache[userId]
	if cached and cached.expires > now then
		return cached
	end
	local store = meta
	if not store or not hasBudget("GetAsync") then
		return cached or mine or EMPTY
	end
	local ok, data = pcall(function()
		return store:GetAsync(tostring(userId))
	end)
	if not ok then
		return cached or mine or EMPTY
	end
	cached = { expires = now + META_SECONDS }
	if typeof(data) == "table" then
		cached.name = if typeof(data.name) == "string" then data.name else nil
		cached.character = if typeof(data.character) == "string" then data.character else nil
	end
	metaCache[userId] = cached
	return cached
end

-- Mejor marca de la semana de un jugador concreto (nil si no tiene ninguna).
local function valueOf(userId: number): number?
	local now = os.clock()
	local cached = values[userId]
	local stored = if cached then cached.kills else nil
	local store = ordered
	if (not cached or cached.expires <= now) and store and hasBudget("GetAsync") then
		local ok, result = pcall(function()
			return store:GetAsync(tostring(userId))
		end)
		if ok then
			stored = if typeof(result) == "number" then result else nil
			values[userId] = { expires = now + CACHE_SECONDS, kills = stored }
		end
	end
	local mine = known[userId]
	local best = math.max(stored or 0, if mine then mine.kills else 0)
	return if best > 0 then best else nil
end

-- Superpone a una lista leída del almacén las marcas que conoce este servidor (sólo las de members
-- si se indica) y la ordena de mayor a menor.
local function merged(page, members: { [number]: boolean }?)
	local list = {}
	local seen = {}
	for _, item in page do
		local mine = known[item.userId]
		table.insert(list, { userId = item.userId, kills = if mine then math.max(mine.kills, item.kills) else item.kills })
		seen[item.userId] = true
	end
	-- Con la página llena, una marca por debajo de la última no se sabe en qué puesto cae
	local floor = if #page >= PAGE_SIZE then page[#page].kills else 0
	for userId, mine in known do
		if not seen[userId] and mine.kills >= floor and (not members or members[userId]) then
			table.insert(list, { userId = userId, kills = mine.kills })
		end
	end
	table.sort(list, byKills)
	return list
end

-- Primera página de la clasificación global, o nil si no se puede leer.
local function fetchGlobalPage()
	local store = ordered
	if not store or not hasBudget("GetSortedAsync") then
		return nil
	end
	local ok, result = pcall(function()
		return store:GetSortedAsync(false, PAGE_SIZE):GetCurrentPage()
	end)
	if not ok then
		warn("[Clasificación] No se pudo leer la clasificación global:", result)
		return nil
	end
	local page = {}
	for _, item in result do
		local userId = tonumber(item.key)
		if userId and typeof(item.value) == "number" and item.value > 0 then
			table.insert(page, { userId = userId, kills = item.value })
		end
	end
	table.sort(page, byKills)
	return page
end

local function globalList()
	local now = os.clock()
	local cache = globalCache
	if not cache or cache.expires <= now then
		if cache then
			-- Mientras se lee, las demás peticiones usan la lista anterior
			cache.expires = now + CACHE_SECONDS
		end
		local page = fetchGlobalPage()
		if page then
			cache = { expires = now + CACHE_SECONDS, page = page, persistent = true }
		elseif not cache then
			cache = { expires = now + CACHE_SECONDS, page = {}, persistent = false }
		end
		globalCache = cache
	end
	return merged(cache.page), cache.persistent
end

-- Amigos del jugador (máximo 50); si no se pueden leer, se reintenta al caducar la caché.
local function friendIds(player: Player): { number }
	local now = os.clock()
	local cached = friendLists[player]
	if cached and cached.expires > now then
		return cached.ids
	end
	local ids = {}
	local ok = pcall(function()
		local pages = player:GetFriendsAsync()
		while true do
			for _, friend in pages:GetCurrentPage() do
				if #ids >= MAX_FRIENDS then
					return
				end
				table.insert(ids, friend.Id)
				if typeof(friend.Username) == "string" then
					names[friend.Id] = friend.Username
				end
			end
			if pages.IsFinished or #ids >= MAX_FRIENDS then
				return
			end
			pages:AdvanceToNextPageAsync()
		end
	end)
	if not ok and cached then
		ids = cached.ids
	end
	friendLists[player] = { expires = now + (if ok then FRIENDS_LIST_SECONDS else CACHE_SECONDS), ids = ids }
	return ids
end

local function friendsList(player: Player)
	local now = os.clock()
	local cache = friendsCache[player]
	if not cache or cache.expires <= now then
		local members = { [player.UserId] = true }
		local ids = { player.UserId }
		for _, id in friendIds(player) do
			if not members[id] then
				members[id] = true
				table.insert(ids, id)
			end
		end
		local page = {}
		for _, id in ids do
			local kills = valueOf(id)
			if kills then
				table.insert(page, { userId = id, kills = kills })
			end
		end
		cache = { expires = now + CACHE_SECONDS, page = page, members = members, persistent = ordered ~= nil }
		friendsCache[player] = cache
	end
	return merged(cache.page, cache.members), cache.persistent
end

local function entryFor(rank: number?, userId: number, kills: number)
	local info = if kills > 0 then metaOf(userId) else EMPTY
	return {
		rank = rank,
		userId = userId,
		name = nameOf(userId, info.name),
		kills = kills,
		character = info.character,
	}
end

local function build(player: Player, scope: string)
	local userId = player.UserId
	names[userId] = player.Name
	local list, persistent
	if scope == "global" then
		list, persistent = globalList()
	else
		list, persistent = friendsList(player)
	end
	local entries = {}
	local myRank, myKills = nil, nil
	for i, item in list do
		if i <= TOP then
			table.insert(entries, entryFor(i, item.userId, item.kills))
		end
		if item.userId == userId then
			myRank, myKills = i, item.kills
		end
	end
	return {
		scope = scope,
		entries = entries,
		me = entryFor(myRank, userId, myKills or valueOf(userId) or 0),
		resetsIn = resetsIn(),
		persistent = persistent,
	}
end

-- Registra el resultado de una partida; sólo cuenta si supera la mejor marca de la semana.
function Leaderboard.submit(player: Player, kills: number, characterId: string?)
	if typeof(kills) ~= "number" or kills ~= kills or kills < 1 or kills == math.huge then
		return
	end
	kills = math.floor(kills)
	syncWeek()
	local startWeek = week
	local userId = player.UserId
	local name = player.Name
	names[userId] = name
	local character = if typeof(characterId) == "string" then characterId else nil

	local stored = nil
	local wrote = false
	local store = ordered
	if store then
		local ok, err = pcall(function()
			store:UpdateAsync(tostring(userId), function(old)
				stored = if typeof(old) == "number" then old else nil
				wrote = stored == nil or stored < kills
				return if wrote then kills else nil
			end)
		end)
		if not ok then
			wrote = false
			warn("[Clasificación] No se pudo guardar la marca:", err)
		end
	end
	if week ~= startWeek then
		return -- la semana cambió mientras se escribía
	end

	local mine = known[userId]
	local previous = math.max(stored or 0, if mine then mine.kills else 0)
	if kills > previous then
		known[userId] = { kills = kills, name = name, character = character }
		values[userId] = { expires = os.clock() + CACHE_SECONDS, kills = if wrote then kills else stored }
		local metaStore = meta
		if wrote and metaStore then
			local ok, err = pcall(function()
				metaStore:SetAsync(tostring(userId), { name = name, character = character })
			end)
			if not ok then
				warn("[Clasificación] No se pudieron guardar los datos de la marca:", err)
			end
		end
	elseif not mine or mine.kills < previous then
		-- La mejor marca es de otro servidor: su personaje se lee de los metadatos
		known[userId] = { kills = previous, name = name }
	end
end

-- Respuesta del contrato GetLeaderboard para scope = "global" | "friends".
function Leaderboard.get(player: Player, scope: string)
	if scope ~= "global" and scope ~= "friends" then
		return nil
	end
	syncWeek()
	local slots = requests[player]
	if not slots then
		slots = {}
		requests[player] = slots
	end
	local slot = slots[scope]
	local now = os.clock()
	if slot and now - slot.at < REQUEST_INTERVAL then
		-- Petición repetida: se responde con la anterior (esperando a que acabe si está en curso)
		local waited = 0
		while slot.pending and waited < PENDING_WAIT do
			waited += task.wait(0.1)
		end
		if slot.response then
			slot.response.resetsIn = resetsIn()
			return slot.response
		end
	end
	slot = { at = now, pending = true }
	slots[scope] = slot
	local ok, response = pcall(build, player, scope)
	if not ok then
		warn("[Clasificación] Error al preparar la clasificación:", response)
		local mine = known[player.UserId]
		response = {
			scope = scope,
			entries = {},
			me = { userId = player.UserId, name = player.Name, kills = if mine then mine.kills else 0 },
			resetsIn = resetsIn(),
			persistent = false,
		}
	end
	slot.pending = false
	slot.response = response
	return response
end

Players.PlayerRemoving:Connect(function(player)
	requests[player] = nil
	friendsCache[player] = nil
	friendLists[player] = nil
end)

syncWeek()

return Leaderboard
