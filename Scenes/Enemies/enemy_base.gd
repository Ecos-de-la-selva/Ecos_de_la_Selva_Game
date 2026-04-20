class_name EnemyBase
extends CharacterBody2D

@export var max_health: int = 3
@export var contact_damage: int = 1
@export var damage_invulnerability_time: float = 0.15

var health: int
var _can_receive_damage: bool = true

func _ready() -> void:
	health = max_health

func take_damage(amount: int = 1, hit_direction: float = 0.0, push_force: float = 0.0) -> void:
	if not _can_receive_damage:
		return

	health -= amount
	_can_receive_damage = false

	if push_force > 0.0 and hit_direction != 0.0:
		velocity.x = hit_direction * push_force

	if health <= 0:
		die()
		return

	_start_damage_cooldown()

func _start_damage_cooldown() -> void:
	await get_tree().create_timer(damage_invulnerability_time).timeout
	_can_receive_damage = true

func die() -> void:
	queue_free()
