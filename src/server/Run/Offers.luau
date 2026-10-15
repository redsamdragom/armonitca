-- Ofertas de subida de nivel: candidatos elegibles (desbloqueados, ranuras, niveles máximos,
-- exclusiones), rareza de la mejora y aplicación de la elección.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Stats = require(ReplicatedStorage.Shared.Stats)
local Weapons = require(script.Parent.Parent.Combat.Weapons)

local Offers = {}

local WEAPON_STAT_LABEL = {
	Damage = "Daño",
	Count = "Cantidad",
	Bounces = "Rebotes",
	ProjectileSpeed = "Velocidad de proyectil",
	Knockback = "Retroceso",
	Duration = "Duración",
	Size = "Tamaño",
	CritChance = "Probabilidad crítica",
	CritDamage = "Daño crítico",
}
local PERCENT_STATS = { Size = true, CritChance = true, CritDamage = true }

local TOME_VALUE = {}
for _, tome in ipairs(Catalog.Tomes) do
	TOME_VALUE[tome.stat] = tome.value
end

-- Rareza de la mejora: la suerte desplaza el peso hacia rarezas altas [Pendiente: fórmula]
function Offers.rollRarity(session, forced: string?): string
	if forced then
		return forced
	end
	local luck = math.max(0, session.stats.Luck)
	local weights, total = {}, 0
	for i, rarity in Catalog.UpgradeRarities do
		local w = Config.Offers.RarityWeights[rarity] * (1 + luck) ^ (i - 1)
		weights[i] = w
		total += w
	end
	local roll = session.rng:NextNumber() * total
	for i, rarity in Catalog.UpgradeRarities do
		roll -= weights[i]
		if roll <= 0 then
			return rarity
		end
	end
	return "Common"
end

local function fmt(stat: string, value: number): string
	if PERCENT_STATS[stat] then
		return string.format("%.0f%%", value * 100)
	end
	if math.abs(value - math.round(value)) < 1e-6 then
		return tostring(math.round(value))
	end
	return string.format("%.2f", value)
end

