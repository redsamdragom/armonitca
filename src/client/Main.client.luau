-- Arranque del cliente: escena del menú, menús, HUD, elecciones, pausa, resultados, números de daño,
-- movimiento y postura de patinar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local Client = script.Parent
local ClientState = require(Client.ClientState)
local Movement = require(Client.Movement)
local Skating = require(Client.Skating)
local Ui = Client.Ui
local MenuScene = require(Ui.MenuScene)
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

-- La escena de fondo (bosque desenfocado) controla la cámara mientras el menú está abierto.
local function showMenu()
	ClientState.inRun = false
	Hud.show(false)
	Menu.show(true)
	MenuScene.show(true)
	task.spawn(function()
		ClientState.setProfile(Net.get("GetProfile"):InvokeServer())
	end)
end

MenuScene.init()
Menu.init()
Hud.init()
Modal.init(Hud.last)
Pause.init(Hud.last)
Results.init(showMenu)
DamageNumbers.init()
Movement.init()
Skating.init()

Net.get("Profile").OnClientEvent:Connect(ClientState.setProfile)

Net.get("RunStarted").OnClientEvent:Connect(function()
	ClientState.inRun = true
	Menu.show(false)
	MenuScene.show(false)
	Hud.show(true)
	local character = Players.LocalPlayer.Character
	if character then
		workspace.CurrentCamera.CameraSubject = character:FindFirstChildOfClass("Humanoid")
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
