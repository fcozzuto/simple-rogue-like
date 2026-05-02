extends Node3D

@export var health: int = 80
@export var rotation_speed: float = 2.0
@export var fire_rate: float = 2.0
@export var projectile_speed: float = 14.0
@export var projectile_damage: int = 12
@export var detection_range: float = 18.0

var player: Node3D = null
var fire_timer: float = 0.0
var current_rotation: float = 0.0
var target_rotation: float = 0.0
var is_active: bool = false

var projectile_scene: PackedScene = preload("res://scenes/projectile.tscn")

func _ready() -> void:
	refresh_player()
	
	# Connect detection
	var detection = $DetectionArea
	if detection:
		detection.body_entered.connect(_on_detection_body_entered)
		detection.body_exited.connect(_on_detection_body_exited)

func _physics_process(delta: float) -> void:
	refresh_player()
	if not player:
		return
	
	# Calculate target rotation to face player
	var to_player := player.global_position - global_position
	to_player.y = 0
	is_active = to_player.length() <= detection_range
	if not is_active:
		fire_timer = 0.0
		return
	target_rotation = atan2(to_player.x, -to_player.z)
	
	# Smooth rotation
	var rot_diff := target_rotation - current_rotation
	# Normalize to -PI to PI
	while rot_diff > PI:
		rot_diff -= 2 * PI
	while rot_diff < -PI:
		rot_diff += 2 * PI
	
	current_rotation += rot_diff * rotation_speed * delta
	rotation.y = -current_rotation
	
	# Fire if facing player (within tolerance)
	if abs(rot_diff) < 0.1:
		fire_timer += delta
		if fire_timer >= fire_rate:
			fire_timer = 0.0
			fire()

func _on_detection_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		is_active = true

func _on_detection_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		is_active = false
		fire_timer = 0.0

func fire() -> void:
	var projectile = projectile_scene.instantiate()
	projectile.damage = projectile_damage
	projectile.speed = projectile_speed
	projectile.direction = -transform.basis.z
	projectile.source = "turret"
	
	projectile.set_enemy_color()
	
	var main = get_tree().get_first_node_in_group("main")
	if not main:
		return
	var barrel = $Barrel
	var projectiles = main.get_projectiles_container()
	if not projectiles:
		return
	projectiles.add_child(projectile)
	projectile.global_position = barrel.global_position
	
	projectile.set_collision_layer(0)
	projectile.set_collision_mask(0)
	projectile.set_collision_layer_value(4, true)
	projectile.set_collision_mask_value(1, true)

func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		var main = get_tree().get_first_node_in_group("main")
		if main:
			main.register_enemy_kill("turret")
		queue_free()

func refresh_player() -> void:
	if player and is_instance_valid(player):
		return
	player = get_tree().get_first_node_in_group("player")