local function weaponChoice(session, w, rarity: string)
	local def = w.def
	local mult = Catalog.UpgradeRarityMult[rarity]
	local pool = {}
	for stat in def.upgrades do
		table.insert(pool, stat)
	end
	table.sort(pool)
	local picks = 1 + (if rarity == "Rare" or rarity == "Epic" or rarity == "Legendary" then 1 else 0)
	picks += session.items.Anvil or 0
	local changes = {}
	for _ = 1, math.min(picks, #pool) do
		local stat = table.remove(pool, session.rng:NextInteger(1, #pool))
		local delta = def.upgrades[stat] * mult
		if stat == "Count" or stat == "Bounces" then
			delta = math.max(1, math.floor(delta + 1e-6)) -- [Pendiente] conversión de cantidades fraccionarias
		end
		local before = (def.base[stat] or 0) + (w.bonus[stat] or 0)
		table.insert(changes, {
			stat = stat,
			delta = delta,
			label = WEAPON_STAT_LABEL[stat] or stat,
			from = fmt(stat, before),
			to = fmt(stat, before + delta),
			text = string.format("%s: %s → %s", WEAPON_STAT_LABEL[stat] or stat, fmt(stat, before), fmt(stat, before + delta)),
		})
	end
	return {
		type = "WeaponUp",
		id = w.id,
		level = w.level,
		rarity = rarity,
		name = def.name,
		subtitle = string.format("Nivel %d → %d", w.level, w.level + 1),
		desc = def.desc,
		changes = changes,
	}
end

-- Valor de una estadística para las cartas: porcentajes sin signo ("12%") y cifras tal cual.
local function tomeValue(stat: string, value: number): string
	local display = Stats.Display[stat]
	local kind = display and display[2] or "flat"
	if kind == "pct" or kind == "eff" then
		local pct = (if kind == "eff" then Stats.diminishing(value) else value) * 100
		if math.abs(pct - math.round(pct)) < 0.05 then
			return string.format("%d%%", math.round(pct))
		end
		return string.format("%.1f%%", pct)
	end
	return fmt(stat, value)
end

local function tomeChoice(session, tome, rarity: string, isNew: boolean)
	local def = tome.def
	local mult = Catalog.UpgradeRarityMult[rarity]
	local stat = def.stat
	if stat == "Chaos" then
		local pool = Catalog.ChaosPool
		stat = pool[session.rng:NextInteger(1, #pool)]
	end
	local base = if def.stat == "Chaos" then TOME_VALUE[stat] or 0.05 else def.value
	local delta = base * mult
	if stat == "Quantity" then
		delta = math.max(1, math.floor(delta + 1e-6))
	end
	local before = session.stats[stat] or 0
	return {
		type = if isNew then "TomeNew" else "TomeUp",
		id = def.id,
		level = tome.level,
		rarity = rarity,
		name = def.name,
		subtitle = if isNew then "¡Nuevo tomo!" else string.format("Nivel %d → %d", tome.level, tome.level + 1),
		desc = def.desc,
		stat = stat,
		delta = delta,
		changes = {
			{
				stat = stat,
				delta = delta,
				label = Stats.label(stat),
				from = tomeValue(stat, before),
				to = tomeValue(stat, before + delta),
				text = string.format("%s: %s → %s", Stats.label(stat), Stats.format(stat, before), Stats.format(stat, before + delta)),
			},
		},
	}
end

local function eligible(session, key: string): boolean
	return session.unlocked[key] == true and not session.banished[key]
end

function Offers.candidates(session)
	local list = {}
	local weaponMax = Weapons.maxLevel(session)
	local tomeMax = Config.Slots.TomeMaxLevel + session.tomeLevelBonus
	local ownedWeapons, ownedTomes = {}, {}
	for _, w in session.weapons do
		ownedWeapons[w.id] = true
		if w.level < weaponMax and not session.banished["weapon:" .. w.id] then
			table.insert(list, { kind = "weapon", w = w })
		end
	end
	if #session.weapons < session.weaponSlots then
		for _, def in ipairs(Catalog.Weapons) do
			if not ownedWeapons[def.id] and eligible(session, "weapon:" .. def.id) then
				table.insert(list, { kind = "newWeapon", id = def.id })
			end
		end
	end
	for _, tome in session.tomes do
		ownedTomes[tome.id] = true
		if tome.level < tomeMax and not session.banished["tome:" .. tome.id] then
			table.insert(list, { kind = "tome", tome = tome })
		end
	end
	if #session.tomes < session.tomeSlots then
		for _, def in ipairs(Catalog.Tomes) do
			if not ownedTomes[def.id] and eligible(session, "tome:" .. def.id) then
				if not (def.id == "Silver" and session.settings.disableSilverTome) then
					table.insert(list, { kind = "newTome", id = def.id })
				end
			end
		end
	end
	return list
end

function Offers.build(session, forcedRarity: string?)
	local candidates = Offers.candidates(session)
	local choices = {}
	for _ = 1, math.min(Config.Offers.Choices, #candidates) do
		local c = table.remove(candidates, session.rng:NextInteger(1, #candidates))
		local rarity = Offers.rollRarity(session, forcedRarity)
		if c.kind == "weapon" then
			table.insert(choices, weaponChoice(session, c.w, rarity))
		elseif c.kind == "newWeapon" then
			local def = Catalog.Weapon[c.id]
			table.insert(choices, {
				type = "WeaponNew",
				id = c.id,
				rarity = "Common",
				name = def.name,
				subtitle = "¡Nueva arma!",
				desc = def.desc,
				changes = {},
			})
		elseif c.kind == "tome" then
			table.insert(choices, tomeChoice(session, c.tome, rarity, false))
		else
			local def = Catalog.Tome[c.id]
			table.insert(choices, tomeChoice(session, { def = def, level = 0, id = def.id }, rarity, true))
		end
	end
	return choices
end

function Offers.apply(session, choice)
	if choice.type == "WeaponUp" then
		for _, w in session.weapons do
			if w.id == choice.id then
				w.level += 1
				for _, change in choice.changes do
					w.bonus[change.stat] = (w.bonus[change.stat] or 0) + change.delta
				end
				Weapons.compute(session, w)
				session:recordMax("weapon." .. w.id, w.level)
				break
			end
		end
	elseif choice.type == "WeaponNew" then
		session:addWeapon(choice.id)
	else
		local tome
		for _, t in session.tomes do
			if t.id == choice.id then
				tome = t
			end
		end
		if not tome then
			tome = { id = choice.id, def = Catalog.Tome[choice.id], level = 0, values = {} }
			table.insert(session.tomes, tome)
		end
		tome.level += 1
		tome.values[choice.stat] = (tome.values[choice.stat] or 0) + choice.delta
		session:recordMax("tome." .. tome.id, tome.level)
		session:onTomeLevel(tome)
	end
	session.statsDirty = true
end

-- Clave de contenido de una elección (para Banish)
function Offers.contentKey(choice): string
	if choice.type == "WeaponUp" or choice.type == "WeaponNew" then
		return "weapon:" .. choice.id
	end
	return "tome:" .. choice.id
end

return Offers
