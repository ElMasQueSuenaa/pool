class_name Powers
extends RefCounted

## Poderes de las naciones. Cada jugador tiene 1 carga y la recupera tras RECHARGE_TURNS turnos
## propios. Se activa con el botón de poder antes de tirar y afecta a la blanca en ese tiro;
## al quedar la mesa en reposo todo vuelve a la normalidad.
## Las cargas no tocan nodos (se prueban en tests/test_powers.gd); los efectos sí tocan la blanca.

enum Nation { EARTH, FIRE, WATER, AIR }

const NAMES := ["Tierra", "Fuego", "Agua", "Aire"]
const AVAILABLE := [Nation.EARTH, Nation.FIRE]  # los que ya están hechos, en el orden del selector
const RECHARGE_TURNS := 3
const EARTH_MASS := 3.0
const FIRE_BOOST := 1.5

var nations: Array[int] = [Nation.EARTH, Nation.FIRE]  # la de cada jugador, se elige al empezar
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


## Primer choque de la blanca con una bola en este tiro (table.gd lo llama desde body_entered).
func on_first_hit(ball: Ball) -> void:
	match active:
		Nation.FIRE:
			# El choque ya se ha resuelto en el motor, pero el nodo aún no lo sabe (su
			# linear_velocity sigue a 0): se lee la velocidad del motor. Va en la dirección
			# blanca → bola, así que basta con multiplicarla.
			var v: Vector2 = PhysicsServer2D.body_get_state(ball.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
			ball.linear_velocity = v * FIRE_BOOST


func end_shot(cue_ball: Ball) -> void:
	active = -1
	cue_ball.mass = 1.0  # la de ball.tscn
