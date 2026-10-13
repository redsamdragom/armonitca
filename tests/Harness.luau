--!nolint
-- Entorno simulado de Roblox para ejecutar el código del servidor con Lune, sin Studio.
-- Implementa sólo lo que el juego usa: árbol de instancias genérico, señales, servicios,
-- planificador de `task` con reloj simulado, Random determinista, suelo plano para raycasts
-- y registro de los mensajes enviados al cliente (con validación de serialización).

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Harness = {}

local V3, CF = roblox.Vector3, roblox.CFrame

-- Señales --------------------------------------------------------------------------------------

local Connection = {}
Connection.__index = Connection
function Connection:Disconnect()
	self.Connected = false
end

local Signal = {}
Signal.__index = Signal
function Signal.new()
	return setmetatable({ handlers = {} }, Signal)
end
function Signal:Connect(fn)
	local c = setmetatable({ fn = fn, Connected = true }, Connection)
	table.insert(self.handlers, c)
	return c
end
function Signal:Fire(...)
	for _, c in table.clone(self.handlers) do
		if c.Connected then
			c.fn(...)
		end
	end
end
function Signal:Wait()
	return nil
end

-- Planificador de task con reloj simulado ------------------------------------------------------

local clock = 0
local queue = {}

local function schedule(at, thread, ...)
	table.insert(queue, { at = at, thread = thread, args = table.pack(...) })
end

local function resume(thread, ...)
	local ok, err = coroutine.resume(thread, ...)
	if not ok then
		error(debug.traceback(thread, tostring(err)), 0)
	end
end

local task = {}
function task.spawn(fn, ...)
	local thread = if type(fn) == "thread" then fn else coroutine.create(fn)
	resume(thread, ...)
	return thread
end
function task.defer(fn, ...)
	local thread = coroutine.create(fn)
	schedule(clock, thread, ...)
	return thread
end
function task.delay(t, fn, ...)
	local thread = coroutine.create(fn)
	schedule(clock + (t or 0), thread, ...)
	return thread
end
function task.wait(t)
	local thread = coroutine.running()
	schedule(clock + (t or 0), thread)
	coroutine.yield()
	return t or 0
end

function Harness.advance(dt)
	clock += dt
	local due = {}
	for i = #queue, 1, -1 do
		if queue[i].at <= clock then
			table.insert(due, table.remove(queue, i))
		end
	end
	table.sort(due, function(a, b)
		return a.at < b.at
	end)
	for _, entry in due do
		if coroutine.status(entry.thread) == "suspended" then
			resume(entry.thread, table.unpack(entry.args, 1, entry.args.n))
		end
	end
end

-- Random determinista ---------------------------------------------------------------------------

local Random = {}
Random.__index = Random
function Random.new(seed)
	return setmetatable({ state = (seed or 1) % 2147483647 + 1 }, Random)
end
function Random:_next()
	self.state = (self.state * 48271) % 2147483647
	return self.state / 2147483647
end
function Random:NextNumber(a, b)
	local u = self:_next()
	if a == nil then
		return u
	end
	return a + (b - a) * u
end
function Random:NextInteger(a, b)
	return math.floor(a + (b - a + 1) * self:_next())
end

-- Instancias ------------------------------------------------------------------------------------

local EVENTS = {
	Triggered = true, OnServerEvent = true, OnClientEvent = true, Heartbeat = true, RenderStepped = true,
	Changed = true, CharacterAdded = true, PlayerAdded = true, PlayerRemoving = true, Died = true,
	StateChanged = true, Activated = true, JumpRequest = true, InputBegan = true,
}
local PART_CLASSES = { Part = true, WedgePart = true, BasePart = true, MeshPart = true, SpawnLocation = true }

local Methods = {}
local instMeta = {}
Harness.remoteLog = {}
Harness.serializationErrors = {}

local function isInstance(v)
	return type(v) == "table" and getmetatable(v) == instMeta
end

