class_name Ball
extends RigidBody2D

const RADIUS := 12.0  # igual que el CircleShape2D de ball.tscn
const STOP_SPEED := 5.0
const COLORS := [Color("f2bd0f"), Color("1d4fc4"), Color("d42a2a"), Color("5c2d91"), Color("f0761a"), Color("138a4a"), Color("7d1f22"), Color("1c1c1c")]
const FONT_SIZE := 9

var number := 0  # 0 = blanca, 1-7 lisas, 8 negra, 9-15 rayadas
# Solo para dibujar: la física no gira las bolas (lock_rotation), así que el giro se calcula
# aparte con lo que avanza la bola. Pasa de los ejes de la bola a los de la vista (ver ball.gdshader).
var orientation := Basis.IDENTITY
var _last_position := Vector2.ZERO


func _ready() -> void:
	var body: ShaderMaterial = $Body.material
	body.set_shader_parameter("color", Color.WHITE if number == 0 else COLORS[(number - 1) % 8])
	body.set_shader_parameter("striped", number > 8)
	body.set_shader_parameter("numbered", number > 0)
	body.set_shader_parameter("radius", RADIUS)
	# El shader pinta la esfera dentro de este cuadrado; se dibuja una vez y no cambia
	$Body.draw.connect(func(): $Body.draw_rect(Rect2(-RADIUS - 1, -RADIUS - 1, 2 * RADIUS + 2, 2 * RADIUS + 2), Color.WHITE))
	$Shadow.draw.connect(_draw_shadow)


func _process(_delta: float) -> void:
	var moved := position - _last_position
	if moved == Vector2.ZERO:
		return
	_last_position = position
	# Rueda sin deslizar: gira lo avanzado / RADIUS alrededor del eje de la mesa perpendicular al avance
	orientation = (Basis(Vector3(moved.y, -moved.x, 0).normalized(), moved.length() / RADIUS) * orientation).orthonormalized()
	_update_orientation()


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# Sin esto las bolas se arrastran eternamente
	if state.linear_velocity.length() < STOP_SPEED:
		state.linear_velocity = Vector2.ZERO


func _draw() -> void:
	# El número, encima de la esfera del shader (Body se dibuja detrás). Va en los dos lados.
	if number == 0:
		return
	var font := ThemeDB.fallback_font
	var text := str(number)
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	var baseline := Vector2(-size.x / 2, font.get_ascent(FONT_SIZE) - size.y / 2)
	for side in [1, -1]:
		var pole := orientation * Vector3(0, 0, -side)
		# Se desvanece hacia el borde, antes de que el círculo blanco se corte
		var alpha := clampf((-pole.z - 0.45) / 0.25, 0, 1)
		if alpha > 0:
			var right := orientation * Vector3(side, 0, 0)
			var down := orientation * Vector3(0, 1, 0)
			draw_set_transform_matrix(Transform2D(Vector2(right.x, right.y), Vector2(down.x, down.y), Vector2(pole.x, pole.y) * RADIUS))
			draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(0.1, 0.1, 0.1, alpha))
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_shadow() -> void:
	# La lámpara está arriba a la izquierda: sombra difusa abajo a la derecha.
	# Shadow va un z por debajo de la bola (z 1 en ball.tscn) para quedar bajo todas las bolas.
	for i in 4:
		$Shadow.draw_circle(Vector2(3, 4), RADIUS + 2 - i, Color(0, 0, 0, 0.13), true, -1, true)


func _update_orientation() -> void:
	$Body.material.set_shader_parameter("orientation", orientation)
	queue_redraw()


## Aire: la blanca va por encima de las demás bolas, un poco más grande y con la sombra más lejos.
## Solo es dibujo: las capas de colisión las cambia powers.gd.
func set_airborne(on: bool) -> void:
	z_index = 2 if on else 1
	$Body.scale = Vector2.ONE * (1.25 if on else 1.0)
	$Shadow.position = Vector2(6, 8) if on else Vector2.ZERO


func pocket() -> void:
	hide()
	freeze = true
	# Congelada sigue chocando: se le quitan las capas para que no tape la tronera
	collision_layer = 0
	collision_mask = 0


func place(pos: Vector2) -> void:
	freeze = false
	position = pos
	# Mover solo el nodo no siempre llega al motor de física, y en la siguiente sincronización
	# la bola vuelve a la posición vieja: se le da la posición directamente al motor
	PhysicsServer2D.body_set_state(get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, global_transform)
	PhysicsServer2D.body_set_state(get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2.ZERO)
	linear_velocity = Vector2.ZERO
	collision_layer = 1
	collision_mask = 3  # bolas y bandas
	# Recién colocada, con el número hacia arriba
	_last_position = pos
	orientation = Basis.IDENTITY
	_update_orientation()
	show()
