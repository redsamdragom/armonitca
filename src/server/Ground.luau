-- Consultas de altura del suelo para colocar enemigos y gemas sobre el terreno.

local Ground = {}

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = true

-- Instancias que el raycast debe ignorar (los personajes de los jugadores).
function Ground.setIgnore(list: { Instance })
	params.FilterDescendantsInstances = list
end

-- Altura del suelo bajo `position`, lanzando el rayo desde `fromHeight` studs por encima.
function Ground.height(position: Vector3, fallback: number, fromHeight: number?): number
	local origin = Vector3.new(position.X, position.Y + (fromHeight or 40), position.Z)
	local result = workspace:Raycast(origin, Vector3.new(0, -1000, 0), params)
	return if result then result.Position.Y else fallback
end

return Ground
