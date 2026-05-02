extends Node3D

signal player_died
signal level_complete

const TURRET_KILL_SCORE := 100
const CHASER_KILL_SCORE := 50
const BASE_PLAYER_STATE := {
	"move_speed": 6.0,
	"dodge_distance": 3.5,
	"dodge_duration": 0.25,
	"dodge_cooldown": 1.5,
	"melee_damage": 35,
	"melee_range": 2.0,
	"melee_cooldown": 0.4,
	"ranged_damage": 20,
	"ranged_speed": 22.0,
	"ranged_cooldown": 0.6,
	"max_health": 100,
	"health": 100,
	"damage_reduction": 0.0,
	"regeneration_amount": 0,
	"regeneration_interval": 0.0
}

var current_level: int = 1
var score: int = 0
var survival_timer: float = 0.0
var game_over: bool = false
var game_won: bool = false
var level_transition_pending: bool = false

var player_scene: PackedScene = preload("res://scenes/player.tscn")
var turret_scene: PackedScene = preload("res://scenes/turret.tscn")
var chaser_scene: PackedScene = preload("res://scenes/chaser.tscn")
var item_scene: PackedScene = preload("res://scenes/item.tscn")
var ui_scene: PackedScene = preload("res://scenes/ui.tscn")
var powerup_screen_scene: PackedScene = preload("res://scenes/powerup_screen.tscn")

var player: CharacterBody3D = null
var turrets_node: Node3D
var chasers_node: Node3D
var items_node: Node3D
var projectiles_node: Node3D
var ui: CanvasLayer = null
var powerup_screen: Control = null
var player_state: Dictionary = {}

var powerup_pool: Array = [
	{"name": "Vitality", "effect": "vitality", "color": "#ff4444", "desc": "+25 max HP"},
	{"name": "Swift Feet", "effect": "swift_feet", "color": "#4444ff", "desc": "+1.5 move speed"},
	{"name": "Sharp Blade", "effect": "sharp_blade", "color": "#ff8800", "desc": "+10 melee damage"},
	{"name": "Quick Shot", "effect": "quick_shot", "color": "#00ffff", "desc": "-0.15 ranged cooldown"},
	{"name": "Iron Skin", "effect": "iron_skin", "color": "#888888", "desc": "-15% damage taken"},
	{"name": "Regeneration", "effect": "regeneration", "color": "#00ff00", "desc": "Heal 5 HP / 3 sec"},
	{"name": "Swift Dodge", "effect": "swift_dodge", "color": "#aa44ff", "desc": "-0.4s dodge cooldown"}
]

func _enter_tree() -> void:
	add_to_group("main")

func _ready() -> void:
	randomize()
	reset_player_state()
	start_level(1)

func _physics_process(delta: float) -> void:
	if game_over or game_won or level_transition_pending:
		if game_over and Input.is_action_just_pressed("restart"):
			restart_game()
		return
	
	survival_timer += delta
	if survival_timer >= 1.0:
		survival_timer -= 1.0
		add_score(10)
	
	check_level_complete()

func start_level(level_num: int) -> void:
	current_level = level_num
	game_over = false
	game_won = false
	level_transition_pending = true
	survival_timer = 0.0
	get_tree().paused = false
	
	call_deferred("_setup_level")

func _setup_level() -> void:
	clear_level()
	create_containers()
	spawn_ui()
	spawn_player()
	spawn_enemies()
	spawn_items()
	level_transition_pending = false
	
func create_containers() -> void:
	turrets_node = Node3D.new()
	turrets_node.name = "Turrets"
	add_child(turrets_node)
	
	chasers_node = Node3D.new()
	chasers_node.name = "Chasers"
	add_child(chasers_node)
	
	items_node = Node3D.new()
	items_node.name = "Items"
	add_child(items_node)
	
	projectiles_node = Node3D.new()
	projectiles_node.name = "Projectiles"
	add_child(projectiles_node)

func spawn_player() -> void:
	if player:
		player.queue_free()
	
	player = player_scene.instantiate()
	player.name = "Player"
	add_child(player)
	player.global_position = Vector3(-12, 0.5, 0)
	if player.has_method("apply_runtime_state"):
		player.apply_runtime_state(player_state)
	
	if player.has_signal("died"):
		player.died.connect(_on_player_died)

func spawn_enemies() -> void:
	var turret_positions = [
		Vector3(-10, 0.25, -10),
		Vector3(10, 0.25, -10),
		Vector3(-10, 0.25, 10),
		Vector3(10, 0.25, 10),
		Vector3(0, 0.25, -12),
		Vector3(0, 0.25, 12),
		Vector3(-12, 0.25, 0),
		Vector3(12, 0.25, 0)
	]
	var turret_count: int = min(turret_positions.size(), 2 + int((current_level - 1) / 2))
	for i in range(turret_count):
		var pos = turret_positions[i]
		var turret = turret_scene.instantiate()
		apply_turret_scaling(turret)
		turrets_node.add_child(turret)
		turret.global_position = pos
	
	var chaser_count: int = 3 + (current_level - 1)
	var chaser_positions = [
		Vector3(-5, 0.5, 0),
		Vector3(5, 0.5, 0),
		Vector3(0, 0.5, 5)
	]
	for i in range(chaser_count):
		var pos = chaser_positions[i % chaser_positions.size()]
		var offset = Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
		var chaser = chaser_scene.instantiate()
		apply_chaser_scaling(chaser)
		chasers_node.add_child(chaser)
		chaser.global_position = pos + offset

