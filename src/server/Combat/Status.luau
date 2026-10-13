-- Estados alterados de los enemigos: Poison, Burn, Freeze, Stun, Bloodmark y maldición.
-- Todos usan el reloj de la partida (`session.time`), que se detiene en pausa y menús.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Fx = require(script.Parent.Fx)

local Status = {}
Status.Damage = nil :: any -- enlazado tardío

local POISON = Color3.fromRGB(160, 80, 220)

local function track(session, enemy)
	session.statusEnemies[enemy] = true
end

-- Veneno: pulsos cada 0,5 s; duración 5 × multiplicador de duración; daño por pulso
-- cargas × max(1, multiplicador de daño). Las cargas no tienen máximo documentado.
function Status.poison(session, enemy, stacks: number, source: string)
	if enemy.dead or stacks <= 0 then
		return
	end
	local first = (enemy.poison or 0) == 0
	enemy.poison = (enemy.poison or 0) + stacks
	enemy.poisonUntil = session.time + Config.Status.PoisonDuration * (1 + session.stats.Duration)
	enemy.poisonTick = enemy.poisonTick or (session.time + Config.Status.PoisonTick)
	enemy.poisonSource = source
	if first then
		session.poisonedAlive += 1
		if source == "item:MoldyCheese" then
			session:addCounter("poisoned.MoldyCheese", 1)
		end
	end
	track(session, enemy)
end

function Status.burn(session, enemy, dps: number, duration: number?, source: string)
	if enemy.dead then
		return
	end
	enemy.burnDps = math.max(enemy.burnDps or 0, dps)
	enemy.burnUntil = session.time + (duration or Config.Status.BurnDuration) * (1 + session.stats.Duration)
	enemy.burnTick = enemy.burnTick or (session.time + Config.Status.BurnTick)
	enemy.burnSource = source
	track(session, enemy)
end

-- Congelación: −70% de velocidad (no inmovilidad absoluta). Los jefes no se congelan durante
-- el Final Swarm avanzado (ver Director).
function Status.freeze(session, enemy, duration: number, source: string)
	if enemy.dead or enemy.ccImmune then
		return
	end
	local now = session.time
	local wasFrozen = enemy.frozenUntil and enemy.frozenUntil > now
	enemy.frozenUntil = math.max(enemy.frozenUntil or 0, now + duration * (1 + session.stats.Duration))
	if not wasFrozen then
		enemy.part.Color = enemy.color:Lerp(Color3.fromRGB(80, 220, 210), 0.6)
		if source == "item:IceCube" then
			session:addCounter("freeze.IceCube", 1)
		end
	end
	track(session, enemy)
end

-- Aturdimiento: inmoviliza. Contra jefes dura la mitad y no cancela un ataque ya preparado [Pendiente].
function Status.stun(session, enemy, duration: number)
	if enemy.dead or enemy.ccImmune then
		return
	end
	if enemy.boss or enemy.miniboss then
		duration *= 0.5
	end
	enemy.stunnedUntil = math.max(enemy.stunnedUntil or 0, session.time + duration)
end

-- Bloodmark: daño pendiente que detona al expirar o cuando sería letal.
-- Daño: (nivel + 8) × 0,75 × multiplicador de daño × cargas.
function Status.bloodmark(session, enemy, stacks: number, fromLifesteal: boolean?)
	if enemy.dead or stacks <= 0 then
		return
	end
	local base = if fromLifesteal then Config.Status.BloodmarkDurationLifesteal else Config.Status.BloodmarkDurationWeapon
	enemy.bloodmark = (enemy.bloodmark or 0) + stacks
	enemy.bloodmarkUntil = session.time + base * (1 + session.stats.Duration)
	track(session, enemy)
	Status.checkBloodmark(session, enemy)
end

local function bloodmarkDamage(session, enemy): number
	return (session.level + 8) * 0.75 * (1 + session.stats.Damage) * (enemy.bloodmark or 0)
end

