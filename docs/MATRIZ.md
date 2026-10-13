# Matriz de correspondencia

Generada con `lune run tests/matrix` a partir del catálogo y del código. Versión de referencia: v1.0.69.

| Estado | Significado |
|---|---|
| Completado | Implementado y jugable con los datos de referencia de la especificación |
| Provisional | Implementado y jugable, pero con valores no documentados (editables en `src/shared`) |
| Pendiente | No implementado, o su condición no se puede cumplir todavía en el juego |
| Discrepancia | Las fuentes se contradicen; se usa un valor provisional |

En todos los casos, los modelos son reconstrucciones con primitivas: no hay mallas, rigs, animaciones, iconos ni audio originales.

## Personajes (21)

| Personaje | Arma | Pasiva | Estado | Desbloqueo | Notas |
|---|---|---|---|---|---|
| Fox | Firestaff | RNG Blessing | Completado | Inicial: Disponible desde el inicio | Pasiva y valores documentados implementados |
| Sir Oofie | Sword | Reinforced | Completado | Inicial: Disponible desde el inicio | Pasiva y valores documentados implementados |
| Calcium | Bone | Speed Demon | Provisional | Rastreado: Matar 1.000 esqueletos | aceleración, velocidad extra y curva de daño |
| Megachad | Aura | Flex | Provisional | Rastreado: Subir Damage Tome al nivel 7 | duración, enfriamiento inicial y mínimo |
| Ogre | Axe | Warrior | Completado | Rastreado: Matar 15.000 goblins | Pasiva y valores documentados implementados |
| CL4NK | Revolver | Crit Happens | Completado | Rastreado: Completar Forest Tier 1 | Pasiva y valores documentados implementados |
| Athena | Aegis | Lock in | Provisional | Rastreado: Subir Thorns Tome al nivel 9 | curva de daño por vida baja |
| Robinette | Bow | Stonks | Provisional | Rastreado: Completar Forest Tier 2 | umbrales de los tramos de oro |
| Monke | Bananarang | Monke Grip | Provisional | Pendiente (no rastreable): Encontrar la Gold Key y abrir la jaula de Forest (secreto aún no implementado) | coeficientes de movimiento |
| Tony McZoom | Wireless Dagger | Zap | Provisional | Rastreado: Completar 2 Challenges | distancia por carga, radio, daño |
| Bush | Sniper Rifle | Bullseye | Provisional | Pendiente (no rastreable): Encontrar y derrotar a Bush en Forest (encuentro aún no implementado) | frecuencia de marcado y daño de la explosión |
| Birdo | Tornado | Float | Provisional | Rastreado: En Desert, matar 100 enemigos con Tornado mientras un tornado te transporta | velocidad de planeo; coeficientes de movimiento |
| Noelle | Frostwalker | Enduring | Completado | Rastreado: Duplicar Ice Crystal 3 veces seguidas con Microwave | Pasiva y valores documentados implementados |
| Amog | Poison Flask | Plague | Provisional | Rastreado: Envenenar 50.000 enemigos con Moldy Cheese | orden de aplicación y multiplicación por tamaño |
| Spaceman | Black Hole | Quantum XP Theory | Provisional | Rastreado: Completar 6 Challenges | coeficientes de movimiento |
| Bandit | Dexecutioner | Flowstate | Completado | Pendiente (no rastreable): Encontrar y derrotar a Bandit en Desert (Desert aún no implementado) | Pasiva y valores documentados implementados |
| Ninja | Katana | Shadowstep | Provisional | Rastreado: Completar Desert Tier 1 | daño contra jefes |
| Vlad | Blood Magic | Vampire | Completado | Rastreado: Completar Desert Tier 2 | Pasiva y valores documentados implementados |
| Sir Chadwell | Corrupted Sword | Corrupted | Completado | Rastreado: Completar Forest Tier 3 | Pasiva y valores documentados implementados |
| Dicehead | Dice | Gamba | Provisional | Rastreado: Completar 100 quests | fórmula de eficiencia y tabla de estadísticas |
| Roberto | Scythe | Hoarder | Completado | Pendiente (no rastreable): Derrotar a Spooky Steve en Graveyard (Graveyard aún no implementado) | Pasiva y valores documentados implementados |

