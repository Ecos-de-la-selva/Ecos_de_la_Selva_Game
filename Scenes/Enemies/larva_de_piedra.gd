extends EnemyBase

@export var move_speed: float = 70.0
@export var shell_push_speed: float = 320.0
@export var shell_duration: float = 2.0
@export var shell_friction: float = 380.0

var move_direction: float = -1.0
var in_shell: bool = false

@onready var shell_timer: Timer = $ShellTimer
@onready var shape: CollisionShape2D = $CollisionShape2D
@onready var visual: AnimatedSprite2D = $Visual
@onready var body_shape: RectangleShape2D = shape.shape

func _ready() -> void:
	super._ready()
	visual.play("walk")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if in_shell:
		if absf(velocity.x) > 0.0:
			velocity.x = move_toward(velocity.x, 0.0, shell_friction * delta)
	else:
		velocity.x = move_direction * move_speed

	move_and_slide()
	visual.flip_h = move_direction > 0.0
	_handle_wall_turn()
	_check_player_stomp()

func _handle_wall_turn() -> void:
	if in_shell:
		return

	if is_on_wall():
		move_direction *= -1.0

func _check_player_stomp() -> void:
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var collider := collision.get_collider() as Node
		if collider == null:
			continue
		if not collider.is_in_group("player"):
			continue

		var collider_node_2d := collider as Node2D
		if collider_node_2d == null:
			continue

		var player_above: bool = collider_node_2d.global_position.y < global_position.y - 6.0
		var player_falling: bool = false
		var collider_body := collider as CharacterBody2D
		if collider_body != null:
			player_falling = collider_body.velocity.y > 120.0

		if player_above and player_falling and not in_shell:
			enter_shell()
			if collider.has_method("bounce"):
				collider.bounce()
			return

func enter_shell() -> void:
	in_shell = true
	move_direction = 0.0
	velocity.x = 0.0
	shell_timer.start(shell_duration)
	visual.play("shell")
	body_shape.size = Vector2(18.0, 12.0)
	shape.position.y = 10.0

func _on_shell_timer_timeout() -> void:
	in_shell = false
	move_direction = -1.0 if randf() < 0.5 else 1.0
	visual.play("walk")
	body_shape.size = Vector2(18.0, 20.0)
	shape.position.y = 6.0

func take_damage(amount: int = 1, hit_direction: float = 0.0, push_force: float = 0.0) -> void:
	if in_shell:
		var direction := hit_direction
		if direction == 0.0:
			direction = -1.0
		velocity.x = direction * shell_push_speed
		return

	super.take_damage(amount, hit_direction, push_force)
