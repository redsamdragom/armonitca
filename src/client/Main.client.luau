-- Arranque del cliente: menús, HUD, elecciones, pausa, resultados, números de daño y movimiento.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local Client = script.Parent
local ClientState = require(Client.ClientState)
local Movement = require(Client.Movement)
local Ui = Client.Ui
local Menu = require(Ui.Menu)
local Hud = require(Ui.Hud)
local Modal = require(Ui.Modal)
local Pause = require(Ui.Pause)
local Results = require(Ui.Results)
local DamageNumbers = require(Ui.DamageNumbers)

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

local camera = workspace.CurrentCamera
local menuAngle = 0
local menuCamera: RBXScriptConnection?

local function startMenuCamera()
	if menuCamera then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	menuCamera = RunService.RenderStepped:Connect(function(dt)
		menuAngle += dt * 0.05
		local pos = Vector3.new(math.cos(menuAngle) * 120, 60, math.sin(menuAngle) * 120)
		camera.CFrame = CFrame.lookAt(pos, Vector3.zero)
	end)
end

local function stopMenuCamera()
	if menuCamera then
		menuCamera:Disconnect()
		menuCamera = nil
	end
	camera.CameraType = Enum.CameraType.Custom
end

local function showMenu()
	ClientState.inRun = false
	Hud.show(false)
	Menu.show(true)
	startMenuCamera()
	task.spawn(function()
		ClientState.setProfile(Net.get("GetProfile"):InvokeServer())
	end)
end

Menu.init()
Hud.init()
Modal.init()
Pause.init(Hud.last)
Results.init(showMenu)
DamageNumbers.init()
Movement.init()

Net.get("Profile").OnClientEvent:Connect(ClientState.setProfile)

Net.get("RunStarted").OnClientEvent:Connect(function()
	ClientState.inRun = true
	Menu.show(false)
	Hud.show(true)
	stopMenuCamera()
	local character = Players.LocalPlayer.Character
	if character then
		camera.CameraSubject = character:FindFirstChildOfClass("Humanoid")
	end
end)

Net.get("Results").OnClientEvent:Connect(function(data)
	ClientState.inRun = false
	Pause.close()
	Hud.show(false)
	Results.show(data)
end)

Net.get("Toast").OnClientEvent:Connect(function(text)
	if not ClientState.inRun then
		Menu.setStatus(text)
	end
end)

showMenu()
