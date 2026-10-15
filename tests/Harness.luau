--!nolint
-- Entorno simulado de Roblox para ejecutar el código del juego con Lune, sin Studio.
-- Implementa sólo lo que el juego usa: árbol de instancias genérico, señales, servicios,
-- planificador de `task` con reloj simulado, Random determinista, suelo plano para raycasts
-- y registro de los mensajes enviados al cliente (con validación de serialización).
-- Con Harness.setupClient() carga también src/client y simula los servicios del cliente; el
-- servidor y el cliente comparten el mismo árbol y los mensajes de red se entregan diferidos.
-- En ese modo las instancias creadas por el juego se validan contra la base de datos de
-- reflexión de @lune/roblox: propiedades inexistentes, de sólo lectura o con un tipo incorrecto
-- fallan igual que en Roblox, y las propiedades sin asignar devuelven su valor por defecto.

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
function Signal:Once(fn)
	local c
	c = self:Connect(function(...)
		c:Disconnect()
		fn(...)
	end)
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
function Signal:DisconnectAll()
	for _, c in self.handlers do
		c.Connected = false
	end
	table.clear(self.handlers)
end

-- Planificador de task con reloj simulado ------------------------------------------------------

local clock = 0
local queue = {}
local sequence = 0

-- A igual hora, las tareas se reanudan en el orden en que se programaron (como los mensajes de red).
local function schedule(at, thread, ...)
	sequence += 1
	table.insert(queue, { at = at, order = sequence, thread = thread, args = table.pack(...) })
end

-- Error en un hilo: sin manejador se propaga (pruebas del servidor); con Harness.onError se
-- registra y la ejecución sigue, como en Roblox (un error en un hilo no detiene a los demás).
local function resume(thread, ...)
	local ok, err = coroutine.resume(thread, ...)
	if not ok then
		local message = debug.traceback(thread, tostring(err))
		if Harness.onError then
			Harness.onError(message)
		else
			error(message, 0)
		end
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
function task.cancel(thread)
	for i = #queue, 1, -1 do
		if queue[i].thread == thread then
			table.remove(queue, i)
		end
	end
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
		if a.at ~= b.at then
			return a.at < b.at
		end
		return a.order < b.order
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

-- Reflexión de clases (base de datos de @lune/roblox) -------------------------------------------

local db = roblox.getReflectionDatabase()
local classes = {}
local properties = {}
local defaults = {}

local function classOf(name)
	local c = classes[name]
	if c == nil then
		local ok, result = pcall(function()
			return db:GetClass(name)
		end)
		c = (ok and result) or false
		classes[name] = c
	end
	return c or nil
end

-- Propiedad `prop` de la clase o de alguna superclase: { datatype, readable, writable } o nil.
local function propertyOf(className, prop)
	local byClass = properties[className]
	if not byClass then
		byClass = {}
		properties[className] = byClass
	end
	local info = byClass[prop]
	if info == nil then
		info = false
		local c = classOf(className)
		while c do
			local p = c.Properties[prop]
			if p then
				local access = p.Scriptability
				info = {
					datatype = p.Datatype,
					readable = access ~= "None" and access ~= "Write",
					writable = access ~= "None" and access ~= "Read",
				}
				break
			end
			c = c.Superclass and classOf(c.Superclass)
		end
		byClass[prop] = info
	end
	return info or nil
end

local function defaultOf(className, prop)
	local list = defaults[className]
	if list == nil then
		local c = classOf(className)
		list = c and c.DefaultProperties or false
		defaults[className] = list
	end
	return list and list[prop]
end

local function inherits(className, target)
	if className == target or target == "Instance" then
		return true
	end
	local c = classOf(className)
	while c and c.Superclass do
		if c.Superclass == target then
			return true
		end
		c = classOf(c.Superclass)
	end
	return false
end

local NUMBER_TYPES = { Float32 = true, Float64 = true, Int32 = true, Int64 = true }
local VALUE_TYPES = {
	UDim = true, UDim2 = true, Vector2 = true, Vector3 = true, CFrame = true, Color3 = true, Font = true,
	NumberSequence = true, ColorSequence = true, NumberRange = true, Rect = true, BrickColor = true,
}

