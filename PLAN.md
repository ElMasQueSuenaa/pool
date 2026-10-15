# Pool Elemental: plan de trabajo

Juego de pool (8-ball) en 2D cenital para el navegador (PC y móvil), con los cuatro elementos de *Avatar: The Last Airbender* como poderes.
**Se publica en GitHub Pages** (`https://elmasquesuenaa.github.io/pool/`), así que el repo y la versión web son públicos: solo llevan arte propio o CC0. El fan art de Avatar se queda en `assets/ip/` (git lo ignora) y solo se ve al jugar en local con F5.

**Stack:** Godot 4.x (estable más reciente, ≥ 4.3) · GDScript · renderer *Compatibility* · Fedora Linux → Web (GitHub Pages, exportado por GitHub Actions).

**Regla de oro del consejo:** primero que el billar sea divertido con círculos grises. Los poderes y la temática van después.

---

## Estructura del proyecto

Las carpetas se crean a medida que hagan falta, no antes.

```
pool/
├─ project.godot
├─ export_presets.cfg            preset Web
├─ .github/workflows/pages.yml   exporta y publica en cada push a main
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

Cada push a `main` dispara `.github/workflows/pages.yml`: descarga Godot y las plantillas oficiales, exporta el preset **Web** y lo publica en GitHub Pages. En local no hacen falta plantillas de exportación: se juega con F5.

- [x] Instalar Godot (versión estándar, no .NET): `sudo dnf install godot`.
- [x] Crear el proyecto en la raíz del repo con renderer **Compatibility**.
- [x] **Project Settings:** `stretch/mode` = `canvas_items`, `aspect` = `keep`, `physics_ticks_per_second` = `120` y `2d/default_gravity` = `0`. La orientación no aplica en el navegador: se gira el móvil.
- [x] Preset de exportación **Web** sin hilos (`variant/thread_support = false`), porque GitHub Pages no envía las cabeceras COOP/COEP que necesitan los hilos.
- [x] `scenes/main.tscn`: un `Label` "hola" como escena principal.
- [ ] Hacer público el repo (GitHub Pages gratis solo publica repos públicos).
- [ ] En GitHub, **Settings → Pages → Source** = **GitHub Actions**.
- [ ] Lanzar el workflow: push a `main` o **Actions → Publicar en GitHub Pages → Run workflow**.

**Hecho cuando:** la escena "hola" se abre en el navegador del móvil en `https://elmasquesuenaa.github.io/pool/`.

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

**Prueba sí/no** (en el navegador del móvil desde GitHub Pages, no solo en el PC):

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

- [ ] Placeholders CC0 primero (Kenney: kenney.nl). El fan art y los assets de la serie van **solo** a `assets/ip/`, que git ignora. Así ni el repo ni la versión web llevan nada con copyright.
- [ ] Selector de nación al empezar: Agua, Tierra, Fuego y Aire, con color. Los retratos y nombres de personajes (Katara, Toph, Zuko, Aang) se cargan solo si existen en `assets/ip/`, así que solo salen en local.
- [ ] Mesa y fondo con el estilo de la nación (paño, marco).
- [ ] Efectos de cada poder con `CPUParticles2D` (compatible con el renderer Compatibility): estela de agua, polvo de tierra, chispas de fuego, ráfaga de aire.
- [ ] Sonidos con `AudioStreamPlayer2D`: choque, banda, tronera y uno por poder.
- [ ] Vibración al embocar con `Input.vibrate_handheld(30)`. En el navegador funciona en Android; en iPhone no hace nada.

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

Online, APK y Play Store, anuncios y compras, roguelike o colección, y 3D. La temática Avatar solo existe en local; la versión publicada usa arte propio o CC0. El código es el mismo, porque el arte está separado de la lógica.

## Riesgos y respuesta

| Riesgo | Respuesta |
|---|---|
| Bolas que se atraviesan o un saque inestable | CCD + 120 ticks. Si no basta, Plan B con física propia (Fase 1) |
| La física va lenta en el navegador del móvil (la exportación web va en un solo hilo) | Probar la Fase 1 en el móvil desde GitHub Pages. Si no da, bajar a 60 ticks o pasar al Plan B |
| Bolas que nunca se paran | Umbral de parada en `_integrate_forces` |
| Poderes que rompen el billar | Cargas limitadas y 5 partidas de prueba por elemento |
| Apuntar con el dedo es impreciso | Tirachinas + ajuste fino (Fase 6) |
| El proyecto crece sin control | Lista de fuera de alcance; no se empieza una fase sin cerrar la anterior |
