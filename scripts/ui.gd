extends CanvasLayer

@onready var health_bar: ProgressBar = $HealthBar
@onready var health_text: Label = $HealthText
@onready var dodge_bar: ProgressBar = $DodgeBar
@onready var score_label: Label = $ScoreLabel
@onready var level_label: Label = $LevelLabel
@onready var game_over: Control = $GameOver
@onready var final_score: Label = $GameOver/FinalScore

var score: int = 0
var level: int = 1

func _process(_delta: float) -> void:
	var main = get_tree().get_first_node_in_group("main")
	if main:
		var player = main.get_player()
		if player and "health" in player:
			var player_health = player.get("health")
			var player_max_health = player.get("max_health")
			var player_dodge_cd = player.get("dodge_cooldown")
			var player_dodge_cd_timer = player.get("dodge_cooldown_timer")
			
			health_bar.value = player_health
			health_bar.max_value = player_max_health
			health_text.text = "HP: %d/%d" % [player_health, player_max_health]
			
			var dodge_ready = player_dodge_cd_timer <= 0
			if dodge_ready:
				dodge_bar.value = player_dodge_cd
			else:
				dodge_bar.value = player_dodge_cd - player_dodge_cd_timer
	
	score_label.text = "Score: %d" % score
	level_label.text = "Level: %d" % level
	
func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func show_game_over(score) -> void:
	final_score.text = "Final Score: %d" % score
	game_over.visible = true

func hide_game_over() -> void:
	game_over.visible = false

func add_score(points: int) -> void:
	score += points

func set_level(lvl: int) -> void:
	level = lvl

func set_score(total: int) -> void:
	score = total

func reset_score() -> void:
	score = 0
