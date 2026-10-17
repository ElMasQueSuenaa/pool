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
	p.start_shot(0, cue)
	check("activar y desactivar no gasta la carga", p.is_ready(0) and p.active == -1)
	p.toggle(0)
	p.start_shot(0, cue)
	check("tirar con el poder activado gasta la carga", not p.is_ready(0) and not p.armed and p.active == Powers.Nation.EARTH)
	p.end_shot(cue)
	p.toggle(0)
	check("sin carga no se puede activar", not p.armed)
	p.start_turn(0)
	p.start_turn(0)
	check("a los 2 turnos propios aún no ha recargado", not p.is_ready(0))
	p.start_turn(0)
	check("a los 3 turnos propios vuelve a tener la carga", p.is_ready(0) and p.is_ready(1))

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

	print("FALLOS: %d" % fails)
	quit(fails)


## La blanca, recta contra la 1 y sin más bolas, con el poder de esa nación (-1 = sin poder).
## Devuelve la velocidad de la blanca y la de la 1 justo después del choque, como fracción de la
## que llevaba la blanca justo antes.
func straight_shot(table: Table, nation: int) -> Array[float]:
	table.new_game()
	for b in table.balls.slice(2):
		b.pocket()
	table.cue_ball.place(Vector2(300, 250))
	table.balls[1].place(Vector2(500, 250))
	await physics_frame
	if nation >= 0:
		table.powers.nations.assign([nation, nation])
		table.powers.toggle(table.rules.turn)
	table.shoot(Vector2(1000, 0))
	var before := 0.0
	while table.first_hit < 0:
		before = table.cue_ball.linear_velocity.x
		await physics_frame
	for i in 8:
		await physics_frame
	var after: Array[float] = [table.cue_ball.linear_velocity.x / before, table.balls[1].linear_velocity.x / before]
	while table.state == Table.State.ROLLING:
		await physics_frame
	return after