-- Devuelve la descripción del problema si `value` no puede asignarse a una propiedad del tipo dado.
local function typeProblem(datatype, value, isInstance)
	local t = typeof(value)
	if datatype == "Ref" then
		if value ~= nil and not isInstance(value) then
			return "Instance expected, got " .. t
		end
	elseif datatype == "Bool" then
		if t ~= "boolean" then
			return "bool expected, got " .. t
		end
	elseif NUMBER_TYPES[datatype] then
		if t ~= "number" then
			return "number expected, got " .. t
		end
	elseif datatype == "Content" then
		if t ~= "string" and t ~= "number" and not (type(value) == "table" and value.__content ~= nil) then
			return "Content expected, got " .. t
		end
	elseif datatype == "String" or datatype == "ContentId" then
		if t ~= "string" and t ~= "number" then
			return "string expected, got " .. t
		end
	elseif string.sub(datatype, 1, 5) == "Enum." then
		if t == "EnumItem" then
			if string.sub(tostring(value), 1, #datatype + 1) ~= datatype .. "." then
				return datatype .. " expected, got " .. tostring(value)
			end
		elseif t ~= "number" and t ~= "string" then
			return datatype .. " expected, got " .. t
		end
	elseif VALUE_TYPES[datatype] then
		if t ~= datatype then
			return datatype .. " expected, got " .. t
		end
	end
	return nil
end

-- Instancias ------------------------------------------------------------------------------------

local EVENTS = {
	Triggered = true, OnServerEvent = true, OnClientEvent = true, Heartbeat = true, RenderStepped = true,
	Stepped = true, Changed = true, CharacterAdded = true, CharacterRemoving = true, PlayerAdded = true,
	PlayerRemoving = true, Died = true, StateChanged = true, Activated = true, JumpRequest = true,
	InputBegan = true, InputEnded = true, InputChanged = true, MouseEnter = true, MouseLeave = true,
	MouseMoved = true, SelectionGained = true, SelectionLost = true, SelectionChanged = true,
	MouseButton1Click = true, MouseButton1Down = true, MouseButton1Up = true, MouseButton2Click = true,
	Destroying = true, ChildAdded = true, ChildRemoved = true, DescendantAdded = true,
	DescendantRemoving = true, AncestryChanged = true, AttributeChanged = true, Focused = true,
	FocusLost = true, Touched = true, TouchEnded = true, Completed = true, MoveToFinished = true,
	Running = true, Jumping = true, HealthChanged = true, GamepadConnected = true,
	GamepadDisconnected = true, LastInputTypeChanged = true, WindowFocused = true, WindowFocusReleased = true,
	PromptShown = true, PromptHidden = true, TriggerEnded = true, PromptButtonHoldBegan = true,
}
local PART_CLASSES = { Part = true, WedgePart = true, BasePart = true, MeshPart = true, SpawnLocation = true }

local Methods = {}
local instMeta = {}
Harness.remoteLog = {}
Harness.serializationErrors = {}
Harness.strict = false

local function isInstance(v)
	return type(v) == "table" and getmetatable(v) == instMeta
end

local function new(className, props)
	local self = setmetatable({ _class = className, _props = { Name = className, ClassName = className }, _children = {}, _attributes = {}, _changed = {} }, instMeta)
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

local function isStrict(self)
	return Harness.strict and rawget(self, "_strict") == true
end

local function memberError(self, key)
	return string.format("%s is not a valid member of %s \"%s\"", tostring(key), rawget(self, "_class"), tostring(self._props.Name))
end

local function propertyChanged(self, key)
	local s = rawget(self, "_changed")[key]
	if s then
		s:Fire()
	end
	local changed = rawget(self._props, "Changed")
	if changed then
		changed:Fire(key)
	end
end

local function reparent(self, parent)
	local old = self._props.Parent
	if old == parent then
		return
	end
	if old then
		local children = old._children
		local index = table.find(children, self)
		if index then
			table.remove(children, index)
		end
		local removed = rawget(old._props, "ChildRemoved")
		if removed then
			removed:Fire(self)
		end
	end
	self._props.Parent = parent
	if parent then
		table.insert(parent._children, self)
		local added = rawget(parent._props, "ChildAdded")
		if added then
			added:Fire(self)
		end
	end
	propertyChanged(self, "Parent")
end

-- Tamaño absoluto aproximado: la pantalla mide lo que la cámara; el resto, según su Size y el padre.
local function absoluteSize(self)
	local class = rawget(self, "_class")
	if class == "ScreenGui" then
		local camera = Harness.workspace and Harness.workspace._props.CurrentCamera
		return camera and camera._props.ViewportSize or roblox.Vector2.new(1920, 1080)
	end
	local parent = self._props.Parent
	local base = if parent and inherits(parent._class, "GuiBase2d") then parent.AbsoluteSize else roblox.Vector2.zero
	local size = self._props.Size
	if typeof(size) ~= "UDim2" then
		return roblox.Vector2.zero
	end
	return roblox.Vector2.new(base.X * size.X.Scale + size.X.Offset, base.Y * size.Y.Scale + size.Y.Offset)
end

local COMPUTED = {
	AbsoluteSize = absoluteSize,
	AbsolutePosition = function()
		return roblox.Vector2.zero
	end,
	AbsoluteCanvasSize = function(self)
		return absoluteSize(self)
	end,
	AbsoluteWindowSize = function(self)
		return absoluteSize(self)
	end,
	TextBounds = function()
		return roblox.Vector2.zero
	end,
}

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
	local strict = isStrict(self)
	local property = strict and propertyOf(rawget(self, "_class"), key)
	if property then
		if not property.readable then
			error(string.format("%s cannot be read from %s", key, rawget(self, "_class")), 2)
		end
		local computed = COMPUTED[key]
		if computed then
			return computed(self)
		end
		if key == "Position" and props.CFrame then
			return props.CFrame.Position
		end
		local d = defaultOf(rawget(self, "_class"), key)
		if d ~= nil then
			return d
		end
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
	if strict and not property and classOf(rawget(self, "_class")) then
		error(memberError(self, key), 2)
	end
	return nil
end

local CALLBACKS = { OnServerInvoke = true, OnClientInvoke = true, OnInvoke = true }

instMeta.__newindex = function(self, key, value)
	local strict = isStrict(self)
	if key == "Parent" then
		if strict then
			if self._props.Destroyed then
				error(string.format("The Parent property of %s is locked, current parent: NULL, new parent %s", tostring(self), tostring(value)), 2)
			end
			if value ~= nil and not isInstance(value) then
				error("Unable to assign property Parent. Instance expected, got " .. typeof(value), 2)
			end
		end
		reparent(self, value)
		return
	end
	if CALLBACKS[key] then
		self._props[key] = value
		return
	end
	local class = rawget(self, "_class")
	if strict then
		local property = propertyOf(class, key)
		if property then
			if not property.writable then
				error(string.format("Unable to assign property %s. Property is read only", key), 2)
			end
			local problem = typeProblem(property.datatype, value, isInstance)
			if problem then
				error(string.format("Unable to assign property %s. %s", key, problem), 2)
			end
		elseif classOf(class) then
			error(memberError(self, key), 2)
		end
	end
	if key == "Position" and (not strict or PART_CLASSES[class] or inherits(class, "BasePart")) then
		local cf = self._props.CFrame or CF.identity
		self._props.CFrame = CF.new(value) * cf.Rotation
		propertyChanged(self, "CFrame")
		return
	end
	local old = self._props[key]
	self._props[key] = value
	if old ~= value then
		propertyChanged(self, key)
	end
end

instMeta.__tostring = function(self)
	return self._props.Name
end

function Methods:Destroy()
	local destroying = rawget(self._props, "Destroying")
	if destroying then
		destroying:Fire()
	end
	reparent(self, nil)
	self._props.Destroyed = true
	for _, child in table.clone(self._children) do
		child:Destroy()
	end
	-- Como en Roblox, al destruir se desconectan todas las conexiones de la instancia
	if Harness.strict then
		for _, value in self._props do
			if getmetatable(value) == Signal then
				value:DisconnectAll()
			end
		end
		for _, s in rawget(self, "_changed") do
			s:DisconnectAll()
		end
	end
end
function Methods:ClearAllChildren()
	for _, child in table.clone(self._children) do
		child:Destroy()
	end
end
function Methods:FindFirstChild(name, recursive)
	for _, child in self._children do
		if child._props.Name == name then
			return child
		end
	end
	if recursive then
		for _, child in self._children do
			local found = child:FindFirstChild(name, true)
			if found then
				return found
			end
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
function Methods:FindFirstChildWhichIsA(className, recursive)
	for _, child in self._children do
		if child:IsA(className) then
			return child
		end
	end
	if recursive then
		for _, child in self._children do
			local found = child:FindFirstChildWhichIsA(className, true)
			if found then
				return found
			end
		end
	end
	return nil
end
function Methods:FindFirstAncestor(name)
	local p = self._props.Parent
	while p do
		if p._props.Name == name then
			return p
		end
		p = p._props.Parent
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
	if className == "BasePart" and PART_CLASSES[self._class] then
		return true
	end
	return inherits(self._class, className)
end
function Methods:IsDescendantOf(ancestor)
	local p = self._props.Parent
	while p do
		if p == ancestor then
			return true
		end
		p = p._props.Parent
	end
	return false
end
function Methods:GetFullName()
	local names = { self._props.Name }
	local p = self._props.Parent
	while p and p._class ~= "DataModel" do
		table.insert(names, 1, p._props.Name)
		p = p._props.Parent
	end
	return table.concat(names, ".")
end
function Methods:GetPropertyChangedSignal(name)
	if isStrict(self) and not propertyOf(self._class, name) and classOf(self._class) then
		error(memberError(self, name), 2)
	end
	local changed = rawget(self, "_changed")
	local s = changed[name]
	if not s then
		s = Signal.new()
		changed[name] = s
	end
	return s
end
function Methods:SetAttribute(name, value)
	self._attributes[name] = value
end
function Methods:GetAttribute(name)
	return self._attributes[name]
end
function Methods:GetAttributes()
	return table.clone(self._attributes)
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
function Methods:GetState()
	return self._props.State or roblox.Enum.HumanoidStateType.Running
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

Harness.validatePayload = validatePayload

local function reportPayload(name, args)
	for i = 1, args.n do
		local err = validatePayload(args[i], name .. "[" .. i .. "]")
		if err and not Harness.serializationErrors[err] then
			Harness.serializationErrors[err] = true
			print("  [serialización] " .. err)
		end
	end
end

local function logRemote(self, direction, player, ...)
	local name = self._props.Name
	local args = table.pack(...)
	reportPayload(name, args)
	local log = Harness.remoteLog[name]
	if not log then
		log = { count = 0 }
		Harness.remoteLog[name] = log
	end
	log.count += 1
	log.last = args
end

-- Copia de una carga útil como la que recibe el otro extremo (sin referencias compartidas).
local function copyPayload(value, seen)
	if type(value) ~= "table" or isInstance(value) then
		return value
	end
	seen = seen or {}
	if seen[value] then
		return seen[value]
	end
	local out = {}
	seen[value] = out
	for k, v in value do
		out[copyPayload(k, seen)] = copyPayload(v, seen)
	end
	return out
end

local function copyArgs(...)
	local args = table.pack(...)
	for i = 1, args.n do
		args[i] = copyPayload(args[i])
	end
	return args
end

-- Entrega diferida de un mensaje de red (llega en el siguiente paso del planificador).
local function deliver(signal, args)
	task.defer(function()
		signal:Fire(table.unpack(args, 1, args.n))
	end)
end

function Methods:FireClient(player, ...)
	logRemote(self, "client", player, ...)
	if Harness.clientPlayer and player == Harness.clientPlayer then
		deliver(self.OnClientEvent, copyArgs(...))
	end
end
function Methods:FireAllClients(...)
	logRemote(self, "all", nil, ...)
	if Harness.clientPlayer then
		deliver(self.OnClientEvent, copyArgs(...))
	end
end
function Methods:FireServer(...)
	if Harness.clientPlayer then
		reportPayload(self._props.Name .. " (al servidor)", table.pack(...))
		local args = copyArgs(...)
		table.insert(args, 1, Harness.clientPlayer)
		args.n += 1
		deliver(self.OnServerEvent, args)
		return
	end
	self.OnServerEvent:Fire(Harness.localPlayer, ...)
end
function Methods:InvokeServer(...)
	local handler = self._props.OnServerInvoke
	if not Harness.clientPlayer then
		return handler(Harness.localPlayer, ...)
	end
	local name = self._props.Name
	reportPayload(name .. " (al servidor)", table.pack(...))
	assert(handler, "OnServerInvoke sin asignar en " .. name)
	local args = copyArgs(...)
	local results = table.pack(handler(Harness.clientPlayer, table.unpack(args, 1, args.n)))
	reportPayload(name .. " (respuesta)", results)
	local copied = copyArgs(table.unpack(results, 1, results.n))
	return table.unpack(copied, 1, copied.n)
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

local env

function Harness.build(root)
	Harness.root = root
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
		ContentProvider = new("ContentProvider", { Name = "ContentProvider" }),
		AssetService = new("AssetService", { Name = "AssetService" }),
		Workspace = workspace,
	}
	-- EditableImage simulado: guarda los píxeles escritos para poder comprobarlos
	services.AssetService.CreateEditableImage = function(_, options)
		local size = options and options.Size or roblox.Vector2.new(512, 512)
		return {
			Size = size,
			WritePixelsBuffer = function(self, position, region, pixels)
				assert(buffer.len(pixels) == region.X * region.Y * 4, "WritePixelsBuffer: tamaño de buffer incorrecto")
				self.pixels = pixels
			end,
		}
	end
	-- Carga de imágenes: todas cargan salvo las de Harness.failedAssets[id] = true
	Harness.failedAssets = {}
	services.ContentProvider.PreloadAsync = function(_, list, callback)
		for _, id in list do
			if callback then
				callback(id, if Harness.failedAssets[id] then roblox.Enum.AssetFetchStatus.Failure else roblox.Enum.AssetFetchStatus.Success)
			end
		end
	end
	services.RunService.IsServer = function()
		return true
	end
	services.RunService.IsClient = function()
		return Harness.clientPlayer ~= nil
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
	services.DataStoreService.GetOrderedDataStore = function()
		error("OrderedDataStore no disponible en el arnés")
	end
	local players = {}
	services.Players.GetPlayers = function()
		return table.clone(players)
	end
	services.Players.GetNameFromUserIdAsync = function(_, userId)
		error("GetNameFromUserIdAsync no disponible en el arnés (" .. tostring(userId) .. ")")
	end
	-- Amigos simulados: Harness.friends[userId] = { ids }; sin lista, la llamada falla como en Studio
	-- sin conexión. Devuelve un FriendPages de una sola página.
	Harness.friends = {}
	services.Players.GetFriendsAsync = function(_, userId)
		local ids = Harness.friends[userId]
		if not ids then
			error("Lista de amigos no disponible en el arnés")
		end
		local page = {}
		for _, id in ids do
			table.insert(page, { Id = id, Username = "Jugador" .. id, DisplayName = "Jugador" .. id, IsOnline = false })
		end
		return {
			IsFinished = true,
			GetCurrentPage = function()
				return page
			end,
			AdvanceToNextPageAsync = function() end,
		}
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
	local clientEnv
	local function loadModule(node)
		if cache[node] ~= nil then
			return cache[node]
		end
		local source = rawget(node, "_source")
		local base = if rawget(node, "_client") then clientEnv else env
		local chunkEnv = setmetatable({ script = node }, { __index = base })
		local chunk = luau.load(source, { debugName = node._path, environment = chunkEnv, injectGlobals = false })
		local result = chunk()
		cache[node] = result
		return result
	end
	local function customRequire(node)
		assert(isInstance(node) and node._path, "require de algo que no es un ModuleScript: " .. tostring(node))
		return loadModule(node)
	end
	local function tree(dir, parent, client)
		for _, name in fs.readDir(dir) do
			local path = dir .. "/" .. name
			if fs.isDir(path) then
				tree(path, new("Folder", { Name = name, Parent = parent }), client)
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
				-- Se lee aquí y no al requerirlo: en Lune, fs.readFile cede el hilo si se llama
				-- desde una corrutina (los scripts del cliente arrancan en hilos de task.spawn).
				rawset(node, "_source", fs.readFile(path))
				if client then
					rawset(node, "_client", true)
				end
			end
		end
	end
	local shared = new("Folder", { Name = "Shared", Parent = services.ReplicatedStorage })
	tree(root .. "/src/shared", shared)
	local server = new("Folder", { Name = "Server", Parent = services.ServerScriptService })
	tree(root .. "/src/server", server)

	local Instance = {
		new = function(className, parent)
			if Harness.strict then
				local c = classOf(className)
				if c and (table.find(c.Tags, "NotCreatable") or table.find(c.Tags, "Service")) then
					error("Unable to create an Instance of type \"" .. className .. "\"", 2)
				end
			end
			local inst = new(className)
			rawset(inst, "_strict", true)
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
	local TweenInfo = {
		new = function(time, style, direction, repeatCount, reverses, delayTime)
			return { Time = time or 1, EasingStyle = style, EasingDirection = direction, RepeatCount = repeatCount or 0, Reverses = reverses or false, DelayTime = delayTime or 0 }
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
		Content = {
			fromObject = function(object)
				return { __content = object }
			end,
		},
		Font = roblox.Font,
		NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		NumberRange = roblox.NumberRange,
		Rect = roblox.Rect,
		BrickColor = roblox.BrickColor,
		PhysicalProperties = roblox.PhysicalProperties,
		TweenInfo = TweenInfo,
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
			local parts = {}
			for i = 1, select("#", ...) do
				table.insert(parts, tostring((select(i, ...))))
			end
			table.insert(Harness.warnings, table.concat(parts, " "))
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
	-- El cliente mide el tiempo con os.clock: en el arnés sigue al reloj simulado.
	local clientOs = setmetatable({
		clock = function()
			return 100 + clock
		end,
	}, { __index = os })
	clientEnv = setmetatable({ os = clientOs }, { __index = env })

	Harness.services = services
	Harness.Instance = Instance
	Harness.shared = shared
	Harness.server = server
	Harness.require = customRequire
	Harness.new = new
	Harness.tree = tree
	Harness.game = game
	return Harness
end

function Harness.addPlayer(userId)
	local player = new("Player", { Name = "Jugador" .. userId, UserId = userId, DisplayName = "Jugador" .. userId })
	table.insert(Harness.players, player)
	Harness.localPlayer = player
	return player
end

-- Cliente ---------------------------------------------------------------------------------------

-- Prepara el lado del cliente: carga src/client en StarterPlayer.StarterPlayerScripts.Client,
-- simula sus servicios y crea el jugador local. Activa la validación estricta de propiedades,
-- la entrega diferida de mensajes de red y el registro de errores (Harness.errors).
function Harness.setupClient(userId)
	local services = Harness.services
	local game = Harness.game
	Harness.strict = true
	Harness.errors = {}
	Harness.onError = function(message)
		table.insert(Harness.errors, message)
		print("  [error] " .. message)
	end

	local function strict(inst)
		rawset(inst, "_strict", true)
		return inst
	end

	local starterPlayer = new("StarterPlayer", { Name = "StarterPlayer", Parent = game })
	local scripts = new("StarterPlayerScripts", { Name = "StarterPlayerScripts", Parent = starterPlayer })
	local client = new("Folder", { Name = "Client", Parent = scripts })
	Harness.tree(Harness.root .. "/src/client", client, true)
	Harness.client = client
	services.StarterPlayer = starterPlayer

	-- Entrada: mando conectado para recorrer también los caminos de selección con mando
	local input = new("UserInputService", { Name = "UserInputService" })
	input._props.GamepadEnabled = true
	input._props.KeyboardEnabled = true
	input._props.MouseEnabled = true
	input._props.TouchEnabled = false
	input.GetMouseLocation = function()
		return roblox.Vector2.new(960, 540)
	end
	services.UserInputService = strict(input)

	local guiService = new("GuiService", { Name = "GuiService" })
	guiService.GetGuiInset = function()
		return roblox.Vector2.new(0, 58), roblox.Vector2.zero
	end
	services.GuiService = strict(guiService)

	local starterGui = new("StarterGui", { Name = "StarterGui", Parent = game })
	Harness.coreGui = {}
	starterGui.SetCoreGuiEnabled = function(_, coreType, enabled)
		assert(typeof(coreType) == "EnumItem" and typeof(enabled) == "boolean", "SetCoreGuiEnabled: argumentos inválidos")
		Harness.coreGui[coreType.Name] = enabled
	end
	starterGui.SetCore = function() end
	services.StarterGui = strict(starterGui)

	-- Las interpolaciones validan las propiedades al crearse y las aplican al terminar.
	local tweenService = new("TweenService", { Name = "TweenService" })
	tweenService.Create = function(_, instance, info, goals)
		assert(isInstance(instance), "TweenService:Create: el primer argumento debe ser una Instance")
		assert(type(info) == "table" and type(info.Time) == "number", "TweenService:Create: TweenInfo inválido")
		for key, value in goals do
			local property = isStrict(instance) and propertyOf(instance._class, key)
			if isStrict(instance) and classOf(instance._class) then
				assert(property, "TweenService:Create: " .. memberError(instance, key))
				local problem = typeProblem(property.datatype, value, isInstance)
				assert(not problem, "TweenService:Create: " .. key .. ": " .. tostring(problem))
			end
		end
		local tween = { Completed = Signal.new(), PlaybackState = roblox.Enum.PlaybackState.Begin }
		function tween:Play()
			tween.PlaybackState = roblox.Enum.PlaybackState.Playing
			task.delay(info.Time + (info.DelayTime or 0), function()
				if tween.PlaybackState ~= roblox.Enum.PlaybackState.Playing then
					return
				end
				for key, value in goals do
					instance[key] = value
				end
				tween.PlaybackState = roblox.Enum.PlaybackState.Completed
				tween.Completed:Fire(roblox.Enum.PlaybackState.Completed)
			end)
		end
		function tween:Cancel()
			tween.PlaybackState = roblox.Enum.PlaybackState.Cancelled
		end
		function tween:Pause()
			tween.PlaybackState = roblox.Enum.PlaybackState.Paused
		end
		function tween:Destroy() end
		return tween
	end
	services.TweenService = strict(tweenService)

	services.SoundService = strict(new("SoundService", { Name = "SoundService", Parent = game }))
	-- Política del jugador: Harness.policyLinks son los enlaces externos permitidos (nil: falla)
	Harness.policyLinks = { "Discord" }
	local policyService = new("PolicyService", { Name = "PolicyService", Parent = game })
	policyService.GetPolicyInfoForPlayerAsync = function(_, player)
		assert(player == services.Players.LocalPlayer, "GetPolicyInfoForPlayerAsync: se esperaba el jugador local")
		if not Harness.policyLinks then
			error("HTTP 500 (política no disponible)")
		end
		return { AllowedExternalLinkReferences = table.clone(Harness.policyLinks), ArePaidRandomItemsRestricted = false }
	end
	services.PolicyService = strict(policyService)
	local textService = new("TextService", { Name = "TextService" })
	textService.GetTextSize = function(_, text, size)
		return roblox.Vector2.new(#tostring(text) * size * 0.5, size)
	end
	services.TextService = strict(textService)

	-- Cámara y luz con los valores con los que arranca un lugar
	local camera = Harness.workspace.Camera
	camera._props.CameraType = roblox.Enum.CameraType.Custom
	camera._props.CFrame = CF.new(0, 20, 20)
	camera._props.FieldOfView = 70
	camera._props.ViewportSize = roblox.Vector2.new(1920, 1080)
	strict(camera)
	local lighting = services.Lighting
	lighting._props.ClockTime = 14
	lighting._props.Brightness = 2
	lighting._props.FogEnd = 100000
	strict(lighting)

	-- Jugador local
	local player = Harness.addPlayer(userId)
	new("PlayerGui", { Name = "PlayerGui", Parent = player })
	new("PlayerScripts", { Name = "PlayerScripts", Parent = player })
	Harness.kicked = nil
	player.Kick = function(_, message)
		Harness.kicked = message or ""
	end
	strict(player)
	services.Players._props.LocalPlayer = player
	Harness.thumbnailFailures = {}
	services.Players.GetUserThumbnailAsync = function(_, id, thumbnailType, thumbnailSize)
		assert(type(id) == "number", "GetUserThumbnailAsync: userId debe ser un número")
		assert(typeof(thumbnailType) == "EnumItem" and typeof(thumbnailSize) == "EnumItem", "GetUserThumbnailAsync: tipo y tamaño deben ser Enum")
		if Harness.thumbnailFailures[id] then
			error("HTTP 400 (miniatura no disponible)")
		end
		return "rbxthumb://type=AvatarHeadShot&id=" .. id .. "&w=48&h=48", true
	end
	strict(services.Players)
	Harness.clientPlayer = player
	return player
end

-- Ejecuta un Script o LocalScript en su propio hilo (los errores van a Harness.onError).
function Harness.run(node)
	return task.spawn(Harness.require, node)
end

function Harness.clock()
	return clock
end

Harness.Signal = Signal
Harness.isInstance = isInstance
Harness.isStudio = false
Harness.warnings = {}

return Harness
