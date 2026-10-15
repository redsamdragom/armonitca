# Armonitca

Recreación jugable en Roblox de un roguelite de supervivencia en tercera persona al estilo de MegaBonk (versión de referencia 1.0.69). Tus armas atacan solas, recoges experiencia y oro, eliges mejoras, construyes una combinación de armas, tomos y objetos, buscas el portal del jefe y avanzas por las etapas hasta el jefe final.

El estado de cada personaje, arma, tomo, objeto y mapa está en [docs/MATRIZ.md](docs/MATRIZ.md): completado, provisional, pendiente o con discrepancia.

## Qué hay implementado

- **Catálogo completo como datos:** 21 personajes, 30 armas, 23 tomos y 85 objetos, más enemigos, mapas, sombreros y skins (`src/shared/Data`). Al arrancar se valida que todas las referencias sean correctas.
- **Combate:** las 30 armas atacan con 11 patrones (tajo, proyectil, rayo, aura, rastro, órbita, minas, campo, haz, cono y escudo Aegis). El daño se calcula por grupos, con críticos (también por encima del 100%), ejecución, retroceso y robo de vida. Los ataques persistentes no dependen de los FPS.
- **Estados alterados:** veneno, quemadura, congelación (−70% de velocidad), aturdimiento, Bloodmark y maldición.
- **Objetos:** los 85 tienen comportamiento, organizado por eventos (al golpear, al hacer crítico, al matar, al recibir daño, al evadir, al curar, al moverse, al interactuar y quieto). Respetan Overpowered Lamp y los coeficientes de activación documentados, con límite de encadenamiento.
- **Pasivas** de los 21 personajes, incluidas las especiales: impulso de Calcium, Flex, Stonks, Plague, Gamba, Hoarder, Shadowstep, Bullseye y Zap. También el movimiento propio: saltos extra, planeo de Birdo, escalada de Monke y baja gravedad de Spaceman.
- **Partida:** subida de nivel con 1 de 3 mejoras de rareza variable, más Refresh, Skip y Banish. La simulación se pausa de verdad y cada nivel se procesa por separado. Incluye cofres, Charge Shrine y Golden Charge Shrine, Greed, Boss Curse, Shrine of Succ, Microwave, Shady Guy, vasijas y powerups.
- **Progresión de la partida:** minijefes, portal del jefe, salida a la siguiente etapa, jefe final por tier, Final Swarm con su propio reloj y pantalla de resultados con el daño por fuente.
- **Mapas:** Forest y Desert, generados con semilla (terreno con colinas y mesetas, rampas, árboles o cactus, y ruinas).
- **Progreso de la cuenta:** plata, desbloqueos, ranuras de arma y tomo, tienda, contadores acumulados y por partida, y rangos.
  - **Personajes:** se empieza con Fox, Sir Oofie y Calcium. Cada uno de los demás se desbloquea solo al cumplir su misión (por ejemplo, «Derrotar 2 minijefes») y tener su arma inicial; no se compran.
  - **Armas, tomos, objetos y mapas:** primero se cumple la condición y después se compran con plata (son estados distintos).
  - Las misiones de la referencia que aún no se pueden cumplir (Challenges, secretos, Graveyard) se han cambiado por otras provisionales; la matriz indica cuáles.
- **Guardado:** DataStore con versión de esquema, compras transaccionales y copia de seguridad.
- **Interfaz en español:** menú (personaje con vista 3D giratoria, mapa y tier, desbloqueos, tienda, colección y opciones con teclas reasignables), HUD con minimapa y mapa completo, pausa con estadísticas e inventario, y números de daño.

## Qué falta

