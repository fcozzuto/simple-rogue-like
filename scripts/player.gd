extends CharacterBody3D

signal died

@export var move_speed: float = 6.0
@export var dodge_distance: float = 3.5
@export var dodge_duration: float = 0.25
@export var dodge_cooldown: float = 1.5

@export var melee_damage: int = 35
@export var melee_range: float = 2.0
@export var melee_cooldown: float = 0.4
@export var melee_swing_duration: float = 0.14
@export var melee_knockback_base: float = 6.0
@export var melee_knockback_per_damage: float = 0.16

@export var ranged_damage: int = 20
@export var ranged_speed: float = 22.0
@export var ranged_cooldown: float = 0.6
@export var damage_reduction: float = 0.0
@export var regeneration_amount: int = 0
@export var regeneration_interval: float = 0.0

var health: int = 100
var max_health: int = 100

var is_dead: bool = false
var is_dodging: bool = false
var dodge_timer: float = 0.0
var dodge_cooldown_timer: float = 0.0
var dodge_direction: Vector3 = Vector3.BACK

var melee_timer: float = 0.0
var melee_swing_timer: float = 0.0
var ranged_timer: float = 0.0
var regeneration_timer: float = 0.0

var facing_direction: Vector3 = Vector3.BACK

var projectile_scene: PackedScene = preload("res://scenes/projectile.tscn")
var weapon_rest_basis: Basis
var weapon_rest_position: Vector3

func _enter_tree() -> void:
	add_to_group("player")

func _ready() -> void:
	var weapon: Node3D = $Weapon
	weapon_rest_basis = weapon.transform.basis
	weapon_rest_position = weapon.transform.origin

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	if dodge_cooldown_timer > 0.0:
		dodge_cooldown_timer -= delta
	
	if is_dodging:
		dodge_timer -= delta
		if dodge_timer <= 0.0:
			is_dodging = false
			velocity = Vector3.ZERO
		else:
			velocity = dodge_direction.normalized() * (dodge_distance / dodge_duration)
			move_and_slide()
			return
	
	var input_dir := Vector3.ZERO
	
	if Input.is_action_pressed("move_forward"):
		input_dir.z -= 1.0
	if Input.is_action_pressed("move_backward"):
		input_dir.z += 1.0
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1.0
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1.0
	
	if input_dir != Vector3.ZERO:
		input_dir = input_dir.normalized()
		velocity = input_dir * move_speed
	else:
		velocity = Vector3.ZERO
	
	move_and_slide()
	
	if facing_direction != Vector3.ZERO:
		var target_basis := Basis.looking_at(facing_direction)
		transform.basis = transform.basis.slerp(target_basis, 0.15)
	
	#if $Weapon:
	#	var weapon_basis := Basis.looking_at(facing_direction)
	#	$Weapon.transform.basis = $Weapon.transform.basis.slerp(weapon_basis, 0.15)
	
	if melee_timer > 0:
		melee_timer -= delta
	if melee_swing_timer > 0:
		melee_swing_timer = maxf(0.0, melee_swing_timer - delta)
	if ranged_timer > 0:
		ranged_timer -= delta
	_update_weapon_pose()
	
	if regeneration_amount > 0 and regeneration_interval > 0.0 and health < max_health:
		regeneration_timer += delta
		while regeneration_timer >= regeneration_interval:
			regeneration_timer -= regeneration_interval
			heal(regeneration_amount)
	else:
		regeneration_timer = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	
	if event.is_action_pressed("dodge") and dodge_cooldown_timer <= 0.0 and not is_dodging:
		start_dodge()
	
	if event is InputEventMouseMotion:
		update_facing_from_mouse()
	
	if event.is_action_pressed("melee_attack"):
		melee_attack()
	
	if event.is_action_pressed("ranged_attack"):
		ranged_attack()

func start_dodge() -> void:
	is_dodging = true
	dodge_timer = dodge_duration
	dodge_cooldown_timer = dodge_cooldown
	
	var input_dir := Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		input_dir.z -= 1.0
	if Input.is_action_pressed("move_backward"):
		input_dir.z += 1.0
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1.0
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1.0
	
	if input_dir != Vector3.ZERO:
		dodge_direction = input_dir.normalized()
	else:
		dodge_direction = facing_direction

func update_facing_from_mouse() -> void:
	var aim_target: Variant = get_mouse_aim_target()
	if aim_target != null:
		var look_dir: Vector3 = (aim_target - global_position).normalized()
		look_dir.y = 0
		if look_dir.length() > 0.1:
			facing_direction = look_dir

func melee_attack() -> void:
	if melee_timer > 0:
		return
	
	melee_timer = melee_cooldown
	melee_swing_timer = melee_swing_duration
	
	var melee_area = $MeleeArea
	if not melee_area:
		return
	
	var bodies = melee_area.get_overlapping_bodies()
	for body in bodies:
		if body.has_method("take_damage"):
			body.take_damage(melee_damage)
			var to_enemy: Vector3 = body.global_position - global_position
			to_enemy.y = 0.0
			var knockback_direction: Vector3 = to_enemy
			if knockback_direction.length() <= 0.05:
				knockback_direction = facing_direction
			if knockback_direction.length() > 0.05 and body.has_method("apply_knockback"):
				body.apply_knockback(knockback_direction.normalized() * get_melee_knockback_force())

