-- Rejilla espacial en XZ para consultas de proximidad sin comparar todos contra todos.

local SpatialHash = {}
SpatialHash.__index = SpatialHash

function SpatialHash.new(cellSize: number)
	return setmetatable({ cellSize = cellSize, cells = {} }, SpatialHash)
end

local function key(cx: number, cz: number): number
	return (cx + 32768) * 65536 + (cz + 32768)
end

function SpatialHash:clear()
	table.clear(self.cells)
end

function SpatialHash:insert(entry, position: Vector3)
	local cs = self.cellSize
	local k = key(position.X // cs, position.Z // cs)
	local cell = self.cells[k]
	if not cell then
		cell = {}
		self.cells[k] = cell
	end
	table.insert(cell, entry)
end

-- Llama a fn(entry) para cada entrada de las celdas que tocan el círculo (prefiltro).
function SpatialHash:each(position: Vector3, radius: number, fn: (any) -> boolean?)
	local cs = self.cellSize
	local x0, x1 = (position.X - radius) // cs, (position.X + radius) // cs
	local z0, z1 = (position.Z - radius) // cs, (position.Z + radius) // cs
	for cx = x0, x1 do
		for cz = z0, z1 do
			local cell = self.cells[key(cx, cz)]
			if cell then
				for _, entry in cell do
					if fn(entry) then
						return
					end
				end
			end
		end
	end
end

return SpatialHash
