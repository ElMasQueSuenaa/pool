class_name Rules
extends RefCounted

## Reglas de 8-ball, simplificadas a propósito. Lógica pura, sin nodos:
## se prueba con `godot --headless -s tests/test_rules.gd`.
## Fuera: cantar tronera, banda tras contacto, 4 bandas en el saque y 3 faltas.

enum { OPEN, SOLIDS, STRIPES }

var turn := 0  # jugador que tira: 0 o 1
var groups := [OPEN, OPEN]  # grupo de cada jugador
var on_table: Array[int] = []  # bolas 1-15 que siguen en la mesa
var is_break := true
var winner := -1
# Resultado del último tiro
var foul := false
var rerack := false
var message := ""


func _init() -> void:
	on_table.assign(range(1, 16))


static func group_of(n: int) -> int:
	return SOLIDS if n < 8 else STRIPES


## first_hit: primera bola que tocó la blanca (-1 si ninguna).
## pocketed: bolas que entraron en el tiro, en orden; el 0 es la blanca.
func apply(first_hit: int, pocketed: Array[int]) -> void:
	var group: int = groups[turn]
	var cleared := group != OPEN and not on_table.any(func(n): return n != 8 and group_of(n) == group)
	var target_ok: bool  # ¿la primera bola tocada era una permitida?
	if cleared:
		target_ok = first_hit == 8
	elif group == OPEN:
		target_ok = first_hit != 8
	else:
		target_ok = first_hit != 8 and group_of(first_hit) == group
	var foul_reason := ""
	if pocketed.has(0):
		foul_reason = "la blanca entró"
	elif first_hit < 0:
		foul_reason = "no tocó ninguna bola"
	elif not target_ok:
		foul_reason = "tocó primero la %d" % first_hit
	foul = foul_reason != ""
	rerack = false
	message = "Falta: %s" % foul_reason if foul else ""
	for n in pocketed:
		on_table.erase(n)

	if pocketed.has(8):
		if is_break:
			# El mismo jugador vuelve a sacar
			on_table.assign(range(1, 16))
			foul = false
			rerack = true
			message = "La 8 entró en el saque: se vuelve a colocar"
		elif cleared and not foul:
			winner = turn
		else:
			winner = 1 - turn
			message = "La 8 entró con falta" if foul else "La 8 entró antes de tiempo"
		return

	var was_break := is_break
	is_break = false
	var balls := pocketed.filter(func(n): return n != 0)
	if foul or balls.is_empty():
		turn = 1 - turn
	elif group == OPEN:
		# En el saque la mesa sigue abierta; después, la primera bola embocada decide
		if not was_break:
			groups[turn] = group_of(balls[0])
			groups[1 - turn] = STRIPES if groups[turn] == SOLIDS else SOLIDS
			message = "Jugador %d se queda las %s" % [turn + 1, "lisas" if groups[turn] == SOLIDS else "rayadas"]
	elif not balls.any(func(n): return group_of(n) == group):
		turn = 1 - turn
