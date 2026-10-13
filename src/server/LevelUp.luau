-- Experiencia, subida de nivel y elección de mejoras (1 de 3 cartas).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local PlayerState = require(script.Parent.PlayerState)

local LevelUp = {}

local remotes

local function buildCandidates(state)
	local candidates = {}
	for id, def in Config.Weapons do
		local level = state.Weapons[id]
		if level then
			if level < def.MaxLevel then
				table.insert(candidates, { Kind = "Weapon", Id = id, Level = level + 1 })
			end
		elseif state.WeaponCount < Config.Player.MaxWeapons then
			table.insert(candidates, { Kind = "Weapon", Id = id, Level = 1 })
		end
	end
	for id, def in Config.Passives do
		local level = state.Passives[id] or 0
		if level < def.MaxLevel then
			table.insert(candidates, { Kind = "Passive", Id = id, Level = level + 1 })
		end
	end
	return candidates
end

local function describe(choice)
	local def = if choice.Kind == "Weapon" then Config.Weapons[choice.Id] else Config.Passives[choice.Id]
	local isNew = choice.Kind == "Weapon" and choice.Level == 1
	return {
		Kind = choice.Kind,
		Id = choice.Id,
		Level = choice.Level,
		Name = def.Name,
		Description = if isNew then "¡Nueva! " .. def.Description else def.Description,
	}
end

function LevelUp.offerNext(player: Player)
	local state = PlayerState.get(player)
	if not state or state.CurrentOffer or state.PendingLevelUps <= 0 then
		return
	end
	local candidates = buildCandidates(state)
	if #candidates == 0 then
		state.PendingLevelUps = 0
		return
	end

	local offer = {}
	for _ = 1, math.min(3, #candidates) do
		local choice = table.remove(candidates, math.random(#candidates))
		table.insert(offer, describe(choice))
	end
	state.CurrentOffer = offer
	remotes.LevelUpOffer:FireClient(player, offer)
end

local function apply(player: Player, state, choice)
	if choice.Kind == "Weapon" then
		if not state.Weapons[choice.Id] then
			state.WeaponCount += 1
		end
		state.Weapons[choice.Id] = choice.Level
	else
		state.Passives[choice.Id] = choice.Level
		PlayerState.applyCharacterStats(player)
	end
end

local function onChoose(player: Player, index: unknown)
	local state = PlayerState.get(player)
	if typeof(index) ~= "number" or not state or not state.CurrentOffer then
		return
	end
	local choice = state.CurrentOffer[index]
	if not choice then
		return
	end
	apply(player, state, choice)
	state.CurrentOffer = nil
	state.PendingLevelUps -= 1
	LevelUp.offerNext(player)
end

function LevelUp.init(remoteEvents)
	remotes = remoteEvents
	remotes.ChooseUpgrade.OnServerEvent:Connect(onChoose)
end

function LevelUp.addXP(player: Player, amount: number)
	local state = PlayerState.get(player)
	if not state then
		return
	end
	state.XP += amount
	while state.XP >= state.XPToNext do
		state.XP -= state.XPToNext
		state.Level += 1
		state.XPToNext = Config.xpToNext(state.Level)
		state.PendingLevelUps += 1
	end
	LevelUp.offerNext(player)
end

return LevelUp
