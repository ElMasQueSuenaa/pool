class_name Powers
extends RefCounted

## Poderes de las naciones. Cada jugador tiene 1 carga y la recupera tras RECHARGE_TURNS turnos
## propios. Se activa con el botón de poder antes de tirar y afecta a la blanca en ese tiro;
## al quedar la mesa en reposo todo vuelve a la normalidad.
## Las cargas no tocan nodos (se prueban en tests/test_powers.gd); los efectos sí tocan la blanca.

enum Nation { EARTH, FIRE, WATER, AIR }

const NAMES := ["Tierra", "Fuego", "Agua", "Aire"]
const RECHARGE_TURNS := 3
const EARTH_MASS := 3.0

var nations: Array[int] = [Nation.EARTH, Nation.EARTH]  # todos Tierra hasta que haya otro poder
var wait: Array[int] = [0, 0]  # turnos propios que le faltan a cada jugador; 0 = cargado
var armed := false  # el jugador del turno lo ha activado para el próximo tiro
var active := -1  # nación cuyo efecto está en marcha en este tiro, -1 si ninguna


func is_ready(player: int) -> bool:
	return wait[player] == 0


## Activa o desactiva el poder para el próximo tiro. Sin carga no hace nada.
func toggle(player: int) -> void:
	armed = is_ready(player) and not armed


## Al empezar cada turno de un jugador le queda uno menos para recargar.
func start_turn(player: int) -> void:
	armed = false
	wait[player] = maxi(wait[player] - 1, 0)


func start_shot(player: int, cue_ball: Ball) -> void:
	if not armed:
		return
	armed = false
	wait[player] = RECHARGE_TURNS
	active = nations[player]
	match active:
		Nation.EARTH:
			# El tiro fija la velocidad, así que sale igual de rápida: solo pesa más al chocar
			cue_ball.mass = EARTH_MASS


func end_shot(cue_ball: Ball) -> void:
	active = -1
	cue_ball.mass = 1.0  # la de ball.tscn
