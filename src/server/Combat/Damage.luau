-- Canalización de daño: a enemigos (grupos de cálculo, crítico, ejecución, retroceso, robo de
-- vida, activación de objetos) y al jugador (bloqueos, evasión, armadura, escudo, espinas).
--
-- Grupos de cálculo (se multiplican entre sí; dentro de cada grupo se suma):
--   general   1 + Damage (tomos, objetos planos, pasivas por nivel)
--   pasiva    efectos condicionales del personaje (impulso, oro, congelados, vida baja, Flex)
--   objetos   condicionales de objetos (en el aire, cerca, vida alta, vida baja, quieto...)
--   élite     1 + EliteDamage contra élites y jefes
--   veneno    1 + PoisonDamage para daño de veneno
-- La agrupación sigue el análisis comunitario de grupos de daño; los detalles son [Pendiente].

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Stats = require(ReplicatedStorage.Shared.Stats)
local Fx = require(script.Parent.Fx)

local Damage = {}

-- Enlazado tardío (RunSession): Items, Passives, Weapons, Status
Damage.Items = nil :: any
Damage.Passives = nil :: any
Damage.Weapons = nil :: any
Damage.Status = nil :: any

local MAX_PROC_DEPTH = 2

function Damage.multiplier(session, enemy, info): number
	local s = session.stats
	local m = 1 + s.Damage
	m *= Damage.Passives.damageMult(session, enemy, info)
	m *= Damage.Items.damageMult(session, enemy, info)
	if enemy.elite or enemy.boss or enemy.miniboss then
		m *= 1 + s.EliteDamage
	end
	if info.element == "Poison" then
		m *= 1 + s.PoisonDamage
	end
	if session.airborne then
		m *= 1 + s.AirDamage
	end
	m *= session.tempDamageMult
	return m
end

-- info: { source, amount, weapon?, canCrit?, procCoef?, element?, knockback?: Vector3,
--         isDot?, depth?, executeChance?, critBonus?, flat? }
function Damage.toEnemy(session, enemy, info): number
	if enemy.dead or session.ended then
		return 0
	end
	local s = session.stats
	local rng = session.rng
	local amount = info.amount
	if not info.flat then
		amount *= Damage.multiplier(session, enemy, info)
	end

	local isCrit = false
	local kind = info.kind or "normal"
	if info.canCrit ~= false and not info.isDot then
		local w = info.weapon
		local chance = s.CritChance + (if w then w.stats.CritChance or 0 else 0) + (info.critBonus or 0)
		local critMult = Config.Player.BaseCritDamage + s.CritDamage + (if w then w.stats.CritDamage or 0 else 0)
		local tiers = math.floor(chance)
		if rng:NextNumber() < chance - tiers then
			tiers += 1
		end
		if tiers > 0 then
			isCrit = true
			amount *= 1 + (critMult - 1) * tiers
			amount *= Damage.Items.critMult(session)
			kind = if tiers > 1 then "overcrit" else "crit"
			session:addCounter("crits", 1)
		end
	end

	if info.executeChance and not (enemy.boss or enemy.miniboss) and rng:NextNumber() < info.executeChance then
		amount = math.max(amount, enemy.health)
		kind = "execute"
	end

	enemy.health -= amount
	session:recordDamage(info.source, amount)
	Fx.damageNumber(session.player, enemy.pos + Vector3.new(0, enemy.halfHeight + 1, 0), amount, kind)
	session.enemies:flash(enemy)

	if not info.isDot and (info.depth or 0) == 0 then
		Damage.lifestealRoll(session, s.Lifesteal, "lifesteal")
		Damage.lifestealRoll(session, s.BloodyHeal, "bloody")
	end

	if info.knockback and not (enemy.boss or enemy.miniboss) then
		enemy.vel += info.knockback * (1 + s.Knockback)
	end

	if enemy.health <= 0 then
		session.enemies:kill(enemy, info)
		return amount
	end

	Damage.Status.checkBloodmark(session, enemy)

	if (info.procCoef or 0) > 0 and (info.depth or 0) < MAX_PROC_DEPTH and not enemy.dead then
		Damage.Items.onHit(session, enemy, info, amount, isCrit)
		Damage.Passives.onHit(session, enemy, info, amount, isCrit)
	end
	return amount
end

-- Probabilidad (puede superar 1) de curar 1 de vida por impacto.
function Damage.lifestealRoll(session, chance: number, source: string)
	if chance <= 0 then
		return
	end
	local heals = math.floor(chance)
	if session.rng:NextNumber() < chance - heals then
		heals += 1
	end
	if heals > 0 then
		Damage.heal(session, heals, source)
	end
end

function Damage.heal(session, amount: number, source: string?)
	if session.ended or amount <= 0 then
		return
	end
	local maxHealth = session.stats.MaxHealth
	local cap = maxHealth * (1 + session.stats.Overheal)
	local before = session.health
	session.health = math.min(cap, session.health + amount)
	local healed = session.health - before
	if healed > 0 then
		if source == "lifesteal" then
			session:addCounter("heal.lifesteal", healed)
		end
		Damage.Items.onHeal(session, healed, source)
	end
end

-- Daño recibido por el jugador.
function Damage.toPlayer(session, amount: number, attacker, opts: any?)
	if session.ended or session.paused or session.state ~= "Playing" then
		return
	end
	opts = opts or {}
	local s = session.stats
	if not opts.selfInflicted then
		if session.time < session.invulnUntil then
			return
		end
		if Damage.Passives.tryBlock(session, attacker) then
			return
		end
		if Damage.Weapons.tryAegisBlock(session, attacker) then
			return
		end
		if session.rng:NextNumber() < Stats.diminishing(s.Evasion) then
			Fx.damageNumber(session.player, session.root.Position + Vector3.new(0, 3, 0), 0, "evade")
			Damage.Items.onEvade(session, attacker)
			Damage.Passives.onEvade(session, attacker)
			return
		end
		local mitigated = amount * Stats.diminishing(s.Armor)
		amount -= mitigated
		session:addCounter("mitigated.char." .. session.characterId, mitigated)
		amount *= session.incomingMult
	end

	local raw = amount
	if not opts.selfInflicted and session.shield > 0 then
		-- El escudo absorbe el golpe completo; el exceso no pasa a la vida [Referencia comunitaria, validar]
		session.shield = math.max(0, session.shield - amount)
		amount = 0
	end
	if amount > 0 then
		local floor = if opts.selfInflicted then 1 else -math.huge
		session.health = math.max(floor, session.health - amount)
	end

	if not opts.selfInflicted then
		session.lastDamageTime = session.time
		session.invulnUntil = session.time + Config.Player.ContactInvulnerability
		session.runFlags.tookDamage = true
	end
	Fx.damageNumber(session.player, session.root.Position + Vector3.new(0, 3, 0), raw, "player")
	Damage.Passives.onDamageTaken(session, raw, attacker)
	Damage.Items.onDamageTaken(session, raw, attacker, opts.selfInflicted == true)

	if attacker and not attacker.dead and s.Thorns > 0 and not opts.selfInflicted then
		Damage.toEnemy(session, attacker, {
			source = "thorns",
			amount = s.Thorns,
			canCrit = false,
			procCoef = 0,
			kind = "thorns",
			thorns = true,
		})
		Damage.Items.onThorns(session, attacker, s.Thorns)
	end

	if session.health <= 0 then
		session:onLethal()
	end
end

return Damage
