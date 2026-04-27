extends EnemyBase

signal defeated

@export var walk_speed: float = 80.0
@export var activation_distance: float = 220.0
@export var teleport_distance: float = 70.0
@export var teleport_cooldown: float = 2.0
@export var patrol_range: float = 120.0
@export var acceleration: float = 520.0
@export var phase2_dash_speed: float = 220.0
@export var phase2_dash_duration: float = 0.22
@export var phase2_dash_cooldown: float = 1.15
@export var spear_attack_range: float = 72.0
@export var spear_attack_cooldown: float = 1.25
@export var spear_windup_time: float = 0.16
@export var spear_lunge_distance: float = 44.0
@export var spear_hit_range: float = 74.0
@export var spear_damage: int = 26

var _phase_two: bool = false
var _can_teleport: bool = true
var _can_dash: bool = true
var _is_dashing: bool = false
var _can_spear_attack: bool = true
var _is_spear_attacking: bool = false
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

	if _is_dashing or _is_spear_attacking:
		move_and_slide()
		try_deal_contact_damage()
		return

	var player := _get_player_target()
	if player == null:
		_patrol()
		move_and_slide()
		try_deal_contact_damage()
		return

	var distance := global_position.distance_to(player.global_position)
	if distance < activation_distance:
		var delta_x := player.global_position.x - global_position.x
		var direction := signf(delta_x)
		if direction == 0.0:
			direction = _patrol_direction
		if absf(delta_x) <= spear_attack_range and _can_spear_attack:
			_start_spear_attack(direction)
			move_and_slide()
			try_deal_contact_damage()
			return
		var target_speed := direction * walk_speed
		velocity.x = move_toward(velocity.x, target_speed, acceleration * delta)
		_patrol_direction = direction
		visual.flip_h = direction < 0.0
		visual.play("run")

		if _phase_two and _can_teleport:
			_can_teleport = false
			_short_teleport(direction)
		if _phase_two and _can_dash:
			_start_dash(direction)
	else:
		_patrol()

	move_and_slide()
	try_deal_contact_damage()

func _patrol() -> void:
	if global_position.x < _spawn_x - patrol_range:
		_patrol_direction = 1.0
	elif global_position.x > _spawn_x + patrol_range:
		_patrol_direction = -1.0

	var target_speed := _patrol_direction * (walk_speed * 0.55)
	velocity.x = move_toward(velocity.x, target_speed, acceleration * 0.75 * get_physics_process_delta_time())
	visual.flip_h = _patrol_direction < 0.0
	if absf(velocity.x) > 12.0:
		visual.play("run")
	else:
		visual.play("idle")

func take_damage(amount: int = 1, hit_direction: float = 0.0, push_force: float = 0.0) -> void:
	super.take_damage(amount, hit_direction, push_force)
	if float(health) <= float(max_health) * 0.5 and not _phase_two:
		_phase_two = true

func _short_teleport(direction: float) -> void:
	global_position.x += direction * teleport_distance
	await get_tree().create_timer(teleport_cooldown).timeout
	_can_teleport = true

func _start_dash(direction: float) -> void:
	_can_dash = false
	_is_dashing = true
	velocity.x = direction * phase2_dash_speed
	visual.play("run")
	await get_tree().create_timer(phase2_dash_duration).timeout
	_is_dashing = false
	velocity.x = direction * (walk_speed * 0.6)
	await get_tree().create_timer(phase2_dash_cooldown).timeout
	_can_dash = true

func _start_spear_attack(direction: float) -> void:
	_can_spear_attack = false
	_is_spear_attacking = true
	velocity.x = 0.0
	visual.flip_h = direction < 0.0
	visual.play("idle")

	var tree := get_tree()
	if tree == null:
		_is_spear_attacking = false
		_can_spear_attack = true
		return

	await tree.create_timer(spear_windup_time).timeout

	var player := _get_player_target()
	if player != null:
		var final_dir := signf(player.global_position.x - global_position.x)
		if final_dir == 0.0:
			final_dir = direction if direction != 0.0 else 1.0
		visual.flip_h = final_dir < 0.0
		global_position.x += final_dir * spear_lunge_distance
		_try_apply_spear_damage(player, final_dir)

	_is_spear_attacking = false
	await tree.create_timer(spear_attack_cooldown).timeout
	_can_spear_attack = true

func _try_apply_spear_damage(player: Node2D, attack_dir: float) -> void:
	if not player.has_method("recibir_danio"):
		return
	var delta := player.global_position - global_position
	if absf(delta.y) > 56.0:
		return
	if absf(delta.x) > spear_hit_range:
		return
	var same_side := signf(delta.x) == attack_dir or absf(delta.x) <= 10.0
	if not same_side:
		return
	player.recibir_danio(spear_damage, global_position)

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
