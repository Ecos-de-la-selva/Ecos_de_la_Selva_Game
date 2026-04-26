class_name EnemyBase
extends CharacterBody2D

@export var max_health: int = 3
@export var contact_damage: int = 1
@export var damage_invulnerability_time: float = 0.15
@export var contact_damage_radius: float = 80.0
@export var contact_damage_interval: float = 0.35

var health: int
var _can_receive_damage: bool = true
var _can_deal_contact_damage: bool = true

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

func try_deal_contact_damage() -> void:
	if not _can_deal_contact_damage:
		return

	var player := _get_player_target()
	if player == null:
		return
	if global_position.distance_to(player.global_position) > contact_damage_radius:
		return
	if not player.has_method("recibir_danio"):
		return

	var damage_amount: int = int(max(contact_damage * 12, 20))
	player.recibir_danio(damage_amount, global_position)
	_can_deal_contact_damage = false
	_start_contact_damage_cooldown()

func _start_contact_damage_cooldown() -> void:
	var tree := get_tree()
	if tree == null:
		_can_deal_contact_damage = true
		return
	await tree.create_timer(contact_damage_interval).timeout
	_can_deal_contact_damage = true

func _get_player_target() -> Node2D:
	var by_group := get_tree().get_first_node_in_group("player") as Node2D
	if by_group != null:
		return by_group

	var current_scene := get_tree().current_scene
	if current_scene != null and current_scene.has_node("Personaje1"):
		return current_scene.get_node("Personaje1") as Node2D

	return null

func die() -> void:
	queue_free()
