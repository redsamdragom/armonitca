-- Catálogo de los 21 personajes.
-- Estado de los datos: "ref" = referencia comunitaria/oficial citada en la especificación;
-- todo lo marcado [Pendiente] es un valor provisional editable.
--
-- Estadísticas base: valores absolutos (MaxHealth, Shield, PickupRange, JumpHeight, Thorns) o
-- bonificaciones sobre la base (MoveSpeed 0.2 = 1,2×, Luck 0.15 = +15%).
-- Armor y Evasion se guardan en bruto; `shown(p)` convierte el valor mostrado en la referencia
-- al valor bruto según la fórmula provisional de rendimientos decrecientes (ver StatBlock).
-- perLevel: bonificación por cada nivel ganado dentro de la partida (nivel - 1).

local Unlock = require(script.Parent.Unlock)

local function shown(p: number): number
	return p / (1 - p)
end

local function rgb(r, g, b)
	return { r, g, b }
end

-- Piezas del atuendo provisional (reconstrucción con primitivas, no mallas originales).
-- attach: Head | Torso | Root ; shape: Block | Ball | Cylinder | Wedge
local function piece(attach, shape, size, offset, color, rot, material)
	return { attach = attach, shape = shape, size = size, offset = offset, color = color, rot = rot, material = material }
end

