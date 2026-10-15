-- Iconos compartidos por el menú, las cartas de subida de nivel y el HUD.
-- Usan la imagen subida (Data/Images) y, mientras no haya ID, un dibujo con primitivas.

local AssetService = game:GetService("AssetService")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Images = require(ReplicatedStorage.Shared.Data.Images)
local TomeArt = require(ReplicatedStorage.Shared.Data.TomeArt)
local Theme = require(script.Parent.Theme)

local Icons = {}

local PAGES = Color3.fromRGB(240, 232, 205)
local DEFAULT_COVER = Color3.fromRGB(120, 70, 175)

local function piece(parent: Instance, color: Color3, x: number, y: number, w: number, h: number, z: number, rotation: number?): Frame
	return Theme.frame({
		BackgroundColor3 = color,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(w, h),
		Rotation = rotation or 0,
		ZIndex = z,
		Parent = parent,
	})
end

local function outline(frame: Frame, radius: number?): Frame
	if radius then
		Theme.corner(frame, radius)
	end
	Theme.stroke(frame, Theme.Colors.Outline, 2)
	return frame
end

-- Libro dibujado: páginas, tapa del color dado, lomo más oscuro y gema dorada.
function Icons.book(holder: GuiObject, cover: Color3?)
	local color = cover or DEFAULT_COVER
	outline(piece(holder, PAGES, 0.56, 0.52, 0.6, 0.78, 1), 3)
	outline(piece(holder, color, 0.47, 0.5, 0.6, 0.8, 2), 3)
	piece(holder, color:Lerp(Color3.new(0, 0, 0), 0.3), 0.21, 0.5, 0.08, 0.8, 3)
	Theme.stroke(piece(holder, Theme.Colors.Gold, 0.5, 0.42, 0.2, 0.2, 3, 45), Theme.Colors.Outline, 1)
end

-- Espada estilizada (icono genérico de arma).
function Icons.sword(holder: GuiObject)
	outline(piece(holder, Color3.fromRGB(205, 214, 224), 0.61, 0.39, 0.13, 0.67, 1, 45))
	outline(piece(holder, Color3.fromRGB(150, 105, 50), 0.36, 0.64, 0.42, 0.1, 2, 45))
	outline(piece(holder, Color3.fromRGB(95, 62, 35), 0.255, 0.745, 0.09, 0.2, 1, 45))
	outline(piece(holder, Theme.Colors.Gold, 0.165, 0.835, 0.14, 0.14, 2), 8)
end

-- Gema del color de la rareza (icono genérico de objeto).
function Icons.gem(holder: GuiObject, color: Color3)
	Theme.stroke(piece(holder, color, 0.5, 0.5, 0.56, 0.56, 1, 45), Theme.Colors.Outline, 2)
	piece(holder, color:Lerp(Color3.new(1, 1, 1), 0.45), 0.5, 0.5, 0.28, 0.28, 2, 45)
	piece(holder, Color3.new(1, 1, 1), 0.43, 0.39, 0.08, 0.08, 3, 45)
end

-- Imagen a tamaño completo del contenedor.
function Icons.image(holder: GuiObject, image: string, tint: Color3?): ImageLabel
	local img = Instance.new("ImageLabel")
	img.Name = "Icon"
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.ScaleType = Enum.ScaleType.Fit
	img.Image = image
	img.ImageColor3 = tint or Color3.new(1, 1, 1)
	img.ZIndex = holder.ZIndex
	img.Parent = holder
	return img
end

-- Resultado de la carga de cada imagen: "ok" o "fail". Las que fallan (ID equivocado, imagen
-- en moderación o rechazada) se avisan una vez en Output y se sustituyen por el dibujo.
local loadState: { [string]: string } = {}
local waiting: { [string]: { () -> () } } = {}

local function whenLoaded(image: string, label: string, onResult: (ok: boolean) -> ())
	local state = loadState[image]
	if state then
		onResult(state == "ok")
		return
	end
	local list = waiting[image]
	if list then
		table.insert(list, function()
			onResult(loadState[image] == "ok")
		end)
		return
	end
	waiting[image] = {
		function()
			onResult(loadState[image] == "ok")
		end,
	}
	task.spawn(function()
		local ok = pcall(function()
			ContentProvider:PreloadAsync({ image }, function(_, status)
				loadState[image] = if status == Enum.AssetFetchStatus.Success then "ok" else "fail"
			end)
		end)
		if not ok or not loadState[image] then
			loadState[image] = "fail"
		end
		if loadState[image] == "fail" then
			warn(string.format("[Imágenes] No se pudo cargar %s (%s): revisa el ID en Data/Images (¿ID del Decal en vez de la Image, o aún en moderación?)", label, image))
		end
		local callbacks = waiting[image]
		waiting[image] = nil
		for _, callback in callbacks do
			callback()
		end
	end)
end

-- Imágenes de los tomos incluidas en el juego (Data/TomeArt) -----------------------------------
-- Se dibujan con un EditableImage cuando el tomo no tiene ID o su imagen subida no carga, de modo
-- que el tomo se ve con su arte aunque el ID esté mal. Si el EditableImage no está disponible
-- (versión antigua o API desactivada) queda el libro dibujado.

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_VALUE: { [number]: number } = {}
for i = 1, #B64 do
	B64_VALUE[string.byte(B64, i)] = i - 1
end

