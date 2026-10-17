class_name Table
extends Node2D

## Mesa: bandas, troneras, rack, turnos, bola en mano y poderes.
## Estados: CHOOSING (cada jugador elige nación) → AIMING → ROLLING → (al quedar en reposo se
## aplican las reglas) → BALL_IN_HAND | AIMING | OVER
## El paño va de (0, 0) a (W, H); las bandas quedan fuera y dejan huecos en las troneras.

const W := 1000.0
const H := 500.0
const RAIL := 30.0
const CORNER_GAP := 40.0  # boca de las troneras de esquina, medida sobre cada banda
const SIDE_GAP := 24.0  # media boca de las troneras del medio
# Godot suma el bounce de los dos cuerpos: 0.475 (bola) + 0.275 = 0.75 contra la banda
const RAIL_BOUNCE := 0.275
const RAILS := [
	Rect2(CORNER_GAP, -RAIL, W / 2 - SIDE_GAP - CORNER_GAP, RAIL),
	Rect2(W / 2 + SIDE_GAP, -RAIL, W / 2 - SIDE_GAP - CORNER_GAP, RAIL),
	Rect2(CORNER_GAP, H, W / 2 - SIDE_GAP - CORNER_GAP, RAIL),
	Rect2(W / 2 + SIDE_GAP, H, W / 2 - SIDE_GAP - CORNER_GAP, RAIL),
	Rect2(-RAIL, CORNER_GAP, RAIL, H - 2 * CORNER_GAP),
	Rect2(W, CORNER_GAP, RAIL, H - 2 * CORNER_GAP),
]
const POCKETS := [Vector2(0, 0), Vector2(W / 2, 0), Vector2(W, 0), Vector2(0, H), Vector2(W / 2, H), Vector2(W, H)]
const HEAD_SPOT := Vector2(W * 0.25, H / 2)
const FOOT_SPOT := Vector2(W * 0.75, H / 2)
# La 8 en el centro y una lisa y una rayada en las esquinas de atrás
const RACK_ORDER := [1, 9, 2, 10, 8, 3, 11, 4, 12, 5, 6, 13, 7, 14, 15]
const GROUP_NAMES := ["mesa abierta", "lisas", "rayadas"]
# Solo dibujo: la goma de las bandas va pegada al paño y el resto, hasta FRAME, es madera
const FRAME := 38.0
const CUSHION := 14.0
const FELT := Color("1d7a48")
const CUSHION_COLOR := Color("16643a")
const WOOD := Color("6b3b1c")
const FLOOR := Color("121315")  # igual que el color de fondo de project.godot

enum State { CHOOSING, AIMING, ROLLING, BALL_IN_HAND, OVER }

var balls: Array[Ball] = []  # balls[n] es la bola número n
var cue_ball: Ball
var rules := Rules.new()
var powers := Powers.new()
var state := State.AIMING
var pocketed: Array[int] = []
var first_hit := -1
var shot_time := 0.0
# Degradados del dibujo de la mesa. Tienen que seguir vivos mientras se usen en _draw.
var _lamp := _radial([Color("2c2822"), FLOOR])
var _felt_shade := _radial([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.28)], [0, 0.55, 1])


func _ready() -> void:
	var rails := StaticBody2D.new()
	rails.collision_layer = 2
	rails.collision_mask = 0
	rails.physics_material_override = PhysicsMaterial.new()
	rails.physics_material_override.bounce = RAIL_BOUNCE
	rails.physics_material_override.friction = 0
	for r: Rect2 in RAILS:
		var s := CollisionShape2D.new()
		s.shape = RectangleShape2D.new()
		s.shape.size = r.size
		s.position = r.get_center()
		rails.add_child(s)
	add_child(rails)

	for n in 16:
		var b: Ball = preload("res://scenes/ball.tscn").instantiate()
		b.number = n
		add_child(b)
		balls.append(b)
	cue_ball = balls[0]
	cue_ball.body_entered.connect(_on_cue_ball_hit)
	$HUD/Reiniciar.pressed.connect(new_game)
	$HUD/Poder.pressed.connect(_on_power_pressed)
	$HUD/Naciones.chosen.connect(_on_nations_chosen)
	new_game()


