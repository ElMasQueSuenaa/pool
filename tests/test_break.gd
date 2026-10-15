extends SceneTree

## Prueba sí/no de la Fase 1, sin pantalla: 20 saques a fuerza máxima.
##   godot --headless --fixed-fps 240 -s tests/test_break.gd
## --fixed-fps 240 hace un tick de física por fotograma y corre más rápido que el tiempo real.
## Un solape breve al chocar es normal; "atravesar" es acercar los centros a menos de un radio.

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
		table.rack()
		await physics_frame
		table.shoot(Vector2.RIGHT.rotated(deg_to_rad(randf_range(-2, 2))) * speed)
		var errors := {}
		while table.rolling and table.shot_time < MAX_REST:
			await physics_frame
			var on_table := table.balls.filter(func(b): return b.visible)
			for a in on_table:
				for r: Rect2 in Table.RAILS:
					if r.has_point(a.position):
						errors["la %d atravesó una banda" % a.number] = true
				for b in on_table:
					if a.number < b.number:
						var d: float = a.position.distance_to(b.position)
						worst = max(worst, 2 * Ball.RADIUS - d)
						if d < Ball.RADIUS:
							errors["la %d atravesó a la %d" % [a.number, b.number]] = true
		if table.rolling:
			errors["no quedó en reposo en %d s" % MAX_REST] = true
		print("saque %2d: %4.1f s, embocadas %s %s" % [i + 1, table.shot_time, table.pocketed, ", ".join(errors.keys())])
		fails += errors.size()
	print("solape máximo entre bolas: %.1f px (atravesar = más de %d)" % [worst, Ball.RADIUS])
	print("FALLOS: %d" % fails)
	quit(fails)
