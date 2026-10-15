extends Node2D

## El tiro, como un tirachinas: se pulsa sobre la blanca y se arrastra hacia atrás.
## La dirección es la opuesta al arrastre y la fuerza va con la distancia.
## Solo eventos de ratón: Godot convierte el toque en ratón, así que sirve en PC y móvil.

@export var max_drag := 150.0
@export var max_speed := 3000.0

var aiming := false
var pointer := Vector2.ZERO  # último punto del ratón o el dedo, en coordenadas de la mesa

@onready var table: Table = get_parent()


func _unhandled_input(event: InputEvent) -> void:
	if table.rolling or not event is InputEventMouse:
		return
	pointer = make_input_local(event).position
	var drag := _drag()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			aiming = drag.length() < Ball.RADIUS * 3
		elif aiming:
			aiming = false
			# Soltar sin salir de la blanca cancela el tiro
			if drag.length() > Ball.RADIUS:
				table.shoot(drag / max_drag * max_speed)
	queue_redraw()


func _draw() -> void:
	if aiming:
		var from := table.cue_ball.position
		draw_line(from, from + _drag() * 3, Color.WHITE, 2)


func _drag() -> Vector2:
	return (table.cue_ball.position - pointer).limit_length(max_drag)