- **Graveyard y Crypt:** guardianes, llaves, Spooky Steve, Big Bob y lava.
- **Secretos y encuentros:** encuentros secretos (Bush, Bandit), secretos de mapa (jaula de Monke, plátano oculto) y eventos de Desert (tormentas y tornados ambientales).
- **Challenges y Moai Shrine.**
- **Jefes:** sus patrones exactos y la retirada de armas en los combates de Tier 3.
- **Recursos originales:** mallas, rigs, animaciones, iconos, música y sonido. Los personajes son atuendos hechos con primitivas sobre el avatar.
- **Cosméticos:** son sólo datos; no se pueden equipar.
- **Valores numéricos:** casi todos están marcados como `[Pendiente]` y hay que calibrarlos con una copia del juego de referencia.

## Cómo jugar

| Acción | Teclado | Mando |
|---|---|---|
| Moverse / cámara | WASD / ratón | Stick izquierdo / derecho |
| Saltar (y saltos extra, planear) | Espacio | A |
| Interactuar | E (mantener en santuarios y portales) | X |
| Elegir mejora | Clic o 1, 2, 3 | Selección + A |
| Pausa | P (reasignable) | Select |
| Mapa completo | M (reasignable) | Y |

Busca el **portal del jefe** (rojo en el minimapa) antes de que acabe la cuenta atrás de la etapa. Si llega a cero, empieza el **Final Swarm**.

## Desarrollo

