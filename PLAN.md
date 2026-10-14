# Pool Elemental: plan de trabajo

Juego de pool (8-ball) en 2D cenital para Android, con los cuatro elementos de *Avatar: The Last Airbender* como poderes.
**Proyecto personal: no se publica.** El APK se queda en tus dispositivos (si se lo pasas a otros, eso ya cuenta como distribuirlo).

**Stack:** Godot 4.x (estable más reciente, ≥ 4.3) · GDScript · renderer *Compatibility* · Windows → Android por USB.

**Regla de oro del consejo:** primero que el billar sea divertido con círculos grises. Los poderes y la temática van después.

---

## Estructura del proyecto

Las carpetas se crean a medida que hagan falta, no antes.

```
pool/
├─ project.godot
├─ PLAN.md
├─ scenes/      main.tscn, table.tscn, ball.tscn
├─ scripts/     ball.gd, table.gd, cue.gd, rules.gd, powers.gd, ai.gd
├─ tests/       test_rules.gd
└─ assets/
   ├─ placeholder/   arte y sonidos CC0 (Kenney, freesound CC0)
   └─ ip/            fan art de Avatar: solo local, git lo ignora
```

**Capas de colisión:** 1 = bolas, 2 = bandas, 3 = troneras.

---

## Fase 0: Entorno (medio día)

- [ ] Instalar Godot 4.x estable (versión estándar, no .NET).
- [ ] Instalar JDK 17 y el Android SDK (con Android Studio o con las *command-line tools*: `platform-tools`, `build-tools` y `platforms` en las versiones que pide la doc de Godot para tu versión).
- [ ] En Godot, ir a **Editor → Manage Export Templates → Download**.
- [ ] En **Editor Settings → Export → Android**, poner las rutas de *Java SDK Path* y *Android SDK Path*. El keystore de debug lo genera Godot.
- [ ] En el móvil, activar Opciones de desarrollador → Depuración USB.
- [ ] Crear el proyecto en `D:\pool` con renderer **Compatibility** y *Version Control Metadata* en **None** (el repo ya tiene `.gitignore`).
- [ ] En **Project Settings**:
  - `display/window/handheld/orientation` = `landscape`
  - `display/window/stretch/mode` = `canvas_items` y `aspect` = `keep`
  - `physics/common/physics_ticks_per_second` = `120`
  - `physics/2d/default_gravity` = `0`
- [ ] Añadir el preset de exportación Android y probar con una escena vacía usando el botón *Remote Deploy* (arriba a la derecha).

**Hecho cuando:** una escena con un `Label` "hola" se abre en tu móvil con un clic.

---

## Fase 1: Mesa y física (spike con decisión sí/no)

El mayor riesgo técnico es si la física 2D de Godot aguanta un billar. Esta fase sirve para averiguarlo **antes** de invertir en lo demás.

- [ ] `ball.tscn`: un `RigidBody2D` con `CircleShape2D` y un sprite de círculo de color. Propiedades:
  - `continuous_cd = CCD_MODE_CAST_SHAPE` (evita que las bolas rápidas atraviesen cosas)
  - `lock_rotation = true` y `gravity_scale = 0`
  - `physics_material_override`: `bounce ≈ 0.95`, `friction = 0`
  - `linear_damp ≈ 1.0` (ajustar a mano)
  - `contact_monitor = true` y `max_contacts_reported = 4` (para saber a qué bola se golpeó primero)
- [ ] Umbral de parada: en `_integrate_forces`, si `state.linear_velocity.length() < 5`, poner la velocidad a cero. Sin esto las bolas se arrastran eternamente.
- [ ] `table.tscn`: bandas como `StaticBody2D` (segmentos o polígonos) con `bounce ≈ 0.75`, y 6 troneras como `Area2D` con un círculo pequeño en la boca.
- [ ] Al entrar una bola en una tronera (`body_entered`), se registra en el tiro actual y se oculta y congela (`freeze = true`).
- [ ] Rack inicial: triángulo de 15 bolas y bola blanca en la línea de salida.
- [ ] `cue.gd`, el tiro: arrastrar desde la blanca hacia atrás (tirachinas). La dirección es la opuesta al arrastre y la fuerza va con la distancia (con tope). Al soltar, `apply_central_impulse(dir * fuerza)`.
  Usar solo eventos de ratón: Godot convierte el toque en ratón por defecto, así que funciona igual en PC y en el móvil.
