extends Node2D

## El tiro, como un tirachinas: se pulsa sobre la blanca y se arrastra hacia atrás.
## La dirección es la opuesta al arrastre y la fuerza va con la distancia.
## Con bola en mano, la blanca sigue al dedo y se coloca al soltar si cabe.
## Solo eventos de ratón: Godot convierte el toque en ratón, así que sirve en PC y móvil.
## _input y no _unhandled_input: si se suelta encima del botón Reiniciar, el botón se queda
## el evento y el tiro nunca terminaría. El botón no se activa porque no se pulsó sobre él.

@export var max_drag := 150.0
@export var max_speed := 3000.0

var aiming := false
var pointer := Vector2.ZERO  # último punto del ratón o el dedo, en coordenadas de la mesa

@onready var table: Table = get_parent()


func _input(event: InputEvent) -> void:
	if not event is InputEventMouse:
		return
	pointer = make_input_local(event).position
	var released: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed
	match table.state:
		Table.State.AIMING:
			var drag := _drag()
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				aiming = drag.length() < Ball.RADIUS * 3
			elif released and aiming:
				aiming = false
				# Soltar sin salir de la blanca cancela el tiro
				if drag.length() > Ball.RADIUS:
					table.shoot(drag / max_drag * max_speed)
		Table.State.BALL_IN_HAND:
			if released and table.can_place(pointer):
				table.place_cue_ball(pointer)
	queue_redraw()


func _draw() -> void:
	if table.state == Table.State.BALL_IN_HAND:
		draw_circle(pointer, Ball.RADIUS, Color(1, 1, 1, 0.8 if table.can_place(pointer) else 0.3))
	elif aiming:
		var from := table.cue_ball.position
		draw_line(from, from + _drag() * 3, Color.WHITE, 2)


func _drag() -> Vector2:
	return (table.cue_ball.position - pointer).limit_length(max_drag)
