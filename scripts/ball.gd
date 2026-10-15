class_name Ball
extends RigidBody2D

const RADIUS := 12.0  # igual que el CircleShape2D de ball.tscn
const STOP_SPEED := 5.0
const COLORS := [Color.GOLD, Color.ROYAL_BLUE, Color.RED, Color.PURPLE, Color.ORANGE, Color.FOREST_GREEN, Color.MAROON, Color.BLACK]

var number := 0  # 0 = blanca, 1-7 lisas, 8 negra, 9-15 rayadas


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# Sin esto las bolas se arrastran eternamente
	if state.linear_velocity.length() < STOP_SPEED:
		state.linear_velocity = Vector2.ZERO


func _draw() -> void:
	if number == 0:
		draw_circle(Vector2.ZERO, RADIUS, Color.WHITE)
	elif number > 8:
		draw_circle(Vector2.ZERO, RADIUS, Color.WHITE)
		draw_circle(Vector2.ZERO, RADIUS * 0.65, COLORS[number - 9])
	else:
		draw_circle(Vector2.ZERO, RADIUS, COLORS[number - 1])


func pocket() -> void:
	hide()
	freeze = true
	# Congelada sigue chocando: se le quitan las capas para que no tape la tronera
	collision_layer = 0
	collision_mask = 0


func place(pos: Vector2) -> void:
	freeze = true
	position = pos
	linear_velocity = Vector2.ZERO
	collision_layer = 1
	collision_mask = 3  # bolas y bandas
	show()
	freeze = false
