# Armonitca

Un roguelike de supervivencia en 3D para Roblox, al estilo de Megabonk. Corres por una arena abierta, tus armas atacan solas, recoges XP de las hordas, eliges mejoras al subir de nivel y sobrevives 10 minutos hasta el jefe final.

## Cómo jugar

- **Muévete y salta** para esquivar a los enemigos. Las armas disparan solas.
- **Recoge las gemas** que sueltan los enemigos para subir de nivel.
- **Al subir de nivel**, elige 1 de 3 mejoras (clic o teclas `1`, `2`, `3`): un arma nueva, subir de nivel un arma o una pasiva.
- **A los 10:00** aparece el jefe final. Derrótalo para ganar.
- Es cooperativo: todos los jugadores del servidor comparten la partida.

## Desarrollo

El código vive en este repo como archivos `.luau` y se sincroniza con Roblox Studio usando [Rojo](https://rojo.space).

1. Instala [Rokit](https://github.com/rojo-rbx/rokit) y ejecuta `rokit install` (instala Rojo 7.4.4).
2. Instala el plugin de Rojo en Studio: `rojo plugin install`.
3. Ejecuta `rojo serve` en la carpeta del repo.
4. Abre un Baseplate en Studio, pulsa **Connect** en el plugin de Rojo y luego **Play**.

Para generar un archivo de lugar sin Studio: `rojo build -o armonitca.rbxl`.

## Estructura

```text
src/
├── shared/Config.luau          # Balance: armas, pasivas, enemigos, curva de XP
├── server/
│   ├── Main.server.luau        # Bucle de partida, oleadas, jefe, victoria/derrota
│   ├── Enemies.luau            # Enemigos (Parts + BulkMoveTo para hordas grandes)
│   ├── Weapons.luau            # Armas automáticas: proyectil, aura, orbital
│   ├── LevelUp.luau            # XP y cartas de mejora
│   ├── Gems.luau               # Gemas de XP con imán
│   ├── PlayerState.luau        # Estado del jugador en la partida
│   ├── Map.luau                # Arena generada (colinas, rampas, plataformas)
│   └── Ground.luau             # Raycasts al suelo
└── client/Hud.client.luau      # XP, temporizador, bajas, cartas de mejora
```

Para agregar un arma o un enemigo, añade su entrada en `Config.luau`. Si es un tipo de arma nuevo, implementa su `Kind` en `Weapons.luau`.

## Hoja de ruta

- [ ] Oro, tienda entre partidas y guardado con DataStore
- [ ] Más armas (rayo encadenado, bumerán, minas) y evoluciones de armas
- [ ] Cofres en el mapa y un minijefe a los 5 minutos
- [ ] Personajes desbloqueables con habilidades distintas
- [ ] Modelos, animaciones, efectos y sonido
- [ ] Separación entre enemigos para que no se amontonen
