-- Sesión de partida de un jugador: estado, bucle de simulación, progreso dentro de la partida,
-- menús de elección (con pausa real), jefes, etapas, Final Swarm y resultados.
-- El progreso de la cuenta se registra en contadores que se vuelcan al perfil al terminar.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Net = require(ReplicatedStorage.Shared.Net)

local Server = script.Parent.Parent
local Fx = require(Server.Combat.Fx)
local Damage = require(Server.Combat.Damage)
local Status = require(Server.Combat.Status)
local Enemies = require(Server.Combat.Enemies)
local Weapons = require(Server.Combat.Weapons)
local Items = require(Server.Combat.Items)
local Ground = require(Server.World.Ground)
local MapGen = require(Server.World.MapGen)
local Interactables = require(Server.World.Interactables)
local Costumes = require(Server.World.Costumes)
local StatBlock = require(script.Parent.StatBlock)
local Offers = require(script.Parent.Offers)
local Passives = require(script.Parent.Passives)
local Director = require(script.Parent.Director)
local Pickups = require(script.Parent.Pickups)

-- Enlazado tardío entre módulos de combate
Damage.Items = Items
Damage.Passives = Passives
Damage.Weapons = Weapons
Damage.Status = Status
Status.Damage = Damage
Enemies.Damage = Damage

local RunSession = {}
RunSession.__index = RunSession

local HUD_INTERVAL = 0.15

function RunSession.new(player: Player, profile, opts)
	local character = Catalog.Character[opts.character]
	local map = Catalog.Map[opts.map]
	local self = setmetatable({}, RunSession)
	self.player = player
	self.profile = profile
	self.character = character
	self.characterId = character.id
	self.map = map
	self.tierIndex = opts.tier
	self.tier = map.tiers[opts.tier]
	self.stage = 1
	self.seed = opts.seed or Random.new():NextInteger(1, 2 ^ 30)
	self.rng = Random.new(self.seed)
	self.time = 0
	self.totalTime = 0
	self.frame = 0
	self.state = "Loading"
	self.paused = false
	self.modal = nil
	self.modalQueue = {}

	self.level = 1
	self.xp = 0
	self.xpToNext = Config.xpToNext(1)
	self.gold = 0
	self.silverFound = 0
	self.kills = 0
	self.bossesDefeated = 0

	self.weapons = {}
	self.tomes = {}
	self.items = {}
	self.itemData = {}
	self.bonus = {}
	self.powerupStats = {}
	self.timedStats = {}
	self.passiveData = {}
	self.unlocked = profile:unlockedSet()
	self.banished = {}
	self.weaponSlots = profile:weaponSlots()
	self.tomeSlots = profile:tomeSlots()
	self.charges = profile:offerCharges()
	self.settings = profile.data.Settings

	self.projectiles = {}
	self.zones = {}
	self.pickups = {}
	self.gemCount = 0
	self.statusEnemies = {}
	self.delayed = {}
	self.counters = {}
	self.maxes = {}
	self.damageBySource = {}
	self.runFlags = { tookDamage = false, usedShrine = false, pickedItem = false, pickedPowerup = false }

	self.weaponLevelBonus = 0
	self.tomeLevelBonus = 0
	self.tempDamageMult = 1
	self.tempAttackSpeed = 0
	self.passiveAttackSpeed = 0
	self.incomingMult = 1
	self.maxHealthMult = 1
	self.regenMult = 1
	self.invulnUntil = 0
	self.lastDamageTime = 0
	self.chestsOpened = 0
	self.chestsBought = 0
	self.bossCurses = 0
	self.chargeShrinesDone = 0
	self.chargeShrinesTotal = 0
	self.microwaveStreak = { id = nil, count = 0 }
	self.poisonedAlive = 0
	self.frozenCount = 0
	self.stationaryTime = 0
	self.horizontalSpeed = 0
	self.frameDistance = 0
	self.airborne = false
	self.runPots = 0
	self.runIdleKills = 0
	self.stageTime = map.stageDuration
	self.stageElapsed = 0
	self.swarm = false
	self.swarmTime = 0
	self.bossActive = false
	self.bosses = {}
	self.aimDir = Vector3.zAxis
	self.hudTimer = 0
	self.markersDirty = true
	self.markerTimer = 0
	self.timeSlowUntil = 0

	self.stats = StatBlock.compute(self)
	self.statsDirty = false
	self.health = self.stats.MaxHealth
	self.shield = self.stats.Shield
	return self