El código vive como archivos `.luau` y se sincroniza con Roblox Studio usando [Rojo](https://rojo.space).

1. Instala [Rokit](https://github.com/rojo-rbx/rokit) y ejecuta `rokit install` (instala Rojo 7.4.4 y Lune 0.10.4).
2. Instala el plugin de Rojo en Studio con `rojo plugin install`.
3. Ejecuta `rojo serve` en la carpeta del repo, abre un Baseplate en Studio, pulsa **Connect** en el plugin y luego **Play**.
4. En **Game Settings**:
   - **Security → Enable Studio Access to API Services**, para que se guarde el progreso.
   - **Places → Max Players = 1**: el juego es de un jugador.

Con `Config.Debug.StudioUnlockAll = true`, en Studio todo el contenido aparece desbloqueado para poder probarlo. Está desactivado para ver la progresión real; no lo actives en la versión publicada.

### Pruebas sin Studio

```bash
lune run tests/simulate   # partidas reales simuladas: 21 personajes, 30 armas, 85 objetos, jefes, etapas, guardado
lune run tests/client     # prueba de humo del cliente: menú, ventanas, partida, HUD, elecciones, pausa y resultados
lune run tests/matrix     # regenera docs/MATRIZ.md
```

`tests/Harness.luau` simula lo que el juego usa de Roblox: instancias, servicios, `task` con reloj simulado y suelo plano. En la prueba del cliente corren a la vez el servidor y el cliente reales; las propiedades de las instancias se validan con la base de datos de reflexión de Lune (miembros inexistentes, de sólo lectura o con un tipo incorrecto fallan como en Roblox) y los mensajes de red llegan diferidos y en orden. Las pruebas también comprueban que todo lo que se envía entre cliente y servidor sea serializable. GitHub Actions las ejecuta en cada push.

## Imágenes de la interfaz

Los retratos de los personajes, los iconos de armas, pasivas y skins, y las siluetas de los personajes bloqueados se configuran en `src/shared/Data/Images.luau`.

1. En Roblox Studio abre **View → Asset Manager → Import** y sube el PNG (o súbelo en Creator Hub → Development Items → Decals).
2. Copia el ID numérico de la imagen.
3. Pégalo en el campo del personaje, por ejemplo `Fox = "rbxassetid://123456789"`.

Mientras un campo esté vacío, el juego dibuja un sustituto: el busto del modelo del personaje o un icono hecho con primitivas. Los nombres y las frases en español están en `src/shared/Data/Spanish.luau`.

### Tomos

Las 23 imágenes de los tomos están en `assets/tomos/`. Cada archivo lleva el número original y el tomo al que corresponde (`tomo-03-Cooldown.png`). Se ven en Desbloqueos (pestaña TOMOS), en las cartas de subida de nivel y en la fila de tomos del HUD.

1. En Studio abre **View → Asset Manager → Bulk Import** y selecciona las 23 imágenes a la vez.
2. Con clic derecho en cada imagen, **Copy ID to Clipboard**.
3. Pega cada ID en `Images.Tomes` de `src/shared/Data/Images.luau`. El comentario de cada línea indica su archivo.

Además, las 23 imágenes van incluidas en el propio juego (`src/shared/Data/TomeArt.luau`, generado con `python3 tools/generar_tomos.py`). Si un tomo no tiene ID o su imagen subida no carga, el juego dibuja esa copia incluida con un EditableImage, así que los tomos se ven sin subir nada. Si el EditableImage no está disponible, se ve un libro del color del tomo y Output lo avisa.

## Diseños de los personajes

Los modelos hechos a mano están en `src/shared/Personajes/<Id>.rbxm` (Rojo los mete en `ReplicatedStorage.Shared.Personajes`). Con diseño, el personaje aparece así en la partida (se usa como `StarterCharacter`, con las animaciones de Roblox) y en las vistas del menú; sin diseño, se usa el avatar con el atuendo de primitivas.

| Diseño | Personaje |
| --- | --- |
| Lobo Mago | Fox (Zorro) |
| Samurai de Hierro | Sir Oofie |
| Esqueleto Skater | Calcium (Calcio) |
| Toro Musculoso Voxel | Megachad |
| Vikingo Voxel | Ogre (Ogro) |
| Vaquero Espacial Voxel | CL4NK |
| Guerrero Espartano Voxel | Athena (Atenea) |
| Hawkeye Morado | Robinette (Robinetta) |
| Lagartija Ancha con Lentes | Monke |
| Gato Voxel Skater | Tony McZoom (Tony McVeloz) |

Para importar diseños nuevos desde un lugar de Studio, añade su nombre a `MAPPING` en `tools/importar_personajes.luau` y ejecuta `lune run tools/importar_personajes <lugar.rbxl>` (hace falta Lune 0.11 o posterior). El script quita los scripts y herramientas, deja las patinetas soldadas bajo los pies y quita la colisión a las piezas de adorno.

## Estructura

```text
assets/tomos/             Imágenes de los 23 tomos (para subir a Roblox)
src/shared/
  Config.luau            Parámetros globales (provisionales marcados con [Pendiente])
  Catalog.luau           Índice por id, contenido comprable y validación
  Stats.luau             Estadísticas, rendimientos decrecientes y formato
  Net.luau               Canales de red
  Data/                  Characters, Weapons, Tomes, Items, Enemies, Maps, Cosmetics, Unlock
src/server/
  Main.server.luau       Arranque, perfiles, inicio de partidas y bucle
  Combat/                Damage, Status, Enemies, Weapons, Items, Fx, SpatialHash
  Run/                   RunSession, StatBlock, Offers, Loot, Passives, Director, Pickups
  World/                 MapGen, Interactables, Costumes, Ground
  Save/                  Profile, SaveService
src/client/
  Main.client.luau       Arranque del cliente
  ClientState.luau       Perfil, opciones y teclas
  Movement.luau          Saltos extra, planeo, escalada, baja gravedad y mira
  Ui/                    Menu, Hud, Modal, Pause, Results, DamageNumbers, Preview, Theme
tests/                   Harness, simulate, client, matrix (Lune)
docs/MATRIZ.md           Matriz de correspondencia con la referencia
```

Para añadir o ajustar contenido, edita su ficha en `src/shared/Data`. El comportamiento de cada objeto está en `src/server/Combat/Items.luau`, indexado por id, y el de cada patrón de arma en `src/server/Combat/Weapons.luau`.

## Publicación

Antes de publicar en Roblox, sustituye los nombres, personajes y diseños tomados de MegaBonk por contenido propio. Las mecánicas se pueden reutilizar, pero los nombres, personajes y arte son de sus autores. Algunos nombres originales ya se muestran cambiados (por ejemplo, «Cohete Travieso») porque infringirían las normas de contenido de Roblox; sus identificadores internos se mantienen para poder cotejarlos con la referencia.
