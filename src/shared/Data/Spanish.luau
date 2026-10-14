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

function Spanish.characterName(id: string, fallback: string): string
	local entry = Spanish.Characters[id]
	return if entry then entry.name else fallback
end

function Spanish.weaponName(id: string, fallback: string): string
	return Spanish.Weapons[id] or fallback
end

return Spanish