-- Decodifica base64 a un buffer.
function Icons.decodeBase64(text: string): buffer
	local clean = string.gsub(text, "[^%w%+/]", "")
	local out = buffer.create(math.floor(#clean * 3 / 4))
	local n, acc, bits = 0, 0, 0
	for i = 1, #clean do
		acc = bit32.bor(bit32.lshift(acc, 6), B64_VALUE[string.byte(clean, i)])
		bits += 6
		if bits >= 8 then
			bits -= 8
			if n < buffer.len(out) then
				buffer.writeu8(out, n, bit32.band(bit32.rshift(acc, bits), 0xFF))
				n += 1
			end
		end
	end
	return out
end

-- Píxeles RGBA (size × size × 4) del arte incluido de un tomo, o nil si no lo hay.
function Icons.tomePixels(tomeId: string): buffer?
	local art = TomeArt.tomes[tomeId]
	if not art then
		return nil
	end
	local size = TomeArt.size
	local palette = Icons.decodeBase64(art.palette)
	local indices = Icons.decodeBase64(art.pixels)
	local pixels = buffer.create(size * size * 4)
	for i = 0, size * size - 1 do
		local index = buffer.readu8(indices, i)
		if index > 0 then
			buffer.writeu8(pixels, i * 4, buffer.readu8(palette, index * 3))
			buffer.writeu8(pixels, i * 4 + 1, buffer.readu8(palette, index * 3 + 1))
			buffer.writeu8(pixels, i * 4 + 2, buffer.readu8(palette, index * 3 + 2))
			buffer.writeu8(pixels, i * 4 + 3, 255)
		end
	end
	return pixels
end

local artCache: { [string]: any } = {}

local function artContent(tomeId: string): any
	local cached = artCache[tomeId]
	if cached ~= nil then
		return cached or nil
	end
	local ok, content = pcall(function()
		local pixels = Icons.tomePixels(tomeId)
		if not pixels then
			return nil
		end
		local size = Vector2.new(TomeArt.size, TomeArt.size)
		local editable = AssetService:CreateEditableImage({ Size = size })
		editable:WritePixelsBuffer(Vector2.zero, size, pixels)
		return Content.fromObject(editable)
	end)
	if not ok then
		warn("[Imágenes] No se pudo dibujar el arte incluido del tomo " .. tomeId .. ": " .. tostring(content))
	end
	artCache[tomeId] = (ok and content) or false
	return artCache[tomeId] or nil
end

-- Arte incluido del tomo sobre `holder`; devuelve false si no se pudo dibujar.
local function artImage(holder: GuiObject, tomeId: string, silhouette: boolean?): boolean
	local content = artContent(tomeId)
	if not content then
		return false
	end
	local img = Instance.new("ImageLabel")
	img.Name = "Art"
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.ScaleType = Enum.ScaleType.Fit
	img.ImageContent = content
	img.ImageColor3 = if silhouette then Color3.new(0, 0, 0) else Color3.new(1, 1, 1)
	img.ZIndex = holder.ZIndex
	img.Parent = holder
	return true
end

-- Sustituto mientras la imagen subida no está: el arte incluido o, si no se puede, el libro
-- dibujado del color del tomo (oscurecido si está bloqueado).
local function fallbackIcon(holder: GuiObject, tomeId: string, silhouette: boolean?)
	if artImage(holder, tomeId, silhouette) then
		return
	end
	local rgb = Images.TomeColors[tomeId]
	Icons.book(holder, if rgb then Color3.fromRGB(rgb[1], rgb[2], rgb[3]) else nil)
	if silhouette then
		Theme.frame({ Name = "Shadow", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.2, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = holder })
	end
end

-- Icono de un tomo; con `silhouette` se ve negro (bloqueado). Usa la imagen subida (ID de
-- Data/Images); mientras carga, si no carga o si no hay ID, el arte incluido en el juego.
function Icons.tome(holder: GuiObject, tomeId: string, silhouette: boolean?)
	local image = Images.get(Images.Tomes, tomeId)
	if image and loadState[image] == "ok" then
		Icons.image(holder, image, if silhouette then Color3.new(0, 0, 0) else nil)
		return
	end
	local fallback = Theme.frame({ Name = "Fallback", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = holder })
	fallbackIcon(fallback, tomeId, silhouette)
	if not image then
		return
	end
	local img = Icons.image(holder, image, if silhouette then Color3.new(0, 0, 0) else nil)
	img.Visible = false
	whenLoaded(image, "el tomo " .. tomeId, function(ok)
		if img.Parent then
			img.Visible = ok
			fallback.Visible = not ok
		end
	end)
end

-- Icono de un arma: la imagen subida (Data/Images) o una losa de su color con una espada.
function Icons.weapon(holder: GuiObject, weaponId: string)
	local image = Images.get(Images.Weapons, weaponId)
	if image then
		Icons.image(holder, image)
		return
	end
	local Catalog = require(ReplicatedStorage.Shared.Catalog)
	local weapon = Catalog.Weapon[weaponId]
	local color = if weapon and weapon.color then Color3.fromRGB(weapon.color[1], weapon.color[2], weapon.color[3]) else Color3.fromRGB(120, 120, 130)
	local slab = Theme.frame({ Name = "Slab", BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.5), Size = UDim2.fromScale(1, 1), Parent = holder })
	Icons.sword(Theme.frame({ BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.8, 0.8), Parent = slab }))
end

-- Icono de un objeto: gema del color de su rareza.
function Icons.item(holder: GuiObject, rarity: string?)
	Icons.gem(holder, Theme.Rarity[rarity or ""] or Theme.Colors.Text)
end

return Icons
