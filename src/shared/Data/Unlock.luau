-- Constructores de condiciones de desbloqueo.
-- Una condición cumplida deja el contenido "completado"; después hay que comprarlo con plata.
--
-- kind:
--   start    disponible desde el inicio (ya comprado)
--   counter  contador acumulado de la cuenta (Counters[key] >= target)
--   max      mejor marca de la cuenta (Max[key] >= target), p. ej. nivel de tomo en una partida
--   pending  condición todavía no rastreable en la recreación; no se puede completar jugando

local Unlock = {}

function Unlock.start()
	return { kind = "start", text = "Disponible desde el inicio" }
end

function Unlock.counter(key: string, target: number, text: string)
	return { kind = "counter", key = key, target = target, text = text }
end

function Unlock.max(key: string, target: number, text: string)
	return { kind = "max", key = key, target = target, text = text }
end

function Unlock.pending(text: string)
	return { kind = "pending", text = text }
end

return Unlock
