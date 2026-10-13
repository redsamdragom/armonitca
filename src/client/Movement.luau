-- Movimiento propio de cada personaje (en el cliente, que es dueño de la física del avatar):
-- saltos extra, planeo (Birdo), escalada (Monke), baja gravedad (Spaceman) y dirección de mira.
-- Coeficientes [Pendiente] de calibración contra grabaciones del original.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Net = require(ReplicatedStorage.Shared.Net)
local ClientState = require(script.Parent.ClientState)

local Movement = {}

local player = Players.LocalPlayer
local FLOAT_FALL_SPEED = -6
local CLIMB_SPEED = 16
local LOW_GRAVITY_FACTOR = 0.45

local jumpsUsed = 0
local jumpHeld = false
local character: Model?
local humanoid: Humanoid?
local root: BasePart?
local antiGravity: VectorForce?

local function setupCharacter(model: Model)
	character = model
	humanoid = model:WaitForChild("Humanoid") :: Humanoid
	root = model:WaitForChild("HumanoidRootPart") :: BasePart
	jumpsUsed = 0
	antiGravity = nil;
	(humanoid :: Humanoid).StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running then
			jumpsUsed = 0
		end
	end)
end

function Movement.init()
	if player.Character then
		task.spawn(setupCharacter, player.Character)
	end
	player.CharacterAdded:Connect(setupCharacter)

	UserInputService.JumpRequest:Connect(function()
		if not humanoid or not root or not player:GetAttribute("InRun") then
			return
		end
		local state = humanoid:GetState()
		local inAir = state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping
		local extra = player:GetAttribute("ExtraJumps") or 0
		if inAir and jumpsUsed < extra and not root.Anchored then
			jumpsUsed += 1
			local g = workspace.Gravity * (if player:GetAttribute("LowGravity") then LOW_GRAVITY_FACTOR else 1)
			local velocity = math.sqrt(2 * g * humanoid.JumpHeight)
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(v.X, velocity, v.Z)
		end
	end)

	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
			jumpHeld = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
			jumpHeld = false
		end
	end)

	local aimTimer = 0
	RunService.Heartbeat:Connect(function(dt)
		UserInputService.MouseDeltaSensitivity = ClientState.settings.sensitivity
		if not humanoid or not root or not character or not character.Parent or root.Anchored then
			return
		end

		-- Baja gravedad: fuerza ascendente constante
		local lowGravity = player:GetAttribute("LowGravity") == true
		if lowGravity and not antiGravity then
			local attachment = Instance.new("Attachment")
			attachment.Parent = root
			local force = Instance.new("VectorForce")
			force.Attachment0 = attachment
			force.RelativeTo = Enum.ActuatorRelativeTo.World
			force.ApplyAtCenterOfMass = true
			force.Parent = root
			antiGravity = force
		end
		if antiGravity then
			local mass = root.AssemblyMass
			antiGravity.Force = if lowGravity then Vector3.new(0, mass * workspace.Gravity * (1 - LOW_GRAVITY_FACTOR), 0) else Vector3.zero
		end

		local v = root.AssemblyLinearVelocity
		-- Planeo: mantener salto limita la velocidad de caída
		if player:GetAttribute("CanFloat") and jumpHeld and v.Y < FLOAT_FALL_SPEED then
			root.AssemblyLinearVelocity = Vector3.new(v.X, FLOAT_FALL_SPEED, v.Z)
		end
		-- Escalada: avanzar contra una pared la sube
		if player:GetAttribute("CanClimb") and humanoid.MoveDirection.Magnitude > 0.1 then
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { character }
			local hit = workspace:Raycast(root.Position, humanoid.MoveDirection * 2.5, params)
			if hit and math.abs(hit.Normal.Y) < 0.4 then
				root.AssemblyLinearVelocity = Vector3.new(v.X, CLIMB_SPEED, v.Z)
				jumpsUsed = 0
			end
		end

		-- Dirección de mira para las armas que apuntan con la cámara
		aimTimer -= dt
		if aimTimer <= 0 then
			aimTimer = 0.1
			local look = workspace.CurrentCamera.CFrame.LookVector
			Net.get("Aim"):FireServer(Vector3.new(look.X, math.clamp(look.Y, -0.3, 0.3), look.Z))
		end
	end)
end

return Movement
