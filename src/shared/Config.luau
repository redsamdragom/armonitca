-- Configuración central del juego: balance de la partida, armas, pasivas y enemigos.
-- Todo el balance vive aquí para poder ajustarlo sin tocar la lógica.

local Config = {}

Config.Run = {
	Duration = 600, -- segundos hasta que aparece el jefe final
	MaxEnemies = 150,
	SpawnDistanceMin = 45,
	SpawnDistanceMax = 70,
	BaseSpawnInterval = 1.2,
	MinSpawnInterval = 0.2,
	HealthScalePerMinute = 0.35, -- +35% de vida enemiga por minuto
	RestartDelay = 8,
	ArenaHalfSize = 280,
}

Config.Player = {
	MaxHealth = 100,
	WalkSpeed = 20,
	PickupRadius = 10,
	MaxWeapons = 4,
	StartingWeapon = "MagicBolt",
}

function Config.xpToNext(level: number): number
	return math.floor(5 + (level - 1) * 4 + (level - 1) ^ 1.5)
end

Config.Weapons = {
	MagicBolt = {
		Name = "Rayo Mágico",
		Description = "Dispara al enemigo más cercano.",
		Kind = "Projectile",
		MaxLevel = 6,
		Damage = 12,
		Cooldown = 1.0,
		Speed = 70,
		Range = 70,
		Count = 1,
		Pierce = 1,
		Color = Color3.fromRGB(120, 180, 255),
	},
	Aura = {
		Name = "Aura Ardiente",
		Description = "Quema a los enemigos a tu alrededor.",
		Kind = "Aura",
		MaxLevel = 6,
		Damage = 5,
		Cooldown = 0.5,
		Radius = 9,
		Color = Color3.fromRGB(255, 120, 60),
	},
	Blades = {
		Name = "Cuchillas Orbitales",
		Description = "Cuchillas que giran a tu alrededor.",
		Kind = "Orbit",
		MaxLevel = 6,
		Damage = 10,
		Cooldown = 0.4, -- tiempo mínimo entre golpes al mismo enemigo
		Radius = 7,
		Count = 2,
		RotationSpeed = 3,
		Color = Color3.fromRGB(230, 230, 240),
	},
}

-- Estadísticas de un arma según su nivel.
function Config.weaponStats(id: string, level: number)
	local base = Config.Weapons[id]
	local stats = table.clone(base)
	stats.Damage = base.Damage * (1 + 0.3 * (level - 1))
	if base.Count then
		stats.Count = base.Count + math.floor((level - 1) / 2)
	end
	if base.Radius then
		stats.Radius = base.Radius * (1 + 0.1 * (level - 1))
	end
	if base.Pierce then
		stats.Pierce = base.Pierce + math.floor((level - 1) / 3)
	end
	return stats
end

Config.Passives = {
	Might = { Name = "Fuerza", Description = "+15% de daño", MaxLevel = 5, Stat = "DamageMult", PerLevel = 0.15 },
	Haste = { Name = "Prisa", Description = "-8% de recarga", MaxLevel = 5, Stat = "CooldownMult", PerLevel = -0.08 },
	Swiftness = { Name = "Agilidad", Description = "+10% de velocidad", MaxLevel = 5, Stat = "SpeedMult", PerLevel = 0.10 },
	Vitality = { Name = "Vitalidad", Description = "+20 de vida máxima", MaxLevel = 5, Stat = "BonusHealth", PerLevel = 20 },
	Magnet = { Name = "Imán", Description = "+30% de radio de recogida", MaxLevel = 5, Stat = "PickupMult", PerLevel = 0.30 },
}

-- Damage es daño por segundo mientras el enemigo está en contacto con el jugador.
Config.Enemies = {
	Slime = {
		Health = 15,
		Speed = 9,
		Damage = 10,
		XP = 1,
		Size = Vector3.new(3, 3, 3),
		Color = Color3.fromRGB(90, 200, 90),
		UnlockTime = 0,
		Weight = 10,
	},
	Runner = {
		Health = 10,
		Speed = 16,
		Damage = 8,
		XP = 1,
		Size = Vector3.new(2, 4, 2),
		Color = Color3.fromRGB(230, 200, 60),
		UnlockTime = 60,
		Weight = 5,
	},
	Brute = {
		Health = 80,
		Speed = 7,
		Damage = 25,
		XP = 5,
		Size = Vector3.new(5, 6, 5),
		Color = Color3.fromRGB(170, 60, 60),
		UnlockTime = 180,
		Weight = 2,
	},
	Boss = {
		Health = 3000,
		Speed = 10,
		Damage = 40,
		XP = 0,
		Size = Vector3.new(12, 14, 12),
		Color = Color3.fromRGB(120, 40, 160),
		UnlockTime = math.huge,
		Weight = 0,
	},
}

return Config
