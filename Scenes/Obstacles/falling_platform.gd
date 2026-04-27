extends AnimatableBody2D

@export var fall_delay: float = 0.45
@export var fall_speed: float = 165.0
@export var respawn_time: float = 2.8
@export var shake_distance: float = 2.5
@export var shake_speed: float = 45.0
@export var respawn_enabled: bool = true
@export var spike_targets: Array[NodePath] = []
@export var spike_camera_shake_enabled: bool = true
@export var spike_camera_shake_strength: float = 2.0
@export var spike_camera_shake_duration: float = 0.12

var _origin_position: Vector2
var _is_triggered: bool = false
var _is_falling: bool = false
var _shake_time: float = 0.0

@onready var collider: CollisionShape2D = $CollisionShape2D
@onready var trigger_area: Area2D = $TriggerArea
@onready var visual: Polygon2D = $Visual

func _ready() -> void:
	_origin_position = global_position
	trigger_area.body_entered.connect(_on_trigger_body_entered)

func _physics_process(delta: float) -> void:
	if _is_triggered and not _is_falling:
		_shake_time += delta * shake_speed
		global_position.x = _origin_position.x + sin(_shake_time) * shake_distance
		return

	if _is_falling:
		global_position.y += fall_speed * delta

func _on_trigger_body_entered(body: Node) -> void:
	if _is_triggered or _is_falling:
		return
	if not body.is_in_group("player"):
		return
	_start_fall_sequence()

func _start_fall_sequence() -> void:
	_is_triggered = true
	visual.modulate = Color(1.0, 0.82, 0.82, 1.0)
	await get_tree().create_timer(fall_delay).timeout
	_activate_spike_targets()
	_is_falling = true
	visual.modulate = Color(0.88, 0.72, 0.72, 1.0)
	if not respawn_enabled:
		return
	await get_tree().create_timer(respawn_time).timeout
	_reset_platform()

func _reset_platform() -> void:
	_is_triggered = false
	_is_falling = false
	_shake_time = 0.0
	global_position = _origin_position
	collider.disabled = false
	visual.modulate = Color(0.45, 0.37, 0.2, 1.0)

func _activate_spike_targets() -> void:
	var tree := get_tree()
	if spike_camera_shake_enabled:
		_shake_player_camera()
	for target_path in spike_targets:
		var target := get_node_or_null(target_path)
		if target == null:
			continue
		var spike_shape := target.get_node_or_null("CollisionShape2D") as CollisionShape2D
		var spike_visual := target.get_node_or_null("Visual") as CanvasItem
		if spike_visual != null:
			spike_visual.visible = true
			spike_visual.modulate = Color(0.75, 0.25, 0.25, 1.0)
			spike_visual.scale = Vector2(1.0, 0.18)
			if tree != null:
				var tween := tree.create_tween()
				tween.tween_property(spike_visual, "scale:y", 1.0, 0.2)
		if spike_shape != null:
			spike_shape.disabled = true
			if tree != null:
				var timer := tree.create_timer(0.2)
				timer.timeout.connect(func() -> void:
					if is_instance_valid(spike_shape):
						spike_shape.disabled = false
				)
			else:
				spike_shape.disabled = false

func _shake_player_camera() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var player := tree.get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return

	var base_offset := camera.offset
	var elapsed := 0.0
	while elapsed < spike_camera_shake_duration and is_instance_valid(camera):
		camera.offset = base_offset + Vector2(
			randf_range(-spike_camera_shake_strength, spike_camera_shake_strength),
			randf_range(-spike_camera_shake_strength, spike_camera_shake_strength)
		)
		await tree.process_frame
		elapsed += get_process_delta_time()

	if is_instance_valid(camera):
		camera.offset = base_offset
