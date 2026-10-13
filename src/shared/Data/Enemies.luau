-- Enemigos, minijefes y jefes. El bestiario completo NO está documentado en las fuentes: estos
-- registros son una base PROVISIONAL (vida, daño, velocidad y patrones) que debe calibrarse.
--
-- ai: Chase (persigue y golpea), Charge (embiste tras preparar), Float (flota ignorando el suelo),
--     Ranged (mantiene distancia y dispara), Boss (máquina de estados con `attacks`)
-- shape: Block | Ball | Cylinder | Wedge

local Enemies = {
	-- Forest
	Goblin = { name = "Goblin", family = "Goblin", ai = "Chase", health = 14, speed = 10, damage = 8, xp = 1, gold = 1, size = { 2.4, 3.2, 2.4 }, shape = "Block", color = { 90, 170, 70 } },
	Skeleton = { name = "Esqueleto", family = "Skeleton", ai = "Chase", health = 22, speed = 8, damage = 10, xp = 2, gold = 1, size = { 2.2, 4.2, 1.6 }, shape = "Block", color = { 235, 230, 210 } },
	Wisp = { name = "Wisp", family = "Wisp", ai = "Float", health = 8, speed = 17, damage = 6, xp = 1, gold = 1, size = { 1.8, 1.8, 1.8 }, shape = "Ball", color = { 140, 220, 255 }, neon = true, hover = 3 },
	Boar = { name = "Jabalí", family = "Boar", ai = "Charge", health = 30, speed = 9, damage = 14, xp = 3, gold = 2, size = { 3, 2.6, 4.2 }, shape = "Block", color = { 120, 80, 50 }, chargeSpeed = 38 },
	GoblinShaman = { name = "Chamán goblin", family = "Goblin", ai = "Ranged", health = 18, speed = 8, damage = 9, xp = 3, gold = 2, size = { 2.4, 3.6, 2.4 }, shape = "Cylinder", color = { 60, 130, 120 }, range = 30, projectileSpeed = 30 },

	-- Desert
	Scorpion = { name = "Escorpión", family = "Scorpion", ai = "Chase", health = 20, speed = 11, damage = 10, xp = 2, gold = 1, size = { 3.2, 1.6, 3.2 }, shape = "Block", color = { 200, 120, 50 } },
	CactusEnemy = { name = "Cactus", family = "Cactus", ai = "Ranged", health = 26, speed = 5, damage = 10, xp = 2, gold = 1, size = { 1.8, 4.4, 1.8 }, shape = "Cylinder", color = { 70, 150, 70 }, range = 28, projectileSpeed = 26 },
	BoneRoller = { name = "Bola de huesos", family = "Skeleton", ai = "Charge", health = 40, speed = 8, damage = 16, xp = 3, gold = 2, size = { 3.6, 3.6, 3.6 }, shape = "Ball", color = { 225, 220, 200 }, chargeSpeed = 42 },
	DesertWisp = { name = "Wisp", family = "Wisp", ai = "Float", health = 10, speed = 18, damage = 7, xp = 1, gold = 1, size = { 1.8, 1.8, 1.8 }, shape = "Ball", color = { 255, 200, 120 }, neon = true, hover = 3 },

	-- Final Swarm
	SwarmGhost = { name = "Fantasma", family = "Ghost", ai = "Float", health = 60, speed = 14, damage = 20, xp = 2, gold = 2, size = { 2.4, 3, 2.4 }, shape = "Ball", color = { 230, 60, 60 }, neon = true, hover = 2, swarm = true },

	-- Minijefes
	ChunkhamTheTerrible = { name = "Chunkham The Terrible", family = "Miniboss", ai = "Boss", miniboss = true, health = 900, speed = 9, damage = 22, xp = 40, gold = 40, size = { 6, 7, 6 }, shape = "Block", color = { 120, 90, 60 }, attacks = { "Slam", "Charge" } },
	StoneGolem = { name = "Stone Golem", family = "Miniboss", ai = "Boss", miniboss = true, health = 1300, speed = 6, damage = 28, xp = 50, gold = 50, size = { 7, 9, 7 }, shape = "Block", color = { 130, 130, 140 }, attacks = { "Slam", "Ring" } },
	SandGolem = { name = "Sand Golem", family = "Miniboss", ai = "Boss", miniboss = true, health = 1400, speed = 6, damage = 28, xp = 50, gold = 50, size = { 7, 9, 7 }, shape = "Block", color = { 210, 180, 120 }, attacks = { "Slam", "Ring" } },
	Scorpionussy = { name = "Escorpionaza", family = "Miniboss", ai = "Boss", miniboss = true, health = 1100, speed = 11, damage = 24, xp = 45, gold = 45, size = { 8, 3, 8 }, shape = "Block", color = { 170, 60, 40 }, attacks = { "Charge", "Ring" } },

	-- Jefes de fase
	LilBark = { name = "Lil Bark", family = "Boss", ai = "Boss", boss = true, health = 4000, speed = 8, damage = 30, xp = 120, gold = 120, size = { 9, 12, 9 }, shape = "Cylinder", color = { 110, 75, 45 }, attacks = { "Slam", "Ring", "Summon" } },
	Chadbark = { name = "Chadbark", family = "Boss", ai = "Boss", boss = true, health = 9000, speed = 9, damage = 40, xp = 200, gold = 200, size = { 11, 14, 11 }, shape = "Cylinder", color = { 90, 60, 35 }, attacks = { "Slam", "Ring", "Charge", "Summon" } },
	BarkVader = { name = "Bark Vader", family = "Boss", ai = "Boss", boss = true, health = 18000, speed = 10, damage = 50, xp = 300, gold = 300, size = { 12, 16, 12 }, shape = "Cylinder", color = { 40, 30, 30 }, attacks = { "Slam", "Ring", "Charge", "Summon" } },
	Anubis = { name = "Anubis", family = "Boss", ai = "Boss", boss = true, health = 5000, speed = 9, damage = 32, xp = 140, gold = 140, size = { 8, 13, 8 }, shape = "Block", color = { 40, 40, 50 }, attacks = { "Ring", "Slam", "Summon" } },
	Anubruh = { name = "Anubruh", family = "Boss", ai = "Boss", boss = true, health = 11000, speed = 10, damage = 42, xp = 220, gold = 220, size = { 9, 14, 9 }, shape = "Block", color = { 30, 30, 40 }, attacks = { "Ring", "Slam", "Charge", "Summon" } },
	JugeAnubis = { name = "Juge Anubis", family = "Boss", ai = "Boss", boss = true, health = 21000, speed = 11, damage = 55, xp = 320, gold = 320, size = { 10, 16, 10 }, shape = "Block", color = { 200, 170, 60 }, attacks = { "Ring", "Slam", "Charge", "Summon" } },
}

return Enemies
