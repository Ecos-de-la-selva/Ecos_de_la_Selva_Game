extends Area2D

@export var speed: float = 220.0
@export var damage: int = 12
@export var lifetime: float = 2.5

var _direction: Vector2 = Vector2.DOWN

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_start_lifetime()

func _physics_process(delta: float) -> void:
	global_position += _direction * speed * delta

func set_direction(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		_direction = Vector2.DOWN
	else:
		_direction = dir.normalized()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if body.has_method("recibir_danio"):
			body.recibir_danio(damage, global_position)
		queue_free()
		return
	if not body.is_in_group("enemies"):
		queue_free()

func _start_lifetime() -> void:
	var tree := get_tree()
	if tree == null:
		return
	await tree.create_timer(lifetime).timeout
	if is_instance_valid(self):
		queue_free()
