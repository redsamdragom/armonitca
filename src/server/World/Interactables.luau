-- Interactuables del escenario: cofres, santuarios, microondas, vendedor, vasijas y portales.
-- Precios, recompensas y probabilidades son [Pendiente] salvo lo indicado.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Stats = require(ReplicatedStorage.Shared.Stats)
local MapGen = require(script.Parent.MapGen)
local Fx = require(script.Parent.Parent.Combat.Fx)
local Damage = require(script.Parent.Parent.Combat.Damage)
local Items = require(script.Parent.Parent.Combat.Items)
local Loot = require(script.Parent.Parent.Run.Loot)
local Offers = require(script.Parent.Parent.Run.Offers)
local Pickups = require(script.Parent.Parent.Run.Pickups)

local Interactables = {}
Interactables.__index = Interactables

local LABEL = {
	Chest = "Cofre",
	FreeChest = "Cofre gratis",
	ChargeShrine = "Charge Shrine",
	GoldenChargeShrine = "Golden Charge Shrine",
	GreedShrine = "Greed Shrine",
	BossCurse = "Boss Curse",
	ShrineOfSucc = "Shrine of Succ",
	Microwave = "Microwave",
	ShadyGuy = "Shady Guy",
	Pot = "Vasija",
	BossPortal = "Portal del jefe",
	ExitPortal = "Salida",
}

-- Recompensas de Charge Shrine (incremento común) [Pendiente]. Sin Silver Gain desde Christmas.
local SHRINE_REWARDS = {
	MaxHealth = 10,
	Damage = 0.04,
	AttackSpeed = 0.04,
	CritChance = 0.03,
	CritDamage = 0.08,
	MoveSpeed = 0.05,
	Armor = 0.04,
	Evasion = 0.04,
	Size = 0.04,
	Luck = 0.04,
	XPGain = 0.04,
	Regen = 15,
	Shield = 10,
	PickupMult = 0.15,
	Duration = 0.05,
	ProjectileSpeed = 0.05,
	Thorns = 5,
	Knockback = 0.08,
}
local SHRINE_KEYS = {}
for stat in SHRINE_REWARDS do
	table.insert(SHRINE_KEYS, stat)
