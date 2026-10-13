-- Botín de objetos: rareza según la suerte y selección de un objeto elegible
-- (desbloqueado, sin superar su límite de copias).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Catalog = require(ReplicatedStorage.Shared.Catalog)

local Loot = {}

function Loot.rollRarity(session): string
	local luck = math.max(0, session.stats.Luck)
	local weights, total = {}, 0
	for i, rarity in Catalog.ItemRarities do
		local w = Config.Items.RarityWeights[rarity] * (1 + luck) ^ (i - 1)
		weights[i] = w
		total += w
	end
	local roll = session.rng:NextNumber() * total
	for i, rarity in Catalog.ItemRarities do
		roll -= weights[i]
		if roll <= 0 then
			return rarity
		end
	end
	return "Common"
end

function Loot.eligible(session, rarity: string)
	local list = {}
	for _, item in ipairs(Catalog.Items) do
		if item.rarity == rarity and session.unlocked["item:" .. item.id] then
			local owned = session.items[item.id] or 0
			if not item.cap or owned < item.cap then
				table.insert(list, item)
			end
		end
	end
	return list
end

-- Devuelve un objeto de la rareza pedida (o de una inferior si no hay elegibles).
function Loot.pick(session, rarity: string?)
	rarity = rarity or Loot.rollRarity(session)
	local order = { "Legendary", "Epic", "Rare", "Common" }
	local start = table.find(order, rarity) or 4
	for i = start, #order do
		local list = Loot.eligible(session, order[i])
		if #list > 0 then
			return list[session.rng:NextInteger(1, #list)]
		end
	end
	return nil
end

return Loot
