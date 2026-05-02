extends Control

signal selected(powerup: Dictionary)

var powerup_data: Dictionary = {}

@onready var panel: Panel = $Panel
@onready var icon_rect: ColorRect = $Panel/IconRect
@onready var title_label: Label = $Panel/TitleLabel
@onready var description_label: Label = $Panel/DescriptionLabel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_disable_child_mouse($Panel)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func setup(data: Dictionary) -> void:
	powerup_data = data
	title_label.text = str(data.get("name", "Power-Up"))
	description_label.text = str(data.get("desc", ""))
	icon_rect.color = Color(str(data.get("color", "#ffffff")))
	var stylebox: StyleBoxFlat = panel.get_theme_stylebox("panel").duplicate()
	stylebox.border_color = icon_rect.color
	panel.add_theme_stylebox_override("panel", stylebox)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		selected.emit(powerup_data)
		accept_event()

func _on_mouse_entered() -> void:
	scale = Vector2(1.03, 1.03)
	modulate = Color(1, 1, 1, 1)

func _on_mouse_exited() -> void:
	scale = Vector2.ONE
	modulate = Color(0.94, 0.94, 0.94, 1)

func _disable_child_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_disable_child_mouse(child)
