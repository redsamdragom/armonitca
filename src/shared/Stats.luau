-- Definición de las estadísticas de una partida y fórmulas compartidas.
-- Las fórmulas de rendimientos decrecientes son PROVISIONALES (ver docs/MATRIZ.md).

local Stats = {}

-- Valor por defecto de cada estadística. Las marcadas como absolutas se sustituyen por el valor
-- del personaje; el resto se suman como bonificaciones.
Stats.Defaults = {
	-- Supervivencia
	MaxHealth = 100,
	Regen = 0, -- vida por minuto
	Overheal = 0, -- capacidad de sobrecuración en fracción de la vida máxima
	Shield = 0,
	Armor = 0, -- bruto
	Evasion = 0, -- bruto
	Lifesteal = 0, -- probabilidad de curar 1 al impactar [Pendiente]
	Thorns = 0,
	-- Ataque
	Damage = 0,
	CritChance = 0,
	CritDamage = 0,
	AttackSpeed = 0,
	Quantity = 0,
	Bounces = 0,
	-- Geometría y efectos
	Size = 0,
	ProjectileSpeed = 0,
	Duration = 0,
	Knockback = 0,
	EliteDamage = 0,
	-- Movimiento
	MoveSpeed = 0,
	ExtraJumps = 0,
	JumpHeight = 8,
	-- Recompensas
	Luck = 0,
	PickupRange = 8,
	PickupMult = 0,
	XPGain = 0,
	GoldGain = 0,
	SilverGain = 0,
	-- Presión de partida
	Difficulty = 0,
	EliteSpawn = 0,
	PowerupMult = 0,
	PowerupChance = 0,
	-- Específicas
	BloodyHeal = 0,
	AirDamage = 0,
	PoisonDamage = 0,
}

Stats.Absolute = { MaxHealth = true, Shield = true, PickupRange = true, JumpHeight = true, Thorns = true }

-- Nombres y formato para la interfaz.
Stats.Display = {
	MaxHealth = { "Vida máxima", "flat" },
	Regen = { "Regeneración", "flat" },
	Overheal = { "Sobrecuración", "pct" },
	Shield = { "Escudo", "flat" },
	Armor = { "Armadura", "eff" },
	Evasion = { "Evasión", "eff" },
	Lifesteal = { "Robo de vida", "pct" },
	Thorns = { "Espinas", "flat" },
	Damage = { "Daño", "pct" },
	CritChance = { "Probabilidad crítica", "pct" },
	CritDamage = { "Daño crítico", "pct" },
	AttackSpeed = { "Velocidad de ataque", "pct" },
	Quantity = { "Cantidad", "flat" },
	Bounces = { "Rebotes", "flat" },
	Size = { "Tamaño", "pct" },
	ProjectileSpeed = { "Velocidad de proyectil", "pct" },
	Duration = { "Duración", "pct" },
	Knockback = { "Retroceso", "pct" },
	EliteDamage = { "Daño contra élites", "pct" },
	MoveSpeed = { "Velocidad", "pct" },
	ExtraJumps = { "Saltos extra", "flat" },
	JumpHeight = { "Altura de salto", "flat" },
	Luck = { "Suerte", "pct" },
	PickupRange = { "Radio de recogida", "flat" },
	PickupMult = { "Radio de recogida", "pct" },
	XPGain = { "Experiencia", "pct" },
	GoldGain = { "Oro", "pct" },
	SilverGain = { "Plata", "pct" },
	Difficulty = { "Dificultad", "pct" },
	EliteSpawn = { "Aparición de élites", "pct" },
	PowerupMult = { "Multiplicador de powerups", "pct" },
	PowerupChance = { "Probabilidad de powerups", "pct" },
	BloodyHeal = { "Curación al impactar", "pct" },
	AirDamage = { "Daño en el aire", "pct" },
	PoisonDamage = { "Daño de veneno", "pct" },
}

-- Rendimientos decrecientes de armadura y evasión [Pendiente]: efectivo = bruto / (1 + bruto)
function Stats.diminishing(raw: number): number
	if raw <= 0 then
		return raw
	end
	return raw / (1 + raw)
end

-- Probabilidad hiperbólica usada por varios objetos: k·n / (k·n + c)
function Stats.hyperbolic(k: number, n: number, c: number): number
	if n <= 0 then
		return 0
	end
	return (k * n) / (k * n + c)
end

function Stats.format(stat: string, value: number): string
	local display = Stats.Display[stat]
	local kind = display and display[2] or "flat"
	if kind == "pct" then
		return string.format("%+.1f%%", value * 100)
	elseif kind == "eff" then
		return string.format("%.1f%%", Stats.diminishing(value) * 100)
	end
	if math.abs(value - math.round(value)) < 1e-6 then
		return string.format("%d", value)
	end
	return string.format("%.2f", value)
end

function Stats.label(stat: string): string
	local display = Stats.Display[stat]
	return display and display[1] or stat
end

return Stats
