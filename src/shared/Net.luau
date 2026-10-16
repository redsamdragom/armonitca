-- Nombres de los canales de red. El servidor los crea; el cliente los espera.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

Net.Events = {
	"StartRun", -- cliente → servidor: { character, map, tier }
	"RunStarted", -- servidor → cliente: datos fijos de la partida (mapa, interactuables)
	"Hud", -- servidor → cliente: estado del HUD (10 Hz)
	"Modal", -- servidor → cliente: oferta/elección (mejora, objeto, santuario, microondas, vendedor)
	"ModalChoice", -- cliente → servidor: { action, index }
	"Results", -- servidor → cliente: resumen de la partida
	"Toast", -- servidor → cliente: aviso breve
	"MapMarkers", -- servidor → cliente: marcadores del minimapa
	"Pause", -- cliente → servidor: pausar/reanudar
	"QuitRun", -- cliente → servidor: abandonar partida
	"SaveSettings", -- cliente → servidor: opciones
	"Profile", -- servidor → cliente: perfil actualizado
}
Net.Unreliable = {
	"Aim", -- cliente → servidor: dirección de la cámara
	"Fx", -- servidor → cliente: números de daño
}
Net.Functions = {
	"GetProfile",
	"Purchase",
	"GetLeaderboard", -- cliente → servidor: scope ("global" | "friends") → clasificación semanal
}

local folder: Folder?

function Net.setup()
	assert(RunService:IsServer())
	local f = Instance.new("Folder")
	f.Name = "Remotes"
	for _, name in Net.Events do
		local r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = f
	end
	for _, name in Net.Unreliable do
		local r = Instance.new("UnreliableRemoteEvent")
		r.Name = name
		r.Parent = f
	end
	for _, name in Net.Functions do
		local r = Instance.new("RemoteFunction")
		r.Name = name
		r.Parent = f
	end
	f.Parent = ReplicatedStorage
	folder = f
end

function Net.get(name: string): any
	if not folder then
		folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
	end
	return (folder :: Folder):WaitForChild(name)
end

return Net
