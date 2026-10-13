-- Índice del contenido: acceso por id, identificadores de contenido ("weapon:Sword"), precios
-- y validación de referencias al cargar.

local Data = script.Parent.Data
local Config = require(script.Parent.Config)
local Characters = require(Data.Characters)
local Weapons = require(Data.Weapons)
local Tomes = require(Data.Tomes)
local Items = require(Data.Items)
local Enemies = require(Data.Enemies)
local Maps = require(Data.Maps)
local Cosmetics = require(Data.Cosmetics)

local Catalog = {
	Characters = Characters,
	Weapons = Weapons,
	Tomes = Tomes,
	Items = Items,
	Enemies = Enemies,
	Maps = Maps,
	Cosmetics = Cosmetics,
	ChaosPool = Tomes.ChaosPool,
	FinalSwarm = Maps.FinalSwarm,
}

Catalog.UpgradeRarities = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
Catalog.UpgradeRarityMult = { Common = 1, Uncommon = 1.2, Rare = 1.4, Epic = 1.6, Legendary = 2 }
Catalog.ItemRarities = { "Common", "Rare", "Epic", "Legendary" }
Catalog.RarityColor = {
	Common = Color3.fromRGB(200, 200, 200),
	Uncommon = Color3.fromRGB(90, 210, 90),
	Rare = Color3.fromRGB(70, 150, 255),
	Epic = Color3.fromRGB(190, 90, 255),
	Legendary = Color3.fromRGB(255, 190, 40),
}
Catalog.RarityName = { Common = "Común", Uncommon = "Poco común", Rare = "Raro", Epic = "Épico", Legendary = "Legendario" }

local function index(list)
	local byId = {}
	for _, entry in ipairs(list) do
		assert(not byId[entry.id], "id duplicado: " .. entry.id)
		byId[entry.id] = entry
	end
	return byId
end

Catalog.Character = index(Characters)
Catalog.Weapon = index(Weapons)
Catalog.Tome = index(Tomes)
Catalog.Item = index(Items)
Catalog.Map = index(Maps)

-- Contenido comprable: "char:Fox", "weapon:Sword", "tome:Agility", "item:Clover", "map:Desert"
Catalog.Content = {}
local function register(kind, list, price)
	for _, entry in ipairs(list) do
		Catalog.Content[kind .. ":" .. entry.id] = {
			key = kind .. ":" .. entry.id,
			kind = kind,
			id = entry.id,
			name = entry.name,
			unlock = entry.unlock,
			requires = entry.requires,
			price = if entry.unlock.kind == "start" then 0 else price,
		}
	end
end
register("char", Characters, Config.ProvisionalPrices.Character)
register("weapon", Weapons, Config.ProvisionalPrices.Weapon)
register("tome", Tomes, Config.ProvisionalPrices.Tome)
register("item", Items, Config.ProvisionalPrices.Item)
register("map", Maps, 0)

function Catalog.validate(): { string }
	local problems = {}
	local function check(ok, message)
		if not ok then
			table.insert(problems, message)
		end
	end
	check(#Characters == 21, "Se esperaban 21 personajes, hay " .. #Characters)
	check(#Weapons == 30, "Se esperaban 30 armas, hay " .. #Weapons)
	check(#Tomes == 23, "Se esperaban 23 tomos, hay " .. #Tomes)
	check(#Items == 85, "Se esperaban 85 objetos, hay " .. #Items)
	local rarityCount = { Common = 0, Rare = 0, Epic = 0, Legendary = 0 }
	for _, item in ipairs(Items) do
		rarityCount[item.rarity] += 1
	end
	check(
		rarityCount.Common == 22 and rarityCount.Rare == 21 and rarityCount.Epic == 20 and rarityCount.Legendary == 22,
		"Reparto de rarezas de objetos distinto de 22/21/20/22"
	)
	for _, character in ipairs(Characters) do
		check(Catalog.Weapon[character.weapon] ~= nil, character.id .. ": arma inicial desconocida " .. character.weapon)
	end
	for key, content in Catalog.Content do
		for _, required in content.requires or {} do
			check(Catalog.Content[required] ~= nil, key .. ": requisito desconocido " .. required)
		end
	end
	for _, map in ipairs(Maps) do
		for _, tier in map.tiers do
			check(not map.playable or Enemies[tier.boss] ~= nil, map.id .. ": jefe desconocido " .. tier.boss)
		end
		for _, spawn in map.spawns or {} do
			check(Enemies[spawn.enemy] ~= nil, map.id .. ": enemigo desconocido " .. spawn.enemy)
		end
		for _, mini in map.minibosses or {} do
			check(Enemies[mini.enemy] ~= nil, map.id .. ": minijefe desconocido " .. mini.enemy)
		end
	end
	return problems
end

return Catalog
