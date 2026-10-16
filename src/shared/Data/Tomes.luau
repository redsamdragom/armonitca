-- Catálogo de los 23 tomos. `value` es el incremento de una oferta Común (referencia comunitaria);
-- los multiplicadores de rareza se aplican encima. Chaos elige una estadística aleatoria.

local Unlock = require(script.Parent.Unlock)

local Tomes = {
	{ id = "Agility", name = "Agility Tome", stat = "MoveSpeed", value = 0.15, desc = "+15% de velocidad de movimiento.", unlock = Unlock.start() },
	{ id = "Cooldown", name = "Cooldown Tome", stat = "AttackSpeed", value = 0.075, desc = "+7,5% de velocidad de ataque.", unlock = Unlock.start() },
	{ id = "Damage", name = "Damage Tome", stat = "Damage", value = 0.08, desc = "+0,08 al multiplicador de daño.", unlock = Unlock.start() },
	{ id = "Evasion", name = "Evasion Tome", stat = "Evasion", value = 0.10, desc = "+10% de evasión (con rendimientos decrecientes).", unlock = Unlock.start() },
	{ id = "Golden", name = "Golden Tome", stat = "GoldGain", value = 0.12, desc = "+12% de oro obtenido.", unlock = Unlock.start() },
	{ id = "Health", name = "Health Tome", stat = "MaxHealth", value = 25, desc = "+25 de vida máxima.", unlock = Unlock.start() },
	{ id = "Knockback", name = "Knockback Tome", stat = "Knockback", value = 0.20, desc = "+20% de retroceso.", unlock = Unlock.start() },
	{ id = "Precision", name = "Precision Tome", stat = "CritChance", value = 0.07, desc = "+7% de probabilidad crítica (puede superar 100%).", unlock = Unlock.start() },
	{ id = "ProjectileSpeed", name = "Projectile Speed Tome", stat = "ProjectileSpeed", value = 0.15, desc = "+15% de velocidad de proyectiles.", unlock = Unlock.start() },
	{ id = "Regen", name = "Regen Tome", stat = "Regen", value = 40, desc = "+40 de vida regenerada por minuto.", unlock = Unlock.start() },
	{ id = "Shield", name = "Shield Tome", stat = "Shield", value = 25, desc = "+25 de escudo.", unlock = Unlock.start() },
	{ id = "Silver", name = "Silver Tome", stat = "SilverGain", value = 0.12, desc = "+12% de plata obtenida.", unlock = Unlock.start() },
	{ id = "Size", name = "Size Tome", stat = "Size", value = 0.10, desc = "+10% de tamaño de ataques.", unlock = Unlock.start() },
	{
		id = "Armor",
		name = "Armor Tome",
		stat = "Armor",
		value = 0.12,
		desc = "+12% de armadura (con rendimientos decrecientes).",
		unlock = Unlock.counter("kills.char.SirOofie", 5000, "Matar 5.000 enemigos con Sir Oofie"),
	},
	{
		id = "Attraction",
		name = "Attraction Tome",
		stat = "PickupMult",
		value = 0.75,
		desc = "+75% de radio de recogida.",
		unlock = Unlock.counter("shrineSucc", 8, "Usar el Shrine of Succ 8 veces"),
	},
	{
		id = "Bloody",
		name = "Bloody Tome",
		stat = "BloodyHeal",
		value = 0.10,
		desc = "+10% de probabilidad de curar 1 de vida al impactar.",
		unlock = Unlock.counter("kills", 12500, "Matar 12.500 enemigos en total"),
	},
	{
		id = "Chaos",
		name = "Chaos Tome",
		stat = "Chaos",
		value = 1,
		desc = "Cada elección mejora una estadística aleatoria.",
		unlock = Unlock.counter("event.AllChargeShrinesT3", 1, "Cargar todos los Charge Shrines de las 3 etapas de una partida Tier 3 sin salir de sus zonas"),
	},
	{
		id = "Cursed",
		name = "Cursed Tome",
		stat = "Difficulty",
		value = 0.035,
		desc = "+3,5% de dificultad: más enemigos y más fuertes.",
		unlock = Unlock.counter("event.StageBossUnder5", 1, "Derrotar un Stage Boss en menos de 5 minutos"),
	},
	{
		id = "Duration",
		name = "Duration Tome",
		stat = "Duration",
		value = 0.15,
		desc = "+15% de duración de ataques y efectos.",
		unlock = Unlock.max("weapon.Axe", 10, "Subir Axe al nivel 10"),
	},
	{
		id = "Luck",
		name = "Luck Tome",
		stat = "Luck",
		value = 0.08,
		desc = "+8% de suerte: mejores recompensas.",
		unlock = Unlock.counter("drop.LuckTome", 1, "Drop raro (0,01%) al matar enemigos"),
	},
	{
		id = "Quantity",
		name = "Quantity Tome",
		stat = "Quantity",
		value = 1,
		desc = "+1 a la cantidad de ataques y proyectiles.",
		unlock = Unlock.counter("projectiles", 5000, "Disparar 5.000 proyectiles en total"),
	},
	{
		id = "Thorns",
		name = "Thorns Tome",
		stat = "Thorns",
		value = 15,
		desc = "+15 de daño de represalia.",
		unlock = Unlock.counter("aegis.blocks", 250, "Bloquear 250 ataques con Aegis"),
	},
	{
		id = "XP",
		name = "XP Tome",
		stat = "XPGain",
		value = 0.07,
		desc = "+7% de experiencia.",
		unlock = Unlock.max("run.pots", 20, "Romper 20 vasijas en una partida"),
	},
}

-- Estadísticas que puede tocar Chaos Tome (sin Silver Gain ni Jump Height desde Christmas Patch).
Tomes.ChaosPool = {
	"MoveSpeed", "AttackSpeed", "Damage", "Evasion", "GoldGain", "MaxHealth", "Knockback", "CritChance",
	"ProjectileSpeed", "Regen", "Shield", "Size", "Armor", "PickupMult", "Duration", "Luck", "XPGain", "Thorns",
}

return Tomes