func ranged_attack() -> void:
	if ranged_timer > 0:
		return

	var weapon = $Weapon
	var muzzle: Node3D = $Weapon/Muzzle if has_node("Weapon/Muzzle") else weapon
	var launch_origin: Vector3 = muzzle.global_position
	
	# Calculate aim point from mouse
	var aim_point: Vector3 = launch_origin + facing_direction.normalized() * 10.0
	var hit: Variant = get_mouse_aim_target()
	if hit != null:
		aim_point = hit
	
	ranged_timer = ranged_cooldown
	
	var main = get_tree().get_first_node_in_group("main")
	if not main:
		return
	
	var projectile = projectile_scene.instantiate()
	projectile.damage = ranged_damage
	projectile.speed = ranged_speed
	
	# Direction toward mouse aim point
	var travel_dir = (aim_point - launch_origin).normalized()
	if travel_dir.length() <= 0.001:
		travel_dir = facing_direction.normalized()
	projectile.direction = travel_dir
	projectile.source = "player"
	
	var projectiles = main.get_projectiles_container()
	if not projectiles:
		return
	projectiles.add_child(projectile)
	projectile.global_position = launch_origin
	
	projectile.set_collision_layer(0)
	projectile.set_collision_mask(0)
	projectile.set_collision_layer_value(3, true)
	projectile.set_collision_mask_value(2, true)

func take_damage(amount: int) -> void:
	if is_dead or is_dodging:
		return
	
	var adjusted_damage := amount
	if damage_reduction > 0.0:
		adjusted_damage = maxi(1, int(round(float(amount) * (1.0 - damage_reduction))))
	
	health -= adjusted_damage
	if health <= 0:
		health = 0
		die()

func heal(amount: int) -> void:
	health = mini(health + amount, max_health)

func die() -> void:
	if is_dead:
		return
	
	is_dead = true
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	for area in [$PickupArea, $MeleeArea]:
		area.monitoring = false
		area.monitorable = false
	set_physics_process(false)
	set_process_unhandled_input(false)
	died.emit()

func get_runtime_state() -> Dictionary:
	return {
		"move_speed": move_speed,
		"dodge_distance": dodge_distance,
		"dodge_duration": dodge_duration,
		"dodge_cooldown": dodge_cooldown,
		"melee_damage": melee_damage,
		"melee_range": melee_range,
		"melee_cooldown": melee_cooldown,
		"ranged_damage": ranged_damage,
		"ranged_speed": ranged_speed,
		"ranged_cooldown": ranged_cooldown,
		"max_health": max_health,
		"health": health,
		"damage_reduction": damage_reduction,
		"regeneration_amount": regeneration_amount,
		"regeneration_interval": regeneration_interval
	}

func apply_runtime_state(state: Dictionary) -> void:
	move_speed = state.get("move_speed", move_speed)
	dodge_distance = state.get("dodge_distance", dodge_distance)
	dodge_duration = state.get("dodge_duration", dodge_duration)
	dodge_cooldown = state.get("dodge_cooldown", dodge_cooldown)
	melee_damage = int(state.get("melee_damage", melee_damage))
	melee_range = state.get("melee_range", melee_range)
	melee_cooldown = state.get("melee_cooldown", melee_cooldown)
	ranged_damage = int(state.get("ranged_damage", ranged_damage))
	ranged_speed = state.get("ranged_speed", ranged_speed)
	ranged_cooldown = state.get("ranged_cooldown", ranged_cooldown)
	max_health = int(state.get("max_health", max_health))
	health = clampi(int(state.get("health", health)), 0, max_health)
	damage_reduction = state.get("damage_reduction", damage_reduction)
	regeneration_amount = int(state.get("regeneration_amount", regeneration_amount))
	regeneration_interval = state.get("regeneration_interval", regeneration_interval)
	regeneration_timer = 0.0

func get_melee_knockback_force() -> float:
	var bonus_damage := maxf(0.0, float(melee_damage - 35))
	return melee_knockback_base + bonus_damage * melee_knockback_per_damage

func _update_weapon_pose() -> void:
	var weapon: Node3D = $Weapon
	if melee_swing_duration <= 0.0:
		weapon.transform = Transform3D(weapon_rest_basis, weapon_rest_position)
		return
	
	var swing_strength := 0.0
	if melee_swing_timer > 0.0:
		var progress := 1.0 - (melee_swing_timer / melee_swing_duration)
		swing_strength = sin(progress * PI)
	
	var swing_angle := deg_to_rad(95.0) * swing_strength
	var swing_basis := Basis.from_euler(Vector3(-swing_angle * 0.2, 0.0, swing_angle))
	var swing_offset := Vector3(0.10, -0.05, -0.12) * swing_strength
	weapon.transform = Transform3D(weapon_rest_basis * swing_basis, weapon_rest_position + swing_offset)

func get_mouse_plane_point(plane_y: float) -> Variant:
	var viewport = get_viewport()
	if not viewport:
		return null
	
	var camera = viewport.get_camera_3d()
	if not camera:
		return null
	
	var mouse_pos = viewport.get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var dir = camera.project_ray_normal(mouse_pos)
	var plane = Plane(Vector3.UP, plane_y)
	return plane.intersects_ray(from, dir)

func get_mouse_aim_target() -> Variant:
	var viewport = get_viewport()
	if not viewport:
		return null
	
	var camera = viewport.get_camera_3d()
	if not camera:
		return null
	
	var mouse_pos = viewport.get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var dir = camera.project_ray_normal(mouse_pos)
	var to = from + dir * 200.0
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 3, [get_rid()])
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var result: Dictionary = space_state.intersect_ray(query)
	if not result.is_empty():
		return result.get("position")
	return get_mouse_plane_point(0.0)
