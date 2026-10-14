--!nolint
-- Genera docs/MATRIZ.md a partir del catálogo y del código:  lune run tests/matrix
-- Estados: Completado (implementado con datos de referencia), Provisional (implementado con
-- valores provisionales), Pendiente (no implementado o no rastreable), Discrepancia (fuentes
-- contradictorias; se usa un valor provisional).

local fs = require("@lune/fs")
local process = require("@lune/process")
local Harness = require("./Harness")

Harness.build(process.cwd)
local req = Harness.require
local Catalog = req(Harness.shared.Catalog)
local Items = req(Harness.server.Combat.Items)

-- Objetos cuyo comportamiento usa coeficientes inventados para poder jugar (no documentados).
local ITEM_PROVISIONAL = {
	GoldenShield = "oro por golpe",
	ThunderMitts = "daño del rayo",
	Feathers = "conversión de altura de salto",
	ElectricPlug = "daño de la descarga",
	Ghost = "daño de los fantasmas",
	Cactus = "daño de las púas",
	CowardsCloak = "acumulaciones temporales",
	MoldyGloves = "daño de la explosión",
	Mirror = "daño reflejado",
	GasMask = "coeficientes por envenenado",
	CursedGrabbies = "daño de la explosión",
	Kevin = "daño propio",
	BigBonk = "crecimiento de potencia y radio",
	PowerGloves = "daño, radio y enfriamiento",
	LightningOrb = "daño y encadenamiento",
	Dragonfire = "daño del área y de la quemadura",
	HolyBook = "conversión de curación en daño",
	EnergyCore = "daño e intervalo",
	SoulHarvester = "daño de las almas",
	Snek = "componente adicional de la detonación",
	ZaWarudo = "vida restaurada",
	IceCube = "daño de hielo",
	CursedDoll = "duración de la maldición",
	BobDead = "daño de Bob",
	ShatteredKnowledge = "daño de los fragmentos",
	QuinsMask = "radio de la explosión",
	SpicyMeatball = "radio",
	GrandmasSecretTonic = "radio",
	Beacon = "radio y duración de la zona",
	Pumpkin = "vasijas por copia (8 grandes + 2 pequeñas)",
	GoldenRing = "Golden Microwave no implementado",
}

-- Pasivas cuya lógica especial usa coeficientes provisionales.
local PASSIVE_PROVISIONAL = {
	Momentum = "aceleración, velocidad extra y curva de daño",
	Flex = "duración, enfriamiento inicial y mínimo",
	LockIn = "curva de daño por vida baja",
	Stonks = "umbrales de los tramos de oro",
	Zap = "distancia por carga, radio, daño",
	Bullseye = "frecuencia de marcado y daño de la explosión",
	Gamba = "fórmula de eficiencia y tabla de estadísticas",
	Float = "velocidad de planeo",
	Enduring = nil,
	Plague = "orden de aplicación y multiplicación por tamaño",
	Shadowstep = "daño contra jefes",
	Hoarder = nil,
}

local lines = {}
local function add(line)
	table.insert(lines, line or "")
end

local function unlockState(unlock)
	if unlock.reference then
		return (if unlock.kind == "start" then "Inicial" else "Rastreado") .. " (provisional; referencia: " .. unlock.reference .. ")"
	elseif unlock.kind == "start" then
		return "Inicial"
	elseif unlock.kind == "pending" then
		return "Pendiente (no rastreable)"
	end
	return "Rastreado"
end

local counts = {}
local function tally(group, state)
	counts[group] = counts[group] or {}
	counts[group][state] = (counts[group][state] or 0) + 1
end

add("# Matriz de correspondencia")
add()
add("Generada con `lune run tests/matrix` a partir del catálogo y del código. Versión de referencia: v" .. req(Harness.shared.Config).ReferenceVersion .. ".")
add()
add("| Estado | Significado |")
add("|---|---|")
add("| Completado | Implementado y jugable con los datos de referencia de la especificación |")
add("| Provisional | Implementado y jugable, pero con valores no documentados (editables en `src/shared`) |")
add("| Pendiente | No implementado, o su condición no se puede cumplir todavía en el juego |")
add("| Discrepancia | Las fuentes se contradicen; se usa un valor provisional |")
add()
add("En todos los casos, los modelos son reconstrucciones con primitivas: no hay mallas, rigs, animaciones, iconos ni audio originales.")
add()

