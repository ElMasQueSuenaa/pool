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

	# Tierra: tiro recto contra una bola sola. Sin poder la blanca se queda casi parada;
	# con el triple de masa sigue hacia delante a la mitad de velocidad, más o menos.
	var plain := await straight_shot(table, false)
	var earth := await straight_shot(table, true)
	check("Tierra: la blanca sigue tras el choque (%d%% de su velocidad; sin poder, %d%%)" % [int(earth * 100), int(plain * 100)], earth > 0.4 and plain < 0.1)
	check("Tierra: en reposo la blanca vuelve a pesar 1 y el jugador espera la recarga", cue.mass == 1.0 and table.powers.wait[0] == Powers.RECHARGE_TURNS)

	print("FALLOS: %d" % fails)
	quit(fails)


## La blanca, recta contra la 1 y sin más bolas. Devuelve la velocidad de la blanca justo
## después del choque, como fracción de la que llevaba justo antes.
func straight_shot(table: Table, power: bool) -> float:
	table.new_game()
	for b in table.balls.slice(2):
		b.pocket()
	table.cue_ball.place(Vector2(300, 250))
	table.balls[1].place(Vector2(500, 250))
	await physics_frame
	if power:
		table.powers.toggle(table.rules.turn)
	table.shoot(Vector2(1000, 0))
	var before := 0.0
	while table.first_hit < 0:
		before = table.cue_ball.linear_velocity.x
		await physics_frame
	for i in 8:
		await physics_frame
	var ratio := table.cue_ball.linear_velocity.x / before
	while table.state == Table.State.ROLLING:
		await physics_frame
	return ratio