end

-- Utilidades usadas por los módulos de combate --------------------------------------------------

function RunSession:addCounter(key: string, amount: number)
	self.counters[key] = (self.counters[key] or 0) + amount
end

function RunSession:recordMax(key: string, value: number)
	if value > (self.maxes[key] or -math.huge) then
		self.maxes[key] = value
	end
end

function RunSession:recordDamage(source: string, amount: number)
	self.damageBySource[source] = (self.damageBySource[source] or 0) + amount
end

function RunSession:after(delay: number, fn)
	table.insert(self.delayed, { at = self.time + delay, fn = fn })
end

function RunSession:addZone(zone)
	return Weapons.addZone(self, zone)
end

function RunSession:spawnPickup(kind: string, position: Vector3, value: number, opts: any?)
	return Pickups.spawn(self, kind, position, value, opts)
end

function RunSession:magnetGems(radius: number?)
	Pickups.magnetAll(self, radius)
end

function RunSession:spawnFreeChest()
	if self.interactables and self.root then
		self.interactables:spawnFreeChest(self.root.Position)
	end
end

function RunSession:toast(text: string)
	Net.get("Toast"):FireClient(self.player, text)
end

function RunSession:markersChanged()
	self.markersDirty = true
end

function RunSession:canInteract(): boolean
	return self.state == "Playing" and not self.paused and self.modal == nil
end

function RunSession:setTimeSlow(duration: number)
	self.timeSlowUntil = self.time + duration
	self:toast("¡Speed Boi!")
end

function RunSession:addTimedStats(stats, duration: number)
	table.insert(self.timedStats, { stats = stats, untilTime = self.time + duration })
	self:rebuildTimedStats()
end

function RunSession:rebuildTimedStats()
	table.clear(self.powerupStats)
	for _, entry in self.timedStats do
		for stat, value in entry.stats do
			self.powerupStats[stat] = (self.powerupStats[stat] or 0) + value
		end
	end
	self.statsDirty = true
end

function RunSession:gainGold(amount: number, raw: boolean?)
	if not raw then
		amount *= 1 + self.stats.GoldGain
	end
	self.gold += amount
end

function RunSession:gainXP(amount: number)
	amount *= 1 + self.stats.XPGain
	self.xp += amount
	while self.xp >= self.xpToNext and self.level < Config.Player.MaxLevel do
		self.xp -= self.xpToNext
		self.level += 1
		self.xpToNext = Config.xpToNext(self.level)
		self.statsDirty = true
		-- Cada nivel aplica su pasiva y su propia selección de mejora
		Passives.onLevelUp(self)
		self:recordMax("level.char." .. self.characterId, self.level)
		self:queueLevelUp()
	end
end

function RunSession:addWeapon(id: string)
	if #self.weapons >= self.weaponSlots then
		return nil
	end
	local w = Weapons.new(id)
	table.insert(self.weapons, w)
	Weapons.compute(self, w)
	self:recordMax("weapon." .. id, 1)
	return w
end

function RunSession:addItem(id: string, n: number)
	self.items[id] = (self.items[id] or 0) + n
	self.runFlags.pickedItem = true
	Items.onAcquire(self, id)
	self:recordMax("run." .. id, self.items[id])
	self.statsDirty = true
end

