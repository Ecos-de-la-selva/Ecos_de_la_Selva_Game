extends EnemyBase

@export var hover_speed: float = 1.8
@export var hover_amplitude: float = 8.0
@export var dive_speed: float = 280.0
@export var detection_radius: float = 320.0
@export var vertical_detection_range: float = 220.0
@export var dive_cooldown: float = 1.5
@export var return_speed: float = 220.0
@export var dive_max_time: float = 0.9
@export var dive_reach_distance: float = 10.0
@export var attack_interval: float = 1.0

var _origin_position: Vector2
var _dive_target_position: Vector2 = Vector2.ZERO
var _state: int = 0
var _can_dive: bool = true
var _time: float = 0.0
var _dive_time: float = 0.0
var _attack_timer: float = 0.0

@onready var visual: AnimatedSprite2D = $Visual

enum WaspState {
	HOVER = 0,
	DIVE = 1,
	RETURN = 2
}

func _ready() -> void:
	super._ready()
	_origin_position = global_position
	visual.play("idle")
	_state = WaspState.HOVER
	_attack_timer = attack_interval

func _physics_process(delta: float) -> void:
	_time += delta

	var player := _get_player_target()
	match _state:
		WaspState.HOVER:
			_hover(delta, player)
		WaspState.DIVE:
			_dive(delta)
		WaspState.RETURN:
			_return_to_origin(delta)

	try_deal_contact_damage()

func _hover(delta: float, player: Node2D) -> void:
	var target_position := Vector2(_origin_position.x, _origin_position.y + sin(_time * hover_speed) * hover_amplitude)
	global_position = global_position.move_toward(target_position, return_speed * delta)
	velocity = Vector2.ZERO
	_try_start_dive(player)

func _try_start_dive(player: Node2D) -> void:
	if not _can_dive:
		return
	if player == null:
		return

	_attack_timer -= get_physics_process_delta_time()
	if _attack_timer > 0.0:
		return
	_attack_timer = attack_interval

	var horizontal_distance := absf(player.global_position.x - global_position.x)
	var vertical_distance := absf(player.global_position.y - global_position.y)
	if horizontal_distance <= detection_radius and vertical_distance <= vertical_detection_range:
		_start_dive(player.global_position)

func _start_dive(target_position: Vector2) -> void:
	_dive_target_position = target_position
	_state = WaspState.DIVE
	_dive_time = 0.0
	visual.play("attack")

func _dive(delta: float) -> void:
	_dive_time += delta

	global_position = global_position.move_toward(_dive_target_position, dive_speed * delta)
	velocity = Vector2.ZERO

	if _dive_time >= dive_max_time:
		_end_dive()
		return

	if global_position.distance_to(_dive_target_position) <= dive_reach_distance:
		_end_dive()

func _end_dive() -> void:
	_state = WaspState.RETURN
	velocity = Vector2.ZERO
	visual.play("idle")
	_start_dive_cooldown()

func _return_to_origin(delta: float) -> void:
	global_position = global_position.move_toward(_origin_position, return_speed * delta)
	velocity = Vector2.ZERO
	if global_position.distance_to(_origin_position) < 2.0:
		_state = WaspState.HOVER

func _start_dive_cooldown() -> void:
	_can_dive = false
	await get_tree().create_timer(dive_cooldown).timeout
	_can_dive = true

func _get_player_target() -> Node2D:
	var by_group := get_tree().get_first_node_in_group("player") as Node2D
	if by_group != null:
		return by_group

	var parent := get_parent()
	if parent != null and parent.has_node("Personaje1"):
		return parent.get_node("Personaje1") as Node2D

	return null