local function new(className, props)
	local self = setmetatable({ _class = className, _props = { Name = className, ClassName = className }, _children = {}, _attributes = {} }, instMeta)
	if PART_CLASSES[className] then
		self._props.CFrame = CF.identity
		self._props.Size = V3.new(4, 1, 2)
		self._props.AssemblyLinearVelocity = V3.zero
		self._props.AssemblyMass = 1
		self._props.Anchored = false
	end
	for k, v in props or {} do
		self[k] = v
	end
	return self
end

local function reparent(self, parent)
	local old = self._props.Parent
	if old then
		local children = old._children
		local index = table.find(children, self)
		if index then
			table.remove(children, index)
		end
	end
	self._props.Parent = parent
	if parent then
		table.insert(parent._children, self)
	end
end

instMeta.__index = function(self, key)
	local props = rawget(self, "_props")
	local v = props[key]
	if v ~= nil then
		return v
	end
	local m = Methods[key]
	if m then
		return m
	end
	for _, child in rawget(self, "_children") do
		if child._props.Name == key then
			return child
		end
	end
	if EVENTS[key] then
		local s = Signal.new()
		props[key] = s
		return s
	end
	if key == "Position" and props.CFrame then
		return props.CFrame.Position
	end
	return nil
end

instMeta.__newindex = function(self, key, value)
	if key == "Parent" then
		reparent(self, value)
		return
	end
	if key == "Position" then
		local cf = self._props.CFrame or CF.identity
		self._props.CFrame = CF.new(value) * cf.Rotation
		return
	end
	if key == "OnServerInvoke" then
		self._props.OnServerInvoke = value
		return
	end
	self._props[key] = value
end

instMeta.__tostring = function(self)
	return self._props.Name
end

function Methods:Destroy()
	reparent(self, nil)
	self._props.Destroyed = true
	for _, child in table.clone(self._children) do
		child:Destroy()
	end
end
function Methods:ClearAllChildren()
	for _, child in table.clone(self._children) do
		child:Destroy()
	end
end
function Methods:FindFirstChild(name)
	for _, child in self._children do
		if child._props.Name == name then
			return child
		end
	end
	return nil
end
function Methods:FindFirstChildOfClass(className)
	for _, child in self._children do
		if child._class == className then
			return child
		end
	end
	return nil
end
function Methods:WaitForChild(name)
	local child = self:FindFirstChild(name)
	if not child then
		error("WaitForChild: falta " .. tostring(name) .. " en " .. tostring(self), 2)
	end
	return child
end
function Methods:GetChildren()
	return table.clone(self._children)
end
function Methods:GetDescendants()
	local list = {}
	for _, child in self._children do
		table.insert(list, child)
		for _, d in child:GetDescendants() do
			table.insert(list, d)
		end
	end
	return list
end
function Methods:IsA(className)
	if className == "Instance" or className == self._class then
		return true
	end
	if className == "BasePart" then
		return PART_CLASSES[self._class] == true
	end
	return false
end
function Methods:SetAttribute(name, value)
	self._attributes[name] = value
end
function Methods:GetAttribute(name)
	return self._attributes[name]
end
function Methods:GetPivot()
	local primary = self._props.PrimaryPart or self:FindFirstChild("HumanoidRootPart")
	if primary then
		return primary.CFrame
	end
	return self._props.CFrame or CF.identity
end
function Methods:PivotTo(cf)
	if self._class ~= "Model" then
		self.CFrame = cf
		return
	end
	local delta = cf * self:GetPivot():Inverse()
	for _, d in self:GetDescendants() do
		if PART_CLASSES[d._class] then
			d.CFrame = delta * d.CFrame
		end
	end
end
function Methods:TakeDamage(amount)
	self.Health -= amount
end

-- Comprobación de que una carga útil de red es serializable por Roblox
local function validatePayload(value, path, seen)
	local t = type(value)
	if t == "function" or t == "thread" then
		return path .. ": no se puede enviar " .. t
	end
	if isInstance(value) then
		return nil
	end
	if t ~= "table" then
		return nil
	end
	if getmetatable(value) ~= nil and not isInstance(value) then
		return path .. ": tabla con metatabla"
	end
	seen = seen or {}
	if seen[value] then
		return path .. ": referencia cíclica"
	end
	seen[value] = true
	local n = #value
	local hasString, hasNumber = false, false
	for k, v in value do
		if type(k) == "string" then
			hasString = true
		elseif type(k) == "number" then
			hasNumber = true
			if k > n or k < 1 or k % 1 ~= 0 then
				return path .. ": array con huecos o claves numéricas no secuenciales"
			end
		else
			return path .. ": clave de tipo " .. type(k)
		end
		local err = validatePayload(v, path .. "." .. tostring(k), seen)
		if err then
			return err
		end
	end
	if hasString and hasNumber then
		return path .. ": tabla mixta (array + diccionario)"
	end
	return nil
