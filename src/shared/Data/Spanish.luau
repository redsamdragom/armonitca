-- Textos en español que muestra la interfaz (los identificadores internos siguen en inglés).
-- Las frases de presentación son propias de la recreación.

local Spanish = {}

Spanish.Characters = {
	Fox = { name = "Zorro", tagline = "Ágil y con una suerte sobrenatural.", passive = "Bendición de Suerte" },
	SirOofie = { name = "Sir Oofie", tagline = "Un muro de acero que no retrocede.", passive = "Reforzado" },
	Calcium = { name = "Calcio", tagline = "Cuanto más rápido va, más fuerte golpea.", passive = "Demonio de la Velocidad" },
	Megachad = { name = "Megachad", tagline = "Músculo puro. Los golpes rebotan en él.", passive = "Flexión" },
	Ogre = { name = "Ogro", tagline = "Grande, verde y con ganas de pelea.", passive = "Guerrero" },
	CL4NK = { name = "CL4NK", tagline = "Pistolero de hojalata con puntería letal.", passive = "Crítico Seguro" },
	Athena = { name = "Atenea", tagline = "Se defiende mejor cuanto peor le va.", passive = "Concentración" },
	Robinette = { name = "Robinetta", tagline = "Cada moneda de oro afila sus flechas.", passive = "Inversión" },
	Monke = { name = "Monke", tagline = "Trepa paredes y lanza plátanos.", passive = "Agarre de Mono" },
	TonyMcZoom = { name = "Tony McVeloz", tagline = "Su tabla carga electricidad al moverse.", passive = "Descarga" },
	Bush = { name = "Arbusto", tagline = "Nadie lo ve venir. Nadie.", passive = "Diana" },
	Birdo = { name = "Birdo", tagline = "Planea sobre la batalla sin miedo a caer.", passive = "Planeo" },
	Noelle = { name = "Noelle", tagline = "El frío de sus enemigos la hace más fuerte.", passive = "Resistencia" },
	Amog = { name = "Amog", tagline = "Su veneno se contagia de enemigo en enemigo.", passive = "Plaga" },
	Spaceman = { name = "Hombre Espacial", tagline = "Aprende rápido y cae despacio.", passive = "Teoría Cuántica de la XP" },
	Bandit = { name = "Bandido", tagline = "Duelista veloz que ataca sin descanso.", passive = "Flujo" },
	Ninja = { name = "Ninja", tagline = "Esquiva un golpe y su atacante cae.", passive = "Paso Sombrío" },
	Vlad = { name = "Vlad", tagline = "Se cura con la sangre de sus enemigos.", passive = "Vampiro" },
	SirChadwell = { name = "Sir Chadwell", tagline = "Busca el peligro a propósito.", passive = "Corrupto" },
	Dicehead = { name = "Cabezadado", tagline = "Cada nivel es una tirada de dados.", passive = "Apuesta" },
	Roberto = { name = "Roberto", tagline = "Siempre encuentra un cofre gratis.", passive = "Acaparador" },
}

Spanish.Weapons = {
	Sword = "Espada",
	Flamewalker = "Pasos de Fuego",
	LightningStaff = "Bastón de Rayos",
	Firestaff = "Bastón de Fuego",
	Chunkers = "Pedruscos",
	Bone = "Hueso",
	Bow = "Arco",
	Revolver = "Revólver",
	Aegis = "Égida",
	Bananarang = "Platanerang",
	Aura = "Aura",
	Axe = "Hacha",
	SpaceNoodle = "Fideo Espacial",
	SniperRifle = "Rifle de Francotirador",
	SluttyRocket = "Cohete Travieso",
	Shotgun = "Escopeta",
	Mines = "Minas",
	WirelessDagger = "Daga Inalámbrica",
	Frostwalker = "Pasos de Escarcha",
	Tornado = "Tornado",
	Dexecutioner = "Dexecutor",
	BloodMagic = "Magia de Sangre",
	BlackHole = "Agujero Negro",
	PoisonFlask = "Frasco de Veneno",
	Katana = "Katana",
	DragonsBreath = "Aliento de Dragón",
	Dice = "Dados",
	HeroSword = "Espada del Héroe",
	CorruptedSword = "Espada Corrupta",
	Scythe = "Guadaña",
}