local Characters = {
	{
		id = "Fox",
		name = "Fox",
		weapon = "Firestaff",
		passive = { name = "RNG Blessing", desc = "+1,5% de suerte por nivel.", perLevel = { Luck = 0.015 } },
		stats = { Luck = 0.15, Evasion = shown(0.06), PickupRange = 9, JumpHeight = 8 },
		movement = {},
		unlock = Unlock.start(),
		look = "Zorro naranja con sombrero puntiagudo azul de mago.",
		costume = {
			piece("Head", "Wedge", { 0.5, 0.8, 0.3 }, { -0.45, 0.75, 0 }, rgb(235, 120, 40), { 0, 90, 0 }),
			piece("Head", "Wedge", { 0.5, 0.8, 0.3 }, { 0.45, 0.75, 0 }, rgb(235, 120, 40), { 0, 90, 0 }),
			piece("Head", "Cylinder", { 0.15, 2.2, 2.2 }, { 0, 0.55, 0 }, rgb(40, 110, 200), { 0, 0, 90 }),
			piece("Head", "Wedge", { 1.2, 1.6, 1.2 }, { 0, 1.35, 0 }, rgb(40, 150, 220)),
			piece("Head", "Block", { 0.5, 0.35, 0.5 }, { 0, -0.15, -0.6 }, rgb(250, 230, 200)),
		},
	},
	{
		id = "SirOofie",
		name = "Sir Oofie",
		weapon = "Sword",
		passive = { name = "Reinforced", desc = "+1% de armadura por nivel.", perLevel = { Armor = 0.01 } },
		stats = { MaxHealth = 150, Armor = shown(0.17) },
		movement = {},
		unlock = Unlock.start(),
		look = "Caballero en armadura de placas plateada, casco cerrado.",
		costume = {
			piece("Head", "Block", { 1.35, 1.35, 1.35 }, { 0, 0.05, 0 }, rgb(170, 175, 185), nil, "Metal"),
			piece("Head", "Block", { 0.9, 0.12, 0.05 }, { 0, 0.1, -0.68 }, rgb(20, 20, 20)),
			piece("Torso", "Block", { 1.0, 0.5, 1.2 }, { -1.1, 0.8, 0 }, rgb(160, 165, 175), nil, "Metal"),
			piece("Torso", "Block", { 1.0, 0.5, 1.2 }, { 1.1, 0.8, 0 }, rgb(160, 165, 175), nil, "Metal"),
		},
	},
	{
		id = "Calcium",
		name = "Calcium",
		weapon = "Bone",
		passive = {
			name = "Speed Demon",
			desc = "Acumula impulso al moverse; gana daño según el impulso. Pierde ~25% de impulso al recibir daño.",
			perLevel = { Damage = 0.0075 },
			special = "Momentum",
		},
		stats = { MoveSpeed = 0.2, PickupRange = 8, JumpHeight = 9 },
		movement = { momentum = true },
		-- Inicial por decisión del proyecto: se empieza con Fox, Sir Oofie y Calcium
		unlock = Unlock.instead("matar 1.000 esqueletos", Unlock.start()),
		look = "Esqueleto marfil con gafas de sol sobre un monopatín.",
		costume = {
			piece("Head", "Block", { 1.1, 0.25, 0.1 }, { 0, 0.15, -0.62 }, rgb(15, 15, 15)),
			piece("Root", "Block", { 1.6, 0.2, 3.6 }, { 0, -3.0, 0 }, rgb(200, 60, 60)),
			piece("Root", "Cylinder", { 0.4, 0.4, 0.4 }, { -0.6, -3.25, -1.2 }, rgb(240, 240, 240)),
			piece("Root", "Cylinder", { 0.4, 0.4, 0.4 }, { 0.6, -3.25, 1.2 }, rgb(240, 240, 240)),
		},
	},
	{
		id = "Megachad",
		name = "Megachad",
		weapon = "Aura",
		passive = {
			name = "Flex",
			desc = "Periódicamente bloquea un golpe y aturde a los enemigos cercanos; cada activación da +2,5% de daño.",
			special = "Flex",
		},
		stats = { MaxHealth = 120, JumpHeight = 8 },
		movement = {},
		unlock = Unlock.max("tome.Damage", 7, "Subir Damage Tome al nivel 7"),
		requires = { "weapon:Aura" },
		look = "Hombre musculoso de torso desnudo, mandíbula cuadrada y barba.",
		costume = {
			piece("Torso", "Block", { 3.2, 1.0, 1.4 }, { 0, 0.7, 0 }, rgb(230, 180, 140)),
			piece("Head", "Block", { 1.1, 0.4, 1.1 }, { 0, -0.45, -0.1 }, rgb(40, 30, 25)),
		},
	},
	{
		id = "Ogre",
		name = "Ogre",
		weapon = "Axe",
		passive = { name = "Warrior", desc = "+1,5% de daño por nivel.", perLevel = { Damage = 0.015 } },
		stats = { MaxHealth = 140, Armor = shown(0.06), MoveSpeed = -0.1, Luck = -0.01 },
		movement = {},
		unlock = Unlock.counter("kills.enemy.Goblin", 15000, "Matar 15.000 goblins"),
		requires = { "weapon:Axe" },
		look = "Humanoide verde de cara ancha y orejas laterales.",
		costume = {
			piece("Head", "Block", { 1.5, 1.3, 1.4 }, { 0, 0, 0 }, rgb(110, 160, 70)),
			piece("Head", "Wedge", { 0.3, 0.6, 0.5 }, { -0.85, 0.1, 0 }, rgb(110, 160, 70), { 0, 0, 90 }),
			piece("Head", "Wedge", { 0.3, 0.6, 0.5 }, { 0.85, 0.1, 0 }, rgb(110, 160, 70), { 0, 0, -90 }),
		},
	},
	{
		id = "CL4NK",
		name = "CL4NK",
		weapon = "Revolver",
		passive = { name = "Crit Happens", desc = "+1% de probabilidad crítica por nivel.", perLevel = { CritChance = 0.01 } },
		stats = { MaxHealth = 40, Shield = 50, MoveSpeed = 0.1, PickupRange = 8, JumpHeight = 9 },
		movement = {},
		unlock = Unlock.counter("complete.Forest.T1", 1, "Completar Forest Tier 1"),
		requires = { "weapon:Revolver" },
		look = "Robot azul con sombrero marrón de pistolero.",
		costume = {
			piece("Head", "Block", { 1.25, 1.25, 1.25 }, { 0, 0, 0 }, rgb(90, 120, 160), nil, "Metal"),
			piece("Head", "Ball", { 0.3, 0.3, 0.3 }, { -0.3, 0.1, -0.62 }, rgb(200, 240, 255), nil, "Neon"),
			piece("Head", "Ball", { 0.3, 0.3, 0.3 }, { 0.3, 0.1, -0.62 }, rgb(200, 240, 255), nil, "Neon"),
			piece("Head", "Cylinder", { 0.15, 2.6, 2.6 }, { 0, 0.7, 0 }, rgb(120, 80, 40), { 0, 0, 90 }),
			piece("Head", "Block", { 1.1, 0.6, 1.1 }, { 0, 1.0, 0 }, rgb(120, 80, 40)),
		},
	},
	{
		id = "Athena",
		name = "Athena",
		weapon = "Aegis",
		passive = {
			name = "Lock in",
			desc = "+2 de espinas por nivel; más daño con menos vida y +150% de velocidad de ataque sin escudos Aegis activos.",
			perLevel = { Thorns = 2 },
			special = "LockIn",
		},
		stats = { MaxHealth = 125, Armor = shown(0.17), Thorns = 5 },
		movement = {},
		unlock = Unlock.max("tome.Thorns", 9, "Subir Thorns Tome al nivel 9"),
		requires = { "weapon:Aegis" },
		look = "Mujer con casco dorado de dos prolongaciones y hombreras doradas.",
		costume = {
			piece("Head", "Block", { 1.3, 0.5, 1.3 }, { 0, 0.55, 0 }, rgb(230, 190, 60), nil, "Metal"),
			piece("Head", "Wedge", { 0.2, 1.0, 0.4 }, { -0.5, 1.2, 0 }, rgb(230, 190, 60)),
			piece("Head", "Wedge", { 0.2, 1.0, 0.4 }, { 0.5, 1.2, 0 }, rgb(230, 190, 60)),
			piece("Torso", "Block", { 0.9, 0.4, 1.1 }, { -1.05, 0.85, 0 }, rgb(230, 190, 60), nil, "Metal"),
			piece("Torso", "Block", { 0.9, 0.4, 1.1 }, { 1.05, 0.85, 0 }, rgb(230, 190, 60), nil, "Metal"),
		},
	},
	{
		id = "Robinette",
		name = "Robinette",
		weapon = "Bow",
		passive = {
			name = "Stonks",
			desc = "+1% de oro por nivel; gana daño según el oro que lleva (+10% por cada 1.000, con tramos decrecientes).",
			perLevel = { GoldGain = 0.01 },
			special = "Stonks",
		},
		stats = { MoveSpeed = 0.1, PickupRange = 8, JumpHeight = 10, GoldGain = 0.05 },
		movement = {},
		unlock = Unlock.counter("complete.Forest.T2", 1, "Completar Forest Tier 2"),
		look = "Arquera rubia con sombrero verde puntiagudo y pluma roja.",
		costume = {
			piece("Head", "Wedge", { 1.3, 1.4, 1.3 }, { 0, 0.95, 0 }, rgb(60, 140, 60)),
			piece("Head", "Block", { 0.1, 0.9, 0.2 }, { 0.5, 1.3, 0.2 }, rgb(210, 40, 40), { 0, 0, -30 }),
			piece("Head", "Block", { 1.2, 1.2, 0.3 }, { 0, -0.3, 0.55 }, rgb(240, 210, 90)),
		},
	},
	{
		id = "Monke",
		name = "Monke",
		weapon = "Bananarang",
		passive = { name = "Monke Grip", desc = "Puede escalar paredes; +2 de vida máxima por nivel.", perLevel = { MaxHealth = 2 } },
		stats = { MaxHealth = 135, JumpHeight = 9, Damage = 0.15 },
		movement = { climb = true },
		-- [Provisional] sustituye a la condición de la referencia, que aún no se puede cumplir
		unlock = Unlock.instead("encontrar la Gold Key y abrir la jaula de Forest (secreto aún no implementado)", Unlock.counter("kills.enemy.Boar", 1500, "Matar 1.500 jabalíes")),
		requires = { "weapon:Bananarang" },
		look = "Simio marrón de hocico beige y gafas de sol.",
		costume = {
			piece("Head", "Block", { 1.3, 1.3, 1.3 }, { 0, 0, 0 }, rgb(120, 80, 45)),
			piece("Head", "Block", { 0.9, 0.6, 0.3 }, { 0, -0.25, -0.65 }, rgb(225, 195, 150)),
			piece("Head", "Block", { 1.1, 0.25, 0.1 }, { 0, 0.2, -0.7 }, rgb(15, 15, 15)),
			piece("Head", "Ball", { 0.5, 0.5, 0.5 }, { -0.75, 0.1, 0 }, rgb(120, 80, 45)),
			piece("Head", "Ball", { 0.5, 0.5, 0.5 }, { 0.75, 0.1, 0 }, rgb(120, 80, 45)),
		},
	},
	{
		id = "TonyMcZoom",
		name = "Tony McZoom",
		weapon = "WirelessDagger",
		passive = {
			name = "Zap",
			desc = "Moverse carga una descarga eléctrica; +2% de radio de recogida por nivel.",
			perLevel = { PickupMult = 0.02 },
			special = "Zap",
		},
		stats = {},
		movement = { fallImmune = true },
		-- [Provisional] sustituye a la condición de la referencia, que aún no se puede cumplir
		unlock = Unlock.instead("completar 2 Challenges (aún no implementados)", Unlock.counter("kills.enemy.Miniboss", 2, "Derrotar 2 minijefes")),
		requires = { "weapon:WirelessDagger" },
		look = "Capucha amarilla, rostro oscuro y tabla flotante.",
		costume = {
			piece("Head", "Block", { 1.4, 1.4, 1.4 }, { 0, 0.05, 0.08 }, rgb(240, 200, 40)),
			piece("Head", "Block", { 1.0, 0.9, 0.05 }, { 0, -0.05, -0.64 }, rgb(15, 15, 20)),
			piece("Root", "Block", { 1.6, 0.25, 3.8 }, { 0, -3.0, 0 }, rgb(60, 200, 230), nil, "Neon"),
		},
	},
	{
		id = "Bush",
		name = "Bush",
		weapon = "SniperRifle",
		passive = {
			name = "Bullseye",
			desc = "Marca enemigos con una mira; al impactarlos explotan. +1% de daño crítico por nivel.",
			perLevel = { CritDamage = 0.01 },
			special = "Bullseye",
		},
		stats = { Evasion = shown(0.10), PickupRange = 11 },
		movement = {},
		-- [Provisional] sustituye a la condición de la referencia, que aún no se puede cumplir
		unlock = Unlock.instead("encontrar y derrotar a Bush en Forest (encuentro aún no implementado)", Unlock.counter("kills.enemy.Wisp", 2000, "Matar 2.000 wisps")),
		requires = { "weapon:SniperRifle" },
		look = "Arbusto verde redondeado con dos ojos.",
		costume = {
			piece("Root", "Ball", { 4.5, 4.5, 4.5 }, { 0, 0.3, 0 }, rgb(60, 170, 60), nil, "Grass"),
			piece("Head", "Ball", { 0.35, 0.35, 0.35 }, { -0.35, 0.2, -0.75 }, rgb(250, 250, 250)),
			piece("Head", "Ball", { 0.35, 0.35, 0.35 }, { 0.35, 0.2, -0.75 }, rgb(250, 250, 250)),
		},
	},
	{
		id = "Birdo",
		name = "Birdo",
		weapon = "Tornado",
		passive = {
			name = "Float",
			desc = "Mantener salto permite planear; +1% de daño en el aire por nivel.",
			perLevel = { AirDamage = 0.01 },
			special = "Float",
		},
		stats = { MoveSpeed = 0.1, PickupRange = 10, JumpHeight = 9, ExtraJumps = 1 },
		movement = { fallImmune = true, float = true },
		-- [Provisional] sustituye a la condición de la referencia, que aún no se puede cumplir
		unlock = Unlock.instead("100 bajas con Tornado dentro de un tornado de Desert (tormentas aún no implementadas)", Unlock.counter("kills.enemy.Scorpion", 3000, "Matar 3.000 escorpiones")),
		look = "Ave roja de plumaje en punta, pico amarillo y gafas azules.",
		costume = {
			piece("Head", "Block", { 1.3, 1.3, 1.3 }, { 0, 0, 0 }, rgb(210, 50, 40)),
			piece("Head", "Wedge", { 0.6, 0.4, 0.8 }, { 0, -0.15, -0.95 }, rgb(250, 200, 40), { 90, 0, 0 }),
			piece("Head", "Block", { 1.1, 0.3, 0.1 }, { 0, 0.25, -0.68 }, rgb(70, 140, 230)),
			piece("Head", "Wedge", { 0.3, 0.9, 0.5 }, { -0.2, 1.05, 0 }, rgb(210, 50, 40)),
			piece("Head", "Wedge", { 0.3, 0.9, 0.5 }, { 0.2, 1.05, 0.2 }, rgb(210, 50, 40)),
		},
	},
	{
		id = "Noelle",
		name = "Noelle",
		weapon = "Frostwalker",
		passive = {
			name = "Enduring",
			desc = "+0,75% de tamaño por nivel; +1,5% de daño por cada enemigo congelado ahora mismo.",
			perLevel = { Size = 0.0075 },
			special = "Enduring",
		},
		stats = {},
		movement = {},
		unlock = Unlock.counter("microwave.IceCrystal.streak3", 1, "Duplicar Ice Crystal 3 veces seguidas con Microwave"),
		requires = { "weapon:Frostwalker" },
		look = "Capucha azul, rostro oscuro con dibujo claro y dos orejas claras alargadas.",
		costume = {
			piece("Head", "Block", { 1.4, 1.4, 1.4 }, { 0, 0.05, 0.08 }, rgb(50, 90, 180)),
			piece("Head", "Block", { 1.0, 0.9, 0.05 }, { 0, -0.05, -0.64 }, rgb(20, 25, 40)),
			piece("Head", "Block", { 0.25, 1.4, 0.2 }, { -0.4, 1.3, 0 }, rgb(230, 235, 245)),
			piece("Head", "Block", { 0.25, 1.4, 0.2 }, { 0.4, 1.3, 0 }, rgb(230, 235, 245)),
		},
	},
	{
		id = "Amog",
		name = "Amog",
		weapon = "PoisonFlask",
		passive = {
			name = "Plague",
			desc = "Los envenenados explotan al morir y contagian su veneno; +1% de daño de veneno por nivel.",
			perLevel = { PoisonDamage = 0.01 },
			special = "Plague",
		},
		stats = { MaxHealth = 130, Armor = shown(0.12), PickupRange = 10 },
		movement = {},
		unlock = Unlock.counter("poisoned.MoldyCheese", 50000, "Envenenar 50.000 enemigos con Moldy Cheese"),
		requires = { "weapon:PoisonFlask" },
		look = "Traje amarillo de protección con máscara antigás negra.",
		costume = {
			piece("Head", "Block", { 1.4, 1.4, 1.4 }, { 0, 0.05, 0.05 }, rgb(230, 200, 40)),
			piece("Head", "Block", { 1.0, 0.8, 0.2 }, { 0, -0.1, -0.7 }, rgb(25, 25, 25)),
			piece("Head", "Cylinder", { 0.3, 0.5, 0.5 }, { -0.6, -0.3, -0.7 }, rgb(40, 40, 40)),
			piece("Head", "Cylinder", { 0.3, 0.5, 0.5 }, { 0.6, -0.3, -0.7 }, rgb(40, 40, 40)),
		},
	},
	{
		id = "Spaceman",
		name = "Spaceman",
		weapon = "BlackHole",
		passive = { name = "Quantum XP Theory", desc = "+1,5% de experiencia por nivel.", perLevel = { XPGain = 0.015 } },
		stats = { XPGain = 0.05 },
		movement = { fallImmune = true, lowGravity = true },
		-- [Provisional] sustituye a la condición de la referencia, que aún no se puede cumplir
		unlock = Unlock.instead("completar 6 Challenges (aún no implementados)", Unlock.counter("finalBossKills", 5, "Derrotar 5 jefes finales")),
		requires = { "weapon:BlackHole" },
		look = "Astronauta de traje blanco con visor dorado opaco.",
		costume = {
			piece("Head", "Ball", { 1.9, 1.9, 1.9 }, { 0, 0.1, 0 }, rgb(235, 235, 240)),
			piece("Head", "Ball", { 1.4, 1.1, 0.9 }, { 0, 0.05, -0.55 }, rgb(240, 170, 40), nil, "Glass"),
		},
	},
	{
		id = "Bandit",
		name = "Bandit",
		weapon = "Dexecutioner",
		passive = { name = "Flowstate", desc = "+1% de velocidad de ataque por nivel.", perLevel = { AttackSpeed = 0.01 } },
		stats = { Evasion = shown(0.10), MoveSpeed = 0.1, PickupRange = 9, JumpHeight = 8 },
		movement = {},
		-- [Provisional] sustituye a la condición de la referencia, que aún no se puede cumplir
		unlock = Unlock.instead("encontrar y derrotar a Bandit en Desert (encuentro aún no implementado)", Unlock.counter("kills.enemy.Cactus", 2000, "Matar 2.000 cactus")),
		requires = { "weapon:Dexecutioner" },
		look = "Sombrero de ala ancha, antifaz negro y bigote.",
		costume = {
			piece("Head", "Cylinder", { 0.15, 2.6, 2.6 }, { 0, 0.6, 0 }, rgb(30, 30, 30), { 0, 0, 90 }),
			piece("Head", "Block", { 1.2, 0.8, 1.2 }, { 0, 1.0, 0 }, rgb(30, 30, 30)),
			piece("Head", "Block", { 1.1, 0.3, 0.1 }, { 0, 0.15, -0.62 }, rgb(10, 10, 10)),
		},
	},
	{
		id = "Ninja",
		name = "Ninja",
		weapon = "Katana",
		passive = {
			name = "Shadowstep",
			desc = "Al evadir un ataque, ejecuta al enemigo que lo lanzó; +0,5% de evasión por nivel.",
			perLevel = { Evasion = 0.005 },
			special = "Shadowstep",
		},
		stats = { Evasion = shown(0.06), MoveSpeed = 0.2, PickupRange = 8, JumpHeight = 9 },
		movement = {},
		unlock = Unlock.counter("complete.Desert.T1", 1, "Completar Desert Tier 1"),
		requires = { "weapon:Katana" },
		look = "Figura negra con capucha y máscara; sólo se ven los ojos.",
		costume = {
			piece("Head", "Block", { 1.35, 1.35, 1.35 }, { 0, 0.03, 0.03 }, rgb(20, 20, 25)),
			piece("Head", "Block", { 0.9, 0.18, 0.05 }, { 0, 0.15, -0.67 }, rgb(235, 235, 235)),
		},
	},
	{
		id = "Vlad",
		name = "Vlad",
		weapon = "BloodMagic",
		passive = { name = "Vampire", desc = "+1% de robo de vida por nivel.", perLevel = { Lifesteal = 0.01 } },
		stats = { Lifesteal = 0.05 },
		movement = {},
		unlock = Unlock.counter("complete.Desert.T2", 1, "Completar Desert Tier 2"),
		requires = { "weapon:BloodMagic" },
		look = "Hechicero con sombrero rojo puntiagudo y ojos claros en la sombra.",
		costume = {
			piece("Head", "Cylinder", { 0.15, 2.6, 2.6 }, { 0, 0.55, 0 }, rgb(150, 20, 30), { 0, 0, 90 }),
			piece("Head", "Wedge", { 1.2, 1.8, 1.2 }, { 0, 1.45, 0 }, rgb(150, 20, 30)),
			piece("Head", "Block", { 1.0, 0.8, 0.05 }, { 0, -0.05, -0.64 }, rgb(30, 15, 20)),
		},
	},
	{
		id = "SirChadwell",
		name = "Sir Chadwell",
		weapon = "CorruptedSword",
		passive = { name = "Corrupted", desc = "+1% de dificultad por nivel.", perLevel = { Difficulty = 0.01 } },
		stats = { MaxHealth = 130, Armor = shown(0.10) },
		movement = {},
		unlock = Unlock.counter("complete.Forest.T3", 1, "Completar Forest Tier 3"),
		requires = { "weapon:CorruptedSword" },
		look = "Caballero de armadura gris oscura con abertura roja en zigzag.",
		costume = {
			piece("Head", "Block", { 1.35, 1.35, 1.35 }, { 0, 0.05, 0 }, rgb(60, 60, 70), nil, "Metal"),
			piece("Head", "Block", { 0.9, 0.15, 0.05 }, { 0, 0.1, -0.68 }, rgb(255, 40, 40), nil, "Neon"),
			piece("Head", "Wedge", { 0.2, 0.9, 0.6 }, { 0, 1.0, 0.4 }, rgb(200, 30, 30)),
		},
	},
	{
		id = "Dicehead",
		name = "Dicehead",
		weapon = "Dice",
		passive = {
			name = "Gamba",
			desc = "Cada nivel mejora una estadística aleatoria con rendimientos decrecientes.",
			special = "Gamba",
		},
		stats = {},
		movement = {},
		unlock = Unlock.counter("quests", 100, "Completar 100 quests"),
		requires = { "weapon:Dice" },
		look = "Humanoide con un dado blanco por cabeza, chaqueta oscura y corbata roja.",
		costume = {
			piece("Head", "Block", { 1.5, 1.5, 1.5 }, { 0, 0.1, 0 }, rgb(245, 245, 245)),
			piece("Head", "Ball", { 0.25, 0.25, 0.25 }, { 0, 0.1, -0.76 }, rgb(15, 15, 15)),
			piece("Head", "Ball", { 0.25, 0.25, 0.25 }, { -0.4, 0.5, -0.76 }, rgb(15, 15, 15)),
			piece("Head", "Ball", { 0.25, 0.25, 0.25 }, { 0.4, -0.3, -0.76 }, rgb(15, 15, 15)),
			piece("Torso", "Block", { 0.3, 1.2, 0.1 }, { 0, 0, -0.55 }, rgb(200, 30, 30)),
		},
	},
	{
		id = "Roberto",
		name = "Roberto",
		weapon = "Scythe",
		passive = {
			name = "Hoarder",
			desc = "Genera un cofre gratis cada 60 s; el intervalo crece 2,5 s por cofre hasta 120 s.",
			special = "Hoarder",
		},
		stats = {},
		movement = {},
		-- [Provisional] sustituye a la condición de la referencia, que aún no se puede cumplir
		unlock = Unlock.instead("derrotar a Spooky Steve en Graveyard (aún no implementado)", Unlock.counter("chestsBought", 100, "Abrir 100 cofres")),
		look = "Fantasma de sábana blanca cónica, gafas negras, piernas y zapatos visibles.",
		costume = {
			piece("Root", "Wedge", { 3.2, 4.2, 3.2 }, { 0, 1.0, 0 }, rgb(245, 245, 245), nil, "Fabric"),
			piece("Head", "Block", { 1.0, 0.25, 0.1 }, { 0, 0.4, -1.0 }, rgb(15, 15, 15)),
		},
	},
}

return Characters
