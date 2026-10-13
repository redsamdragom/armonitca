-- Estado de cada jugador durante una partida: nivel, XP, armas y pasivas.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local PlayerState = {}

local states: { [Player]: any } = {}

local function newState()
	local starting = Config.Player.StartingWeapon
	return {
		Level = 1,
		XP = 0,
		XPToNext = Config.xpToNext(1),
		Kills = 0,
		Weapons = { [starting] = 1 }, -- id -> nivel
		WeaponCount = 1,
		Passives = {}, -- id -> nivel
		PendingLevelUps = 0,
		CurrentOffer = nil,
		Cooldowns = {},
	}
end

function PlayerState.reset(player: Player)
	states[player] = newState()
	return states[player]
end

function PlayerState.get(player: Player)
	return states[player]
end

function PlayerState.remove(player: Player)
	states[player] = nil
end

-- Multiplicadores derivados de las pasivas.
function PlayerState.stats(state)
	local stats = { DamageMult = 1, CooldownMult = 1, SpeedMult = 1, BonusHealth = 0, PickupMult = 1 }
	for id, level in state.Passives do
		local passive = Config.Passives[id]
		stats[passive.Stat] += passive.PerLevel * level
	end
	stats.CooldownMult = math.max(0.3, stats.CooldownMult)
	return stats
end

-- Aplica velocidad y vida máxima al Humanoid del jugador.
function PlayerState.applyCharacterStats(player: Player)
	local state = states[player]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not state or not humanoid or humanoid.Health <= 0 then
		return
	end
	local stats = PlayerState.stats(state)
	humanoid.WalkSpeed = Config.Player.WalkSpeed * stats.SpeedMult
	local newMax = Config.Player.MaxHealth + stats.BonusHealth
	local gained = newMax - humanoid.MaxHealth
	humanoid.MaxHealth = newMax
	if gained > 0 then
		humanoid.Health += gained
	end
end

return PlayerState
