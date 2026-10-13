-- Cosméticos: sombreros (Santa Hat + 21 de H A T S) y skins documentadas. Sólo visuales.
-- Sus condiciones se registran como datos; los modelos y la mayoría de rastreos están [Pendiente].

local Unlock = require(script.Parent.Unlock)
local P = Unlock.pending

local Cosmetics = {}

Cosmetics.Hats = {
	{ id = "SantaHat", name = "Santa Hat", unlock = P("Abrir el regalo oculto de Forest") },
	{ id = "GreenFrog", name = "Green Frog", unlock = P("Encontrar las ranas de Forest Stage 1") },
	{ id = "BlueFrog", name = "Blue Frog", unlock = P("Encontrar las ranas de Forest Stage 2") },
	{ id = "RedFrog", name = "Red Frog", unlock = P("Encontrar las ranas de Forest Stage 3") },
	{ id = "ShadyHatBlack", name = "Shady Hat (black)", unlock = Unlock.counter("shady.bought.Common", 100, "Comprar 100 objetos al vendedor Common") },
	{ id = "ShadyHatBlue", name = "Shady Hat (blue)", unlock = Unlock.counter("shady.bought.Rare", 80, "Comprar 80 objetos al vendedor Rare") },
	{ id = "ShadyHatPink", name = "Shady Hat (pink)", unlock = Unlock.counter("shady.bought.Epic", 60, "Comprar 60 objetos al vendedor Epic") },
	{ id = "ShadyHatGold", name = "Shady Hat (gold)", unlock = Unlock.counter("shady.bought.Legendary", 50, "Comprar 50 objetos al vendedor Legendary") },
	{ id = "TopHat", name = "Top Hat", unlock = Unlock.max("run.kills.Forest", 100000, "100.000 bajas en una partida de Forest") },
	{ id = "LoooongTopHat", name = "Looooong Top Hat", unlock = Unlock.max("run.kills.Forest", 300000, "300.000 bajas en una partida de Forest") },
	{ id = "MicrowaveHat", name = "Microwave", unlock = Unlock.counter("microwave.exploded", 50, "Hacer explotar 50 microondas") },
	{ id = "KevinHat", name = "Kevin Hat", unlock = Unlock.counter("kevin.punches", 100000, "Recibir 100.000 puñetazos de Kevin") },
	{ id = "Crown", name = "Crown", unlock = P("Todos los personajes en rango 100") },
	{ id = "SheriffsHat", name = "Sheriff's Hat", character = "CL4NK", unlock = Unlock.counter("event.BossUnder1s.char.CL4NK", 1, "Derrotar un jefe o minijefe en menos de 1 s") },
	{ id = "Headset", name = "Headset", character = "Ninja", unlock = P("Superar Desert Stage 1 con al menos 2 Boss Curse") },
	{ id = "Clown", name = "Clown", character = "Athena", unlock = Unlock.counter("kills.item.QuinsMask", 500, "Matar 500 enemigos con Quin's Mask") },
	{ id = "Sunglasses", name = "Sunglasses", character = "Calcium", unlock = P("Terminar el combate final de Graveyard en menos de 60 s") },
	{ id = "MagicHat", name = "Magic hat", character = "Fox", unlock = P("Firestaff, Lightning Staff y Blood Magic al nivel 40") },
	{ id = "IronHelm", name = "Iron Helm", character = "SirOofie", unlock = P("Vencer al jefe final de Forest 3 con Sword, Hero Sword, Corrupted Sword y Scythe") },
	{ id = "PilotHelm", name = "Pilot Helm", character = "Birdo", unlock = P("1.000 bajas con Mines mientras está en el aire") },
	{ id = "HeadPot", name = "Head Pot", character = "Roberto", unlock = P("Obtener 4 Pot (Stainless Steel) en una partida") },
	{ id = "CheesyHat", name = "Cheesy Hat", character = "Amog", unlock = P("Vencer un jefe final Tier 3 (Forest o Desert) con 8 Moldy Cheese y 1 Snek") },
}

-- Skins documentadas: [15.000 bajas, primer Stage Boss antes de 6 min, jefe final Tier 3, rango 100]
local function skins(character, names)
	local conditions = {
		Unlock.counter("kills.char." .. character, 15000, "15.000 bajas con " .. character),
		Unlock.counter("event.FirstBossUnder6.char." .. character, 1, "Primer Stage Boss antes de 6 min"),
		Unlock.counter("event.FinalBossT3.char." .. character, 1, "Vencer un jefe final Tier 3"),
		P("Rango 100"),
	}
	local list = {}
	for i, name in names do
		table.insert(list, { id = character .. "Skin" .. i, name = name, character = character, unlock = conditions[i] })
	end
	return list
end

Cosmetics.Skins = {}
for _, group in {
	skins("Fox", { "Ice Fox", "Light Fox", "Dark Fox", "Gold Fox" }),
	skins("SirOofie", { "Black Sir Oofie", "White Sir Oofie", "Fire Sir Oofie", "Gold Sir Oofie" }),
	skins("Calcium", { "Dark Calcium", "Acid Calcium", "Fire Calcium", "Gold Calcium" }),
	skins("CL4NK", { "Dark CL4NK", "Future CL4NK", "Blaze CL4NK", "Gold CL4NK" }),
	skins("Monke", { "Ice Monke", "Street Monke", "Fire Monke", "Gold Monke" }),
} do
	for _, skin in group do
		table.insert(Cosmetics.Skins, skin)
	end
end

return Cosmetics
