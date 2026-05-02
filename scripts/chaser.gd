extends CharacterBody3D

@export var health: int = 50
@export var move_speed: float = 3.5
@export var detection_range: float = 8.0
@export var contact_damage: int = 15
@export var contact_cooldown: float = 1.0
@export var knockback_stun_duration: float = 0.18
@export var knockback_falloff: float = 10.0

var player: Node3D = null
var contact_timer: float = 0.0
var is_chasing: bool = false
var knockback_velocity: Vector3 = Vector3.ZERO
var knockback_stun_timer: float = 0.0
var contact_area: Area3D = null

func _ready() -> void:
	refresh_player()
	
	var detection = $DetectionArea
	if detection:
		detection.body_entered.connect(_on_detection_body_entered)
		detection.body_exited.connect(_on_detection_body_exited)
	
	contact_area = $ContactArea
	if contact_area:
		contact_area.body_entered.connect(_on_contact_body_entered)


func _physics_process(delta: float) -> void:
	refresh_player()
	if not player:
		return
	
	# Check distance to player
	var to_player := player.global_position - global_position
	var distance := to_player.length()
	to_player.y = 0
	
	if distance <= detection_range:
		is_chasing = true
	else:
		is_chasing = false
	
	var desired_velocity := Vector3.ZERO
	if knockback_stun_timer > 0.0:
		knockback_stun_timer = maxf(0.0, knockback_stun_timer - delta)
	elif is_chasing and to_player.length() > 0:
		desired_velocity = to_player.normalized() * move_speed
	
	velocity = desired_velocity + knockback_velocity
	move_and_slide()
	knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, knockback_falloff * delta)
	
	# Handle contact damage cooldown
	if contact_timer > 0:
		contact_timer -= delta
	if contact_timer <= 0.0:
		_try_contact_damage()

func _on_detection_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		is_chasing = true

func _on_contact_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and contact_timer <= 0.0:
		_try_contact_damage()

func _on_detection_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		is_chasing = false

func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		var main = get_tree().get_first_node_in_group("main")
		if main:
			main.register_enemy_kill("chaser")
		# Chance to drop health potion
		if randf() < 0.2:
			drop_health_potion()
		queue_free()

func drop_health_potion() -> void:
	var main = get_tree().get_first_node_in_group("main")
	if main.has_method("spawn_item"):
		main.spawn_item(global_position, "health_potion")

func refresh_player() -> void:
	if player and is_instance_valid(player):
		return
	player = get_tree().get_first_node_in_group("player")

func apply_knockback(impulse: Vector3) -> void:
	impulse.y = 0.0
	knockback_velocity += impulse
	knockback_stun_timer = maxf(knockback_stun_timer, knockback_stun_duration)

func _try_contact_damage() -> void:
	if not contact_area:
		return
	for body in contact_area.get_overlapping_bodies():
		if body.is_in_group("player"):
			body.take_damage(contact_damage)
			contact_timer = contact_cooldown
			return
