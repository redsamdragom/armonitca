-- Catálogo de los 85 objetos (22 comunes, 21 raros, 20 épicos, 22 legendarios).
-- Fuente: fichas de "Megabonk Items Explained" (v1.0.69), citadas en la especificación.
-- El comportamiento vive en server/Combat/Items.luau, indexado por `id`.
-- `discrepancy`: contradicción documentada; el valor implementado es provisional.

local Unlock = require(script.Parent.Unlock)
local S = Unlock.start

local function item(id, name, rarity, desc, unlock, extra)
	local t = { id = id, name = name, rarity = rarity, desc = desc, unlock = unlock or S() }
	if extra then
		for k, v in extra do
			t[k] = v
		end
	end
	return t
end

local C, R, E, L = "Common", "Rare", "Epic", "Legendary"

local Items = {
	-- Comunes
	item("MoldyCheese", "Moldy Cheese", C, "40% por copia de envenenar al golpear; más de 100% aplica varias cargas."),
	item("Borgar", "Borgar", C, "Probabilidad de soltar una hamburguesa curativa al matar cerca."),
	item("Wrench", "Wrench", C, "Los santuarios se cargan un 4% más rápido y dan un 7,5% más por copia."),
	item("Clover", "Clover", C, "+10% de suerte por copia."),
	item("TimeBracelet", "Time Bracelet", C, "+8% de experiencia por copia."),
	item("SlipperyRing", "Slippery Ring", C, "+15% de evasión bruta por copia."),
	item("GoldenGlove", "Golden Glove", C, "+15% de oro por baja por copia."),
	item("GymSauce", "Gym Sauce", C, "+10% de daño por copia."),
	item("Oats", "Oats", C, "+25 de vida máxima por copia."),
	item("Medkit", "Medkit", C, "+45 de regeneración por copia."),
	item("TurboSocks", "Turbo Socks", C, "+15% de velocidad por copia.", Unlock.max("tome.Agility", 5, "Subir Agility Tome al nivel 5")),
	item(
		"TacticalGlasses",
		"Tactical Glasses",
		C,
		"+20% de daño contra enemigos con al menos 90% de vida.",
		Unlock.counter("event.MinibossUnder25", 1, "Derrotar un minijefe en 25 s"),
		{ discrepancy = "Límite exacto del 90% (>= o >)" }
	),
	item("Battery", "Battery", C, "+8% de velocidad de ataque por copia.", Unlock.max("tome.Cooldown", 5, "Subir Cooldown Tome al nivel 5")),
	item("ForbiddenJuice", "Forbidden Juice", C, "+10% de probabilidad crítica por copia.", Unlock.counter("crits", 100, "Realizar 100 críticos")),
	item("CursedDoll", "Cursed Doll", C, "Maldice enemigos al azar, que pierden un 30% de su vida por segundo.", Unlock.counter("deaths", 10, "Morir 10 veces")),
	item("BossBuster", "Boss Buster", C, "+15% de daño contra élites y jefes por copia.", Unlock.counter("event.StageBossUnder30", 1, "Derrotar un jefe de fase en menos de 30 s")),
	item("Key", "Key", C, "Probabilidad de abrir gratis cofres de pago.", Unlock.counter("chestsBought", 25, "Comprar 25 cofres")),
	item(
		"IceCrystal",
		"Ice Crystal",
		C,
		"Probabilidad de congelar al golpear.",
		Unlock.counter("kills.weapon.Frostwalker", 50, "Obtener 50 bajas con Frostwalker"),
		{ discrepancy = "Probabilidad (7,5% vs ~9,09%) y duración" }
	),
	item("Skuleg", "Skuleg", C, "+7% de dificultad por copia.", Unlock.max("difficulty", 40, "Alcanzar 40% de dificultad")),
	item("Ghost", "Ghost", C, "Usar un interactuable invoca 6 fantasmas perseguidores por copia.", Unlock.max("swarmSeconds", 60, "Sobrevivir 60 s al Final Swarm")),
	item("Cactus", "Cactus", C, "Al recibir daño lanza púas (3, +2 por copia, máximo 40).", Unlock.pending("Matar 100 cactus con espinas (Desert aún no implementado)")),
	item("OldMask", "Old Mask", C, "+15% de aparición de élites por copia.", Unlock.pending("Encontrarlo en Graveyard (Graveyard aún no implementado)")),

	-- Raros
	item("CreditCardRed", "Credit Card (Red)", R, "Cada cofre abierto da +2,5% de daño por copia."),
	item("GoldenShield", "Golden Shield", R, "Recibir daño da oro."),
	item("ThunderMitts", "Thunder Mitts", R, "Un impacto lanza un rayo de área que aturde 3 s (enfriamiento 10 s)."),
	item("Feathers", "Feathers", R, "+1 salto extra y más altura de salto por copia."),
	item("ElectricPlug", "Electric Plug", R, "Al recibir daño electrocuta hasta 6 enemigos cercanos (+4 por copia)."),
	item("CowardsCloak", "Coward's Cloak", R, "+5% de velocidad; recibir daño da velocidad temporal."),
	item("UnstableTransfusion", "Unstable Transfusion", R, "+35% por copia de aplicar Bloodmark al impactar."),
	item("Beer", "Beer", R, "+20% de daño y −5% de vida máxima por copia."),
	item("Beacon", "Beacon", R, "Los Charge Shrines completados dejan una zona curativa."),
	item("Backpack", "Backpack", R, "+1 proyectil a todas las armas por copia."),
	item(
		"PhantomShroud",
		"Phantom Shroud",
		R,
		"Evadir potencia el siguiente ataque y da velocidad temporal.",
		nil,
		{ discrepancy = "Multiplicador ×2 (descripción) vs ×3 (análisis)" }
	),
	item("Campfire", "Campfire", R, "Quieto 0,6 s: +1100 de regeneración por copia."),
	item("BrassKnuckles", "Brass Knuckles", R, "+25% de daño contra enemigos cercanos por copia.", Unlock.counter("kills.weapon.Sword", 5000, "Matar 5.000 enemigos con Sword")),
	item("DemonicBlade", "Demonic Blade", R, "25% por copia de curar 1 de vida al hacer crítico.", Unlock.counter("heal.lifesteal", 350, "Curar 350 de vida con robo de vida")),
	item("DemonicBlood", "Demonic Blood", R, "+0,5 de vida máxima por baja (hasta 200 bajas por copia).", Unlock.counter("maxhp.BloodMagic", 400, "Aumentar la vida máxima 400 veces con Blood Magic")),
	item("EchoShard", "Echo Shard", R, "+12% por copia de crear un fragmento extra de experiencia al matar.", Unlock.max("tome.XP", 8, "Subir XP Tome al nivel 8")),
	item("MoldyGloves", "Moldy Gloves", R, "Un golpe genera una nube de veneno cada ~9,5 s.", Unlock.counter("microwave.MoldyCheese.streak3", 1, "Duplicar Moldy Cheese 3 veces seguidas en un Microwave")),
	item("GoldenSneakers", "Golden Sneakers", R, "1 de oro por cada 10 m recorridos por copia.", Unlock.counter("pots", 150, "Romper 150 vasijas")),
	item("IdleJuice", "Idle Juice", R, "Quieto: +4% de daño por segundo, hasta +100% por copia.", Unlock.max("run.idleKills", 500, "Matar 500 enemigos sin moverse")),
	item(
		"LeechingCrystal",
		"Leeching Crystal",
		R,
		"+50 de vida máxima y −50% de regeneración por copia.",
		Unlock.max("tome.Regen", 8, "Subir Regen Tome al nivel 8"),
		{ discrepancy = "Apilado de regeneración (−50% lineal vs ×0,5)" }
	),
	item("Pumpkin", "Pumpkin", R, "Más vasijas y +18% de recompensas en fases futuras.", Unlock.pending("Con Roberto, romper todas las calabazas de Graveyard (no implementado)")),

	-- Épicos
	item("BeefyRing", "Beefy Ring", E, "+10 de vida máxima y +0,2% de daño por cada punto de vida máxima por copia."),
	item("CreditCardGreen", "Credit Card (Green)", E, "Cada cofre da +2% de suerte por copia; cofres un 10% más caros."),
	item("SpikyShield", "Spiky Shield", E, "+10% de armadura y +2 de espinas por cada 1% de armadura por copia."),
	item("Scarf", "Scarf", E, "+50% de daño en el aire por copia."),
	item("SlurpGloves", "Slurp Gloves", E, "Un golpe provoca una explosión de sangre que aplica Bloodmark y cura (enfriamiento 9 s)."),
	item("Mirror", "Mirror", E, "Refleja daño en cono y da 0,5 s de invulnerabilidad (enfriamiento 7 s)."),
	item("TurboSkates", "Turbo Skates", E, "La velocidad de movimiento aumenta la de ataque.", Unlock.counter("event.AgilityCooldown5", 1, "Subir Cooldown Tome y Agility Tome a nivel 5 en una partida")),
	item("SluttyCannon", "Cañón Travieso", E, "Al impactar puede disparar misiles.", Unlock.counter("kills.weapon.SluttyRocket", 5000, "Matar 5.000 enemigos con Cohete Travieso")),
	item("ShatteredKnowledge", "Shattered Knowledge", E, "Los fragmentos de experiencia dañan a los enemigos que atraviesan.", Unlock.max("tome.Attraction", 8, "Subir Attraction Tome al nivel 8")),
	item("QuinsMask", "Quin's Mask", E, "+20 de espinas; las espinas pueden explotar.", Unlock.counter("event.AthenaAegisBossKill", 1, "Con Athena, rematar un jefe de fase con Aegis")),
	item("ToxicBarrel", "Toxic Barrel", E, "Recibir daño libera una nube tóxica (5 cargas de veneno por copia).", Unlock.counter("kills.element.Poison", 2000, "Matar 2.000 enemigos con veneno")),
	item("GasMask", "Gas Mask", E, "Armadura y sobrecuración según los enemigos envenenados vivos.", Unlock.counter("kills.char.Amog", 5000, "Matar 5.000 enemigos con Amog")),
	item("GamerGoggles", "Gamer Goggles", E, "Más daño con menos de 50% de vida (hasta +100% por copia).", Unlock.counter("event.StageBossLowHp", 1, "Derrotar un jefe de fase con menos del 10% de vida")),
	item("EagleClaw", "Eagle Claw", E, "+66% de daño a enemigos en el aire; puede lanzarlos.", Unlock.counter("kills.char.Birdo", 10000, "Matar 10.000 enemigos con Birdo")),
	item("DemonicSoul", "Demonic Soul", E, "+0,1% de daño por baja (hasta 1.000 por copia).", Unlock.max("level.char.Calcium", 30, "Alcanzar nivel 30 con Calcium")),
	item("BobDead", "Bob (Dead)", E, "Invoca un Bob cada 14 unidades recorridas por copia.", Unlock.max("swarmSeconds", 120, "Sobrevivir 2 min al Final Swarm")),
	item("GrandmasSecretTonic", "Grandma's Secret Tonic", E, "Los críticos tienen 50% de explotar por el 50% del daño crítico.", Unlock.counter("kills.weapon.SniperRifle", 3000, "Matar 3.000 enemigos con Sniper Rifle")),
	item("CursedGrabbies", "Cursed Grabbies", E, "+10% de dificultad y ×0,8 vida máxima; explosiones malditas al golpear.", Unlock.max("tome.Cursed", 10, "Subir Cursed Tome al nivel 10")),
	item("Kevin", "Kevin", E, "25% por copia de recibir daño propio al golpear (nunca por debajo de 1).", Unlock.max("run.LeechingCrystal", 3, "Obtener tres Leeching Crystal en una partida")),
	item("BobsLight", "Bob's Light", E, "Pulso periódico que mata enemigos normales.", Unlock.pending("Matar a Big Bob con una lámpara (Graveyard aún no implementado)")),

	-- Legendarios
	item("OverpoweredLamp", "Overpowered Lamp", L, "Cada copia añade una tirada extra a los efectos al golpear.", nil, { cap = 2 }),
	item("ZaWarudo", "Za Warudo", L, "Impide una muerte y detiene el tiempo 15 s; se consume.", nil, { cap = 25 }),
	item("BigBonk", "Big Bonk", L, "2% de un golpe BONK ×20."),
	item("SpicyMeatball", "Spicy Meatball", L, "25% de explotar al impactar por el 65% del daño."),
	item("IceCube", "Ice Cube", L, "Añade daño de hielo y permite congelar."),
	item("GiantFork", "Giant Fork", L, "+15% de crítico; los críticos pueden ser megacríticos."),
	item("PowerGloves", "Power Gloves", L, "Explosión grande al golpear que empuja y aturde 3 s."),
	item("LightningOrb", "Lightning Orb", L, "Rayos al impactar que pueden aturdir.", Unlock.counter("kills.element.Electric", 3000, "Matar 3.000 enemigos con daño eléctrico")),
	item("Chonkplate", "Chonkplate", L, "Sobrecuración del 75% de la vida máxima y +20% de robo de vida por copia.", Unlock.max("maxHealth", 500, "Alcanzar 500 de vida máxima")),
	item("Dragonfire", "Dragonfire", L, "Al golpear puede crear un área de fuego y quemar.", Unlock.counter("kills.element.Fire", 4000, "Matar 4.000 enemigos con fuego")),
	item("SuckyMagnet", "Sucky Magnet", L, "Atrae experiencia periódicamente.", Unlock.counter("event.AllChargeShrinesMap", 1, "Completar todos los Charge Shrines de un mapa")),
	item("HolyBook", "Holy Book", L, "+100 de vida, +50 de regeneración; la curación daña en área.", Unlock.counter("event.FirstBossNoDamage", 1, "Matar al primer jefe de fase sin recibir daño en la partida")),
	item("SpeedBoi", "Speed Boi", L, "Con menos de 50% de vida, un golpe ralentiza el tiempo y duplica el daño.", Unlock.counter("event.StageTwoCurses", 1, "Completar una fase con al menos 2 Boss Curse")),
	item("EnergyCore", "Energy Core", L, "Dispara orbes de energía a enemigos cercanos.", Unlock.counter("finalBossKills", 2, "Derrotar dos veces a un jefe final")),
	item("Anvil", "Anvil", L, "Las mejoras de arma pueden traer un atributo adicional.", Unlock.counter("challenges", 3, "Completar 3 Challenges"), { cap = 1 }),
	item("SoulHarvester", "Soul Harvester", L, "Cada baja genera dos almas perseguidoras.", Unlock.max("swarmSeconds", 360, "Sobrevivir 6 min al Final Swarm")),
	item("JoesDagger", "Joe's Dagger", L, "1% de ejecutar enemigos normales; contra jefes, 2% de su vida.", Unlock.counter("kills.weapon.Dexecutioner", 10000, "Matar 10.000 enemigos con Dexecutioner")),
	item("BloodyCleaver", "Bloody Cleaver", L, "+50% de Bloodmark al impactar; el robo de vida añade cargas.", Unlock.max("level.char.Vlad", 50, "Alcanzar nivel 50 con Vlad")),
	item("GoldenRing", "Golden Ring", L, "Sin efecto de combate; se sacrifica en el Golden Microwave."),
	item("Snek", "Snek", L, "4 cargas de veneno por copia al golpear; puede detonar el veneno.", Unlock.pending("Encontrarlo en la cripta de Graveyard (no implementado)")),
	item("PotStainlessSteel", "Pot (Stainless Steel)", L, "Amplía el nivel máximo de todas las armas (+10, +9, ... mínimo +2).", Unlock.pending("Abrir todo en la primera cripta de Graveyard (no implementado)")),
	item("WizardsHat", "Wizard's Hat", L, "Amplía el nivel máximo de todos los tomos (+10, +9, ... mínimo +2).", Unlock.counter("event.VladPotOver40", 1, "Con Vlad, subir un arma por encima del nivel 40 con Pot")),
}

return Items
