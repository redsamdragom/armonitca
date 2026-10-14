-- Imágenes de la interfaz subidas a Roblox. Para usar una imagen:
--   1. En Roblox Studio abre View → Asset Manager → Import (o Creator Hub → Development Items →
--      Decals) y sube el PNG.
--   2. Copia su ID numérico y pégalo aquí como "rbxassetid://123456789".
-- Mientras un campo esté vacío, la interfaz dibuja un sustituto (retrato generado con el modelo del
-- personaje, icono con primitivas).

local Images = {}

-- Retrato cuadrado de cada personaje (selector y ficha)
Images.Portraits = {
	Fox = "",
	SirOofie = "",
	Calcium = "",
	Megachad = "",
	Ogre = "",
	CL4NK = "",
	Athena = "",
	Robinette = "",
	Monke = "",
	TonyMcZoom = "",
	Bush = "",
	Birdo = "",
	Noelle = "",
	Amog = "",
	Spaceman = "",
	Bandit = "",
	Ninja = "",
	Vlad = "",
	SirChadwell = "",
	Dicehead = "",
	Roberto = "",
}

-- Silueta negra de los personajes bloqueados. Si está vacía se usa el retrato teñido de negro.
Images.Silhouettes = {}

-- Icono del arma (por id de arma) y de la pasiva (por id de personaje)
Images.Weapons = {}
Images.Passives = {}

-- Iconos de skin (por id de skin de Data/Cosmetics) y de sombrero (por id de sombrero)
Images.Skins = {}
Images.Hats = {}

function Images.get(group: { [string]: string }, id: string): string?
	local value = group[id]
	if value and value ~= "" then
		return value
	end
	return nil
end

return Images