## Armas (30)

| Arma | Patrón | Estado | Desbloqueo | Notas |
|---|---|---|---|---|
| Sword | Melee | Provisional | Inicial: Disponible desde el inicio | estadísticas base provisionales |
| Flamewalker | Trail | Provisional | Inicial: Disponible desde el inicio | estadísticas base provisionales |
| Lightning Staff | Strike | Provisional | Inicial: Disponible desde el inicio | estadísticas base provisionales |
| Firestaff | Projectile | Provisional | Inicial: Disponible desde el inicio | estadísticas base provisionales |
| Chunkers | Orbit | Provisional | Inicial: Disponible desde el inicio | estadísticas base provisionales; confirmado: Count +1 inicial (Spooky Update) |
| Bone | Projectile | Provisional | Inicial: Disponible desde el inicio | estadísticas base provisionales; mejoras sin valor verificado: CritChance, CritDamage; confirmado: Knockback base 1,5 (H A T S) |
| Bow | Projectile | Provisional | Inicial: Disponible desde el inicio | estadísticas base provisionales |
| Revolver | Projectile | Provisional | Rastreado: Matar 7.500 enemigos en total | estadísticas base provisionales |
| Aegis | Aegis | Provisional | Rastreado: Mitigar 500 de daño con armadura jugando con Sir Oofie | estadísticas base provisionales |
| Bananarang | Projectile | Provisional | Pendiente (no rastreable): Encontrar el plátano oculto en Forest (secreto aún no implementado) | estadísticas base provisionales |
| Aura | Aura | Provisional | Rastreado: Pasar 2 minutos seguidos sin recibir daño | estadísticas base provisionales |
| Axe | Projectile | Provisional | Rastreado: Matar 2.000 enemigos con Sword | estadísticas base provisionales; mejoras sin valor verificado: Damage, Count, Duration, Size |
| Space Noodle | Beam | Provisional | Rastreado: Completar Desert Tier 2 con Tony McZoom | estadísticas base provisionales |
| Sniper Rifle | Projectile | Provisional | Rastreado: Subir Precision Tome al nivel 10 | estadísticas base provisionales |
| Cohete Travieso | Projectile | Provisional | Rastreado: Matar 15.000 enemigos jugando con CL4NK | estadísticas base provisionales |
| Shotgun | Projectile | Provisional | Pendiente (no rastreable): ~5% al romper un Tumbleweed de Desert Stage 2 (Desert aún no implementado) | estadísticas base provisionales; mejoras sin valor verificado: Damage, CritChance, Count, Size, CritDamage; confirmado: Knockback 3; daño crítico sustituye a retroceso (H A T S) |
| Mines | Mines | Provisional | Rastreado: Matar 7.500 enemigos con Cohete Travieso | estadísticas base provisionales |
| Wireless Dagger | Projectile | Provisional | Rastreado: Subir Lightning Staff al nivel 15 | estadísticas base provisionales |
| Frostwalker | Aura | Provisional | Rastreado: Congelar 1.000 enemigos con Ice Cube | estadísticas base provisionales |
| Tornado | Field | Provisional | Pendiente (no rastreable): Cargar 5 Charge Shrines durante tormentas de arena en Desert (Desert aún no implementado) | estadísticas base provisionales |
| Dexecutioner | Projectile | Provisional | Rastreado: Matar 12.500 enemigos con Sword | estadísticas base provisionales |
| Blood Magic | Strike | Provisional | Rastreado: Subir Bloody Tome al nivel 12 | estadísticas base provisionales |
| Black Hole | Field | Provisional | Rastreado: Subir Knockback Tome al nivel 10 | estadísticas base provisionales |
| Poison Flask | Projectile | Provisional | Pendiente (no rastreable): Derrotar 3 veces a Scorpionussy en Desert (Desert aún no implementado) | estadísticas base provisionales; confirmado: Velocidad inicial 16 (Spooky Update) |
| Katana | Melee | Provisional | Pendiente (no rastreable): ~5% al romper un Tumbleweed de Desert Stage 1 (Desert aún no implementado) | estadísticas base provisionales |
| Dragon's Breath | Cone | Provisional | Rastreado: Matar 1.000 Wisps con Fox en Desert | estadísticas base provisionales; mejoras sin valor verificado: Duration, Size; confirmado: Autoapunta, daño base 16, duración 1,5 s, mejora de daño +4 (Spooky Update) |
| Dice | Projectile | Provisional | Rastreado: Subir Luck Tome al nivel 12 | estadísticas base provisionales |
| Hero Sword | Melee | Provisional | Rastreado: Derrotar un Stage Boss sin recoger objetos ni powerups ni usar santuarios | estadísticas base provisionales |
| Corrupted Sword | Melee | Provisional | Rastreado: Subir Cursed Tome al nivel 20 antes de 10:00 | estadísticas base provisionales |
| Scythe | Melee | Provisional | Pendiente (no rastreable): Derrotar a Big Bob en Graveyard (Graveyard aún no implementado) | estadísticas base provisionales; mejoras sin valor verificado: Damage, Size |