- [ ] Detectar "mesa en reposo": todas las bolas con velocidad 0 ⇒ fin del tiro.

**Prueba sí/no** (en el móvil, no solo en el PC):

- [ ] 20 saques a fuerza máxima: ninguna bola atraviesa bandas ni otras bolas.
- [ ] La mesa queda en reposo en menos de unos 8 s.
- [ ] Tiros suaves: las bolas ruedan de forma natural y no se quedan "pegadas".

**Si falla → Plan B, física propia** (unas 150 líneas, en `table.gd`):
- `_physics_process` con 4–8 subpasos.
- Arrays de posición y velocidad, con fricción como deceleración constante.
- Choque bola-bola elástico: con masas iguales, se intercambian las componentes normales de la velocidad.
- Bandas como segmentos: se refleja la velocidad y se multiplica por la restitución.
- Troneras como chequeo de distancia.

Con física propia, los poderes de la Fase 3 son simples modificaciones a ese bucle. Todo lo demás del plan sigue igual.

**Hecho cuando:** pasa la prueba sí/no, ya sea con física de Godot o con la propia.

---

## Fase 2: Reglas de 8-ball y dos jugadores en el mismo móvil

- [ ] `rules.gd` es **lógica pura**: `class_name Rules`, `extends RefCounted`, sin nodos, para poder testearla sin abrir el juego.
  - **Entrada:** el estado de la partida (turno, grupo de cada jugador, bolas restantes) y el resultado del tiro (`first_hit`, `pocketed: Array[int]`, `scratch: bool`).
  - **Salida:** si hubo falta, si se mantiene el turno, los grupos asignados y el ganador.
- [ ] Reglas (simplificadas a propósito):
  - Mesa abierta hasta la primera bola embocada legalmente después del saque; ese jugador se queda con lisas o rayadas.
  - Sigues tirando si embocas una bola tuya sin cometer falta.
  - Falta: blanca embocada, no tocar ninguna bola, o tocar primero una bola que no es tuya (en mesa abierta, tocar la 8 primero). Con falta, el rival tiene **bola en mano**.
  - La 8: si la embocas después de limpiar tu grupo, ganas. Si la embocas antes, o con la blanca dentro en ese tiro, pierdes. Si entra en el saque, se vuelve a colocar el rack.
  - *Fuera:* cantar tronera, banda tras contacto, regla de 4 bandas en el saque y regla de 3 faltas.
- [ ] Máquina de estados en `table.gd`: `APUNTANDO → RODANDO → RESOLVIENDO → (BOLA_EN_MANO | APUNTANDO)`.
- [ ] Bola en mano: arrastrar la blanca y validar que no se solapa con nada usando `PhysicsDirectSpaceState2D.intersect_shape`.
- [ ] HUD mínimo con `Label`: de quién es el turno, su grupo y los mensajes de falta o victoria.
- [ ] `tests/test_rules.gd` (`extends SceneTree`) cubre los casos: saque sin bolas, asignación de grupo, falta por blanca, falta por primer contacto, 8 temprana = derrota y 8 final = victoria. Termina con `quit(fallos)`.
  ```bash
  godot --headless -s tests/test_rules.gd
  ```

**Hecho cuando:** dos personas juegan una partida completa en tu móvil y el test de reglas pasa.

---

## Fase 3: Mecánica elemental (lo que diferencia al juego)

Cada jugador elige una nación al empezar. Su poder tiene **1 carga** y se recarga cada **3 turnos propios** (constante ajustable). Antes de tirar se pulsa el botón ⚡ y el poder afecta a la blanca en ese tiro. Al quedar la mesa en reposo, todo vuelve a la normalidad.

Todo vive en `powers.gd`, un `match` por elemento, separado del arte.

