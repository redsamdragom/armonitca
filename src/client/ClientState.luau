-- Estado compartido del cliente: perfil recibido del servidor, opciones y teclas.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)

local ClientState = {}

ClientState.profile = nil
ClientState.inRun = false
ClientState.settings = {
	master = 1,
	music = 0.7,
	sfx = 0.8,
	sensitivity = 1,
	invertY = false,
	cameraDistance = 18,
	uiScale = 1,
	shake = 1,
	effectOpacity = 1,
	autoPick = false,
	disableSilverTome = false,
}
-- Acciones reasignables (teclado / mando)
ClientState.bindings = {
	Pause = { Enum.KeyCode.P, Enum.KeyCode.ButtonSelect },
	Map = { Enum.KeyCode.M, Enum.KeyCode.ButtonY },
	Choice1 = { Enum.KeyCode.One },
	Choice2 = { Enum.KeyCode.Two },
	Choice3 = { Enum.KeyCode.Three },
}

local listeners = {}

function ClientState.onProfile(fn)
	table.insert(listeners, fn)
	if ClientState.profile then
		task.spawn(fn, ClientState.profile)
	end
end

function ClientState.setProfile(profile)
	if not profile then
		return
	end
	ClientState.profile = profile
	for key, value in profile.settings or {} do
		ClientState.settings[key] = value
	end
	ClientState.applySettings()
	for _, fn in listeners do
		task.spawn(fn, profile)
	end
end

function ClientState.applySettings()
	local player = Players.LocalPlayer
	local s = ClientState.settings
	player.CameraMaxZoomDistance = math.max(8, s.cameraDistance + 10)
	player.CameraMinZoomDistance = math.min(s.cameraDistance, 8)
	local gui = player:FindFirstChild("PlayerGui")
	if gui then
		for _, screen in gui:GetChildren() do
			local scale = screen:FindFirstChild("SettingsScale")
			if scale then
				(scale :: UIScale).Scale = s.uiScale
			end
		end
	end
end

function ClientState.saveSettings()
	ClientState.applySettings()
	Net.get("SaveSettings"):FireServer(ClientState.settings)
end

function ClientState.matches(action: string, keyCode: Enum.KeyCode): boolean
	for _, key in ClientState.bindings[action] or {} do
		if key == keyCode then
			return true
		end
	end
	return false
end

function ClientState.screen(name: string, order: number): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = order
	local scale = Instance.new("UIScale")
	scale.Name = "SettingsScale"
	scale.Scale = ClientState.settings.uiScale
	scale.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui
end

return ClientState
