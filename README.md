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
- **Progreso de la cuenta:** plata, desbloqueos por condición más compra (son estados distintos), ranuras de arma y tomo, tienda, contadores acumulados y por partida, y rangos.
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

En Studio, `Config.Debug.StudioUnlockAll` desbloquea todo el contenido para poder probarlo. Desactívalo antes de publicar.

### Pruebas sin Studio

```bash
lune run tests/simulate   # partidas reales simuladas: 21 personajes, 30 armas, 85 objetos, jefes, etapas, guardado
lune run tests/matrix     # regenera docs/MATRIZ.md
```

`tests/Harness.luau` simula lo que el servidor usa de Roblox: instancias, servicios, `task` con reloj simulado y suelo plano. Las pruebas también comprueban que todo lo que se envía al cliente sea serializable. GitHub Actions las ejecuta en cada push.

## Estructura

```text
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
tests/                   Harness, simulate, matrix (Lune)
docs/MATRIZ.md           Matriz de correspondencia con la referencia
```

Para añadir o ajustar contenido, edita su ficha en `src/shared/Data`. El comportamiento de cada objeto está en `src/server/Combat/Items.luau`, indexado por id, y el de cada patrón de arma en `src/server/Combat/Weapons.luau`.

## Publicación

Antes de publicar en Roblox, sustituye los nombres, personajes y diseños tomados de MegaBonk por contenido propio. Las mecánicas se pueden reutilizar, pero los nombres, personajes y arte son de sus autores. Algunos nombres originales ya se muestran cambiados (por ejemplo, «Cohete Travieso») porque infringirían las normas de contenido de Roblox; sus identificadores internos se mantienen para poder cotejarlos con la referencia.
