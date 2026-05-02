extends Control

signal powerup_selected(powerup: Dictionary)

var card_scene: PackedScene = preload("res://scenes/powerup_card.tscn")

@onready var score_text: Label = $ScoreText
@onready var cards_container: HBoxContainer = $CardsContainer
@onready var hint_text: Label = $HintText

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	mouse_filter = Control.MOUSE_FILTER_STOP
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func setup(options: Array, current_score: int, current_level: int) -> void:
	score_text.text = "Score: %d  |  Next Level: %d" % [current_score, current_level + 1]
	hint_text.text = "Choose 1 permanent upgrade"
	for child in cards_container.get_children():
		child.queue_free()
	for option in options:
		var card = card_scene.instantiate()
		cards_container.add_child(card)
		card.setup(option)
		card.selected.connect(_on_card_selected)

func _on_card_selected(powerup: Dictionary) -> void:
	powerup_selected.emit(powerup)