## Tomos (23)

| Tomo | Estadística | Incremento común | Estado | Desbloqueo |
|---|---|---|---|---|
| Agility Tome | MoveSpeed | 0.15 | Completado | Inicial: Disponible desde el inicio |
| Cooldown Tome | AttackSpeed | 0.075 | Completado | Inicial: Disponible desde el inicio |
| Damage Tome | Damage | 0.08 | Completado | Inicial: Disponible desde el inicio |
| Evasion Tome | Evasion | 0.1 | Completado | Inicial: Disponible desde el inicio |
| Golden Tome | GoldGain | 0.12 | Completado | Inicial: Disponible desde el inicio |
| Health Tome | MaxHealth | 25 | Completado | Inicial: Disponible desde el inicio |
| Knockback Tome | Knockback | 0.2 | Completado | Inicial: Disponible desde el inicio |
| Precision Tome | CritChance | 0.07 | Completado | Inicial: Disponible desde el inicio |
| Projectile Speed Tome | ProjectileSpeed | 0.15 | Completado | Inicial: Disponible desde el inicio |
| Regen Tome | Regen | 40 | Completado | Inicial: Disponible desde el inicio |
| Shield Tome | Shield | 25 | Completado | Inicial: Disponible desde el inicio |
| Silver Tome | SilverGain | 0.12 | Completado | Inicial: Disponible desde el inicio |
| Size Tome | Size | 0.1 | Completado | Inicial: Disponible desde el inicio |
| Armor Tome | Armor | 0.12 | Completado | Rastreado: Matar 5.000 enemigos con Sir Oofie |
| Attraction Tome | PickupMult | 0.75 | Completado | Rastreado: Usar el Shrine of Succ 8 veces |
| Bloody Tome | BloodyHeal | 0.1 | Completado | Rastreado: Matar 12.500 enemigos en total |
| Chaos Tome | Chaos | 1 | Completado | Rastreado: Cargar todos los Charge Shrines de las 3 etapas de una partida Tier 3 sin salir de sus zonas |
| Cursed Tome | Difficulty | 0.035 | Completado | Rastreado: Derrotar un Stage Boss en menos de 5 minutos |
| Duration Tome | Duration | 0.15 | Completado | Rastreado: Subir Axe al nivel 10 |
| Luck Tome | Luck | 0.08 | Completado | Rastreado: Drop raro (0,01%) al matar enemigos |
| Quantity Tome | Quantity | 1 | Completado | Rastreado: Disparar 5.000 proyectiles en total |
| Thorns Tome | Thorns | 15 | Completado | Rastreado: Bloquear 250 ataques con Aegis |
| XP Tome | XPGain | 0.07 | Completado | Rastreado: Romper 20 vasijas en una partida |

## Objetos (85)

