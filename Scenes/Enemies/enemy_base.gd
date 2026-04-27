class_name EnemyBase
extends CharacterBody2D

@export var max_health: int = 3
@export var contact_damage: int = 1
@export var damage_invulnerability_time: float = 0.15
@export var contact_damage_radius: float = 80.0
@export var contact_damage_interval: float = 0.35
@export var hit_sfx_normal: AudioStream
@export var hit_sfx_heavy: AudioStream

var health: int
var _can_receive_damage: bool = true
var _can_deal_contact_damage: bool = true
var _visual_flash_running: bool = false
var _hit_audio_player: AudioStreamPlayer2D

func _ready() -> void:
	health = max_health
	_hit_audio_player = AudioStreamPlayer2D.new()
	_hit_audio_player.name = "HitAudio"
	add_child(_hit_audio_player)

func take_damage(amount: int = 1, hit_direction: float = 0.0, push_force: float = 0.0) -> void:
	if not _can_receive_damage:
		return

	health -= amount
	_can_receive_damage = false
	_show_damage_feedback(amount)

	if push_force > 0.0 and hit_direction != 0.0:
		velocity.x = hit_direction * push_force

	if health <= 0:
		die()
		return

	_start_damage_cooldown()

func _show_damage_feedback(amount: int) -> void:
	_play_hit_sfx(amount)
	_spawn_damage_popup(amount)
	_spawn_hit_particles(amount)
	_flash_visual()

func _play_hit_sfx(amount: int) -> void:
	if _hit_audio_player == null:
		return
	var strong_hit := amount > 1
	var stream := hit_sfx_heavy if strong_hit else hit_sfx_normal
	if stream == null and strong_hit:
		stream = hit_sfx_normal
	if stream == null:
		return
	_hit_audio_player.stream = stream
	_hit_audio_player.pitch_scale = randf_range(0.94, 1.08)
	_hit_audio_player.play()

func _spawn_damage_popup(amount: int) -> void:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return

	var popup_root := Node2D.new()
	popup_root.top_level = true
	popup_root.global_position = global_position + Vector2(-8, -28)
	popup_root.z_as_relative = false
	popup_root.z_index = 220
	tree.current_scene.add_child(popup_root)

	var popup := Label.new()
	popup.text = "-" + str(amount)
	popup.position = Vector2.ZERO
	popup.scale = Vector2(1.25, 1.25)
	popup.modulate = Color(1.0, 0.25, 0.25, 1.0) if amount > 1 else Color(1.0, 0.95, 0.45, 1.0)
	var settings := LabelSettings.new()
	settings.font_size = 24
	settings.outline_size = 3
	settings.outline_color = Color(0, 0, 0, 0.95)
	popup.label_settings = settings
	popup_root.add_child(popup)

	var tween := tree.create_tween()
	tween.tween_property(popup_root, "global_position", popup_root.global_position + Vector2(0, -26), 0.45)
	tween.parallel().tween_property(popup, "modulate:a", 0.0, 0.45)
	tween.finished.connect(func() -> void:
		if is_instance_valid(popup_root):
			popup_root.queue_free()
	)

func _spawn_hit_particles(amount: int) -> void:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return

	var particles := CPUParticles2D.new()
	particles.global_position = global_position + Vector2(0, -6)
	particles.z_index = 180
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 12 if amount > 1 else 8
	particles.lifetime = 0.18
	particles.direction = Vector2.RIGHT
	particles.spread = 180.0
	particles.initial_velocity_min = 45.0
	particles.initial_velocity_max = 95.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 3.2
	particles.color = Color(1.0, 0.35, 0.35, 1.0) if amount > 1 else Color(1.0, 0.95, 0.85, 1.0)
	tree.current_scene.add_child(particles)
	particles.emitting = true

	var cleanup_timer := tree.create_timer(0.35)
	cleanup_timer.timeout.connect(func() -> void:
		if is_instance_valid(particles):
			particles.queue_free()
	)

func _flash_visual() -> void:
	if _visual_flash_running:
		return
	var visual := get_node_or_null("Visual") as CanvasItem
	if visual == null:
		return

	_visual_flash_running = true
	visual.modulate = Color(1.0, 0.93, 0.85, 1.0)
	var tree := get_tree()
	if tree == null:
		visual.modulate = Color(1, 1, 1, 1)
		_visual_flash_running = false
		return
	await tree.create_timer(0.08).timeout
	if not is_instance_valid(visual):
		_visual_flash_running = false
		return
	visual.modulate = Color(1, 1, 1, 1)
	_visual_flash_running = false

func _start_damage_cooldown() -> void:
	if not is_inside_tree():
		_can_receive_damage = true
		return
	var tree := get_tree()
	if tree == null:
		_can_receive_damage = true
		return
	await tree.create_timer(damage_invulnerability_time).timeout
	if not is_instance_valid(self):
		return
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
	if not is_inside_tree():
		_can_deal_contact_damage = true
		return
	var tree := get_tree()
	if tree == null:
		_can_deal_contact_damage = true
		return
	await tree.create_timer(contact_damage_interval).timeout
	if not is_instance_valid(self):
		return
	_can_deal_contact_damage = true

func _get_player_target() -> Node2D:
	var tree := get_tree()
	if tree == null:
		return null
	var by_group := tree.get_first_node_in_group("player") as Node2D
	if by_group != null:
		return by_group

	var current_scene := tree.current_scene
	if current_scene != null and current_scene.has_node("Personaje1"):
		return current_scene.get_node("Personaje1") as Node2D

	return null

func die() -> void:
	queue_free()
