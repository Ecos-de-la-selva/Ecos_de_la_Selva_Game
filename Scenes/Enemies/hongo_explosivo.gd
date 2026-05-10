extends EnemyBase

@export var trigger_radius: float = 92.0
@export var explode_delay: float = 1.0
@export var explosion_radius: float = 82.0
@export var explosion_damage: int = 30

var _is_arming: bool = false

@onready var visual: Polygon2D = $Visual

func _physics_process(_delta: float) -> void:
	if _is_arming:
		return
	var player := _get_player_target()
	if player == null:
		return
	if global_position.distance_to(player.global_position) > trigger_radius:
		return
	_arm_and_explode()

func _arm_and_explode() -> void:
	_is_arming = true
	var tree := get_tree()
	if tree == null:
		return

	var tween := tree.create_tween()
	tween.tween_property(visual, "scale", Vector2(1.25, 1.25), explode_delay)
	tween.parallel().tween_property(visual, "modulate", Color(1.0, 0.35, 0.2, 1.0), explode_delay)
	await tree.create_timer(explode_delay).timeout

	var player := _get_player_target()
	if player != null and player.has_method("recibir_danio"):
		if global_position.distance_to(player.global_position) <= explosion_radius:
			player.recibir_danio(explosion_damage, global_position)

	die()

func take_damage(amount: int = 1, hit_direction: float = 0.0, push_force: float = 0.0) -> void:
	super.take_damage(amount, hit_direction, push_force)
	if health <= 0:
		return
	# Si lo golpean mientras se infla, detona más rápido.
	if _is_arming:
		explode_delay = min(explode_delay, 0.35)
