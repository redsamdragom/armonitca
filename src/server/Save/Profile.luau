-- Perfil persistente de la cuenta: plata, compras, contadores acumulados, mejores marcas, rangos,
-- tienda permanente y opciones. Separa estrictamente el progreso de la cuenta del de la partida.
--
-- Estados de contenido:
--   owned      disponible para jugar (inicial, comprado o personaje con su misión cumplida)
--   available  condición cumplida; falta comprarlo con plata (armas, tomos, objetos y mapas)
--   locked     condición sin cumplir (o requisito de otro contenido sin comprar)

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Catalog = require(ReplicatedStorage.Shared.Catalog)

local Profile = {}
Profile.__index = Profile

-- Compras de la tienda permanente. Requisitos de ranuras según la referencia comunitaria;
-- precios y número de niveles de Refresh/Skip/Banish [Pendiente].
Profile.Shop = {
	{ key = "shop:WeaponSlot3", name = "3.ª ranura de arma", quests = Config.Slots.WeaponSlotQuests[1], price = Config.ProvisionalPrices.WeaponSlot, field = "WeaponSlots", level = 1 },
	{ key = "shop:WeaponSlot4", name = "4.ª ranura de arma", quests = Config.Slots.WeaponSlotQuests[2], price = Config.ProvisionalPrices.WeaponSlot * 2, field = "WeaponSlots", level = 2 },
	{ key = "shop:TomeSlot3", name = "3.ª ranura de tomo", quests = Config.Slots.TomeSlotQuests[1], price = Config.ProvisionalPrices.TomeSlot, field = "TomeSlots", level = 1 },
	{ key = "shop:TomeSlot4", name = "4.ª ranura de tomo", quests = Config.Slots.TomeSlotQuests[2], price = Config.ProvisionalPrices.TomeSlot * 2, field = "TomeSlots", level = 2 },
	{ key = "shop:Refresh1", name = "Refresh (1 por partida)", quests = 3, price = Config.ProvisionalPrices.Refresh, field = "Refresh", level = 1 },
	{ key = "shop:Refresh2", name = "Refresh (2 por partida)", quests = 15, price = Config.ProvisionalPrices.Refresh * 3, field = "Refresh", level = 2 },
	{ key = "shop:Skip1", name = "Skip (1 por partida)", quests = 5, price = Config.ProvisionalPrices.Skip, field = "Skip", level = 1 },
	{ key = "shop:Skip2", name = "Skip (2 por partida)", quests = 20, price = Config.ProvisionalPrices.Skip * 3, field = "Skip", level = 2 },
	{ key = "shop:Banish1", name = "Banish (1 por partida)", quests = 10, price = Config.ProvisionalPrices.Banish, field = "Banish", level = 1 },
	{ key = "shop:Banish2", name = "Banish (2 por partida)", quests = 30, price = Config.ProvisionalPrices.Banish * 3, field = "Banish", level = 2 },
}
local SHOP_BY_KEY = {}
for _, entry in Profile.Shop do
	SHOP_BY_KEY[entry.key] = entry
end

function Profile.defaultData()
	return {
		v = Config.SchemaVersion,
		Silver = 0,
		Owned = {},
		Counters = {},
		Max = {},
		Ranks = {},
		Shop = { WeaponSlots = 0, TomeSlots = 0, Refresh = 0, Skip = 0, Banish = 0 },
		Settings = {
			master = 1,
			music = 0.7,
			sfx = 0.8,
			sensitivity = 1,
			invertY = false,
			cameraDistance = 18,
			uiScale = 1,
			shake = 1,
			effectOpacity = 1,
			autoPick = false,
			disableSilverTome = false,
		},
		Records = { runs = 0, bestMinutes = 0, bestKills = 0 },
	}
end

-- Migración: rellena campos nuevos sin perder el progreso existente.
function Profile.migrate(data)
	local defaults = Profile.defaultData()
	if type(data) ~= "table" then
		return defaults
	end
	for key, value in defaults do
		if data[key] == nil then
			data[key] = value
		elseif type(value) == "table" and type(data[key]) == "table" then
			for k, v in value do
				if data[key][k] == nil then
					data[key][k] = v
				end
			end
		end
	end
	data.v = Config.SchemaVersion
	return data
end

function Profile.new(player: Player, data)
	return setmetatable({ player = player, data = Profile.migrate(data), dirty = false }, Profile)
end

function Profile:conditionMet(unlock): boolean
	local data = self.data
	if unlock.kind == "start" then
		return true
	elseif unlock.kind == "counter" then
		local value
		if unlock.key == "quests" then
			value = self:questsCompleted()
		else
			value = data.Counters[unlock.key] or 0
		end
		return value >= unlock.target
	elseif unlock.kind == "max" then
		return (data.Max[unlock.key] or 0) >= unlock.target
	end
	return false
end

function Profile:progress(unlock): (number, number)
	if unlock.kind == "counter" then
		local value = if unlock.key == "quests" then self:questsCompleted() else self.data.Counters[unlock.key] or 0
		return value, unlock.target
	elseif unlock.kind == "max" then
		return self.data.Max[unlock.key] or 0, unlock.target
	end
	return 0, 0
end

-- Quests completadas: condiciones de desbloqueo cumplidas (no las iniciales).
function Profile:questsCompleted(): number
	if self._questCache then
		return self._questCache
	end
	local n = 0
	self._questCache = 0 -- evita recursión por la condición "quests"
	for _, content in Catalog.Content do
		if content.unlock.kind ~= "start" and content.unlock.key ~= "quests" and self:conditionMet(content.unlock) then
			n += 1
		end
	end
	self._questCache = n
	return n
end

function Profile:invalidate()
	self._questCache = nil
end

