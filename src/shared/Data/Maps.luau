-- Mapas, tiers y etapas. Relojes, poblaciones y recuentos de interactuables son PROVISIONALES.
-- `playable = false` significa que el mapa está registrado pero su recorrido no está implementado.
--
-- Relojes: `stageDuration` es la cuenta atrás de la etapa. Al llegar a 0 empieza el Final Swarm,
-- que tiene su propio reloj (`swarmSeconds`). Ver Run/Director.luau.

local Unlock = require(script.Parent.Unlock)

local Maps = {
	{
		id = "Forest",
		name = "Forest",
		desc = "Bosque verde con árboles, rocas, desniveles y ruinas.",
		playable = true,
		unlock = Unlock.start(),
		stagesPerTier = 3, -- [Pendiente]
		stageDuration = 600, -- Referencia comunitaria: ventanas de 10 minutos
		size = 520,
		biome = {
			ground = "Grass",
			groundColor = { 86, 150, 70 },
			hillMaterial = "Grass",
			rock = { 120, 115, 110 },
			trees = 70,
			treeTrunk = { 100, 70, 45 },
			treeLeaves = { 60, 140, 60 },
			ruins = 10,
			ruinColor = { 150, 145, 135 },
			fog = { 170, 210, 230 },
			ambient = { 140, 140, 150 },
		},
		tiers = {
			{ boss = "LilBark", difficulty = 0 },
			{ boss = "Chadbark", difficulty = 0.35 },
			{ boss = "BarkVader", difficulty = 0.8 },
		},
		spawns = {
			{ enemy = "Goblin", from = 0, weight = 10 },
			{ enemy = "Skeleton", from = 45, weight = 6 },
			{ enemy = "Wisp", from = 90, weight = 5 },
			{ enemy = "Boar", from = 180, weight = 3 },
			{ enemy = "GoblinShaman", from = 240, weight = 2 },
		},
		minibosses = { { enemy = "ChunkhamTheTerrible", at = 180 }, { enemy = "StoneGolem", at = 420 } },
		interactables = {
			Chest = 14,
			ChargeShrine = 5,
			GoldenChargeShrine = 1,
			GreedShrine = 1,
			BossCurse = 1,
			ShrineOfSucc = 1,
			Microwave = 1,
			ShadyGuy = 1,
			Pot = 30,
		},
	},
	{
		id = "Desert",
		name = "Desert",
		desc = "Arena, roca, cactus y tormentas. (Tormentas, tornados ambientales y secretos pendientes.)",
		playable = true,
		unlock = Unlock.counter("event.ForestT2Stage2.char.CL4NK", 1, "Llegar a la etapa 2 de Forest Tier 2 con CL4NK"),
		stagesPerTier = 3,
		stageDuration = 600,
		size = 520,
		biome = {
			ground = "Sand",
			groundColor = { 220, 190, 130 },
			hillMaterial = "Sandstone",
			rock = { 190, 150, 100 },
			trees = 45, -- cactus
			cactus = true,
			treeTrunk = { 70, 150, 70 },
			treeLeaves = { 70, 150, 70 },
			ruins = 14,
			ruinColor = { 210, 180, 120 },
			fog = { 240, 215, 170 },
			ambient = { 160, 140, 120 },
		},
		tiers = {
			{ boss = "Anubis", difficulty = 0.2 },
			{ boss = "Anubruh", difficulty = 0.55 },
			{ boss = "JugeAnubis", difficulty = 1.0 },
		},
		spawns = {
			{ enemy = "Scorpion", from = 0, weight = 10 },
			{ enemy = "DesertWisp", from = 60, weight = 5 },
			{ enemy = "CactusEnemy", from = 120, weight = 4 },
			{ enemy = "BoneRoller", from = 200, weight = 3 },
		},
		minibosses = { { enemy = "Scorpionussy", at = 180 }, { enemy = "SandGolem", at = 420 } },
		interactables = {
			Chest = 14,
			ChargeShrine = 5,
			GoldenChargeShrine = 1,
			GreedShrine = 1,
			BossCurse = 1,
			ShrineOfSucc = 1,
			Microwave = 1,
			ShadyGuy = 1,
			Pot = 30,
		},
	},
	{
		id = "Graveyard",
		name = "Graveyard",
		desc = "Cementerio y criptas con guardianes, llaves y lava. (Recorrido pendiente de implementar.)",
		playable = false,
		unlock = Unlock.counter("event.DesertT2Undead.char.Calcium", 1, "Invocar y derrotar al jefe no muerto de Desert Tier 2 con Calcium"),
		stagesPerTier = 2,
		stageDuration = 960,
		tiers = { { boss = "BigBob", difficulty = 0.6 } },
	},
}

Maps.FinalSwarm = {
	enemy = "SwarmGhost",
	baseInterval = 0.25, -- [Pendiente]
	batch = 3,
	speedUpAfter = 1200, -- Referencia comunitaria: desde los 20 min de enjambre aceleran
	speedUpPerMinute = 0.08, -- [Pendiente]
	ccImmuneAfter = 1800, -- [Pendiente] tolerancia al control decreciente hasta inmunidad
	silverMultCap = 8, -- Referencia oficial: límite 8×
}

return Maps
