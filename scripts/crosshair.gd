extends TextureRect

func _process(_delta: float) -> void:
	position = get_viewport().get_mouse_position() - size * 0.25