| Elemento | Efecto | Implementación |
|---|---|---|
| 🪨 **Tierra** | Blanca pesada que atraviesa racimos y casi no se desvía | `mass = 3` durante el tiro; el impulso se multiplica por la masa para que salga a la misma velocidad |
| 💧 **Agua** | La blanca hace curva | El jugador elige el lado con un toggle; se aplica `constant_force` perpendicular a la dirección durante unos 0.5 s y luego se pone a `Vector2.ZERO` |
| 🔥 **Fuego** | Explosión al primer impacto | En el primer `body_entered` de la blanca con una bola, impulso extra a esa bola en la dirección blanca → bola (×1.5) |
| 🌪️ **Aire** | La blanca salta por encima de bolas | Se quita la capa 1 del `collision_mask` durante unos 0.35 s; se vuelve a activar solo cuando no se solapa con ninguna bola (`intersect_shape`) |

- [ ] Implementar **uno a uno**, en este orden: Tierra (una línea) → Fuego → Agua → Aire.
- [ ] Después de cada elemento, jugar 5 partidas. Si el poder decide la mayoría de las partidas, o solo mete ruido, ajustar o recortar. **El pool tiene que seguir siendo pool.**
- [ ] HUD: nación de cada jugador y estado de la carga.

**Hecho cuando:** los cuatro poderes funcionan y una partida con poderes sigue sintiéndose como billar.

---

## Fase 4: Temática Avatar (solo uso personal)

- [ ] Placeholders CC0 primero (Kenney: kenney.nl). El fan art y los assets de la serie van **solo** a `assets/ip/`, que git ignora. Así, aunque el repo acabe en GitHub, no se sube nada con copyright.
- [ ] Selector de nación al empezar: Agua (Katara), Tierra (Toph), Fuego (Zuko), Aire (Aang), con retrato y color.
- [ ] Mesa y fondo con el estilo de la nación (paño, marco).
- [ ] Efectos de cada poder con `CPUParticles2D` (compatible con el renderer Compatibility): estela de agua, polvo de tierra, chispas de fuego, ráfaga de aire.
- [ ] Sonidos con `AudioStreamPlayer2D`: choque, banda, tronera y uno por poder.
- [ ] Vibración al embocar con `Input.vibrate_handheld(30)`; requiere el permiso `VIBRATE` en el preset de exportación.

**Hecho cuando:** la partida se ve y suena como un duelo entre naciones.

---

## Fase 5: Rival IA (opcional)

Usa el método de la "bola fantasma", en `ai.gd`:

- [ ] Para cada bola del grupo de la IA y cada tronera:
  - Bola fantasma = `pos_bola - dir_a_tronera * 2r`.
  - Comprobar que el camino blanca → fantasma y el camino bola → tronera están libres (`ShapeCast2D` o `intersect_shape`).
  - Puntuar según el ángulo de corte (cuanto más recto, mejor) y la distancia.
- [ ] Elegir el mejor tiro, con fuerza proporcional a la distancia. La dificultad se regula con ruido en el ángulo (±N°).
- [ ] Si no hay tiro limpio, darle suave a la bola propia más cercana.
- [ ] Poder: si está cargado y no hay tiro limpio, usarlo (Aire o Tierra encajan con tiros bloqueados).
- [ ] Menú: 2 jugadores / contra IA.

---

## Fase 6: Pulido

- [ ] Línea de guía: un `ShapeCast2D` desde la blanca dibuja la bola fantasma donde impactaría.
- [ ] Menú principal, pausa y reiniciar.
- [ ] Ajuste fino del apuntado: una zona lateral para girar el ángulo en pasos pequeños.
- [ ] *(Opcional)* Efecto (*english*): retroceso o seguimiento aplicando una fuerza a la blanca tras su primer contacto.

---

## Fuera de alcance

Online, publicación en Play Store, anuncios y compras, roguelike o colección, y 3D. Si algún día quieres publicar, se cambia la temática Avatar por un mundo propio. El código no cambia, porque el arte está separado de la lógica.

## Riesgos y respuesta

| Riesgo | Respuesta |
|---|---|
| Bolas que se atraviesan o un saque inestable | CCD + 120 ticks. Si no basta, Plan B con física propia (Fase 1) |
| Bolas que nunca se paran | Umbral de parada en `_integrate_forces` |
| Poderes que rompen el billar | Cargas limitadas y 5 partidas de prueba por elemento |
| Apuntar con el dedo es impreciso | Tirachinas + ajuste fino (Fase 6) |
| El proyecto crece sin control | Lista de fuera de alcance; no se empieza una fase sin cerrar la anterior |
