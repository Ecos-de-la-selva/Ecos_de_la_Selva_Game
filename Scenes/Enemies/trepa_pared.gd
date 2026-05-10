extends EnemyBase

@export var move_range: float = 90.0
@export var climb_speed: float = 75.0
@export var spit_interval: float = 2.0
@export var spit_scene: PackedScene = preload("res://Scenes/Enemies/AcidSpit.tscn")

var _origin_y: float = 0.0
var _direction: float = -1.0
var _can_spit: bool = true

@onready var visual: Polygon2D = $Visual

func _ready() -> void:
	super._ready()
	_origin_y = global_position.y

func _physics_process(delta: float) -> void:
	global_position.y += _direction * climb_speed * delta
	if global_position.y <= _origin_y - move_range:
		_direction = 1.0
	if global_position.y >= _origin_y + move_range:
		_direction = -1.0

	visual.scale.y = -1.0 if _direction < 0.0 else 1.0

	try_deal_contact_damage()
	_try_spit()

func _try_spit() -> void:
	if not _can_spit:
		return
	var player := _get_player_target()
	if player == null:
		return
	if absf(player.global_position.x - global_position.x) > 180.0:
		return
	if player.global_position.y < global_position.y - 16.0:
		return

	_can_spit = false
	var spit := spit_scene.instantiate() as Area2D
	if spit != null:
		spit.global_position = global_position + Vector2(0, 14)
		get_parent().add_child(spit)
		if spit.has_method("set_direction"):
			spit.set_direction(Vector2.DOWN)

	await get_tree().create_timer(spit_interval).timeout
	_can_spit = true