Spanish.Tomes = {
	Agility = "Tomo de Agilidad",
	Cooldown = "Tomo de Enfriamiento",
	Damage = "Tomo de Daño",
	Evasion = "Tomo de Evasión",
	Golden = "Tomo Dorado",
	Health = "Tomo de Salud",
	Knockback = "Tomo de Retroceso",
	Precision = "Tomo de Precisión",
	ProjectileSpeed = "Tomo de Velocidad de Proyectil",
	Regen = "Tomo de Regeneración",
	Shield = "Tomo de Escudo",
	Silver = "Tomo de Plata",
	Size = "Tomo de Tamaño",
	Armor = "Tomo de Armadura",
	Attraction = "Tomo de Atracción",
	Bloody = "Tomo Sangriento",
	Chaos = "Tomo del Caos",
	Cursed = "Tomo Maldito",
	Duration = "Tomo de Duración",
	Luck = "Tomo de Suerte",
	Quantity = "Tomo de Cantidad",
	Thorns = "Tomo de Espinas",
	XP = "Tomo de Experiencia",
}

function Spanish.tomeName(id: string, fallback: string): string
	return Spanish.Tomes[id] or fallback
end

-- Qué hace cada tomo, en palabras sencillas. El efecto por nivel sale de Data/Tomes.
Spanish.TomeEffects = {
	Agility = "Te mueves más rápido para esquivar y recoger la experiencia.",
	Cooldown = "Tus armas atacan más a menudo.",
	Damage = "Todas tus armas hacen más daño.",
	Evasion = "Te da probabilidad de esquivar por completo un golpe.",
	Golden = "Ganas más oro de los enemigos y los cofres.",
	Health = "Aumenta tu vida máxima.",
	Knockback = "Tus ataques empujan más lejos a los enemigos.",
	Precision = "Haces más golpes críticos, que causan daño extra.",
	ProjectileSpeed = "Tus proyectiles vuelan más rápido y llegan antes.",
	Regen = "Recuperas vida poco a poco con el tiempo.",
	Shield = "Un escudo que absorbe el daño antes que tu vida.",
	Silver = "Ganas más plata, la moneda para comprar desbloqueos.",
	Size = "Tus ataques son más grandes y alcanzan a más enemigos.",
	Armor = "Reduce el daño que recibes.",
	Attraction = "Recoges experiencia, oro y objetos desde más lejos.",
	Bloody = "Cada golpe que das puede curarte un poco.",
	Chaos = "Cada vez que lo eliges mejora una estadística al azar.",
	Cursed = "Sube la dificultad: aparecen más enemigos y más fuertes.",
	Duration = "Tus ataques y sus efectos duran más tiempo.",
	Luck = "Más suerte: mejores rarezas en mejoras, cofres y objetos.",
	Quantity = "Tus armas lanzan más ataques y proyectiles a la vez.",
	Thorns = "Los enemigos que te golpean reciben daño.",
	XP = "Ganas más experiencia y subes de nivel antes.",
}

-- Descripción completa de un tomo: qué hace y cuánto mejora por nivel.
function Spanish.tomeDescription(id: string, perLevel: string?): string
	local effect = Spanish.TomeEffects[id] or ""
	-- El efecto por nivel sólo se añade cuando es una cifra ("+15% de ..."); el Caos ya lo explica
	if perLevel and string.match(perLevel, "^[%+%-]?%d") then
		return if effect ~= "" then effect .. " Por nivel: " .. perLevel else perLevel
	end
	return effect
end

function Spanish.characterName(id: string, fallback: string): string
	local entry = Spanish.Characters[id]
	return if entry then entry.name else fallback
end

function Spanish.weaponName(id: string, fallback: string): string
	return Spanish.Weapons[id] or fallback
end

return Spanish