| Objeto | Rareza | Estado | Desbloqueo | Notas |
|---|---|---|---|---|
| Moldy Cheese | Common | Completado | Inicial: Disponible desde el inicio |  |
| Borgar | Common | Completado | Inicial: Disponible desde el inicio |  |
| Wrench | Common | Completado | Inicial: Disponible desde el inicio |  |
| Clover | Common | Completado | Inicial: Disponible desde el inicio |  |
| Time Bracelet | Common | Completado | Inicial: Disponible desde el inicio |  |
| Slippery Ring | Common | Completado | Inicial: Disponible desde el inicio |  |
| Golden Glove | Common | Completado | Inicial: Disponible desde el inicio |  |
| Gym Sauce | Common | Completado | Inicial: Disponible desde el inicio |  |
| Oats | Common | Completado | Inicial: Disponible desde el inicio |  |
| Medkit | Common | Completado | Inicial: Disponible desde el inicio |  |
| Turbo Socks | Common | Completado | Rastreado: Subir Agility Tome al nivel 5 |  |
| Tactical Glasses | Common | Discrepancia | Rastreado: Derrotar un minijefe en 25 s | Límite exacto del 90% (>= o >) |
| Battery | Common | Completado | Rastreado: Subir Cooldown Tome al nivel 5 |  |
| Forbidden Juice | Common | Completado | Rastreado: Realizar 100 críticos |  |
| Cursed Doll | Common | Provisional | Rastreado: Morir 10 veces | duración de la maldición |
| Boss Buster | Common | Completado | Rastreado: Derrotar un jefe de fase en menos de 30 s |  |
| Key | Common | Completado | Rastreado: Comprar 25 cofres |  |
| Ice Crystal | Common | Discrepancia | Rastreado: Obtener 50 bajas con Frostwalker | Probabilidad (7,5% vs ~9,09%) y duración |
| Skuleg | Common | Completado | Rastreado: Alcanzar 40% de dificultad |  |
| Ghost | Common | Provisional | Rastreado: Sobrevivir 60 s al Final Swarm | daño de los fantasmas |
| Cactus | Common | Provisional | Pendiente (no rastreable): Matar 100 cactus con espinas (Desert aún no implementado) | daño de las púas |
| Old Mask | Common | Completado | Pendiente (no rastreable): Encontrarlo en Graveyard (Graveyard aún no implementado) |  |
| Credit Card (Red) | Rare | Completado | Inicial: Disponible desde el inicio |  |
| Golden Shield | Rare | Provisional | Inicial: Disponible desde el inicio | oro por golpe |
| Thunder Mitts | Rare | Provisional | Inicial: Disponible desde el inicio | daño del rayo |
| Feathers | Rare | Provisional | Inicial: Disponible desde el inicio | conversión de altura de salto |
| Electric Plug | Rare | Provisional | Inicial: Disponible desde el inicio | daño de la descarga |
| Coward's Cloak | Rare | Provisional | Inicial: Disponible desde el inicio | acumulaciones temporales |
| Unstable Transfusion | Rare | Completado | Inicial: Disponible desde el inicio |  |
| Beer | Rare | Completado | Inicial: Disponible desde el inicio |  |
| Beacon | Rare | Provisional | Inicial: Disponible desde el inicio | radio y duración de la zona |
| Backpack | Rare | Completado | Inicial: Disponible desde el inicio |  |
| Phantom Shroud | Rare | Discrepancia | Inicial: Disponible desde el inicio | Multiplicador ×2 (descripción) vs ×3 (análisis) |
| Campfire | Rare | Completado | Inicial: Disponible desde el inicio |  |
| Brass Knuckles | Rare | Completado | Rastreado: Matar 5.000 enemigos con Sword |  |
| Demonic Blade | Rare | Completado | Rastreado: Curar 350 de vida con robo de vida |  |
| Demonic Blood | Rare | Completado | Rastreado: Aumentar la vida máxima 400 veces con Blood Magic |  |
| Echo Shard | Rare | Completado | Rastreado: Subir XP Tome al nivel 8 |  |
| Moldy Gloves | Rare | Provisional | Rastreado: Duplicar Moldy Cheese 3 veces seguidas en un Microwave | daño de la explosión |
| Golden Sneakers | Rare | Completado | Rastreado: Romper 150 vasijas |  |
| Idle Juice | Rare | Completado | Rastreado: Matar 500 enemigos sin moverse |  |
| Leeching Crystal | Rare | Discrepancia | Rastreado: Subir Regen Tome al nivel 8 | Apilado de regeneración (−50% lineal vs ×0,5) |
| Pumpkin | Rare | Provisional | Pendiente (no rastreable): Con Roberto, romper todas las calabazas de Graveyard (no implementado) | vasijas por copia (8 grandes + 2 pequeñas) |
| Beefy Ring | Epic | Completado | Inicial: Disponible desde el inicio |  |
| Credit Card (Green) | Epic | Completado | Inicial: Disponible desde el inicio |  |
| Spiky Shield | Epic | Completado | Inicial: Disponible desde el inicio |  |
| Scarf | Epic | Completado | Inicial: Disponible desde el inicio |  |
| Slurp Gloves | Epic | Completado | Inicial: Disponible desde el inicio |  |
| Mirror | Epic | Provisional | Inicial: Disponible desde el inicio | daño reflejado |
| Turbo Skates | Epic | Completado | Rastreado: Subir Cooldown Tome y Agility Tome a nivel 5 en una partida |  |
| Cañón Travieso | Epic | Completado | Rastreado: Matar 5.000 enemigos con Cohete Travieso |  |
| Shattered Knowledge | Epic | Provisional | Rastreado: Subir Attraction Tome al nivel 8 | daño de los fragmentos |
| Quin's Mask | Epic | Provisional | Rastreado: Con Athena, rematar un jefe de fase con Aegis | radio de la explosión |
| Toxic Barrel | Epic | Completado | Rastreado: Matar 2.000 enemigos con veneno |  |
| Gas Mask | Epic | Provisional | Rastreado: Matar 5.000 enemigos con Amog | coeficientes por envenenado |
| Gamer Goggles | Epic | Completado | Rastreado: Derrotar un jefe de fase con menos del 10% de vida |  |
| Eagle Claw | Epic | Completado | Rastreado: Matar 10.000 enemigos con Birdo |  |
| Demonic Soul | Epic | Completado | Rastreado: Alcanzar nivel 30 con Calcium |  |
| Bob (Dead) | Epic | Provisional | Rastreado: Sobrevivir 2 min al Final Swarm | daño de Bob |
| Grandma's Secret Tonic | Epic | Provisional | Rastreado: Matar 3.000 enemigos con Sniper Rifle | radio |
| Cursed Grabbies | Epic | Provisional | Rastreado: Subir Cursed Tome al nivel 10 | daño de la explosión |
| Kevin | Epic | Provisional | Rastreado: Obtener tres Leeching Crystal en una partida | daño propio |
| Bob's Light | Epic | Completado | Pendiente (no rastreable): Matar a Big Bob con una lámpara (Graveyard aún no implementado) |  |
| Overpowered Lamp | Legendary | Completado | Inicial: Disponible desde el inicio |  |
| Za Warudo | Legendary | Provisional | Inicial: Disponible desde el inicio | vida restaurada |
| Big Bonk | Legendary | Provisional | Inicial: Disponible desde el inicio | crecimiento de potencia y radio |
| Spicy Meatball | Legendary | Provisional | Inicial: Disponible desde el inicio | radio |
| Ice Cube | Legendary | Provisional | Inicial: Disponible desde el inicio | daño de hielo |
| Giant Fork | Legendary | Completado | Inicial: Disponible desde el inicio |  |
| Power Gloves | Legendary | Provisional | Inicial: Disponible desde el inicio | daño, radio y enfriamiento |
| Lightning Orb | Legendary | Provisional | Rastreado: Matar 3.000 enemigos con daño eléctrico | daño y encadenamiento |
| Chonkplate | Legendary | Completado | Rastreado: Alcanzar 500 de vida máxima |  |
| Dragonfire | Legendary | Provisional | Rastreado: Matar 4.000 enemigos con fuego | daño del área y de la quemadura |
| Sucky Magnet | Legendary | Completado | Rastreado: Completar todos los Charge Shrines de un mapa |  |
| Holy Book | Legendary | Provisional | Rastreado: Matar al primer jefe de fase sin recibir daño en la partida | conversión de curación en daño |
| Speed Boi | Legendary | Completado | Rastreado: Completar una fase con al menos 2 Boss Curse |  |
| Energy Core | Legendary | Provisional | Rastreado: Derrotar dos veces a un jefe final | daño e intervalo |
| Anvil | Legendary | Completado | Rastreado: Completar 3 Challenges |  |
| Soul Harvester | Legendary | Provisional | Rastreado: Sobrevivir 6 min al Final Swarm | daño de las almas |
| Joe's Dagger | Legendary | Completado | Rastreado: Matar 10.000 enemigos con Dexecutioner |  |
| Bloody Cleaver | Legendary | Completado | Rastreado: Alcanzar nivel 50 con Vlad |  |
| Golden Ring | Legendary | Provisional | Inicial: Disponible desde el inicio | Golden Microwave no implementado |
| Snek | Legendary | Provisional | Pendiente (no rastreable): Encontrarlo en la cripta de Graveyard (no implementado) | componente adicional de la detonación |
| Pot (Stainless Steel) | Legendary | Completado | Pendiente (no rastreable): Abrir todo en la primera cripta de Graveyard (no implementado) |  |
| Wizard's Hat | Legendary | Completado | Rastreado: Con Vlad, subir un arma por encima del nivel 40 con Pot |  |

