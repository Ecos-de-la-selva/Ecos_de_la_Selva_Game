extends Node2D

@onready var altar_text: Label = $UI/AltarText
@onready var boss_text: Label = $UI/BossText
@onready var barrier: StaticBody2D = $BarreraRaices
@onready var barrier_collision: CollisionShape2D = $BarreraRaices/CollisionShape2D
@onready var barrier_visual: Polygon2D = $BarreraRaices/Visual
@onready var exit_area: Area2D = $Salida
@onready var next_level_text: Label = $UI/NextLevelText
@onready var mid_barrier_collision: CollisionShape2D = $BarreraIntermedia/CollisionShape2D
@onready var mid_barrier_visual: Polygon2D = $BarreraIntermedia/Visual
@onready var spikes: Array[Node2D] = [$PinchosA, $PinchosB, $PinchosC]
@onready var ground_bodies: Array[Node2D] = [$LarvaA, $LarvaB, $GuardianCaido]
@onready var larva_a: Node2D = get_node_or_null("LarvaA")
@onready var larva_b: Node2D = get_node_or_null("LarvaB")

var _mid_barrier_opened: bool = false
var _spikes_active: bool = true
@export var spikes_cycle_enabled: bool = false

func _ready() -> void:
	altar_text.visible = false
	boss_text.visible = true
	next_level_text.visible = false
	exit_area.monitoring = false
	$GuardianCaido.defeated.connect(_on_guardian_defeated)
	_start_level_alignment()
	if spikes_cycle_enabled:
		_start_spike_cycle()
	else:
		_set_spikes_state(true)

func _process(_delta: float) -> void:
	if _mid_barrier_opened:
		return

	if not is_instance_valid(larva_a) and not is_instance_valid(larva_b):
		_mid_barrier_opened = true
		mid_barrier_collision.disabled = true
		mid_barrier_visual.visible = false
		altar_text.text = "Paso despejado. Avanza hacia el guardian."

func _on_altar_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		altar_text.visible = true

func _on_altar_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		altar_text.visible = false

func _on_guardian_defeated() -> void:
	boss_text.text = "Guardian derrotado. Las raices se abren."
	barrier_collision.disabled = true
	barrier_visual.visible = false
	exit_area.monitoring = true
	next_level_text.visible = true

func _on_salida_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		get_tree().change_scene_to_file("res://Scenes/Screen/escreen1.tscn")

func _start_spike_cycle() -> void:
	while is_inside_tree():
		_set_spikes_state(true)
		await get_tree().create_timer(1.4).timeout
		_set_spikes_state(false)
		await get_tree().create_timer(1.0).timeout

func _set_spikes_state(active: bool) -> void:
	_spikes_active = active
	for spike in spikes:
		var visual := spike.get_node_or_null("Visual") as Polygon2D
		if visual != null:
			visual.color = Color(0.35, 0.35, 0.35, 1.0) if active else Color(0.18, 0.18, 0.18, 0.85)
			visual.scale.y = 1.0 if active else 0.55

func _start_level_alignment() -> void:
	_align_after_physics()

func _align_after_physics() -> void:
	await get_tree().physics_frame
	_align_level_objects_to_ground()
	# Segunda pasada por seguridad para escenas cargadas en el mismo frame.
	await get_tree().physics_frame
	_align_level_objects_to_ground()

func _align_level_objects_to_ground() -> void:
	var space_state := get_world_2d().direct_space_state
	for spike in spikes:
		_snap_node_bottom_to_ground(spike, space_state)
	for body in ground_bodies:
		_snap_node_bottom_to_ground(body, space_state)
	for node_name in ["BarreraIntermedia", "BarreraRaices", "PlataformaCaidaA", "PlataformaCaidaB", "PlataformaCaidaC"]:
		var node := get_node_or_null(node_name) as Node2D
		if node != null:
			_snap_node_bottom_to_ground(node, space_state)

func _snap_node_bottom_to_ground(node: Node2D, space_state: PhysicsDirectSpaceState2D) -> void:
	var shape_node := node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or shape_node.shape == null:
		return

	var bottom_offset := _shape_bottom_offset(shape_node)
	if bottom_offset <= 0.0:
		return

	var from := Vector2(node.global_position.x, -200.0)
	var to := Vector2(node.global_position.x, 2000.0)
	var query := PhysicsRayQueryParameters2D.create(from, to, 1)
	query.exclude = [node.get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = 0x7fffffff
	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		return

	node.global_position.y = hit.position.y - bottom_offset

func _shape_bottom_offset(shape_node: CollisionShape2D) -> float:
	var shape := shape_node.shape
	var scale_y := absf(shape_node.global_scale.y)
	if scale_y <= 0.0:
		scale_y = 1.0
	var half_height := _shape_half_height(shape) * scale_y
	if half_height <= 0.0:
		return 0.0
	return shape_node.position.y * scale_y + half_height

func _shape_half_height(shape: Shape2D) -> float:
	if shape is RectangleShape2D:
		return (shape as RectangleShape2D).size.y * 0.5
	if shape is CapsuleShape2D:
		var capsule := shape as CapsuleShape2D
		return capsule.height * 0.5 + capsule.radius
	if shape is CircleShape2D:
		return (shape as CircleShape2D).radius
	return 0.0