function Profile:status(key: string): string
	local content = Catalog.Content[key]
	if not content then
		return "locked"
	end
	if content.unlock.kind == "start" or self.data.Owned[key] then
		return "owned"
	end
	if not self:conditionMet(content.unlock) then
		return "locked"
	end
	for _, required in content.requires or {} do
		if self:status(required) ~= "owned" then
			return "locked"
		end
	end
	-- Los personajes no se compran: se desbloquean solos al cumplir su misión y tener su arma.
	if content.kind == "char" then
		return "owned"
	end
	return "available"
end

function Profile:unlockedSet()
	local set = {}
	local debugAll = Config.Debug.StudioUnlockAll and RunService:IsStudio()
	for key in Catalog.Content do
		if debugAll or self:status(key) == "owned" then
			set[key] = true
		end
	end
	return set
end

function Profile:weaponSlots(): number
	return Config.Slots.BaseWeapons + self.data.Shop.WeaponSlots
end

function Profile:tomeSlots(): number
	return Config.Slots.BaseTomes + self.data.Shop.TomeSlots
end

function Profile:offerCharges()
	local shop = self.data.Shop
	return { Refresh = shop.Refresh, Skip = shop.Skip, Banish = shop.Banish }
end

function Profile:shopStatus(entry): string
	if (self.data.Shop[entry.field] or 0) >= entry.level then
		return "owned"
	end
	if entry.level > 1 and (self.data.Shop[entry.field] or 0) < entry.level - 1 then
		return "locked"
	end
	if self:questsCompleted() < entry.quests then
		return "locked"
	end
	return "available"
end

-- Compra con plata. Devuelve (ok, mensaje). El guardado lo hace SaveService de forma transaccional.
function Profile:purchase(key: string): (boolean, string)
	local data = self.data
	local shopEntry = SHOP_BY_KEY[key]
	local price, name
	if shopEntry then
		if self:shopStatus(shopEntry) ~= "available" then
			return false, "No disponible todavía"
		end
		price, name = shopEntry.price, shopEntry.name
	else
		local content = Catalog.Content[key]
		if not content then
			return false, "Contenido desconocido"
		end
		if self:status(key) ~= "available" then
			return false, "No disponible todavía"
		end
		price, name = content.price, content.name
	end
	if data.Silver < price then
		return false, "Plata insuficiente"
	end
	data.Silver -= price
	if shopEntry then
		data.Shop[shopEntry.field] = shopEntry.level
	else
		data.Owned[key] = true
	end
	self.dirty = true
	self:invalidate()
	return true, name .. " comprado"
end

-- Vuelca los resultados de una partida. Devuelve los nombres de contenido recién disponible.
function Profile:applyRun(run)
	local data = self.data
	local before = {}
	for key in Catalog.Content do
		before[key] = self:status(key)
	end
	for key, value in run.counters do
		data.Counters[key] = (data.Counters[key] or 0) + value
	end
	for key, value in run.maxes do
		if value > (data.Max[key] or -math.huge) then
			data.Max[key] = value
		end
	end
	data.Silver += run.silver
	local rank = data.Ranks[run.character] or { runs = 0, minutes = 0 }
	rank.runs += 1
	rank.minutes += run.minutes
	rank.rank = math.min(100, math.floor(rank.minutes / 3)) -- [Pendiente] curva de rango
	data.Ranks[run.character] = rank
	data.Records.runs += 1
	data.Records.bestMinutes = math.max(data.Records.bestMinutes, run.minutes)
	data.Records.bestKills = math.max(data.Records.bestKills, run.counters.kills or 0)
	self.dirty = true
	self:invalidate()

	local unlocked = {}
	for key, content in Catalog.Content do
		if before[key] == "locked" and self:status(key) ~= "locked" then
			table.insert(unlocked, content.name)
		end
	end
	table.sort(unlocked)
	return unlocked
end

-- Resumen para los menús del cliente.
function Profile:summary()
	local content = {}
	for key, entry in Catalog.Content do
		local current, target = self:progress(entry.unlock)
		local requires = {}
		for _, required in entry.requires or {} do
			local other = Catalog.Content[required]
			table.insert(requires, { key = required, kind = other.kind, id = other.id, name = other.name, owned = self:status(required) == "owned" })
		end
		table.insert(content, {
			key = key,
			kind = entry.kind,
			id = entry.id,
			name = entry.name,
			status = self:status(key),
			price = entry.price,
			text = entry.unlock.text,
			start = entry.unlock.kind == "start",
			met = self:conditionMet(entry.unlock),
			requires = requires,
			pending = entry.unlock.kind == "pending",
			current = current,
			target = target,
		})
	end
	local shop = {}
	for _, entry in Profile.Shop do
		table.insert(shop, { key = entry.key, name = entry.name, price = entry.price, quests = entry.quests, status = self:shopStatus(entry) })
	end
	local cosmetics = {}
	for _, list in { Catalog.Cosmetics.Hats, Catalog.Cosmetics.Skins } do
		for _, c in list do
			local current, target = self:progress(c.unlock)
			table.insert(cosmetics, {
				id = c.id,
				name = c.name,
				character = c.character,
				text = c.unlock.text,
				met = self:conditionMet(c.unlock),
				pending = c.unlock.kind == "pending",
				current = current,
				target = target,
			})
		end
	end
	return {
		silver = self.data.Silver,
		quests = self:questsCompleted(),
		content = content,
		shop = shop,
		cosmetics = cosmetics,
		ranks = self.data.Ranks,
		records = self.data.Records,
		settings = self.data.Settings,
		weaponSlots = self:weaponSlots(),
		tomeSlots = self:tomeSlots(),
		studioUnlockAll = Config.Debug.StudioUnlockAll and RunService:IsStudio(),
	}
end

return Profile
