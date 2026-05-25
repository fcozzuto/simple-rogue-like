extends Area3D

@export var item_type: String = "health_potion"  # "health_potion" or "weapon_upgrade"

var player: Node3D = null
var can_pickup: bool = true

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	setup_visuals()
	call_deferred("_check_initial_overlap")

func setup_visuals() -> void:
	var mesh = $Mesh
	var mat = StandardMaterial3D.new()
	
	if item_type == "health_potion":
		var potion_mesh := CylinderMesh.new()
		potion_mesh.top_radius = 0.2
		potion_mesh.bottom_radius = 0.2
		potion_mesh.height = 0.3
		mesh.mesh = potion_mesh
		mat.albedo_color = Color("#00ff00")
		mat.emission_enabled = true
		mat.emission = Color("#00ff00")
		mat.emission_energy_multiplier = 2.0
	elif item_type == "weapon_upgrade":
		var box_mesh := BoxMesh.new()
		box_mesh.size = Vector3(0.3, 0.3, 0.3)
		mesh.mesh = box_mesh
		mat.albedo_color = Color("#ffff00")
		mat.emission_enabled = true
		mat.emission = Color("#ffff00")
		mat.emission_energy_multiplier = 2.0
	
	mesh.set_surface_override_material(0, mat)

func _on_body_entered(body: Node3D) -> void:
	try_collect(body)

func _on_area_entered(area: Area3D) -> void:
	try_collect(area)

func apply_effect(player_body: Node3D) -> void:
	if item_type == "health_potion":
		player_body.heal(30)
	elif item_type == "weapon_upgrade":
		player_body.ranged_damage += 15
		var main = get_tree().get_first_node_in_group("main")
		if main:
			main.player_state["ranged_damage"] = player_body.ranged_damage

func try_collect(collider: Node) -> void:
	if not can_pickup:
		return
	
	var player_body: Node3D = resolve_player(collider)
	if not player_body:
		return
	
	can_pickup = false
	apply_effect(player_body)
	queue_free()

func resolve_player(collider: Node) -> Node3D:
	if collider == null:
		return null
	if collider.is_in_group("player"):
		return collider
	if collider is Area3D:
		var parent := collider.get_parent()
		if parent and parent.is_in_group("player") and collider.name == "PickupArea":
			return parent
	return null

func _check_initial_overlap() -> void:
	await get_tree().physics_frame
	await get_tree().process_frame
	if not can_pickup:
		return
	
	for body in get_overlapping_bodies():
		try_collect(body)
		if not can_pickup:
			return
	
	for area in get_overlapping_areas():
		try_collect(area)
		if not can_pickup:
			return