end
table.sort(SHRINE_KEYS)

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function block(props): BasePart
	local p = Instance.new(props.ClassName or "Part") :: BasePart
	props.ClassName = nil
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local function billboard(adornee: BasePart, text: string, offset: number)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 40)
	gui.StudsOffset = Vector3.new(0, offset, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 90
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = gui
	gui.Parent = adornee
	return label
end

function Interactables.new(session)
	local folder = Instance.new("Folder")
	folder.Name = "Interactables"
	folder.Parent = workspace:FindFirstChild("Map") or workspace
	return setmetatable({ session = session, list = {}, folder = folder, nextId = 0 }, Interactables)
end

function Interactables:chestCost(): number
	local session = self.session
	local cost = Config.Economy.ChestBaseCost * Config.Economy.ChestCostGrowth ^ session.chestsBought * (1 + session.stage * 0.25)
	return math.floor(cost * (1 + 0.1 * Items.count(session, "CreditCardGreen")))
end

function Interactables:remove(entry)
	entry.removed = true
	if entry.model then
		entry.model:Destroy()
	end
	self.session:markersChanged()
end

local function promptOn(entry, actionText: string, objectText: string, holdDuration: number?)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = holdDuration or 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = entry.anchor
	entry.prompt = prompt
	return prompt
end

function Interactables:add(kind: string, position: Vector3, opts: any?)
	local session = self.session
	self.nextId += 1
	local entry = { id = self.nextId, kind = kind, pos = position, data = opts or {} }
	local model = Instance.new("Model")
	model.Name = kind
	local anchor

	if kind == "Chest" or kind == "FreeChest" then
		anchor = block({ Size = Vector3.new(4, 3, 3), CFrame = CFrame.new(position + Vector3.new(0, 1.5, 0)), Color = if kind == "FreeChest" then rgb(80, 200, 120) else rgb(150, 100, 50), Material = Enum.Material.Wood, Parent = model })
		block({ Size = Vector3.new(4.2, 0.6, 3.2), CFrame = anchor.CFrame * CFrame.new(0, 0.9, 0), Color = rgb(230, 190, 60), Material = Enum.Material.Metal, Parent = model })
		entry.label = billboard(anchor, "", 3)
		local prompt = promptOn(entry, "Abrir", LABEL[kind])
		prompt.Triggered:Connect(function(player)
			if player == session.player then
				self:openChest(entry)
			end
		end)
	elseif kind == "ChargeShrine" or kind == "GoldenChargeShrine" then
		local golden = kind == "GoldenChargeShrine"
		local col = if golden then rgb(255, 200, 50) else rgb(90, 200, 255)
		anchor = block({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(6, 2, 2), CFrame = CFrame.new(position + Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = col, Material = Enum.Material.Neon, Parent = model })
		entry.radius = 9
		entry.ring = block({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, entry.radius * 2, entry.radius * 2), CFrame = CFrame.new(position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = col, Material = Enum.Material.Neon, Transparency = 0.7, CanCollide = false, CanQuery = false, Parent = model })
		entry.progress = 0
		entry.label = billboard(anchor, LABEL[kind], 4)
	elseif kind == "GreedShrine" or kind == "BossCurse" or kind == "ShrineOfSucc" then
		local col = if kind == "GreedShrine" then rgb(255, 210, 60) elseif kind == "BossCurse" then rgb(160, 30, 40) else rgb(120, 240, 255)
		anchor = block({ Size = Vector3.new(3, 7, 3), CFrame = CFrame.new(position + Vector3.new(0, 3.5, 0)), Color = rgb(110, 110, 120), Material = Enum.Material.Slate, Parent = model })
		block({ Shape = Enum.PartType.Ball, Size = Vector3.one * 2.4, CFrame = anchor.CFrame * CFrame.new(0, 4.5, 0), Color = col, Material = Enum.Material.Neon, Parent = model })
		billboard(anchor, LABEL[kind], 6)
		local action = if kind == "GreedShrine" then "Aceptar el trato" elseif kind == "BossCurse" then "Maldecir al jefe" else "Absorber experiencia"
		local prompt = promptOn(entry, action, LABEL[kind], 0.5)
		prompt.Triggered:Connect(function(player)
			if player == session.player then
				self:useShrine(entry)
			end
		end)
	elseif kind == "Microwave" then
		local rarity = Loot.rollRarity(session)
		entry.data.rarity = rarity
		entry.data.uses = Config.Economy.MicrowaveUses[rarity]
		anchor = block({ Size = Vector3.new(5, 3.5, 3.5), CFrame = CFrame.new(position + Vector3.new(0, 1.75, 0)), Color = rgb(220, 220, 225), Material = Enum.Material.Metal, Parent = model })
		block({ Size = Vector3.new(3, 2.4, 0.2), CFrame = anchor.CFrame * CFrame.new(-0.6, 0, -1.8), Color = Catalog.RarityColor[rarity], Material = Enum.Material.Neon, Parent = model })
		entry.label = billboard(anchor, "", 3.2)
		local prompt = promptOn(entry, "Usar", "Microwave")
		prompt.Triggered:Connect(function(player)
			if player == session.player then
				self:useMicrowave(entry)
			end
		end)
	elseif kind == "ShadyGuy" then
		local rarity = Loot.rollRarity(session)
		entry.data.rarity = rarity
		anchor = block({ Size = Vector3.new(2.5, 5, 2), CFrame = CFrame.new(position + Vector3.new(0, 2.5, 0)), Color = rgb(30, 30, 35), Material = Enum.Material.Fabric, Parent = model })
		block({ Shape = Enum.PartType.Ball, Size = Vector3.one * 2, CFrame = anchor.CFrame * CFrame.new(0, 3.3, 0), Color = rgb(30, 30, 35), Parent = model })
		block({ Size = Vector3.new(1.4, 0.3, 0.1), CFrame = anchor.CFrame * CFrame.new(0, 3.4, -1.0), Color = Catalog.RarityColor[rarity], Material = Enum.Material.Neon, Parent = model })
		billboard(anchor, "Shady Guy (" .. Catalog.RarityName[rarity] .. ")", 5.5)
		local prompt = promptOn(entry, "Comerciar", "Shady Guy")
		prompt.Triggered:Connect(function(player)
			if player == session.player then
				self:useShady(entry)
			end
		end)
	elseif kind == "Pot" then
		local silver = session.rng:NextNumber() < Config.Economy.SilverPotChance
		entry.data.silver = silver
		anchor = block({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, 2, 2), CFrame = CFrame.new(position + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = if silver then rgb(210, 215, 225) else rgb(170, 100, 60), Material = if silver then Enum.Material.Metal else Enum.Material.Slate, CanCollide = false, Parent = model })
	elseif kind == "BossPortal" or kind == "ExitPortal" then
		local col = if kind == "BossPortal" then rgb(200, 40, 60) else rgb(80, 255, 140)
		anchor = block({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 10, 10), CFrame = CFrame.new(position + Vector3.new(0, 5.5, 0)) * CFrame.Angles(0, math.pi / 2, 0), Color = col, Material = Enum.Material.Neon, Transparency = 0.25, CanCollide = false, Parent = model })
		billboard(anchor, LABEL[kind], 7)
		local prompt = promptOn(entry, if kind == "BossPortal" then "Invocar jefe" else "Siguiente etapa", LABEL[kind], 1)
		prompt.Triggered:Connect(function(player)
			if player == session.player then
				if kind == "BossPortal" then
					self:remove(entry)
					session:startBoss(entry.pos)
				else
					session:nextStage()
				end
			end
		end)
	end

	entry.anchor = anchor
	entry.model = model
	model.PrimaryPart = anchor
	model.Parent = self.folder
	table.insert(self.list, entry)
	self:refreshLabel(entry)
	return entry
end

function Interactables:refreshLabel(entry)
	if not entry.label then
		return
	end
	if entry.kind == "Chest" then
		entry.label.Text = string.format("Cofre: %d oro", self:chestCost())
	elseif entry.kind == "FreeChest" then
		entry.label.Text = "Cofre gratis"
	elseif entry.kind == "Microwave" then
		entry.label.Text = string.format("Microwave %s (%d usos) · %d oro", Catalog.RarityName[entry.data.rarity], entry.data.uses, Config.Economy.MicrowaveCost)
	end
end

function Interactables:spawnLayout(map, rng: Random, half: number, avoid: { Vector3 })
	local session = self.session
	local counts = table.clone(map.interactables)
	counts.Pot += 10 * Items.count(session, "Pumpkin")
	if rng:NextNumber() > 0.5 then
		counts.GoldenChargeShrine = 0 -- aparición probabilística [Pendiente]
	end
	local order = { "BossPortal", "ShadyGuy", "Microwave", "GreedShrine", "BossCurse", "ShrineOfSucc", "GoldenChargeShrine", "ChargeShrine", "Chest", "Pot" }
	counts.BossPortal = 1
	for _, kind in order do
		for _ = 1, counts[kind] or 0 do
			local gap = if kind == "BossPortal" then 120 elseif kind == "Pot" then 6 else 18
			local pos = MapGen.randomSpot(rng, half, avoid, gap)
			table.insert(avoid, pos)
			self:add(kind, pos)
		end
	end
	session.chargeShrinesTotal = counts.ChargeShrine + counts.GoldenChargeShrine
end

-- Cofres --------------------------------------------------------------------------------------

function Interactables:openChest(entry)
	local session = self.session
	if entry.removed or not session:canInteract() then
		return
	end
	local free = entry.kind == "FreeChest"
	if not free then
		local n = Items.count(session, "Key")
		local keyChance = 0.1 * n / (1 + 0.1 * n)
		if n > 0 and session.rng:NextNumber() < keyChance then
			free = true
			session:toast("¡La llave abre el cofre gratis!")
		else
			local cost = self:chestCost()
			if session.gold < cost then
				session:toast("No tienes oro suficiente")
				return
			end
			session.gold -= cost
			session.chestsBought += 1
			session:addCounter("chestsBought", 1)
		end
	end
	local item = Loot.pick(session)
	self:remove(entry)
	session.chestsOpened += 1
	session.statsDirty = true
	Items.onInteract(session, "Chest")
	for _, other in self.list do
		if not other.removed then
			self:refreshLabel(other)
		end
	end
	if item then
		session:offerItem(item, "Cofre")
	end
end

function Interactables:spawnFreeChest(position: Vector3)
	local angle = self.session.rng:NextNumber(0, math.pi * 2)
	local pos = position + Vector3.new(math.cos(angle) * 6, 0, math.sin(angle) * 6)
	local result = workspace:Raycast(pos + Vector3.new(0, 30, 0), Vector3.new(0, -100, 0))
	if result then
		pos = result.Position
	end
	self:add("FreeChest", pos)
	self.session:markersChanged()
end

-- Santuarios ----------------------------------------------------------------------------------

function Interactables:useShrine(entry)
	local session = self.session
	if entry.removed or not session:canInteract() then
		return
	end
	session.runFlags.usedShrine = true
	if entry.kind == "GreedShrine" then
		local gold = Config.Economy.GreedGold * session.stage
		session:gainGold(gold, true)
		session.bonus.Difficulty = (session.bonus.Difficulty or 0) + Config.Economy.GreedDifficulty
		session.statsDirty = true
		session:toast(string.format("+%d oro · +5%% dificultad", gold))
	elseif entry.kind == "BossCurse" then
		if session.bossActive then
			return
		end
		session.bossCurses += 1
		session:toast("El jefe tendrá una copia más (con recompensa extra)")
	elseif entry.kind == "ShrineOfSucc" then
		Pickups.magnetAll(session)
		session:addCounter("shrineSucc", 1)
	end
	Items.onInteract(session, entry.kind)
	self:remove(entry)
end

function Interactables:completeChargeShrine(entry)
	local session = self.session
	local golden = entry.kind == "GoldenChargeShrine"
	session.runFlags.usedShrine = true
	session.chargeShrinesDone += 1
	Items.onInteract(session, entry.kind)
	local beacon = Items.count(session, "Beacon")
	if beacon > 0 then
		local pos = entry.pos
		local part = Fx.acquire("Cylinder", Color3.fromRGB(120, 255, 160), Vector3.new(0.3, 16, 16))
		part.Transparency = 0.6
		part.CFrame = CFrame.new(pos + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		session:addZone({
			pos = pos,
			untilTime = session.time + 20,
			tick = 1,
			nextTick = session.time,
			part = part,
			pooled = true,
			onTick = function(z)
				if (session.root.Position - z.pos).Magnitude <= 8 then
					Damage.heal(session, session.stats.MaxHealth * 0.025 * beacon, "Beacon")
				end
			end,
		})
	end
	self:remove(entry)

	local wrench = 1 + 0.075 * Items.count(session, "Wrench")
	local pool = table.clone(SHRINE_KEYS)
	local choices = {}
	for _ = 1, 3 do
		local stat = table.remove(pool, session.rng:NextInteger(1, #pool))
		local rarity = Offers.rollRarity(session, if golden then "Legendary" else nil)
		local delta = SHRINE_REWARDS[stat] * Catalog.UpgradeRarityMult[rarity] * wrench
		local before = session.stats[stat] or 0
		table.insert(choices, {
			type = "Shrine",
			rarity = rarity,
			name = Stats.label(stat),
			subtitle = Catalog.RarityName[rarity],
			stat = stat,
			delta = delta,
			changes = { { text = string.format("%s → %s", Stats.format(stat, before), Stats.format(stat, before + delta)) } },
		})
	end
	session:openModal({
		kind = "Shrine",
		title = if golden then "Golden Charge Shrine" else "Charge Shrine",
		choices = choices,
		canSkip = true,
		onChoose = function(index)
			local c = choices[index]
			if c then
				session.bonus[c.stat] = (session.bonus[c.stat] or 0) + c.delta
				session.statsDirty = true
			end
		end,
	})
	if session.chargeShrinesDone >= session.chargeShrinesTotal and session.chargeShrinesTotal > 0 then
		session:addCounter("event.AllChargeShrinesMap", 1)
	end
end

-- Microwave: duplica el objeto elegido pagando oro y sacrifica otro aleatorio de su misma rareza.
-- Usos: común 3, raro y épico 2, legendario 1 (referencia comunitaria). Al agotarse explota.
function Interactables:useMicrowave(entry)
	local session = self.session
	if entry.removed or not session:canInteract() then
		return
	end
	local rarity = entry.data.rarity
	local owned, totalCopies = {}, 0
	for id, n in session.items do
		local item = Catalog.Item[id]
		if n > 0 and item.rarity == rarity then
			table.insert(owned, item)
			totalCopies += n
		end
	end
	if totalCopies < 2 then
		session:toast("Necesitas al menos 2 objetos " .. string.lower(Catalog.RarityName[rarity]) .. "s")
		return
	end
	local cost = Config.Economy.MicrowaveCost * session.stage
	cost = math.floor(cost * (1 + 0.1 * Items.count(session, "CreditCardGreen")))
	table.sort(owned, function(a, b)
		return a.name < b.name
	end)
	local choices = {}
	for _, item in owned do
		table.insert(choices, {
			type = "Item",
			id = item.id,
			rarity = item.rarity,
			name = item.name,
			subtitle = string.format("Tienes %d · %d oro", session.items[item.id], cost),
			desc = item.desc,
			changes = {},
		})
	end
	session:openModal({
		kind = "Microwave",
		title = "Microwave: elige el objeto que quieres duplicar",
		choices = choices,
		canSkip = true,
		onChoose = function(index)
			local chosen = owned[index]
			if not chosen or session.gold < cost or entry.removed then
				return
			end
			if chosen.cap and session.items[chosen.id] >= chosen.cap then
				session:toast("Ese objeto ya está en su límite")
				return
			end
			-- Sacrificio aleatorio de otra copia de la misma rareza (no la elegida)
			local pool = {}
			for id, n in session.items do
				local item = Catalog.Item[id]
				if item.rarity == rarity then
					local available = if id == chosen.id then n - 1 else n
					for _ = 1, available do
						table.insert(pool, id)
					end
				end
			end
			if #pool == 0 then
				session:toast("No hay otro objeto que sacrificar")
				return
			end
			session.gold -= cost
			local victim = pool[session.rng:NextInteger(1, #pool)]
			session:removeItem(victim, 1)
			session:addItem(chosen.id, 1)
			session:toast(string.format("%s duplicado; se perdió %s", chosen.name, Catalog.Item[victim].name))
			-- Rachas para desbloqueos (Ice Crystal / Moldy Cheese 3 veces seguidas)
			local streak = session.microwaveStreak
			if streak.id == chosen.id then
				streak.count += 1
			else
				streak.id, streak.count = chosen.id, 1
			end
			if streak.count >= 3 then
				session:addCounter("microwave." .. chosen.id .. ".streak3", 1)
			end
			entry.data.uses -= 1
			if entry.data.uses <= 0 then
				Fx.flash("Ball", CFrame.new(entry.pos), Vector3.one * 10, Color3.fromRGB(255, 150, 50), 0.3, 0.3)
				session:addCounter("microwave.exploded", 1)
				self:remove(entry)
			else
				self:refreshLabel(entry)
			end
		end,
	})
end

-- Shady Guy: tres objetos de su rareza a cambio de oro; una compra por visita [Pendiente: límites]
function Interactables:useShady(entry)
	local session = self.session
	if entry.removed or not session:canInteract() then
		return
	end
	local rarity = entry.data.rarity
	if not entry.data.stock then
		entry.data.stock = {}
		local pool = Loot.eligible(session, rarity)
		for _ = 1, math.min(Config.Economy.ShadyGuyOffers, #pool) do
			table.insert(entry.data.stock, table.remove(pool, session.rng:NextInteger(1, #pool)))
		end
	end
	local cost = math.floor(Config.Economy.ShadyGuyCost[rarity] * session.stage * (1 + 0.1 * Items.count(session, "CreditCardGreen")))
	local choices = {}
	for _, item in entry.data.stock do
		table.insert(choices, {
			type = "Item",
			id = item.id,
			rarity = item.rarity,
			name = item.name,
			subtitle = string.format("%d oro", cost),
			desc = item.desc,
			changes = {},
		})
	end
	session:openModal({
		kind = "Shop",
		title = "Shady Guy",
		choices = choices,
		canSkip = true,
		onChoose = function(index)
			local item = entry.data.stock[index]
			if not item or entry.removed then
				return
			end
			if session.gold < cost then
				session:toast("No tienes oro suficiente")
				return
			end
			session.gold -= cost
			session:addItem(item.id, 1)
			session:addCounter("shady.bought." .. rarity, 1)
			Items.onInteract(session, "ShadyGuy")
			self:remove(entry)
		end,
	})
end

-- Bucle: carga de santuarios y rotura de vasijas por proximidad ------------------------------

function Interactables:step(dt: number)
	local session = self.session
	local rootPos = session.root.Position
	local chargeTime = math.max(0.2, 5 * (1 - 0.04 * Items.count(session, "Wrench"))) -- referencia comunitaria
	for _, entry in self.list do
		if entry.removed then
			continue
		end
		local kind = entry.kind
		if kind == "ChargeShrine" or kind == "GoldenChargeShrine" then
			local inside = (Vector3.new(rootPos.X, entry.pos.Y, rootPos.Z) - entry.pos).Magnitude <= entry.radius
			if inside then
				entry.progress += dt / chargeTime
				entry.label.Text = string.format("%d%%", math.floor(entry.progress * 100))
				if entry.progress >= 1 then
					self:completeChargeShrine(entry)
				end
			elseif entry.progress > 0 then
				entry.progress = math.max(0, entry.progress - dt / (chargeTime * 2))
				entry.label.Text = if entry.progress > 0 then string.format("%d%%", math.floor(entry.progress * 100)) else LABEL[kind]
			end
		elseif kind == "Pot" then
			if (rootPos - entry.pos).Magnitude <= 3.8 then
				local bonus = 1 + 0.18 * Items.count(session, "Pumpkin")
				if entry.data.silver then
					session:spawnPickup("Silver", entry.pos, math.max(1, math.floor(session.rng:NextInteger(1, 2) * bonus)))
				else
					session:spawnPickup("Gold", entry.pos, math.floor(session.rng:NextInteger(2, 5) * session.stage * bonus))
				end
				Pickups.maybePowerup(session, entry.pos, Pickups.CHANCE_ON_POT)
				session:addCounter("pots", 1)
				session.runPots += 1
				session:recordMax("run.pots", session.runPots)
				Fx.flash("Ball", CFrame.new(entry.pos), Vector3.one * 3, Color3.fromRGB(200, 150, 100), 0.12, 0.4)
				self:remove(entry)
			end
		end
	end
end

function Interactables:spawnExit(position: Vector3)
	local result = workspace:Raycast(position + Vector3.new(0, 30, 0), Vector3.new(0, -200, 0))
	self:add("ExitPortal", if result then result.Position else position)
	self.session:markersChanged()
end

function Interactables:markers()
	local list = {}
	for _, entry in self.list do
		if not entry.removed and entry.kind ~= "Pot" then
			table.insert(list, { kind = entry.kind, x = entry.pos.X, z = entry.pos.Z })
		end
	end
	return list
end

function Interactables:destroy()
	self.folder:Destroy()
	table.clear(self.list)
end

return Interactables
