extends SceneTree

## Casos de las reglas de 8-ball: godot --headless -s tests/test_rules.gd

var fails := 0


func check(name: String, ok: bool) -> void:
	print(("ok    " if ok else "FALLO ") + name)
	fails += int(not ok)


## Partida ya sacada, con estos grupos y estas bolas en la mesa
func game(groups := [Rules.OPEN, Rules.OPEN], on_table := range(1, 16)) -> Rules:
	var r := Rules.new()
	r.is_break = false
	r.groups = groups
	r.on_table.assign(on_table)
	return r


func _initialize() -> void:
	var r := Rules.new()
	r.apply(1, [])
	check("saque sin bolas: pasa el turno y la mesa sigue abierta", r.turn == 1 and not r.foul and r.groups == [Rules.OPEN, Rules.OPEN])

	r = Rules.new()
	r.apply(1, [3, 11])
	check("saque con bolas: sigue tirando y la mesa sigue abierta", r.turn == 0 and r.groups == [Rules.OPEN, Rules.OPEN])

	r = Rules.new()
	r.apply(1, [8])
	check("8 en el saque: se vuelve a colocar y saca el mismo", r.rerack and r.turn == 0 and r.is_break and r.on_table.size() == 15 and r.winner == -1)

	r = game()
	r.apply(2, [2])
	check("asignación de grupo: lisas para quien emboca una lisa", r.groups == [Rules.SOLIDS, Rules.STRIPES] and r.turn == 0)

	r = game()
	r.apply(12, [12, 3])
	check("asignación de grupo: decide la primera bola que entra", r.groups == [Rules.STRIPES, Rules.SOLIDS])

	r = game([Rules.SOLIDS, Rules.STRIPES])
	r.apply(2, [2, 0])
	check("falta por blanca: pasa el turno con bola en mano", r.foul and r.turn == 1 and not r.on_table.has(2))

	r = game([Rules.SOLIDS, Rules.STRIPES])
	r.apply(-1, [])
	check("falta por no tocar ninguna bola", r.foul and r.turn == 1)

	r = game([Rules.SOLIDS, Rules.STRIPES])
	r.apply(9, [2])
	check("falta por primer contacto con bola del rival", r.foul and r.turn == 1)

	r = game()
	r.apply(8, [])
	check("falta por tocar la 8 primero con la mesa abierta", r.foul)

	r = game([Rules.SOLIDS, Rules.STRIPES])
	r.apply(1, [10])
	check("emboca solo del rival sin falta: pasa el turno", not r.foul and r.turn == 1)

	r = game([Rules.SOLIDS, Rules.STRIPES])
	r.apply(1, [8])
	check("8 temprana = derrota", r.winner == 1)

	r = game([Rules.SOLIDS, Rules.STRIPES], [8, 9, 10])
	r.apply(8, [8])
	check("8 final = victoria", r.winner == 0)

	r = game([Rules.SOLIDS, Rules.STRIPES], [8, 9, 10])
	r.apply(8, [8, 0])
	check("8 final con la blanca dentro = derrota", r.winner == 1)

	r = game([Rules.SOLIDS, Rules.STRIPES], [8, 9, 10])
	r.apply(9, [])
	check("con el grupo limpio hay que tocar la 8 primero", r.foul)

	r = game([Rules.SOLIDS, Rules.STRIPES], [7, 8, 9])
	r.apply(7, [7, 8])
	check("la última bola y la 8 en el mismo tiro = derrota", r.winner == 1)

	print("FALLOS: %d" % fails)
	quit(fails)
