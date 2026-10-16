-- Recalcula las estadísticas de la partida a partir de personaje, nivel, tomos, objetos,
-- santuarios y bonificaciones temporales. Se llama cuando `session.statsDirty` es verdadero.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Stats = require(ReplicatedStorage.Shared.Stats)
local Items = require(script.Parent.Parent.Combat.Items)

local StatBlock = {}

function StatBlock.compute(session)
	local s = table.clone(Stats.Defaults)
	local character = session.character
	s.MaxHealth = Config.Player.BaseMaxHealth
	s.JumpHeight = Config.Player.BaseJumpHeight
	s.PickupRange = Config.Player.BasePickupRange

	for stat, value in character.stats do
		if Stats.Absolute[stat] then
			s[stat] = value
		else
			s[stat] += value
		end
	end
	for stat, value in character.passive.perLevel or {} do
		s[stat] += value * (session.level - 1)
	end
	for _, tome in session.tomes do
		for stat, value in tome.values do
			s[stat] += value
		end
	end
	for stat, value in session.bonus do
		s[stat] += value
	end
	for stat, value in session.powerupStats do
		s[stat] += value
	end

	session.maxHealthMult = 1
	session.regenMult = 1
	Items.applyStats(session, s)
	Items.postStats(session, s)

	s.MaxHealth = math.max(1, s.MaxHealth * session.maxHealthMult)
	s.Regen *= session.regenMult
	s.ExtraJumps = math.floor(s.ExtraJumps + 1e-6)
	return s
end

return StatBlock
