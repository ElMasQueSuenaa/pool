class_name Powers
extends RefCounted

## Poderes de las naciones. Cada jugador tiene 1 carga y la recupera tras RECHARGE_TURNS turnos
## propios. Se activa con el botón de poder antes de tirar y afecta a la blanca en ese tiro;
## al quedar la mesa en reposo todo vuelve a la normalidad.
## Las cargas no tocan nodos (se prueban en tests/test_powers.gd); los efectos sí tocan la blanca.

enum Nation { EARTH, FIRE, WATER, AIR }

const NAMES := ["Tierra", "Fuego", "Agua", "Aire"]
const AVAILABLE := [Nation.EARTH, Nation.FIRE, Nation.WATER, Nation.AIR]  # en el orden del selector
const RECHARGE_TURNS := 3
const EARTH_MASS := 3.0
const FIRE_BOOST := 1.5
const WATER_CURVE := 0.8  # fuerza lateral por cada px/s de la velocidad de salida
const WATER_TIME := 0.5
const AIR_TIME := 0.35

var nations: Array[int] = [Nation.EARTH, Nation.FIRE]  # la de cada jugador, se elige al empezar
var wait: Array[int] = [0, 0]  # turnos propios que le faltan a cada jugador; 0 = cargado
var armed := false  # el jugador del turno lo ha activado para el próximo tiro
var curve_left := true  # Agua: hacia dónde curva, visto desde detrás de la blanca
var active := -1  # nación cuyo efecto está en marcha en este tiro, -1 si ninguna
var airborne := false  # Aire: la blanca está en el aire y no choca con bolas

var _cue: Ball
var _time := 0.0  # desde que empezó el tiro


func is_ready(player: int) -> bool:
	return wait[player] == 0


## Activa o desactiva el poder para el próximo tiro. Sin carga no hace nada.
## Con Agua hay un paso más: curva a la izquierda → curva a la derecha → desactivado.
func toggle(player: int) -> void:
	if armed and curve_left and nations[player] == Nation.WATER:
		curve_left = false
		return
	armed = is_ready(player) and not armed
	curve_left = true


## Al empezar cada turno de un jugador le queda uno menos para recargar.
func start_turn(player: int) -> void:
	armed = false
	curve_left = true
	wait[player] = maxi(wait[player] - 1, 0)


func start_shot(player: int, cue_ball: Ball, velocity: Vector2) -> void:
	if not armed:
		return
	armed = false
	wait[player] = RECHARGE_TURNS
	active = nations[player]
	_cue = cue_ball
	_time = 0.0
	match active:
		Nation.EARTH:
			# El tiro fija la velocidad, así que sale igual de rápida: solo pesa más al chocar
			cue_ball.mass = EARTH_MASS
		Nation.WATER:
			# Perpendicular a la salida y proporcional a su velocidad: la curva tiene más o menos
			# el mismo ángulo con cualquier fuerza. orthogonal() gira hacia la izquierda del tiro.
			cue_ball.constant_force = velocity.orthogonal() * WATER_CURVE * (1 if curve_left else -1)
		Nation.AIR:
			# Otra bola choca con la blanca si la máscara de cualquiera de las dos incluye la capa
			# de la otra, así que no basta con quitarle a la blanca la capa 1 de la máscara:
			# también se le quita su capa. Sigue chocando con las bandas (capa 2).
			cue_ball.collision_layer = 0
			cue_ball.collision_mask = 2
			cue_ball.set_airborne(true)
			airborne = true


## Cada tick de física mientras ruedan las bolas.
func tick(delta: float) -> void:
	_time += delta
	match active:
		Nation.WATER:
			if _time >= WATER_TIME:
				_cue.constant_force = Vector2.ZERO
		Nation.AIR:
			# Baja cuando ha pasado el tiempo y no cae encima de ninguna bola
			if airborne and _time >= AIR_TIME and not _over_a_ball():
				_land()


## Primer choque de la blanca con una bola en este tiro (table.gd lo llama desde body_entered).
func on_first_hit(ball: Ball) -> void:
	match active:
		Nation.FIRE:
			# El choque ya se ha resuelto en el motor, pero el nodo aún no lo sabe (su
			# linear_velocity sigue a 0): se lee la velocidad del motor. Va en la dirección
			# blanca → bola, así que basta con multiplicarla.
			var v: Vector2 = PhysicsServer2D.body_get_state(ball.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
			ball.linear_velocity = v * FIRE_BOOST
		Nation.WATER:
			# La curva sirve para llegar a la bola; después del choque, la blanca sigue normal
			_cue.constant_force = Vector2.ZERO


func end_shot(cue_ball: Ball) -> void:
	active = -1
	cue_ball.mass = 1.0  # la de ball.tscn
	cue_ball.constant_force = Vector2.ZERO
	if airborne:  # solo si se para encima de otra bola: baja igual y el motor las separa
		_cue = cue_ball
		_land()


func _land() -> void:
	airborne = false
	_cue.set_airborne(false)
	# Si entró en una tronera se queda sin capas, como las demás bolas embocadas
	if _cue.visible:
		_cue.collision_layer = 1
		_cue.collision_mask = 3


func _over_a_ball() -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _cue.get_node("Shape").shape
	query.transform = _cue.global_transform
	query.collision_mask = 1  # la blanca no tiene capa ahora, así que no se encuentra a sí misma
	return not _cue.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()