## Solo se dibuja una vez. La luz viene de una lámpara arriba a la izquierda, como en las bolas.
func _draw() -> void:
	# Suelo con la luz de la lámpara, y la mesa con su sombra
	draw_texture_rect(_lamp, Rect2(W / 2 - 800, H / 2 - 520, 1600, 1040), false)
	var wood := StyleBoxFlat.new()
	wood.bg_color = WOOD
	wood.set_corner_radius_all(18)
	wood.set_border_width_all(2)
	wood.border_color = WOOD.darkened(0.45)
	wood.shadow_color = Color(0, 0, 0, 0.55)
	wood.shadow_size = 22
	wood.shadow_offset = Vector2(6, 10)
	wood.draw(get_canvas_item(), Rect2(-FRAME, -FRAME, W + 2 * FRAME, H + 2 * FRAME))
	_draw_grain()

	draw_rect(Rect2(0, 0, W, H), FELT)
	draw_texture_rect(_felt_shade, Rect2(0, 0, W, H), false)
	# Línea de salida y los puntos de la blanca y del rack
	draw_line(Vector2(HEAD_SPOT.x, 0), Vector2(HEAD_SPOT.x, H), Color(1, 1, 1, 0.12), 2)
	for p in [HEAD_SPOT, FOOT_SPOT]:
		draw_circle(p, 3, Color(1, 1, 1, 0.3), true, -1, true)

	# El morro de la goma es el borde del rectángulo de colisión, así que choca donde se ve.
	# Por detrás se alarga hacia la tronera (la boca se estrecha, como en una mesa de verdad).
	# Esa parte no choca, pero una bola visible tiene el centro en el paño y apenas la pisa.
	for r: Rect2 in RAILS:
		var out := Vector2(0, -1) if r.end.y <= 0 else Vector2(0, 1) if r.position.y >= H else Vector2(-1, 0) if r.end.x <= 0 else Vector2(1, 0)
		var along := Vector2(absf(out.y), absf(out.x))
		var half: float = r.size.dot(along) / 2
		var a := r.get_center() - out * RAIL / 2 - along * half  # los dos extremos del morro
		var b := a + along * half * 2
		for i in 5:  # sombra de la banda sobre el paño
			draw_line(a - out * (i + 0.5), b - out * (i + 0.5), Color(0, 0, 0, 0.07 * (5 - i)), 1)
		draw_colored_polygon([a, b, b + out * CUSHION + along * 10, a + out * CUSHION - along * 10], CUSHION_COLOR)
		draw_line(a + out, b + out, CUSHION_COLOR.lightened(0.15), 2)
	draw_rect(Rect2(-CUSHION, -CUSHION, W + 2 * CUSHION, H + 2 * CUSHION), WOOD.darkened(0.5), false, 2)

	# Rombos de nácar: dividen cada banda larga en 8 y cada corta en 4
	var mid := (FRAME + CUSHION) / 2
	var diamond := PackedVector2Array([Vector2(0, -4), Vector2(3, 0), Vector2(0, 4), Vector2(-3, 0)])
	for k in [1, 2, 3, 5, 6, 7]:
		for y in [-mid, H + mid]:
			draw_set_transform(Vector2(W * k / 8, y))
			draw_colored_polygon(diamond, Color("efe6cf"))
	for k in [1, 2, 3]:
		for x in [-mid, W + mid]:
			draw_set_transform(Vector2(x, H * k / 4))
			draw_colored_polygon(diamond, Color("efe6cf"))
	draw_set_transform(Vector2.ZERO)

	# Troneras: aro de cuero y agujero, más oscuro hacia dentro. Las del medio, algo hacia fuera.
	for p: Vector2 in POCKETS:
		var r := CORNER_GAP * 0.8 if p.x != W / 2 else SIDE_GAP
		var c := p if p.x != W / 2 else p + Vector2(0, -6 if p.y == 0 else 6)
		draw_circle(c, r + 5, Color("24170f"), true, -1, true)
		for i in 4:
			draw_circle(c, r - i * 2, Color("2b2b2b").darkened(0.33 * i), true, -1, true)


## Vetas de la madera, siempre las mismas (semilla fija)
func _draw_grain() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var grain := Color(WOOD.darkened(0.35), 0.5)
	var strips := [
		Rect2(-FRAME + 18, -FRAME, W + 2 * FRAME - 36, FRAME - CUSHION),
		Rect2(-FRAME + 18, H + CUSHION, W + 2 * FRAME - 36, FRAME - CUSHION),
		Rect2(-FRAME, -CUSHION, FRAME - CUSHION, H + 2 * CUSHION),
		Rect2(W + CUSHION, -CUSHION, FRAME - CUSHION, H + 2 * CUSHION),
	]
	for s: Rect2 in strips:
		var horizontal := s.size.x > s.size.y
		var length := s.size.x if horizontal else s.size.y
		var width := s.size.y if horizontal else s.size.x
		for line in 6:
			var across := rng.randf_range(3, width - 3)
			var phase := rng.randf() * TAU
			var points := PackedVector2Array()
			for i in 25:
				var t := length * i / 24.0
				var wave := clampf(across + sin(t / 60 + phase) * 2.5, 1, width - 1)
				points.append(s.position + (Vector2(t, wave) if horizontal else Vector2(wave, t)))
			draw_polyline(points, grain, 1, true)