-- Personajes
add("## Personajes (21)")
add()
add("| Personaje | Arma | Pasiva | Estado | Desbloqueo | Notas |")
add("|---|---|---|---|---|---|")
for _, c in ipairs(Catalog.Characters) do
	local special = c.passive.special
	local note = special and PASSIVE_PROVISIONAL[special]
	local state = if note then "Provisional" else "Completado"
	if c.movement.climb or c.movement.float or c.movement.lowGravity then
		state = "Provisional"
		note = (note and note .. "; " or "") .. "coeficientes de movimiento"
	end
	tally("Personajes", state)
	add(string.format("| %s | %s | %s | %s | %s: %s | %s |", c.name, Catalog.Weapon[c.weapon].name, c.passive.name, state, unlockState(c.unlock), c.unlock.text, note or "Pasiva y valores documentados implementados"))
end
add()

-- Armas
add("## Armas (30)")
add()
add("| Arma | Patrón | Estado | Desbloqueo | Notas |")
add("|---|---|---|---|---|")
for _, w in ipairs(Catalog.Weapons) do
	local notes = { "estadísticas base provisionales" }
	if w.pendingUpgrades then
		table.insert(notes, "mejoras sin valor verificado: " .. table.concat(w.pendingUpgrades, ", "))
	end
	if w.confirmed then
		table.insert(notes, "confirmado: " .. table.concat(w.confirmed, "; "))
	end
	tally("Armas", "Provisional")
	add(string.format("| %s | %s | Provisional | %s: %s | %s |", w.name, w.behavior, unlockState(w.unlock), w.unlock.text, table.concat(notes, "; ")))
end
add()

-- Tomos
add("## Tomos (23)")
add()
add("| Tomo | Estadística | Incremento común | Estado | Desbloqueo |")
add("|---|---|---|---|---|")
for _, t in ipairs(Catalog.Tomes) do
	tally("Tomos", "Completado")
	add(string.format("| %s | %s | %s | Completado | %s: %s |", t.name, t.stat, tostring(t.value), unlockState(t.unlock), t.unlock.text))
end
add()

-- Objetos
add("## Objetos (85)")
add()
add("| Objeto | Rareza | Estado | Desbloqueo | Notas |")
add("|---|---|---|---|---|")
for _, item in ipairs(Catalog.Items) do
	local state, note
	if not Items.implemented(item.id) then
		state, note = "Pendiente", "sin comportamiento"
	elseif item.discrepancy then
		state, note = "Discrepancia", item.discrepancy
	elseif ITEM_PROVISIONAL[item.id] then
		state, note = "Provisional", ITEM_PROVISIONAL[item.id]
	else
		state, note = "Completado", ""
	end
	tally("Objetos", state)
	add(string.format("| %s | %s | %s | %s: %s | %s |", item.name, item.rarity, state, unlockState(item.unlock), item.unlock.text, note))
end
add()

-- Mapas y encuentros
add("## Mapas")
add()
add("| Mapa | Estado | Notas |")
add("|---|---|---|")
for _, m in ipairs(Catalog.Maps) do
	local state = if m.playable then "Provisional" else "Pendiente"
	tally("Mapas", state)
	add(string.format("| %s | %s | %s |", m.name, state, m.desc))
end
add()
add("## Enemigos y jefes")
add()
add("Todos **Provisional**: el bestiario completo, sus estadísticas y los patrones de cada jefe no están documentados. Los jefes usan una máquina de estados genérica (golpe en área telegrafiado, anillo de proyectiles, embestida, invocación) con fases al 66% y 33% de vida.")
add()
add("| Enemigo | IA | Tipo |")
add("|---|---|---|")
local names = {}
for id in Catalog.Enemies do
	table.insert(names, id)
end
table.sort(names)
for _, id in names do
	local e = Catalog.Enemies[id]
	add(string.format("| %s | %s | %s |", e.name, e.ai, if e.boss then "Jefe" elseif e.miniboss then "Minijefe" else "Normal"))
end
add()
add("Pendientes: Graveyard (Calcium's Dad, Ghostham the Dead, Jeff, Mike, Ted, Gary, Spooky Steve, Big Bob), Bush y Bandit como encuentros secretos, y la retirada de armas en los combates finales de Tier 3.")
add()

-- Cosméticos
add("## Cosméticos")
add()
add("Sombreros (22) y skins documentadas (20) registrados como datos con sus condiciones. **Pendiente**: modelos, equipamiento, compra con plata, skins fantasmales de la cripta y la skin de Megachad de H A T S.")
add()

-- Resumen
add("## Resumen")
add()
add("| Grupo | Completado | Provisional | Discrepancia | Pendiente |")
add("|---|---|---|---|---|")
for _, group in { "Personajes", "Armas", "Tomos", "Objetos", "Mapas" } do
	local c = counts[group] or {}
	add(string.format("| %s | %d | %d | %d | %d |", group, c.Completado or 0, c.Provisional or 0, c.Discrepancia or 0, c.Pendiente or 0))
end
add()

fs.writeFile(process.cwd .. "/docs/MATRIZ.md", table.concat(lines, "\n"))
print("docs/MATRIZ.md generado")