local function detonate(session, enemy)
	local stacks = enemy.bloodmark or 0
	if stacks <= 0 then
		return
	end
	local amount = bloodmarkDamage(session, enemy)
	enemy.bloodmark = 0
	enemy.bloodmarkUntil = nil
	Fx.ring(enemy.pos, enemy.radius + 1.5, Color3.fromRGB(150, 0, 20), 0.2)
	Status.Damage.toEnemy(session, enemy, {
		source = "status:Bloodmark",
		amount = amount,
		canCrit = false,
		procCoef = 0,
		flat = true,
		isDot = true,
		kind = "bloodmark",
	})
end

function Status.checkBloodmark(session, enemy)
	if not enemy.dead and (enemy.bloodmark or 0) > 0 and enemy.health <= bloodmarkDamage(session, enemy) then
		detonate(session, enemy)
	end
end

function Status.curse(session, enemy, duration: number)
	if enemy.dead then
		return
	end
	enemy.cursedUntil = session.time + duration
	enemy.curseTick = session.time + 1
	track(session, enemy)
end

local function clearPoison(session, enemy)
	if (enemy.poison or 0) > 0 then
		session.poisonedAlive = math.max(0, session.poisonedAlive - 1)
	end
	enemy.poison = 0
	enemy.poisonUntil = nil
	enemy.poisonTick = nil
end

function Status.onDeath(session, enemy)
	if (enemy.poison or 0) > 0 then
		session.poisonedAlive = math.max(0, session.poisonedAlive - 1)
	end
	session.statusEnemies[enemy] = nil
end

function Status.tick(session)
	local now = session.time
	local frozen = 0
	local Damage = Status.Damage
	for enemy in session.statusEnemies do
		if enemy.dead then
			session.statusEnemies[enemy] = nil
			continue
		end
		local active = false

		if enemy.poisonUntil then
			if now >= enemy.poisonUntil then
				clearPoison(session, enemy)
			else
				active = true
				if now >= enemy.poisonTick then
					enemy.poisonTick += Config.Status.PoisonTick
					local amount = enemy.poison * math.max(1, 1 + session.stats.Damage) * (1 + session.stats.PoisonDamage)
					Damage.toEnemy(session, enemy, {
						source = enemy.poisonSource or "status:Poison",
						amount = amount,
						canCrit = false,
						procCoef = 0,
						flat = true,
						isDot = true,
						element = "Poison",
						kind = "poison",
					})
				end
			end
		end

		if not enemy.dead and enemy.burnUntil then
			if now >= enemy.burnUntil then
				enemy.burnUntil, enemy.burnDps, enemy.burnTick = nil, nil, nil
			else
				active = true
				if now >= enemy.burnTick then
					enemy.burnTick += Config.Status.BurnTick
					Damage.toEnemy(session, enemy, {
						source = enemy.burnSource or "status:Burn",
						amount = enemy.burnDps * Config.Status.BurnTick,
						canCrit = false,
						procCoef = 0,
						isDot = true,
						element = "Fire",
						kind = "burn",
					})
				end
			end
		end

		if not enemy.dead and enemy.frozenUntil then
			if now >= enemy.frozenUntil then
				enemy.frozenUntil = nil
				if enemy.flashUntil == 0 then
					enemy.part.Color = enemy.color
				end
			else
				active = true
				frozen += 1
			end
		end

		if not enemy.dead and enemy.bloodmarkUntil then
			active = true
			if now >= enemy.bloodmarkUntil then
				detonate(session, enemy)
			end
		end

		if not enemy.dead and enemy.cursedUntil then
			if now >= enemy.cursedUntil then
				enemy.cursedUntil = nil
			else
				active = true
				if now >= enemy.curseTick then
					enemy.curseTick += 1
					local amount = if enemy.boss or enemy.miniboss
						then (8 + session.level) * 0.7
						else enemy.maxHealth * 0.3
					Damage.toEnemy(session, enemy, {
						source = "item:CursedDoll",
						amount = amount,
						canCrit = false,
						procCoef = 1,
						flat = true,
						isDot = true,
						kind = "curse",
					})
				end
			end
		end

		if not active and not enemy.dead then
			session.statusEnemies[enemy] = nil
		end
	end
	session.frozenCount = frozen
end

Status.POISON_COLOR = POISON

return Status
