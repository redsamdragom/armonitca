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

-- Icono de cada tomo (Desbloqueos, cartas de subida de nivel y HUD). Las imágenes están en
-- assets/tomos/: súbelas todas a la vez (Asset Manager → Bulk Import) y pega aquí cada ID.
Images.Tomes = {
	Agility = "rbxassetid://11157781625231", -- assets/tomos/tomo-01-Agility.png
	Cooldown = "rbxassetid://77976159467388", -- assets/tomos/tomo-03-Cooldown.png
	Damage = "rbxassetid://70450206870886", -- assets/tomos/tomo-11-Damage.png
	Evasion = "rbxassetid://124658411720980", -- assets/tomos/tomo-14-Evasion.png
	Golden = "rbxassetid://11010394204995", -- assets/tomos/tomo-02-Golden.png
	Health = "rbxassetid://13176387318398", -- assets/tomos/tomo-07-Health.png
	Knockback = "rbxassetid://81792752440821", -- assets/tomos/tomo-12-Knockback.png
	Precision = "rbxassetid://79414187169976", -- assets/tomos/tomo-06-Precision.png
	ProjectileSpeed = "rbxassetid://100437287994279", -- assets/tomos/tomo-19-ProjectileSpeed.png
	Regen = "rbxassetid://12858238182516", -- assets/tomos/tomo-09-Regen.png
	Shield = "rbxassetid://77439551822330", -- assets/tomos/tomo-10-Shield.png
	Silver = "rbxassetid://132475094248141", -- assets/tomos/tomo-21-Silver.png
	Size = "rbxassetid://134251038935358", -- assets/tomos/tomo-05-Size.png
	Armor = "rbxassetid://127143666424906", -- assets/tomos/tomo-04-Armor.png
	Attraction = "rbxassetid://108446068535887", -- assets/tomos/tomo-15-Attraction.png
	Bloody = "rbxassetid://76039974427160", -- assets/tomos/tomo-16-Bloody.png
	Chaos = "rbxassetid://127504414031229", -- assets/tomos/tomo-23-Chaos.png
	Cursed = "rbxassetid://105195574339171", -- assets/tomos/tomo-13-Cursed.png
	Duration = "rbxassetid://133196844630087", -- assets/tomos/tomo-18-Duration.png
	Luck = "rbxassetid://93866443058863", -- assets/tomos/tomo-17-Luck.png
	Quantity = "rbxassetid://124335329207324", -- assets/tomos/tomo-08-Quantity.png
	Thorns = "rbxassetid://108780448439095", -- assets/tomos/tomo-20-Thorns.png
	XP = "rbxassetid://86968390639527", -- assets/tomos/tomo-22-XP.png
}

-- Color de la tapa de cada tomo (tomado de su imagen): el libro dibujado mientras no haya ID.
Images.TomeColors = {
	Agility = { 70, 150, 230 },
	Cooldown = { 170, 215, 230 },
	Damage = { 240, 120, 30 },
	Evasion = { 230, 70, 140 },
	Golden = { 240, 180, 40 },
	Health = { 200, 70, 40 },
	Knockback = { 200, 60, 40 },
	Precision = { 220, 140, 70 },
	ProjectileSpeed = { 40, 110, 210 },
	Regen = { 230, 90, 170 },
	Shield = { 70, 80, 90 },
	Silver = { 70, 170, 190 },
	Size = { 230, 70, 140 },
	Armor = { 110, 115, 125 },
	Attraction = { 160, 50, 200 },
	Bloody = { 190, 30, 40 },
	Chaos = { 130, 60, 200 },
	Cursed = { 90, 50, 200 },
	Duration = { 60, 190, 200 },
	Luck = { 60, 170, 60 },
	Quantity = { 220, 120, 40 },
	Thorns = { 190, 70, 40 },
	XP = { 240, 170, 50 },
}

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
