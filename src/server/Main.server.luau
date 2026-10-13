-- Bucle principal de la partida: oleadas, jefe final, victoria/derrota y reinicio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Server = script.Parent
local Ground = require(Server.Ground)
local Map = require(Server.Map)
local PlayerState = require(Server.PlayerState)
local Enemies = require(Server.Enemies)
local Gems = require(Server.Gems)
local Weapons = require(Server.Weapons)
local LevelUp = require(Server.LevelUp)

Players.CharacterAutoLoads = false

local remotesFolder = Instance.new("Folder")
remotesFolder.Name = "Remotes"
remotesFolder.Parent = ReplicatedStorage

local function remote(name: string): RemoteEvent
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotesFolder
	return r
end

local remotes = {
	LevelUpOffer = remote("LevelUpOffer"),
	ChooseUpgrade = remote("ChooseUpgrade"),
	Hud = remote("Hud"),
	RunEnded = remote("RunEnded"),
}

Map.build()
Enemies.init()
Gems.init()
Weapons.init()
LevelUp.init(remotes)

local run = {
	State = "Waiting", -- Waiting | Running | Ended
	Elapsed = 0,
	SpawnTimer = 0,
	Boss = nil,
}

local function updateGroundIgnore()
	local characters = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(characters, player.Character)
		end
	end
	Ground.setIgnore(characters)
end

local function spawnPlayer(player: Player)
	PlayerState.reset(player)
	Weapons.clearPlayer(player)
	player:LoadCharacter()
end

local function startRun()
	run.State = "Running"
	run.Elapsed = 0
	run.SpawnTimer = 0
	run.Boss = nil
	for _, player in Players:GetPlayers() do
		spawnPlayer(player)
	end
end

local function endRun(victory: boolean)
	if run.State ~= "Running" then
		return
	end
	run.State = "Ended"
	remotes.RunEnded:FireAllClients(victory, run.Elapsed)
	task.delay(Config.Run.RestartDelay, function()
		Enemies.clear()
		Gems.clear()
		Weapons.clearAll()
		if #Players:GetPlayers() > 0 then
			startRun()
		else
			run.State = "Waiting"
		end
	end)
end

Enemies.onDeath = function(enemy, killer)
	if enemy.Def.XP > 0 then
		Gems.spawn(enemy.Position, enemy.Def.XP)
	end
	local state = killer and PlayerState.get(killer)
	if state then
		state.Kills += 1
	end
	if enemy == run.Boss then
		endRun(true)
	end
end

local function pickEnemyType(elapsed: number): string
	local total = 0
	local pool = {}
	for id, def in Config.Enemies do
		if def.Weight > 0 and elapsed >= def.UnlockTime then
			total += def.Weight
			table.insert(pool, { id = id, weight = def.Weight })
		end
	end
	local roll = math.random() * total
	for _, entry in pool do
		roll -= entry.weight
		if roll <= 0 then
			return entry.id
		end
	end
	return pool[#pool].id
end

local function spawnAround(center: Vector3, typeId: string, healthScale: number)
	local half = Config.Run.ArenaHalfSize
	local angle = math.random() * math.pi * 2
	local distance = Config.Run.SpawnDistanceMin + math.random() * (Config.Run.SpawnDistanceMax - Config.Run.SpawnDistanceMin)
	local x = math.clamp(center.X + math.cos(angle) * distance, -half, half)
	local z = math.clamp(center.Z + math.sin(angle) * distance, -half, half)
	local y = Ground.height(Vector3.new(x, 0, z), 0, 300)
	return Enemies.spawn(typeId, Vector3.new(x, y, z), healthScale)
end

local function getTargets()
	local targets = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local state = PlayerState.get(player)
		if humanoid and root and humanoid.Health > 0 and state then
			table.insert(targets, {
				player = player,
				root = root,
				humanoid = humanoid,
				state = state,
				pickupRadius = Config.Player.PickupRadius * PlayerState.stats(state).PickupMult,
			})
		end
	end
	return targets
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		updateGroundIgnore()
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid.MaxHealth = Config.Player.MaxHealth
		humanoid.Health = Config.Player.MaxHealth
		PlayerState.applyCharacterStats(player)
		humanoid.Died:Connect(function()
			Weapons.clearPlayer(player)
		end)
	end)

	if run.State == "Waiting" then
		startRun()
	elseif run.State == "Running" then
		spawnPlayer(player)
	end
	-- Si la partida terminó, el jugador entra en el próximo reinicio.
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	Weapons.clearPlayer(player)
	PlayerState.remove(player)
	task.defer(updateGroundIgnore)
end)

local hudTimer = 0

RunService.Heartbeat:Connect(function(dt)
	if run.State ~= "Running" then
		return
	end
	run.Elapsed += dt

	local targets = getTargets()
	if #targets == 0 then
		-- Espera a que los personajes terminen de cargar al inicio de la partida.
		if run.Elapsed > 5 then
			endRun(false)
		end
		return
	end

	local minutes = run.Elapsed / 60
	run.SpawnTimer -= dt
	if run.SpawnTimer <= 0 and Enemies.count() < Config.Run.MaxEnemies then
		run.SpawnTimer = math.max(Config.Run.MinSpawnInterval, Config.Run.BaseSpawnInterval * 0.85 ^ minutes)
		local healthScale = 1 + minutes * Config.Run.HealthScalePerMinute
		for _ = 1, 1 + math.floor(minutes / 2) do
			local center = targets[math.random(#targets)].root.Position
			spawnAround(center, pickEnemyType(run.Elapsed), healthScale)
		end
	end

	if not run.Boss and run.Elapsed >= Config.Run.Duration then
		run.Boss = spawnAround(targets[1].root.Position, "Boss", #targets)
	end

	Enemies.step(dt, targets)
	local now = os.clock()
	for _, target in targets do
		Weapons.stepPlayer(target.player, target.state, target.root, dt, now)
	end
	Weapons.stepProjectiles(dt)
	Gems.step(dt, targets, LevelUp.addXP)

	hudTimer -= dt
	if hudTimer <= 0 then
		hudTimer = 0.2
		for _, player in Players:GetPlayers() do
			local state = PlayerState.get(player)
			if state then
				remotes.Hud:FireClient(player, {
					Level = state.Level,
					XP = state.XP,
					XPToNext = state.XPToNext,
					Kills = state.Kills,
					Elapsed = run.Elapsed,
					Duration = Config.Run.Duration,
					BossAlive = run.Boss ~= nil and not run.Boss.Dead,
				})
			end
		end
	end
end)