## Mapas

| Mapa | Estado | Notas |
|---|---|---|
| Forest | Provisional | Bosque verde con árboles, rocas, desniveles y ruinas. |
| Desert | Provisional | Arena, roca, cactus y tormentas. (Tormentas, tornados ambientales y secretos pendientes.) |
| Graveyard | Pendiente | Cementerio y criptas con guardianes, llaves y lava. (Recorrido pendiente de implementar.) |

## Enemigos y jefes

Todos **Provisional**: el bestiario completo, sus estadísticas y los patrones de cada jefe no están documentados. Los jefes usan una máquina de estados genérica (golpe en área telegrafiado, anillo de proyectiles, embestida, invocación) con fases al 66% y 33% de vida.

| Enemigo | IA | Tipo |
|---|---|---|
| Anubis | Boss | Jefe |
| Anubruh | Boss | Jefe |
| Bark Vader | Boss | Jefe |
| Jabalí | Charge | Normal |
| Bola de huesos | Charge | Normal |
| Cactus | Ranged | Normal |
| Chadbark | Boss | Jefe |
| Chunkham The Terrible | Boss | Minijefe |
| Wisp | Float | Normal |
| Goblin | Chase | Normal |
| Chamán goblin | Ranged | Normal |
| Juge Anubis | Boss | Jefe |
| Lil Bark | Boss | Jefe |
| Sand Golem | Boss | Minijefe |
| Escorpión | Chase | Normal |
| Escorpionaza | Boss | Minijefe |
| Esqueleto | Chase | Normal |
| Stone Golem | Boss | Minijefe |
| Fantasma | Float | Normal |
| Wisp | Float | Normal |

Pendientes: Graveyard (Calcium's Dad, Ghostham the Dead, Jeff, Mike, Ted, Gary, Spooky Steve, Big Bob), Bush y Bandit como encuentros secretos, y la retirada de armas en los combates finales de Tier 3.

## Cosméticos

Sombreros (22) y skins documentadas (20) registrados como datos con sus condiciones. **Pendiente**: modelos, equipamiento, compra con plata, skins fantasmales de la cripta y la skin de Megachad de H A T S.

## Resumen

| Grupo | Completado | Provisional | Discrepancia | Pendiente |
|---|---|---|---|---|
| Personajes | 9 | 12 | 0 | 0 |
| Armas | 0 | 30 | 0 | 0 |
| Tomos | 23 | 0 | 0 | 0 |
| Objetos | 50 | 31 | 4 | 0 |
| Mapas | 0 | 2 | 0 | 1 |
