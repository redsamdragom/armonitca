-- Director de enemigos: población por tiempo de etapa y dificultad, élites, minijefes, jefe del
-- portal (con Boss Curse) y Final Swarm. Curvas [Pendiente] de calibración.
--
-- Relojes (ver HUD): `session.stageTime` es la cuenta atrás de la etapa; al llegar a 0 empieza el
-- Final Swarm y corre `session.swarmTime`. `session.stageElapsed` cuenta el tiempo transcurrido.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Ground = require(script.Parent.Parent.World.Ground)

local Director = {}
Director.__index = Director

function Director.new(session)
	return setmetatable({
		session = session,
		spawnTimer = 1,
		swarmTimer = 0,
		minibossIndex = 1,
	}, Director)
end

function Director:difficulty(): number
	local session = self.session
	return session.stats.Difficulty + session.tier.difficulty
end

function Director:healthMult(): number
	local session = self.session
	local minutes = session.stageElapsed / 60
	return (1 + Config.Enemies.HealthGrowthPerMinute * minutes) * (1 + self:difficulty()) * (1 + 0.6 * (session.stage - 1))
end

function Director:damageMult(): number
	local session = self.session
	local minutes = session.stageElapsed / 60
	return (1 + Config.Enemies.DamageGrowthPerMinute * minutes) * (1 + 0.5 * self:difficulty()) * (1 + 0.25 * (session.stage - 1))
end

function Director:basicEnemy(): string
	return self.session.map.spawns[1].enemy
end

function Director:pickEnemy(): string
	local elapsed = self.session.stageElapsed
	local total = 0
	local pool = {}
	for _, entry in self.session.map.spawns do
		if elapsed >= entry.from then
			total += entry.weight
			table.insert(pool, entry)
		end
	end
	local roll = self.session.rng:NextNumber() * total
	for _, entry in pool do
		roll -= entry.weight
		if roll <= 0 then
			return entry.enemy
		end
	end
	return pool[#pool].enemy
end

function Director:spawnNear(defId: string, center: Vector3, minDistance: number, maxDistance: number, opts: any?)
	local session = self.session
	local rng = session.rng
	local half = session.mapHalfSize - 6
	local angle = rng:NextNumber(0, math.pi * 2)
	local distance = rng:NextNumber(minDistance, maxDistance)
	local x = math.clamp(center.X + math.cos(angle) * distance, -half, half)
	local z = math.clamp(center.Z + math.sin(angle) * distance, -half, half)
	local y = Ground.top(x, z, 0)
	opts = opts or {}
	opts.hpMult = (opts.hpMult or 1) * self:healthMult()
	opts.dmgMult = (opts.dmgMult or 1) * self:damageMult()
	return session.enemies:spawn(defId, Vector3.new(x, y, z), opts)
end

function Director:spawnBoss(position: Vector3)
	local session = self.session
	local bossId = session.tier.boss
	local finalStage = session.stage >= session.map.stagesPerTier
	local hpMult = if finalStage then 1.6 else 1 -- [Pendiente]
	local copies = 1 + session.bossCurses
	local bosses = {}
	for i = 1, copies do
		local boss = self:spawnNear(bossId, position, 8, 14, { hpMult = hpMult })
		boss.isStageBoss = true
		boss.isFinalBoss = finalStage
		boss.cursed = i > 1
		table.insert(bosses, boss)
	end
	return bosses
end

function Director:update(dt: number)
	local session = self.session
	local enemies = session.enemies
	local rootPos = session.root.Position
	local minutes = session.stageElapsed / 60

	if session.swarm then
		local swarm = Catalog.FinalSwarm
		self.swarmTimer -= dt
		if self.swarmTimer <= 0 and enemies:count() < Config.Enemies.MaxActive then
			self.swarmTimer = swarm.baseInterval
			local speedUp = 1
			if session.swarmTime > swarm.speedUpAfter then
				speedUp += (session.swarmTime - swarm.speedUpAfter) / 60 * swarm.speedUpPerMinute
			end
			for _ = 1, swarm.batch do
				local ghost = self:spawnNear(swarm.enemy, rootPos, Config.Enemies.SpawnDistanceMin, Config.Enemies.SpawnDistanceMax, {
					hpMult = 1 + session.swarmTime / 60,
				})
				ghost.speedMult = speedUp
				ghost.ccImmune = session.swarmTime > swarm.ccImmuneAfter
			end
		end
		return
	end

	-- Minijefes por tiempo de etapa
	local mini = session.map.minibosses[self.minibossIndex]
	if mini and session.stageElapsed >= mini.at then
		self.minibossIndex += 1
		local m = self:spawnNear(mini.enemy, rootPos, 30, 45)
		m.spawnedAt = session.time
		session:toast(string.format("¡%s ha aparecido!", m.def.name))
	end

	self.spawnTimer -= dt
	if self.spawnTimer <= 0 and enemies:count() < Config.Enemies.MaxActive then
		local interval = 1.1 * 0.88 ^ minutes / (1 + self:difficulty())
		self.spawnTimer = math.max(0.12, interval)
		local batch = 1 + math.floor(minutes / 1.5)
		local eliteChance = Config.Enemies.EliteChance * (1 + session.stats.EliteSpawn) * (1 + minutes * 0.1)
		for _ = 1, batch do
			local elite = session.rng:NextNumber() < eliteChance
			self:spawnNear(self:pickEnemy(), rootPos, Config.Enemies.SpawnDistanceMin, Config.Enemies.SpawnDistanceMax, { elite = elite })
		end
	end
end

return Director
