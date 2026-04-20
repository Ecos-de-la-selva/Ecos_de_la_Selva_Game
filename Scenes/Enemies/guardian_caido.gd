extends EnemyBase

signal defeated

@export var walk_speed: float = 80.0
@export var activation_distance: float = 220.0
@export var teleport_distance: float = 70.0
@export var teleport_cooldown: float = 2.0
@export var patrol_range: float = 120.0

var _phase_two: bool = false
var _can_teleport: bool = true
var _spawn_x: float = 0.0
var _patrol_direction: float = -1.0

@onready var visual: AnimatedSprite2D = $Visual

func _ready() -> void:
	super._ready()
	_spawn_x = global_position.x
	visual.play("idle")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	var player := _get_player_target()
	if player == null:
		_patrol()
		move_and_slide()
		return

	var distance := global_position.distance_to(player.global_position)
	if distance < activation_distance:
		var delta_x := player.global_position.x - global_position.x
		var direction := signf(delta_x)
		if direction == 0.0:
			direction = _patrol_direction
		velocity.x = direction * walk_speed
		_patrol_direction = direction
		visual.flip_h = direction < 0.0
		visual.play("run")

		if _phase_two and _can_teleport:
			_can_teleport = false
			_short_teleport(direction)
	else:
		_patrol()

	move_and_slide()

func _patrol() -> void:
	if global_position.x < _spawn_x - patrol_range:
		_patrol_direction = 1.0
	elif global_position.x > _spawn_x + patrol_range:
		_patrol_direction = -1.0

	velocity.x = _patrol_direction * (walk_speed * 0.55)
	visual.flip_h = _patrol_direction < 0.0
	visual.play("run")

func take_damage(amount: int = 1, hit_direction: float = 0.0, push_force: float = 0.0) -> void:
	super.take_damage(amount, hit_direction, push_force)
	if float(health) <= float(max_health) * 0.5 and not _phase_two:
		_phase_two = true

func _short_teleport(direction: float) -> void:
	global_position.x += direction * teleport_distance
	await get_tree().create_timer(teleport_cooldown).timeout
	_can_teleport = true

func die() -> void:
	defeated.emit()
	queue_free()

func _get_player_target() -> Node2D:
	var by_group := get_tree().get_first_node_in_group("player") as Node2D
	if by_group != null:
		return by_group

	var parent := get_parent()
	if parent != null and parent.has_node("Personaje1"):
		return parent.get_node("Personaje1") as Node2D

	return null