func spawn_items() -> void:
	spawn_item(Vector3(0, 0.15, -5), "health_potion")
	spawn_item(Vector3(10, 0.15, 5), "weapon_upgrade")

func spawn_item(pos: Vector3, item_type: String) -> void:
	if not items_node:
		return
	var item = item_scene.instantiate()
	item.item_type = item_type
	items_node.add_child(item)
	item.global_position = pos

func spawn_ui() -> void:
	if ui:
		ui.queue_free()
	ui = ui_scene.instantiate()
	add_child(ui)
	ui.set_score(score)
	ui.set_level(current_level)

func clear_level() -> void:
	if turrets_node and is_instance_valid(turrets_node):
		turrets_node.queue_free()
		turrets_node = null
	if chasers_node and is_instance_valid(chasers_node):
		chasers_node.queue_free()
		chasers_node = null
	if items_node and is_instance_valid(items_node):
		items_node.queue_free()
		items_node = null
	if projectiles_node and is_instance_valid(projectiles_node):
		projectiles_node.queue_free()
		projectiles_node = null
	if player and is_instance_valid(player):
		player.queue_free()
		player = null
	if ui and is_instance_valid(ui):
		ui.queue_free()
		ui = null
	if powerup_screen and is_instance_valid(powerup_screen):
		powerup_screen.queue_free()
		powerup_screen = null

func add_score(points: int) -> void:
	score += points
	if ui:
		ui.add_score(points)

func check_level_complete() -> void:
	if game_won or level_transition_pending:
		return
	
	if not turrets_node or not chasers_node:
		return
	
	var turrets_dead = turrets_node.get_child_count() == 0
	var chasers_dead = chasers_node.get_child_count() == 0
	
	if turrets_dead and chasers_dead:
		game_won = true
		show_powerup_selection()

func show_powerup_selection() -> void:
	if level_transition_pending:
		return
	level_complete.emit()
	cache_player_state()
	
	var options = powerup_pool.duplicate()
	options.shuffle()
	options = options.slice(0, 3)

	if powerup_screen and is_instance_valid(powerup_screen):
		powerup_screen.queue_free()
	powerup_screen = powerup_screen_scene.instantiate()
	add_child(powerup_screen)
	powerup_screen.setup(options, score, current_level)
	powerup_screen.powerup_selected.connect(_on_powerup_selected, CONNECT_ONE_SHOT)
	get_tree().paused = true

func _on_powerup_selected(chosen: Dictionary) -> void:
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	if powerup_screen and is_instance_valid(powerup_screen):
		powerup_screen.queue_free()
		powerup_screen = null
	apply_powerup(chosen)
	start_level(current_level + 1)

func apply_powerup(powerup: Dictionary) -> void:
	if player_state.is_empty():
		reset_player_state()
	
	match powerup["effect"]:
		"vitality":
			player_state["max_health"] += 25
			player_state["health"] = player_state["max_health"]
		"swift_feet":
			player_state["move_speed"] += 1.5
		"sharp_blade":
			player_state["melee_damage"] += 10
		"quick_shot":
			player_state["ranged_cooldown"] = maxf(0.15, player_state["ranged_cooldown"] - 0.15)
		"iron_skin":
			player_state["damage_reduction"] = minf(0.9, player_state["damage_reduction"] + 0.15)
		"regeneration":
			player_state["regeneration_amount"] = int(player_state["regeneration_amount"]) + 5
			player_state["regeneration_interval"] = 3.0
		"swift_dodge":
			player_state["dodge_cooldown"] = maxf(0.3, player_state["dodge_cooldown"] - 0.4)
	
	if player and is_instance_valid(player) and player.has_method("apply_runtime_state"):
		player.apply_runtime_state(player_state)

func _on_player_died() -> void:
	game_over = true
	disable_enemy_activity()
	if ui:
		ui.show_game_over(score)

func restart_game() -> void:
	score = 0
	current_level = 1
	reset_player_state()
	start_level(1)

func get_player() -> CharacterBody3D:
	return player

func get_projectiles_container() -> Node3D:
	return projectiles_node

func register_enemy_kill(enemy_type: String) -> void:
	match enemy_type:
		"turret":
			add_score(TURRET_KILL_SCORE)
		"chaser":
			add_score(CHASER_KILL_SCORE)

func reset_player_state() -> void:
	player_state = BASE_PLAYER_STATE.duplicate(true)

func cache_player_state() -> void:
	if player and is_instance_valid(player) and player.has_method("get_runtime_state"):
		player_state = player.get_runtime_state()

func disable_enemy_activity() -> void:
	for container in [turrets_node, chasers_node]:
		if not container or not is_instance_valid(container):
			continue
		for enemy in container.get_children():
			enemy.set_physics_process(false)
			enemy.set_process(false)

func apply_turret_scaling(turret: Node) -> void:
	var level_offset: int = current_level - 1
	turret.health += level_offset * 15
	turret.fire_rate = maxf(0.8, turret.fire_rate - level_offset * 0.12)
	turret.projectile_speed += level_offset * 1.0
	turret.projectile_damage += level_offset * 2
	turret.rotation_speed += level_offset * 0.1
	turret.detection_range += minf(8.0, level_offset * 0.6)

func apply_chaser_scaling(chaser: Node) -> void:
	var level_offset: int = current_level - 1
	chaser.health += level_offset * 12
	chaser.move_speed += level_offset * 0.2
	chaser.contact_damage += level_offset * 2
	chaser.detection_range += minf(5.5, level_offset * 0.5)
