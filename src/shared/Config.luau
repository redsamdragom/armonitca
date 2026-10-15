-- Parámetros globales de la recreación.
-- Casi todo lo de este archivo es PROVISIONAL: la especificación no fija estos valores y deben
-- calibrarse contra la versión de referencia (v1.0.69). Ver docs/MATRIZ.md.

local Config = {}

Config.SchemaVersion = 1
Config.ReferenceVersion = "1.0.69"

-- Menú principal
Config.GameTitle = "ARMONITCA"
Config.GameVersion = "0.5.1"
-- Invitación del servidor de Discord (p. ej. "https://discord.gg/xxxx"). Vacía: el botón DISCORD
-- avisa de que falta configurarla.
Config.DiscordInvite = ""

-- Escala entre las unidades de la referencia y los studs de Roblox. [Pendiente de verificar]
Config.UnitToStuds = 1.2

Config.Player = {
	BaseMaxHealth = 100,
	BaseWalkSpeed = 22, -- studs/s para Speed 1,0×
	BaseJumpHeight = 8,
	BasePickupRange = 8,
	BaseCritDamage = 2.0, -- multiplicador de crítico base [Pendiente]
	ShieldRechargeDelay = 5, -- Referencia comunitaria (wiki Stats)
	ShieldRechargeRate = 0.25, -- fracción del escudo por segundo [Pendiente]
	FallDamageSpeed = 85, -- velocidad vertical (studs/s) desde la que hay daño de caída [Pendiente]
	FallDamagePerSpeed = 0.6,
	ContactInvulnerability = 0.35, -- s de invulnerabilidad tras un golpe [Pendiente]
	MaxLevel = 999,
}

-- Experiencia necesaria para el siguiente nivel [Pendiente]
function Config.xpToNext(level: number): number
	return math.floor(10 + (level - 1) * 6 + (level - 1) ^ 1.6)
end

Config.Slots = {
	BaseWeapons = 2,
	BaseTomes = 2,
	MaxWeapons = 4,
	MaxTomes = 4,
	WeaponMaxLevel = 40, -- Referencia comunitaria
	TomeMaxLevel = 99, -- Referencia comunitaria
	-- Quests completadas necesarias para poder comprar cada ranura (Referencia comunitaria)
	WeaponSlotQuests = { 25, 45 },
	TomeSlotQuests = { 35, 55 },
}

Config.Offers = {
	Choices = 3,
	-- Pesos base por rareza de mejora [Pendiente]; la suerte desplaza el peso hacia arriba.
	RarityWeights = { Common = 60, Uncommon = 25, Rare = 10, Epic = 4, Legendary = 1 },
}

Config.Items = {
	-- Pesos base por rareza de objeto de cofre [Pendiente]
	RarityWeights = { Common = 70, Rare = 22, Epic = 7, Legendary = 1 },
}

Config.Economy = {
	ChestBaseCost = 15, -- [Pendiente]
	ChestCostGrowth = 1.18, -- [Pendiente]
	GoldPerKill = 1,
	SilverPerMinute = 2, -- recompensa de plata al terminar [Pendiente]
	SilverPerBoss = 15, -- [Pendiente]
	SilverPotChance = 0.15, -- probabilidad de vasija de plata [Pendiente]
	GreedDifficulty = 0.05, -- Referencia comunitaria: +5% por activación
	GreedGold = 60, -- [Pendiente]
	MicrowaveCost = 40, -- [Pendiente]
	MicrowaveUses = { Common = 3, Rare = 2, Epic = 2, Legendary = 1 }, -- Referencia comunitaria
	ShadyGuyOffers = 3,
	ShadyGuyCost = { Common = 25, Rare = 50, Epic = 90, Legendary = 160 }, -- [Pendiente]
}

Config.Enemies = {
	MaxActive = 220,
	SpawnDistanceMin = 40,
	SpawnDistanceMax = 70,
	EliteChance = 0.02, -- [Pendiente]
	EliteHealthMult = 6,
	EliteDamageMult = 1.6,
	EliteSizeMult = 1.6,
	HealthGrowthPerMinute = 0.30, -- [Pendiente]
	DamageGrowthPerMinute = 0.10, -- [Pendiente]
	AttackCooldown = 1.0,
	SeparationRadius = 2.2,
}

Config.Status = {
	PoisonTick = 0.5, -- Referencia comunitaria
	PoisonDuration = 5, -- × multiplicador de duración (Referencia comunitaria)
	BurnTick = 0.5, -- [Pendiente]
	BurnDuration = 3, -- [Pendiente]
	FreezeSlow = 0.70, -- Referencia comunitaria
	BloodmarkDurationWeapon = 5, -- Referencia comunitaria
	BloodmarkDurationLifesteal = 4,
}

-- Precios en plata: la especificación no los documenta. Todos [Pendiente].
Config.ProvisionalPrices = {
	Weapon = 30,
	Tome = 25,
	Item = 15,
	WeaponSlot = 150,
	TomeSlot = 120,
	Refresh = 40,
	Skip = 30,
	Banish = 50,
}

Config.Debug = {
	-- true: en Studio todo el contenido aparece desbloqueado (para probar armas y personajes sin
	-- jugar). Desactivado para ver la progresión real: se empieza con Fox, Sir Oofie y Calcium.
	StudioUnlockAll = false,
}

return Config
