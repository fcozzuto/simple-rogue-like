extends Area3D

@export var damage: int = 20
@export var speed: float = 22.0
@export var lifespan: float = 3.0
@export var direction: Vector3 = Vector3.BACK
@export var source: String = "player"  # "player" or "turret"

var lifetime: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	# Move projectile
	var motion := direction.normalized() * speed * delta
	var next_position := global_position + motion
	if _check_hit(global_position, next_position):
		return
	global_position = next_position
	
	# Orient mesh to face travel direction
	if direction.length() > 0.1:
		look_at(global_position + direction.normalized(), Vector3.UP)
	
	# Check lifespan
	lifetime += delta
	if lifetime >= lifespan:
		queue_free()
	
	# Check if out of bounds
	var pos := global_position
	if abs(pos.x) > 16 or abs(pos.z) > 16 or pos.y < -1 or pos.y > 5:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	_handle_hit(body)

func _check_hit(from: Vector3, to: Vector3) -> bool:
	if from.is_equal_approx(to):
		return false
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask, [get_rid()])
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return false
	var collider = result.get("collider")
	if collider:
		_handle_hit(collider)
		return true
	return false

func _handle_hit(body: Node) -> void:
	if source == "player":
		# Player projectile hits enemies
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
	elif source == "turret":
		# Turret projectile hits player
		if body.is_in_group("player"):
			body.take_damage(damage)
		queue_free()

func set_enemy_color() -> void:
	# Change material to enemy color (hot pink)
	var mesh = $MeshInstance3D
	if mesh and mesh.get_surface_override_material(0):
		var mat = mesh.get_surface_override_material(0).duplicate()
		mat.albedo_color = Color("#ff0066")
		mat.emission = Color("#ff0066")
		mesh.set_surface_override_material(0, mat)