static func _radial(colors: Array, offsets: Array = [0, 1]) -> GradientTexture2D:
	var t := GradientTexture2D.new()
	t.width = 256
	t.height = 256
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1, 0.5)
	t.gradient = Gradient.new()
	t.gradient.offsets = PackedFloat32Array(offsets)
	t.gradient.colors = PackedColorArray(colors)
	return t


func _physics_process(delta: float) -> void:
	if state != State.ROLLING:
		return
	shot_time += delta
	# Las bandas solo dejan salir del paño por los huecos: si el centro sale, la bola entró
	for b in balls:
		if b.visible and not Rect2(0, 0, W, H).has_point(b.position):
			b.pocket()
			pocketed.append(b.number)
	for b in balls:
		if b.visible and b.linear_velocity != Vector2.ZERO:
			return
	powers.end_shot(cue_ball)
	var shooter := rules.turn
	rules.apply(first_hit, pocketed)
	if rules.turn != shooter:
		powers.start_turn(rules.turn)
	if rules.rerack:
		rack()
	elif rules.winner >= 0:
		state = State.OVER
	elif rules.foul:
		state = State.BALL_IN_HAND
		# La blanca transparente empieza donde estaba la blanca, o en la línea de salida si entró
		$Cue.pointer = cue_ball.position if cue_ball.visible else HEAD_SPOT
		$Cue.queue_redraw()
		cue_ball.pocket()  # pasa a la mano del rival
	else:
		state = State.AIMING
	_update_hud()


func new_game() -> void:
	rules = Rules.new()
	powers.end_shot(cue_ball)  # por si se reinicia con un poder en marcha
	powers = Powers.new()
	rack()
	state = State.CHOOSING
	$HUD/Naciones.show()
	_update_hud()


func rack() -> void:
	state = State.AIMING
	cue_ball.place(HEAD_SPOT)
	var i := 0
	for row in 5:
		for j in row + 1:
			var offset := Vector2(row * sqrt(3.0), (j - row / 2.0) * 2)
			balls[RACK_ORDER[i]].place(FOOT_SPOT + offset * (Ball.RADIUS + 0.1))
			i += 1


func shoot(velocity: Vector2) -> void:
	pocketed.clear()
	first_hit = -1
	shot_time = 0.0
	state = State.ROLLING
	powers.start_shot(rules.turn, cue_ball)
	# Velocidad directa y no impulso: no depende de la masa, así que Tierra solo sube mass
	cue_ball.linear_velocity = velocity
	_update_hud()


## ¿Cabe la blanca aquí? Dentro del paño y sin tocar bolas ni bandas.
func can_place(pos: Vector2) -> bool:
	if not Rect2(Ball.RADIUS, Ball.RADIUS, W - 2 * Ball.RADIUS, H - 2 * Ball.RADIUS).has_point(pos):
		return false
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = cue_ball.get_node("Shape").shape
	query.transform = Transform2D(0, to_global(pos))
	query.collision_mask = 3
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func place_cue_ball(pos: Vector2) -> void:
	cue_ball.place(pos)
	state = State.AIMING
	rules.message = ""
	_update_hud()


func _on_nations_chosen(nations: Array) -> void:
	powers.nations.assign(nations)
	state = State.AIMING
	_update_hud()


func _on_power_pressed() -> void:
	if state == State.AIMING:
		powers.toggle(rules.turn)
	_update_hud()


func _on_cue_ball_hit(body: Node) -> void:
	if state == State.ROLLING and first_hit < 0 and body is Ball:
		first_hit = body.number
		powers.on_first_hit(body)


func _update_hud() -> void:
	var text: String
	if rules.winner >= 0:
		text = "¡Gana el Jugador %d!" % (rules.winner + 1)
	else:
		text = "Turno: Jugador %d (%s)" % [rules.turn + 1, GROUP_NAMES[rules.groups[rules.turn]]]
		if state == State.BALL_IN_HAND:
			text += " · bola en mano: arrastra la blanca a su sitio"
	if rules.message:
		text += "\n" + rules.message
	$HUD/Info.text = text

	# Botón del jugador del turno, y abajo la nación y la carga de los dos
	var p := rules.turn
	var button: Button = $HUD/Poder
	var nation: String = Powers.NAMES[powers.nations[p]]
	if powers.armed:
		button.text = "Poder: %s (activo)" % nation
	elif powers.is_ready(p):
		button.text = "Poder: " + nation
	else:
		button.text = "Poder: " + _charge(p)
	button.set_pressed_no_signal(powers.armed)
	button.disabled = state != State.AIMING or not powers.is_ready(p)
	$HUD/Poderes.text = "   ·   ".join([0, 1].map(func(i): return "Jugador %d: %s (%s)" % [i + 1, Powers.NAMES[powers.nations[i]], _charge(i)]))


func _charge(player: int) -> String:
	var n: int = powers.wait[player]
	return "carga lista" if n == 0 else "recarga en %d turno%s" % [n, "" if n == 1 else "s"]
