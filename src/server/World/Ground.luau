-- Consultas de altura del suelo (terreno y piezas del mapa) para enemigos, botín e interactuables.

local Ground = {}

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = true

-- Instancias que el raycast debe ignorar (personajes y efectos).
function Ground.setIgnore(list: { Instance })
	params.FilterDescendantsInstances = list
end

-- Altura del suelo bajo `position`, lanzando el rayo desde `fromHeight` studs por encima.
function Ground.height(position: Vector3, fallback: number, fromHeight: number?): number
	local origin = Vector3.new(position.X, position.Y + (fromHeight or 30), position.Z)
	local result = workspace:Raycast(origin, Vector3.new(0, -1000, 0), params)
	return if result then result.Position.Y else fallback
end

-- Superficie más alta (para colocar objetos sobre el terreno desde arriba).
function Ground.top(x: number, z: number, fallback: number): (number, Vector3?)
	local result = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -800, 0), params)
	if result then
		return result.Position.Y, result.Normal
	end
	return fallback, nil
end

return Ground
