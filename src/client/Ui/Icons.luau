-- Iconos compartidos por el menú, las cartas de subida de nivel y el HUD.
-- Usan la imagen subida (Data/Images) y, mientras no haya ID, un dibujo con primitivas.

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Images = require(ReplicatedStorage.Shared.Data.Images)
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

-- Icono de un tomo; con `silhouette` se ve negro (bloqueado). Mientras la imagen carga, o si no
-- carga, se ve el libro dibujado del color del tomo (oscurecido si está bloqueado). Devuelve true
-- si el tomo tiene imagen configurada.
function Icons.tome(holder: GuiObject, tomeId: string, silhouette: boolean?): boolean
	local image = Images.get(Images.Tomes, tomeId)
	local rgb = Images.TomeColors[tomeId]
	local cover = if rgb then Color3.fromRGB(rgb[1], rgb[2], rgb[3]) else nil
	if not image then
		Icons.book(holder, cover)
		return false
	end
	if loadState[image] == "ok" then
		Icons.image(holder, image, if silhouette then Color3.new(0, 0, 0) else nil)
		return true
	end
	local fallback = Theme.frame({ Name = "Fallback", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = holder })
	Icons.book(fallback, cover)
	if silhouette then
		Theme.frame({ Name = "Shadow", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.2, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = fallback })
	end
	local img = Icons.image(holder, image, if silhouette then Color3.new(0, 0, 0) else nil)
	img.Visible = false
	whenLoaded(image, "el tomo " .. tomeId, function(ok)
		if img.Parent then
			img.Visible = ok
			fallback.Visible = not ok
		end
	end)
	return true
end

return Icons
