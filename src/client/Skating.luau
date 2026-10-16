-- Postura de patinar para los diseños con patineta (Calcium y Tony McZoom). La animación de andar de
-- Roblox movería las piernas por encima de la tabla, así que en ellos se quita y el cuerpo se
-- mueve con código: inclinación al avanzar, impulso con una pierna, brazos abiertos para el
-- equilibrio y brazos arriba en el aire. El resto de diseños usa la animación normal de Roblox.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Skating = {}

local player = Players.LocalPlayer
local JOINTS = { "RootJoint", "Neck", "Right Shoulder", "Left Shoulder", "Right Hip", "Left Hip" }

type Rig = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	joints: { [string]: Motor6D },
	quadruped: boolean,
	phase: number,
	move: number,
	air: number,
}

local rig: Rig?

-- Diseño hecho a mano que lleva patineta soldada bajo los pies.
function Skating.isSkater(model: Model): boolean
	return model:GetAttribute("Diseno") ~= nil and model:FindFirstChild("Patineta") ~= nil
end

local function stopDefaultAnimation(model: Model, humanoid: Humanoid)
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in animator:GetPlayingAnimationTracks() do
			track:Stop(0)
		end
	end
end

-- Empieza a seguir un personaje (deja de seguir el anterior); sin patineta no hace nada.
function Skating.track(model: Model)
	rig = nil
	local humanoid = model:WaitForChild("Humanoid", 10) :: Humanoid?
	local root = model:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not humanoid or not root or not Skating.isSkater(model) then
		return
	end
	local joints = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and table.find(JOINTS, d.Name) then
			joints[d.Name] = d
		end
	end
	local torso = model:FindFirstChild("Torso") :: BasePart?
	rig = {
		model = model,
		humanoid = humanoid,
		root = root,
		joints = joints,
		-- Cuadrúpedo (Tony): torso más largo que alto; los "brazos" son las patas delanteras
		quadruped = torso ~= nil and torso.Size.Z > torso.Size.Y * 1.5,
		phase = 0,
		move = 0,
		air = 0,
	}
	stopDefaultAnimation(model, humanoid)
	-- Roblox puede añadir el script Animate justo después de aparecer el personaje
	model.ChildAdded:Connect(function(child)
		if child.Name == "Animate" and rig and rig.model == model then
			stopDefaultAnimation(model, humanoid)
		end
	end)
end

local function set(name: string, transform: CFrame)
	local joint = rig and rig.joints[name]
	if joint then
		joint.Transform = transform
	end
end

-- Un paso de la postura. Ejes en el marco R6 estándar de cada articulación: en hombros y caderas
-- el giro en Z adelanta (derecha) o atrasa (izquierda) la extremidad y el giro en X negativo la
-- separa del cuerpo; en RootJoint el giro en X positivo inclina el torso hacia delante.
function Skating.step(dt: number)
	local r = rig
	if not r or not r.model.Parent or not r.root.Parent then
		return
	end
	stopDefaultAnimation(r.model, r.humanoid)
	local v = r.root.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	local state = r.humanoid:GetState()
	local inAir = state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping
	local blend = math.min(1, dt * 8)
	r.move += (math.clamp(speed / math.max(r.humanoid.WalkSpeed, 1), 0, 1) - r.move) * blend
	r.air += ((if inAir then 1 else 0) - r.air) * blend
	r.phase = (r.phase + dt * (3 + 3 * r.move)) % (2 * math.pi)

	local ground = 1 - r.air
	-- Impulso: la pierna derecha empuja hacia atrás una vez por ciclo mientras avanza en el suelo
	local kick = math.max(0, math.sin(r.phase)) * r.move * ground
	local bob = math.sin(r.phase * 2) * 0.06 * r.move * ground
	local lean = (if r.quadruped then 0.05 else 0.12) * r.move - 0.1 * r.air
	set("RootJoint", CFrame.new(0, 0, bob) * CFrame.Angles(lean, 0, 0))
	set("Neck", CFrame.Angles(-lean * 0.5, 0, 0))
	if r.quadruped then
		local stretch = 0.35 * r.air
		set("Right Shoulder", CFrame.Angles(0, 0, stretch))
		set("Left Shoulder", CFrame.Angles(0, 0, -stretch))
		set("Right Hip", CFrame.Angles(0, 0, -stretch - 0.6 * kick))
		set("Left Hip", CFrame.Angles(0, 0, stretch))
	else
		local out = 0.2 + 0.15 * r.move + 0.9 * r.air
		set("Right Shoulder", CFrame.Angles(-out, 0, 0.3 * kick))
		set("Left Shoulder", CFrame.Angles(-out, 0, 0.3 * kick))
		set("Right Hip", CFrame.Angles(-0.08, 0, -0.7 * kick))
		set("Left Hip", CFrame.Angles(-0.08, 0, 0))
	end
end

function Skating.init()
	if player.Character then
		task.spawn(Skating.track, player.Character)
	end
	player.CharacterAdded:Connect(Skating.track)
	-- Stepped va después del paso de animación y antes de la física: lo que se pone aquí es lo
	-- que se ve en este fotograma.
	RunService.Stepped:Connect(function(_, dt)
		Skating.step(dt)
	end)
end

return Skating
