class_name Table
extends Node2D

## Mesa: bandas, troneras, rack, turnos y bola en mano.
## Estados: AIMING → ROLLING → (al quedar en reposo se aplican las reglas) → BALL_IN_HAND | AIMING | OVER
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

enum State { AIMING, ROLLING, BALL_IN_HAND, OVER }

var balls: Array[Ball] = []  # balls[n] es la bola número n
var cue_ball: Ball
var rules := Rules.new()
var state := State.AIMING
var pocketed: Array[int] = []
var first_hit := -1
var shot_time := 0.0


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
	new_game()


func _draw() -> void:
	draw_rect(Rect2(-RAIL, -RAIL, W + 2 * RAIL, H + 2 * RAIL), Color.SADDLE_BROWN)
	draw_rect(Rect2(0, 0, W, H), Color.DARK_GREEN)
	for p: Vector2 in POCKETS:
		draw_circle(p, CORNER_GAP * 0.8 if p.x != W / 2 else SIDE_GAP, Color.BLACK)


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
	rules.apply(first_hit, pocketed)
	if rules.rerack:
		rack()
	elif rules.winner >= 0:
		state = State.OVER
	elif rules.foul:
		state = State.BALL_IN_HAND
		cue_ball.pocket()  # pasa a la mano del rival
	else:
		state = State.AIMING
	_update_hud()


func new_game() -> void:
	rules = Rules.new()
	rack()
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
	# Velocidad directa y no impulso: no depende de la masa (Tierra solo tendrá que subir mass)
	cue_ball.linear_velocity = velocity


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
	_update_hud()


func _on_cue_ball_hit(body: Node) -> void:
	if state == State.ROLLING and first_hit < 0 and body is Ball:
		first_hit = body.number


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