end

local function logRemote(self, direction, player, ...)
	local name = self._props.Name
	local args = table.pack(...)
	for i = 1, args.n do
		local err = validatePayload(args[i], name .. "[" .. i .. "]")
		if err and not Harness.serializationErrors[err] then
			Harness.serializationErrors[err] = true
			print("  [serialización] " .. err)
		end
	end
	local log = Harness.remoteLog[name]
	if not log then
		log = { count = 0 }
		Harness.remoteLog[name] = log
	end
	log.count += 1
	log.last = args
end

function Methods:FireClient(player, ...)
	logRemote(self, "client", player, ...)
end
function Methods:FireAllClients(...)
	logRemote(self, "all", nil, ...)
end
function Methods:FireServer(...)
	self.OnServerEvent:Fire(Harness.localPlayer, ...)
end
function Methods:InvokeServer(...)
	return self._props.OnServerInvoke(Harness.localPlayer, ...)
end

-- Mundo -----------------------------------------------------------------------------------------

function Methods:Raycast(origin, direction, params)
	-- Suelo plano en y = 0
	if direction.Y < 0 and origin.Y >= 0 and origin.Y + direction.Y <= 0 then
		return { Position = V3.new(origin.X, 0, origin.Z), Normal = V3.yAxis, Instance = self, Material = roblox.Enum.Material.Grass }
	end
	return nil
end
function Methods:BulkMoveTo(parts, cframes)
	for i, part in parts do
		part.CFrame = cframes[i]
	end
end
function Methods:FillBlock() end
function Methods:FillBall() end
function Methods:Clear() end
function Methods:SetMaterialColor() end

-- Jugadores -------------------------------------------------------------------------------------

function Methods:LoadCharacter()
	local old = self._props.Character
	if old then
		old:Destroy()
	end
	local model = new("Model", { Name = self.Name })
	local root = new("Part", { Name = "HumanoidRootPart", CFrame = CF.new(0, 3, 0), Parent = model })
	new("Part", { Name = "Head", CFrame = CF.new(0, 4.5, 0), Parent = model })
	new("Part", { Name = "UpperTorso", CFrame = CF.new(0, 3, 0), Parent = model })
	new("Script", { Name = "Health", Parent = model })
	new("Humanoid", {
		Name = "Humanoid",
		Health = 100,
		MaxHealth = 100,
		WalkSpeed = 16,
		JumpHeight = 7.2,
		FloorMaterial = roblox.Enum.Material.Plastic,
		MoveDirection = V3.zero,
		Parent = model,
	})
	model.PrimaryPart = root
	model.Parent = Harness.workspace
	self._props.Character = model
	self.CharacterAdded:Fire(model)
end

-- Servicios -------------------------------------------------------------------------------------

