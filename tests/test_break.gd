extends SceneTree

## Prueba sí/no de la Fase 1, sin pantalla: 20 saques a fuerza máxima.
##   godot --headless --fixed-fps 240 -s tests/test_break.gd
## --fixed-fps 240 hace un tick de física por fotograma y corre más rápido que el tiempo real.
## Un solape breve al chocar es normal (se muestra el máximo). "Atravesar" es que dos bolas en
## contacto queden en el tick siguiente cada una al otro lado: el vector entre ellas se invierte.

const MAX_REST := 8.0


func _initialize() -> void:
	seed(1)
	var table: Table = load("res://scenes/main.tscn").instantiate()
	root.add_child(table)
	await process_frame  # que corra _ready() antes de usar la mesa
	var speed: float = table.get_node("Cue").max_speed
	var fails := 0
	var worst := 0.0
	for i in 20:
		table.new_game()
		await physics_frame
		table.shoot(Vector2.RIGHT.rotated(deg_to_rad(randf_range(-2, 2))) * speed)
		var errors := {}
		var prev := {}  # vector entre cada par de bolas en el tick anterior
		while table.state == Table.State.ROLLING and table.shot_time < MAX_REST:
			await physics_frame
			var on_table := table.balls.filter(func(b): return b.visible)
			for a in on_table:
				for r: Rect2 in Table.RAILS:
					if r.has_point(a.position):
						errors["la %d atravesó una banda" % a.number] = true
				for b in on_table:
					if a.number < b.number:
						var rel: Vector2 = b.position - a.position
						var key: int = a.number * 16 + b.number
						worst = max(worst, 2 * Ball.RADIUS - rel.length())
						if prev.has(key) and prev[key].length() < 2 * Ball.RADIUS and rel.dot(prev[key]) < 0:
							errors["la %d atravesó a la %d" % [a.number, b.number]] = true
						prev[key] = rel
		if table.state == Table.State.ROLLING:
			errors["no quedó en reposo en %d s" % MAX_REST] = true
		print("saque %2d: %4.1f s, embocadas %s %s" % [i + 1, table.shot_time, table.pocketed, ", ".join(errors.keys())])
		fails += errors.size()
	print("solape máximo entre bolas: %.1f px de %d" % [worst, 2 * Ball.RADIUS])
	print("FALLOS: %d" % fails)
	quit(fails)
