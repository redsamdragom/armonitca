-- Guardado con DataStore: versión de esquema, escritura transaccional (UpdateAsync), copia de
-- seguridad recuperable y autoguardado. Si DataStore no está disponible (Studio sin acceso a la
-- API), el perfil funciona en memoria y se avisa de que no se guardará.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local Profile = require(script.Parent.Profile)

local SaveService = {}

local STORE_NAME = "ArmonitcaProfiles_v1"
local AUTOSAVE_INTERVAL = 120

local store: DataStore? = nil
local profiles: { [Player]: any } = {}
SaveService.persistent = false

do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
		SaveService.persistent = true
	else
		warn("[Save] DataStore no disponible; el progreso no se guardará:", result)
	end
end

local function keyFor(player: Player): string
	return "player_" .. player.UserId
end

local function retry(fn, attempts: number)
	local lastError
	for i = 1, attempts do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastError = result
		task.wait(i)
	end
	return false, lastError
end

function SaveService.load(player: Player)
	local data = nil
	if store then
		local ok, result = retry(function()
			return (store :: DataStore):GetAsync(keyFor(player))
		end, 3)
		if ok then
			data = result
			if data ~= nil and type(data) ~= "table" then
				-- Datos dañados: recuperar la copia de seguridad
				local okBackup, backup = retry(function()
					return (store :: DataStore):GetAsync(keyFor(player) .. "_backup")
				end, 2)
				data = if okBackup then backup else nil
			end
		else
			warn("[Save] No se pudo cargar el perfil; se usará uno temporal:", result)
			SaveService.persistent = false
		end
	end
	local profile = Profile.new(player, data)
	profiles[player] = profile
	return profile
end

function SaveService.get(player: Player)
	return profiles[player]
end

function SaveService.save(player: Player, withBackup: boolean?): boolean
	local profile = profiles[player]
	if not profile or not store or not SaveService.persistent then
		return false
	end
	local data = profile.data
	local ok, err = retry(function()
		(store :: DataStore):UpdateAsync(keyFor(player), function()
			return data
		end)
	end, 3)
	if ok then
		profile.dirty = false
		if withBackup then
			pcall(function()
				(store :: DataStore):SetAsync(keyFor(player) .. "_backup", data)
			end)
		end
	else
		warn("[Save] Error al guardar:", err)
	end
	return ok
end

-- Compra transaccional: la plata sólo se descuenta si la escritura del perfil tiene éxito.
function SaveService.purchase(player: Player, key: string): (boolean, string)
	local profile = profiles[player]
	if not profile then
		return false, "Perfil no cargado"
	end
	local snapshot = table.clone(profile.data)
	snapshot.Owned = table.clone(profile.data.Owned)
	snapshot.Shop = table.clone(profile.data.Shop)
	local ok, message = profile:purchase(key)
	if not ok then
		return false, message
	end
	if SaveService.persistent and not SaveService.save(player) then
		profile.data = snapshot
		profile:invalidate()
		return false, "No se pudo guardar la compra; inténtalo de nuevo"
	end
	return true, message
end

function SaveService.release(player: Player)
	SaveService.save(player, true)
	profiles[player] = nil
end

function SaveService.start()
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player, profile in profiles do
				if profile.dirty then
					SaveService.save(player)
				end
			end
		end
	end)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			SaveService.save(player, true)
		end
	end)
end

return SaveService