function Harness.build(root)
	local game = new("DataModel", { Name = "Game" })
	local workspace = new("Workspace", { Name = "Workspace", Gravity = 196.2, Parent = game })
	new("Terrain", { Name = "Terrain", Parent = workspace })
	new("Camera", { Name = "Camera", Parent = workspace })
	workspace.CurrentCamera = workspace.Camera
	Harness.workspace = workspace

	local services = {
		ReplicatedStorage = new("ReplicatedStorage", { Name = "ReplicatedStorage", Parent = game }),
		ServerScriptService = new("ServerScriptService", { Name = "ServerScriptService", Parent = game }),
		Players = new("Players", { Name = "Players", Parent = game }),
		Lighting = new("Lighting", { Name = "Lighting", Parent = game }),
		RunService = new("RunService", { Name = "RunService" }),
		Debris = new("Debris", { Name = "Debris" }),
		DataStoreService = new("DataStoreService", { Name = "DataStoreService" }),
		Workspace = workspace,
	}
	services.RunService.IsServer = function()
		return true
	end
	services.RunService.IsStudio = function()
		return Harness.isStudio
	end
	services.Debris.AddItem = function(_, item, lifetime)
		task.delay(lifetime, function()
			item:Destroy()
		end)
	end
	services.DataStoreService.GetDataStore = function()
		error("DataStore no disponible en el arnés")
	end
	local players = {}
	services.Players.GetPlayers = function()
		return table.clone(players)
	end
	Harness.players = players
	game.GetService = function(_, name)
		local s = services[name]
		assert(s, "servicio no simulado: " .. name)
		return s
	end
	game.BindToClose = function() end

	-- Árbol de scripts desde el sistema de archivos
	local cache = {}
	local env
	local function loadModule(node)
		if cache[node] ~= nil then
			return cache[node]
		end
		local source = fs.readFile(node._path)
		local chunkEnv = setmetatable({ script = node }, { __index = env })
		local chunk = luau.load(source, { debugName = node._path, environment = chunkEnv, injectGlobals = false })
		local result = chunk()
		cache[node] = result
		return result
	end
	local function customRequire(node)
		assert(isInstance(node) and node._path, "require de algo que no es un ModuleScript: " .. tostring(node))
		return loadModule(node)
	end
	local function tree(dir, parent)
		for _, name in fs.readDir(dir) do
			local path = dir .. "/" .. name
			if fs.isDir(path) then
				tree(path, new("Folder", { Name = name, Parent = parent }))
			elseif string.sub(name, -5) == ".luau" then
				local base = string.sub(name, 1, -6)
				local class = "ModuleScript"
				if string.sub(base, -7) == ".server" then
					base, class = string.sub(base, 1, -8), "Script"
				elseif string.sub(base, -7) == ".client" then
					base, class = string.sub(base, 1, -8), "LocalScript"
				end
				local node = new(class, { Name = base, Parent = parent })
				rawset(node, "_path", path)
			end
		end
	end
	local shared = new("Folder", { Name = "Shared", Parent = services.ReplicatedStorage })
	tree(root .. "/src/shared", shared)
	local server = new("Folder", { Name = "Server", Parent = services.ServerScriptService })
	tree(root .. "/src/server", server)

	local Instance = {
		new = function(className, parent)
			local inst = new(className)
			if parent then
				inst.Parent = parent
			end
			return inst
		end,
	}
	local RaycastParams = {
		new = function()
			return { FilterType = nil, FilterDescendantsInstances = {}, IgnoreWater = false }
		end,
	}
	env = {
		game = game,
		workspace = workspace,
		require = customRequire,
		Instance = Instance,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		CFrame = roblox.CFrame,
		Color3 = roblox.Color3,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		Enum = roblox.Enum,
		Random = Random,
		RaycastParams = RaycastParams,
		task = task,
		typeof = function(v)
			if isInstance(v) then
				return "Instance"
			end
			return typeof(v)
		end,
		warn = function(...)
			print("[warn]", ...)
		end,
	}
	for name, value in {
		math = math, string = string, table = table, os = os, coroutine = coroutine, debug = debug,
		bit32 = bit32, utf8 = utf8, buffer = buffer, pairs = pairs, ipairs = ipairs, next = next,
		select = select, type = type, tostring = tostring, tonumber = tonumber, pcall = pcall,
		xpcall = xpcall, error = error, assert = assert, setmetatable = setmetatable,
		getmetatable = getmetatable, rawget = rawget, rawset = rawset, rawequal = rawequal,
		rawlen = rawlen, unpack = table.unpack, print = print,
	} do
		env[name] = value
	end
	Harness.services = services
	Harness.shared = shared
	Harness.server = server
	Harness.require = customRequire
	Harness.new = new
	return Harness
end

function Harness.addPlayer(userId)
	local player = new("Player", { Name = "Jugador" .. userId, UserId = userId })
	table.insert(Harness.players, player)
	Harness.localPlayer = player
	return player
end

function Harness.clock()
	return clock
end

Harness.isStudio = false

return Harness
