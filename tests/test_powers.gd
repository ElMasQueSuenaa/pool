extends SceneTree

## Cargas de los poderes y efecto de cada uno: godot --headless --fixed-fps 240 -s tests/test_powers.gd

var fails := 0


func check(name: String, ok: bool) -> void:
	print(("ok    " if ok else "FALLO ") + name)
	fails += int(not ok)


func _initialize() -> void:
	var table: Table = load("res://scenes/main.tscn").instantiate()
	root.add_child(table)
	await process_frame  # que corra _ready() antes de usar la mesa
	var cue := table.cue_ball

	var p := Powers.new()
	p.nations.assign([Powers.Nation.EARTH, Powers.Nation.FIRE])
	check("al empezar los dos tienen la carga", p.is_ready(0) and p.is_ready(1))
	p.toggle(0)
	p.toggle(0)
	p.start_shot(0, cue, Vector2.RIGHT)
	check("activar y desactivar no gasta la carga", p.is_ready(0) and p.active == -1)
	p.toggle(0)
	p.start_shot(0, cue, Vector2.RIGHT)
	check("tirar con el poder activado gasta la carga", not p.is_ready(0) and not p.armed and p.active == Powers.Nation.EARTH)
	p.end_shot(cue)
	p.toggle(0)
	check("sin carga no se puede activar", not p.armed)
	p.start_turn(0)
	p.start_turn(0)
	check("a los 2 turnos propios aún no ha recargado", not p.is_ready(0))
	p.start_turn(0)
	check("a los 3 turnos propios vuelve a tener la carga", p.is_ready(0) and p.is_ready(1))

	p = Powers.new()
	p.nations.assign([Powers.Nation.WATER, Powers.Nation.WATER])
	p.toggle(0)
	var left := p.armed and p.curve_left
	p.toggle(0)
	var right := p.armed and not p.curve_left
	p.toggle(0)
	check("Agua: el botón pasa por izquierda, derecha y desactivado", left and right and not p.armed and p.is_ready(0))

	# Tiro recto contra una bola sola. Sin poder la blanca se queda casi parada y la bola sale
	# con casi toda su velocidad.
	var plain := await straight_shot(table, -1)
	check("sin poder: la blanca se para y la bola sale casi igual (%d%% y %d%%)" % [int(plain[0] * 100), int(plain[1] * 100)], plain[0] < 0.1 and plain[1] > 0.9)
	# Tierra: con el triple de masa la blanca sigue hacia delante a la mitad de velocidad, más o menos
	var earth := await straight_shot(table, Powers.Nation.EARTH)
	check("Tierra: la blanca sigue tras el choque (%d%% de su velocidad)" % int(earth[0] * 100), earth[0] > 0.4)
	check("Tierra: en reposo la blanca vuelve a pesar 1 y el jugador espera la recarga", cue.mass == 1.0 and table.powers.wait[0] == Powers.RECHARGE_TURNS)
	# Fuego: la bola golpeada sale a 1.5 veces lo normal
	var fire := await straight_shot(table, Powers.Nation.FIRE)
	check("Fuego: la bola sale disparada (%d%% de la velocidad de la blanca)" % int(fire[1] * 100), absf(fire[1] / plain[1] - Powers.FIRE_BOOST) < 0.05)

	# Agua: sin bolas delante, la blanca se desvía hacia el lado elegido mientras dura la curva
	for to_left in [true, false]:
		setup(table, Powers.Nation.WATER, Vector2(-100, -100))  # la 1 fuera de la mesa
		if not to_left:
			table.powers.toggle(table.rules.turn)
		await physics_frame
		table.shoot(Vector2(1000, 0))
		while table.shot_time < Powers.WATER_TIME + 0.01:
			await physics_frame
		var dy := cue.position.y - 250
		check("Agua: curva a la %s (%+d px)" % ["izquierda" if to_left else "derecha", int(dy)], dy < -50 if to_left else dy > 50)
		check("Agua: la curva dura %.1f s" % Powers.WATER_TIME, cue.constant_force == Vector2.ZERO)
		await rest(table)

	# Aire: la blanca pasa por encima de la 1 sin tocarla, baja después y vuelve a chocar
	setup(table, Powers.Nation.AIR, Vector2(400, 250))
	await physics_frame
	table.shoot(Vector2(1000, 0))
	await physics_frame
	var jumped := cue.collision_layer == 0 and cue.z_index == 2
	while table.powers.airborne:
		await physics_frame
	check("Aire: salta por encima de la 1 sin tocarla (%.2f s en el aire)" % table.shot_time, jumped and table.first_hit < 0 and table.balls[1].linear_velocity == Vector2.ZERO)
	check("Aire: al bajar vuelve a chocar", cue.collision_layer == 1 and cue.collision_mask == 3 and cue.z_index == 1)
	await rest(table)

	print("FALLOS: %d" % fails)
	quit(fails)


## Partida nueva con solo la blanca en (300, 250) y la 1 en ball_1, y el poder de esa nación
## activado (-1 = sin poder).
func setup(table: Table, nation: int, ball_1: Vector2) -> void:
	table.new_game()
	for b in table.balls.slice(2):
		b.pocket()
	table.cue_ball.place(Vector2(300, 250))
	if Rect2(0, 0, Table.W, Table.H).has_point(ball_1):
		table.balls[1].place(ball_1)
	else:
		table.balls[1].pocket()
	if nation >= 0:
		table.powers.nations.assign([nation, nation])
		table.powers.toggle(table.rules.turn)


func rest(table: Table) -> void:
	while table.state == Table.State.ROLLING:
		await physics_frame


## La blanca, recta contra la 1 y sin más bolas. Devuelve la velocidad de la blanca y la de
## la 1 justo después del choque, como fracción de la que llevaba la blanca justo antes.
func straight_shot(table: Table, nation: int) -> Array[float]:
	setup(table, nation, Vector2(500, 250))
	await physics_frame
	table.shoot(Vector2(1000, 0))
	var before := 0.0
	while table.first_hit < 0:
		before = table.cue_ball.linear_velocity.x
		await physics_frame
	for i in 8:
		await physics_frame
	var after: Array[float] = [table.cue_ball.linear_velocity.x / before, table.balls[1].linear_velocity.x / before]
	await rest(table)
	return after
