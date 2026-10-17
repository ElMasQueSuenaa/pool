extends PanelContainer

## Al empezar cada partida, cada jugador elige su nación. Solo salen los poderes ya hechos
## (Powers.AVAILABLE). Se recuerda la elección anterior, así que basta con pulsar Jugar.

signal chosen(nations: Array)

var _groups: Array[ButtonGroup] = []


func _ready() -> void:
	for player in 2:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "Jugador %d" % (player + 1)
		label.custom_minimum_size.x = 110
		row.add_child(label)
		var group := ButtonGroup.new()
		for nation: int in Powers.AVAILABLE:
			var button := Button.new()
			button.text = Powers.NAMES[nation]
			button.toggle_mode = true
			button.button_group = group
			button.custom_minimum_size = Vector2(110, 44)  # que se acierte con el dedo
			# La elegida, en el mismo dorado que el botón Poder activado
			button.add_theme_color_override("font_pressed_color", Color(1, 0.8, 0.4))
			button.add_theme_color_override("font_hover_pressed_color", Color(1, 0.8, 0.4))
			button.set_meta("nation", nation)
			# La primera vez, cada jugador una distinta
			button.button_pressed = nation == Powers.AVAILABLE[player % Powers.AVAILABLE.size()]
			row.add_child(button)
		_groups.append(group)
		$Rows/Players.add_child(row)
	$Rows/Jugar.pressed.connect(_on_play)


func _on_play() -> void:
	hide()
	chosen.emit(_groups.map(func(g: ButtonGroup): return g.get_pressed_button().get_meta("nation")))