function RunSession:removeItem(id: string, n: number)
	local left = (self.items[id] or 0) - n
	self.items[id] = if left > 0 then left else nil
	Items.onAcquire(self, id) -- recalcula límites (Pot, Wizard's Hat)
	self.statsDirty = true
end

function RunSession:onTomeLevel(tome)
	if tome.id == "Cursed" and tome.level >= 20 and self.totalTime < 600 then
		self:addCounter("event.CursedTome20Before10", 1)
	end
	local agility, cooldown = 0, 0
	for _, t in self.tomes do
		if t.id == "Agility" then
			agility = t.level
		elseif t.id == "Cooldown" then
			cooldown = t.level
		end
	end
	if agility >= 5 and cooldown >= 5 then
		self:addCounter("event.AgilityCooldown5", 1)
	end
end

-- Menús de elección (pausan toda la simulación) ----------------------------------------------

local function publicChoices(choices)
	local list = {}
	for _, c in choices do
		table.insert(list, {
			type = c.type,
			id = c.id,
			level = c.level,
			rarity = c.rarity,
			name = c.name,
			subtitle = c.subtitle,
			desc = c.desc,
			changes = c.changes,
		})
	end
	return list
end

function RunSession:sendModal()
	local modal = self.modal
	if not modal then
		Net.get("Modal"):FireClient(self.player, nil)
		return
	end
	Net.get("Modal"):FireClient(self.player, {
		kind = modal.kind,
		title = modal.title,
		choices = publicChoices(modal.choices),
		canSkip = modal.canSkip,
		charges = if modal.kind == "LevelUp" then self.charges else nil,
		remaining = #self.modalQueue,
	})
end

function RunSession:showNextModal()
	while not self.modal and #self.modalQueue > 0 do
		local modal = table.remove(self.modalQueue, 1)
		if modal.build then
			modal.choices = modal.build()
		end
		if #modal.choices > 0 then
			self.modal = modal
		end
	end
	self:sendModal()
end

function RunSession:openModal(modal)
	table.insert(self.modalQueue, modal)
	if not self.modal then
		self:showNextModal()
	end
end

function RunSession:queueLevelUp()
	local modal
	modal = {
		kind = "LevelUp",
		title = "¡Subiste de nivel!",
		canSkip = false,
		build = function()
			return Offers.build(self)
		end,
		onChoose = function(index)
			local choice = modal.choices[index]
			if choice then
				Offers.apply(self, choice)
			end
		end,
	}
	self:openModal(modal)
end

function RunSession:offerItem(item, sourceLabel: string)
	self:openModal({
		kind = "Item",
		title = sourceLabel,
		canSkip = true,
		choices = {
			{
				type = "Item",
				id = item.id,
				rarity = item.rarity,
				name = item.name,
				subtitle = string.format("%s · tienes %d", Catalog.RarityName[item.rarity], self.items[item.id] or 0),
				desc = item.desc,
				changes = {},
			},
		},
		onChoose = function()
			self:addItem(item.id, 1)
		end,
	})
end

function RunSession:onModalChoice(action: string, index: number?)
	local modal = self.modal
	if not modal or self.state ~= "Playing" then
		return
	end
	if action == "pick" then
		if typeof(index) ~= "number" or not modal.choices[index] then
			return
		end
		self.modal = nil
		modal.onChoose(index)
	elseif action == "skip" then
		if modal.kind == "LevelUp" then
			if self.charges.Skip <= 0 then
				return
			end
			self.charges.Skip -= 1
		elseif not modal.canSkip then
			return
		end
		self.modal = nil
	elseif action == "refresh" and modal.kind == "LevelUp" and self.charges.Refresh > 0 then
		self.charges.Refresh -= 1
		modal.choices = Offers.build(self)
		self:sendModal()
		return
	elseif action == "banish" and modal.kind == "LevelUp" and self.charges.Banish > 0 then
		local choice = typeof(index) == "number" and modal.choices[index]
		if not choice then
			return
		end
		self.charges.Banish -= 1
		self.banished[Offers.contentKey(choice)] = true
		modal.choices = Offers.build(self)
		if #modal.choices == 0 then
			self.modal = nil
		else
			self:sendModal()
			return
		end
	else
		return
	end
	if self.statsDirty then
		self:refreshStats()
	end
	self:showNextModal()
end

-- Estadísticas -------------------------------------------------------------------------------

function RunSession:refreshStats()
	local oldMax = self.stats.MaxHealth
	local oldShield = self.stats.Shield
	self.stats = StatBlock.compute(self)
	self.statsDirty = false
	local s = self.stats
	if s.MaxHealth > oldMax then
		self.health += s.MaxHealth - oldMax
	end
	self.health = math.min(self.health, s.MaxHealth * (1 + s.Overheal))
	if s.Shield > oldShield then
		self.shield += s.Shield - oldShield
	end
	self.shield = math.min(self.shield, s.Shield)
	self.walkSpeed = Config.Player.BaseWalkSpeed * math.max(0.2, 1 + s.MoveSpeed)
	self.pickupRadius = s.PickupRange * (1 + s.PickupMult) * Config.UnitToStuds
	for _, w in self.weapons do
		Weapons.compute(self, w)
	end
	if self.humanoid then
		self.humanoid.JumpHeight = s.JumpHeight * 0.9
		self.player:SetAttribute("ExtraJumps", s.ExtraJumps + (self.character.movement.extraJumps or 0))
	end
	self:recordMax("maxHealth", s.MaxHealth)
	self:recordMax("difficulty", math.floor((s.Difficulty + self.tier.difficulty) * 100))
end

-- Personaje y mundo --------------------------------------------------------------------------

function RunSession:spawnCharacter(position: Vector3)
	local player = self.player
	local designed = Costumes.prepare(self.character.id)
	player:LoadCharacter()
	local model = player.Character or player.CharacterAdded:Wait()
	local humanoid = model:WaitForChild("Humanoid") :: Humanoid
	local root = model:WaitForChild("HumanoidRootPart") :: BasePart
	local healthScript = model:FindFirstChild("Health")
	if healthScript then
		healthScript:Destroy()
	end
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.MaxHealth = 1e9
	humanoid.Health = 1e9
	humanoid.UseJumpPower = false
	humanoid.BreakJointsOnDeath = false
	if not designed then
		Costumes.apply(model, self.character)
	end
	model:PivotTo(CFrame.new(position + Vector3.new(0, 5, 0)))
	self.model = model
	self.humanoid = humanoid
	self.root = root
	self.lastPos = root.Position
	Ground.setIgnore({ model })

	local movement = self.character.movement
	player:SetAttribute("CanFloat", movement.float == true)
	player:SetAttribute("CanClimb", movement.climb == true)
	player:SetAttribute("LowGravity", movement.lowGravity == true)
	player:SetAttribute("InRun", true)
end

function RunSession:buildStage()
	local seed = self.seed + self.stage * 7919
	local info = MapGen.generate(self.map, seed)
	self.mapHalfSize = info.halfSize
	local rng = Random.new(seed)
	local spawnY = Ground.top(0, 0, 0)
	self.spawnPoint = Vector3.new(0, spawnY, 0)
	if self.interactables then
		self.interactables:destroy()
	end
	self.interactables = Interactables.new(self)
	self.interactables:spawnLayout(self.map, rng, self.mapHalfSize, { self.spawnPoint })
	self.director = Director.new(self)
	self.stageTime = self.map.stageDuration
	self.stageElapsed = 0
	self.swarm = false
	self.bossActive = false
	self.bosses = {}
	self.bossCurses = 0
	self.chargeShrinesDone = 0
	self.markersDirty = true
end

function RunSession:start()
	Fx.flushNumbers()
	self.enemies = Enemies.new(self)
	self:buildStage()
	self:spawnCharacter(self.spawnPoint)
	self:addWeapon(self.character.weapon)
	self:refreshStats()
	self.health = self.stats.MaxHealth
	self.shield = self.stats.Shield
	self.state = "Playing"
	Net.get("RunStarted"):FireClient(self.player, {
		character = self.characterId,
		map = self.map.id,
		mapName = self.map.name,
		tier = self.tierIndex,
		stage = self.stage,
		stages = self.map.stagesPerTier,
		halfSize = self.mapHalfSize,
		seed = self.seed,
	})
end

function RunSession:startBoss(position: Vector3)
	if self.bossActive or self.state ~= "Playing" then
		return
	end
	self.bossActive = true
	self.bossStart = self.time
	self.bosses = self.director:spawnBoss(position)
	self:toast(string.format("¡%s!", self.bosses[1].def.name))
	self:markersChanged()
end

function RunSession:nextStage()
	if self.state ~= "Playing" or self.stage >= self.map.stagesPerTier then
		return
	end
	-- Recoge lo que quedaba en el suelo para no perder recompensas
	for _, p in self.pickups do
		if p.kind == "XP" then
			self:gainXP(p.value)
		elseif p.kind == "Gold" then
			self:gainGold(p.value)
		end
	end
	Pickups.clear(self)
	Weapons.clearAll(self)
	self.enemies:destroy()
	self.enemies = Enemies.new(self)
	table.clear(self.statusEnemies)
	self.poisonedAlive = 0
	self.stage += 1
	if self.map.id == "Forest" and self.tierIndex == 2 and self.stage == 2 and self.characterId == "CL4NK" then
		self:addCounter("event.ForestT2Stage2.char.CL4NK", 1)
	end
	self:buildStage()
	self.model:PivotTo(CFrame.new(self.spawnPoint + Vector3.new(0, 5, 0)))
	self.lastPos = self.root.Position
	self:toast(string.format("Etapa %d", self.stage))
	Net.get("RunStarted"):FireClient(self.player, {
		character = self.characterId,
		map = self.map.id,
		mapName = self.map.name,
		tier = self.tierIndex,
		stage = self.stage,
		stages = self.map.stagesPerTier,
		halfSize = self.mapHalfSize,
		seed = self.seed,
	})
end

-- Muertes de enemigos y jefes ----------------------------------------------------------------

function RunSession:onEnemyKilled(enemy, info)
	self.kills += 1
	local source = info and info.source or ""
	local family = enemy.def.family
	self:addCounter("kills", 1)
	self:addCounter("kills.enemy." .. family, 1)
	self:addCounter("kills.char." .. self.characterId, 1)
	self:addCounter(string.format("kills.enemy.%s.char.%s.map.%s", family, self.characterId, self.map.id), 1)
	if enemy.def.miniboss or enemy.def.boss then
		self:addCounter("kills.boss." .. enemy.defId, 1)
	end
	local kind, id = string.match(source, "^(%a+):(.+)$")
	if kind == "weapon" then
		self:addCounter("kills.weapon." .. id, 1)
	elseif kind == "item" then
		self:addCounter("kills.item." .. id, 1)
	end
	local element = info and info.element
	if element then
		self:addCounter("kills.element." .. element, 1)
	end
	if (enemy.poison or 0) > 0 or (info and info.element == "Poison") then
		self:addCounter("kills.element.Poison", 1)
	end
	if self.stationaryTime > 1 then
		self.runIdleKills += 1
		self:recordMax("run.idleKills", self.runIdleKills)
	end
	self:recordMax("run.kills." .. self.map.id, self.kills)

	Status.onDeath(self, enemy)

	-- Botín
	local xp = enemy.def.xp * (if enemy.elite then 5 else 1)
	if xp > 0 then
		Pickups.spawn(self, "XP", enemy.pos - Vector3.new(0, enemy.halfHeight - 0.5, 0), xp)
	end
	if self.rng:NextNumber() < 0.3 or enemy.boss or enemy.miniboss then
		local gold = enemy.def.gold * Config.Economy.GoldPerKill * (1 + 0.15 * Items.count(self, "GoldenGlove")) * (1 + self.stats.GoldGain)
		Pickups.spawn(self, "Gold", enemy.pos - Vector3.new(0, enemy.halfHeight - 0.5, 0), gold)
	end
	Pickups.maybePowerup(self, enemy.pos, Pickups.CHANCE_ON_KILL)
	if self.rng:NextNumber() < 0.0001 then
		self:addCounter("drop.LuckTome", 1)
		self:toast("¡Has encontrado el Luck Tome! (desbloqueo)")
	end

	Items.onKill(self, enemy, info)
	Passives.onKill(self, enemy)
	Weapons.onKill(self, enemy, info)

	if enemy.miniboss then
		if enemy.spawnedAt and self.time - enemy.spawnedAt <= 25 then
			self:addCounter("event.MinibossUnder25", 1)
		end
		self.interactables:spawnFreeChest(enemy.pos)
	end
	if enemy.isStageBoss then
		if enemy.cursed then
			self.interactables:spawnFreeChest(enemy.pos)
		end
		local alive = false
		for _, boss in self.bosses do
			if not boss.dead then
				alive = true
			end
		end
		if not alive then
			self:onBossDefeated(enemy, info)
		end
	end
end

function RunSession:onBossDefeated(boss, info)
	self.bossActive = false
	self.bossesDefeated += 1
	local fightTime = self.time - (self.bossStart or self.time)
	local charId = self.characterId
	if self.stageElapsed < 300 then
		self:addCounter("event.StageBossUnder5", 1)
	end
	if fightTime < 30 then
		self:addCounter("event.StageBossUnder30", 1)
	end
	if fightTime < 1 then
		self:addCounter("event.BossUnder1s.char." .. charId, 1)
	end
	if self.health < self.stats.MaxHealth * 0.1 then
		self:addCounter("event.StageBossLowHp", 1)
	end
	local flags = self.runFlags
	if not flags.pickedItem and not flags.pickedPowerup and not flags.usedShrine then
		self:addCounter("event.HeroSword", 1)
	end
	if self.stage == 1 then
		if not flags.tookDamage then
			self:addCounter("event.FirstBossNoDamage", 1)
		end
		if self.stageElapsed < 360 then
			self:addCounter("event.FirstBossUnder6.char." .. charId, 1)
		end
	end
	if charId == "Athena" and info and info.source == "weapon:Aegis" then
		self:addCounter("event.AthenaAegisBossKill", 1)
	end
	if self.bossCurses >= 2 then
		self:addCounter("event.StageTwoCurses", 1)
	end

	if boss.isFinalBoss then
		local key = string.format("complete.%s.T%d", self.map.id, self.tierIndex)
		self:addCounter(key, 1)
		self:addCounter(key .. ".char." .. charId, 1)
		self:addCounter("finalBossKills", 1)
		if self.tierIndex == 3 then
			self:addCounter("event.FinalBossT3.char." .. charId, 1)
		end
		self:toast("¡Tier completado!")
		self:finish(true, "Victoria: jefe final derrotado")
	else
		self.interactables:spawnExit(boss.pos)
		self:toast("¡Jefe derrotado! La salida a la siguiente etapa está abierta.")
	end
end

-- Muerte y final -----------------------------------------------------------------------------

function RunSession:onLethal()
	if self.state ~= "Playing" then
		return
	end
	if Items.tryPreventDeath(self) then
		return
	end
	self:finish(false, "Muerte")
end

function RunSession:finish(victory: boolean, reason: string)
	if self.state == "Ended" then
		return
	end
	self.state = "Ended"
	self.ended = true
	self.modal = nil
	table.clear(self.modalQueue)
	Net.get("Modal"):FireClient(self.player, nil)
	if not victory then
		self:addCounter("deaths", 1)
	end

	local minutes = self.totalTime / 60
	local swarm = Catalog.FinalSwarm
	local swarmMult = math.min(swarm.silverMultCap, 1 + self.swarmTime / 120) -- [Pendiente] curva
	local silver = (minutes * Config.Economy.SilverPerMinute + self.bossesDefeated * Config.Economy.SilverPerBoss + self.silverFound)
		* (1 + self.stats.SilverGain)
		* swarmMult
	silver = math.floor(silver)

	local damage = {}
	for source, amount in self.damageBySource do
		local kind, id = string.match(source, "^(%a+):(.+)$")
		local name = source
		if kind == "weapon" and Catalog.Weapon[id] then
			name = Catalog.Weapon[id].name
		elseif kind == "item" and Catalog.Item[id] then
			name = Catalog.Item[id].name
		elseif kind == "status" then
			name = "Estado: " .. id
		elseif kind == "passive" then
			name = "Pasiva: " .. id
		elseif source == "thorns" then
			name = "Espinas"
		end
		table.insert(damage, { name = name, amount = math.floor(amount) })
	end
	table.sort(damage, function(a, b)
		return a.amount > b.amount
	end)

	local unlockedNow = self.profile:applyRun({
		counters = self.counters,
		maxes = self.maxes,
		silver = silver,
		character = self.characterId,
		minutes = minutes,
		charges = self.charges,
	})

	Net.get("Results"):FireClient(self.player, {
		victory = victory,
		reason = reason,
		time = self.totalTime,
		swarmTime = self.swarmTime,
		kills = self.kills,
		level = self.level,
		character = self.character.name,
		map = self.map.name,
		tier = self.tierIndex,
		stage = self.stage,
		bosses = self.bossesDefeated,
		silver = silver,
		gold = math.floor(self.gold),
		damage = damage,
		unlocked = unlockedNow,
	})
	-- La limpieza se difiere: puede llegarse aquí en mitad de un recorrido de listas del frame.
	task.defer(function()
		self:cleanup()
	end)
end

function RunSession:cleanup()
	Weapons.clearAll(self)
	Pickups.clear(self)
	Passives.cleanup(self)
	if self.enemies then
		self.enemies:destroy()
	end
	if self.interactables then
		self.interactables:destroy()
	end
	self.player:SetAttribute("InRun", false)
	local model = self.model
	if model and model.Parent then
		if self.humanoid then
			self.humanoid.Health = 0
		end
		task.delay(2, function()
			if model.Parent then
				model:Destroy()
			end
		end)
	end
end

function RunSession:quit()
	if self.state == "Playing" then
		self:finish(false, "Partida abandonada")
	end
end

-- Bucle --------------------------------------------------------------------------------------

function RunSession:setPaused(paused: boolean)
	self.paused = paused
end

local function anchorRoot(self, anchored: boolean)
	if self.root and self.root.Anchored ~= anchored then
		self.root.Anchored = anchored
	end
end

function RunSession:sendHud()
	local s = self.stats
	local weapons, tomes, items = {}, {}, {}
	for _, w in self.weapons do
		table.insert(weapons, { id = w.id, name = w.def.name, level = w.level })
	end
	for _, t in self.tomes do
		table.insert(tomes, { id = t.id, name = t.def.name, level = t.level })
	end
	for id, n in self.items do
		local item = Catalog.Item[id]
		table.insert(items, { id = id, name = item.name, rarity = item.rarity, count = n })
	end
	local boss = nil
	if self.bossActive then
		local hp, maxHp = 0, 0
		for _, b in self.bosses do
			if not b.dead then
				hp += b.health
			end
			maxHp += b.maxHealth
		end
		boss = { name = self.bosses[1].def.name, hp = hp, max = maxHp }
	end
	Net.get("Hud"):FireClient(self.player, {
		hp = self.health,
		maxHp = s.MaxHealth,
		shield = self.shield,
		maxShield = s.Shield,
		xp = self.xp,
		xpToNext = self.xpToNext,
		level = self.level,
		gold = math.floor(self.gold),
		kills = self.kills,
		stageTime = self.stageTime,
		swarm = self.swarm,
		swarmTime = self.swarmTime,
		stage = self.stage,
		stages = self.map.stagesPerTier,
		mapName = self.map.name,
		tier = self.tierIndex,
		weapons = weapons,
		tomes = tomes,
		items = items,
		boss = boss,
		difficulty = s.Difficulty + self.tier.difficulty,
		paused = self.paused,
		momentum = self.momentum,
		stats = s,
	})
end

function RunSession:update(dt: number)
	if self.state ~= "Playing" then
		return
	end
	local root = self.root
	if not root or not root.Parent or not self.humanoid or self.humanoid.Health <= 0 then
		self:finish(false, "Personaje perdido")
		return
	end

	local frozen = self.paused or self.modal ~= nil
	anchorRoot(self, frozen)
	if frozen then
		self.lastPos = root.Position
		self.hudTimer -= dt
		if self.hudTimer <= 0 then
			self.hudTimer = 0.5
			self:sendHud()
		end
		return
	end

	dt = math.min(dt, 0.1)
	self.time += dt
	self.totalTime += dt
	self.frame += 1
	local slowed = self.time < self.timeSlowUntil
	self.tempDamageMult = if slowed then 2 else 1
	local enemyDt = if slowed then dt * 0.3 else dt

	-- Bonificaciones temporales caducadas
	for i = #self.timedStats, 1, -1 do
		if self.time >= self.timedStats[i].untilTime then
			table.remove(self.timedStats, i)
			self:rebuildTimedStats()
		end
	end
	if self.statsDirty then
		self:refreshStats()
	end
	local s = self.stats

	-- Movimiento
	local pos = root.Position
	local delta = (pos - self.lastPos) * Vector3.new(1, 0, 1)
	local distance = delta.Magnitude
	if distance > 20 then
		distance = 0 -- teletransporte
	end
	self.lastPos = pos
	self.frameDistance = distance
	self.horizontalSpeed = distance / dt
	local wasStationary = self.stationaryTime >= 0.6
	if self.horizontalSpeed < 1 then
		self.stationaryTime += dt
	else
		self.stationaryTime = 0
	end
	if (self.stationaryTime >= 0.6) ~= wasStationary and self.items.Campfire then
		self.statsDirty = true
	end
	if distance > 0 then
		Items.onMove(self, distance)
	end
	self.airborne = self.humanoid.FloorMaterial == Enum.Material.Air
	self.humanoid.WalkSpeed = self.walkSpeed * Passives.speedMult(self)

	-- Daño de caída
	local vy = root.AssemblyLinearVelocity.Y
	local threshold = Config.Player.FallDamageSpeed
	if (self.lastVy or 0) < -threshold and vy > -10 and not self.character.movement.fallImmune then
		local amount = (-(self.lastVy :: number) - threshold) * Config.Player.FallDamagePerSpeed
		Damage.toPlayer(self, amount, nil, { selfInflicted = false })
	end
	self.lastVy = vy
	if pos.Y < -60 then
		self.model:PivotTo(CFrame.new(self.spawnPoint + Vector3.new(0, 6, 0)))
	end

	-- Regeneración (vida por minuto) y escudo
	if self.health < s.MaxHealth and s.Regen > 0 then
		self.health = math.min(s.MaxHealth, self.health + s.Regen / 60 * dt)
	end
	if s.Shield > 0 and self.shield < s.Shield and self.time - self.lastDamageTime >= Config.Player.ShieldRechargeDelay then
		self.shield = math.min(s.Shield, self.shield + s.Shield * Config.Player.ShieldRechargeRate * dt)
	end
	self:recordMax("noDamageStreak", self.time - self.lastDamageTime)

	-- Relojes de etapa y Final Swarm
	self.stageElapsed += dt
	if self.swarm then
		self.swarmTime += dt
		self:recordMax("swarmSeconds", self.swarmTime)
	else
		self.stageTime -= dt
		if self.stageTime <= 0 then
			self.stageTime = 0
			self.swarm = true
			self:toast("¡FINAL SWARM!")
		end
	end

	self.director:update(dt)
	self.enemies:step(enemyDt)
	for _, w in self.weapons do
		Weapons.tick(self, w, dt)
	end
	Weapons.stepProjectiles(self, dt)
	Weapons.stepZones(self, dt)
	Status.tick(self)
	Pickups.step(self, dt)
	if self.state ~= "Playing" then
		return
	end
	self.interactables:step(dt)
	Items.tick(self, dt)
	Passives.tick(self, dt)

	local delayed = self.delayed
	for i = #delayed, 1, -1 do
		if self.time >= delayed[i].at then
			local action = table.remove(delayed, i)
			action.fn()
		end
	end

	self.hudTimer -= dt
	if self.hudTimer <= 0 then
		self.hudTimer = HUD_INTERVAL
		self:sendHud()
	end
	self.markerTimer -= dt
	if self.markersDirty and self.markerTimer <= 0 then
		self.markersDirty = false
		self.markerTimer = 0.5
		local markers = self.interactables:markers()
		for _, boss in self.bosses do
			if not boss.dead then
				table.insert(markers, { kind = "Boss", x = boss.pos.X, z = boss.pos.Z })
			end
		end
		Net.get("MapMarkers"):FireClient(self.player, markers)
	end
end

return RunSession
