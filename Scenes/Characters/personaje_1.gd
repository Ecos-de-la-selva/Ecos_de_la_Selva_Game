extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const ATTACK_DAMAGE = 1
const ATTACK_PUSH_FORCE = 150.0
const HitStopUtils = preload("res://Scripts/hit_stop.gd")

# --- VARIABLES DE SALUD ---
var salud_max = 100
var salud_actual = 100
var invulnerable_al_danio = false
var tiempo_invulnerable = 0.7
var tiempo_invulnerable_pinchos = 0.35
var radio_contacto_enemigo = 56.0
var danio_pinchos = 15
var radio_pinchos_x = 64.0
var rango_pinchos_y = 64.0
var _damage_flash_active = false
# Esta línea busca la barra de vida en la escena Screen que instanciaste
@onready var barra_vida: TextureProgressBar = null
@onready var body_shape: CollisionShape2D = $CollisionShape2D

# VARIABLE PARA EL ATAQUE
var is_attacking = false
var _already_hit_in_current_attack: Array[Node2D] = []

@onready var animaciones: AnimatedSprite2D = $Animaciones
@onready var attack_area: Area2D = $AttackArea
@onready var hurt_box: Area2D = $HurtBox

func _ready():
	_ensure_barra_vida()
	# Al empezar, aseguramos que la barra esté llena
	if barra_vida:
		barra_vida.max_value = salud_max
		barra_vida.value = salud_actual

func _physics_process(delta: float) -> void:
	# Gravedad
	if not is_on_floor():
		velocity += get_gravity() * delta

	# ATAQUE
	if _is_attack_pressed() and not is_attacking:
		attack()

	# Movimiento y Salto
	if not is_attacking:
		if _is_jump_pressed() and is_on_floor():
			velocity.y = JUMP_VELOCITY

		var direction := _get_move_axis()
		if direction:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
	
	move_and_slide()
	_check_spike_collision_damage()
	_check_hurt_box_damage()
	_check_spike_damage()
	decide_animation()

func attack():
	is_attacking = true
	_already_hit_in_current_attack.clear()

	if is_on_floor():
		animaciones.play("attack")
	else:
		animaciones.play("attackair")

	# Tiempo para que el golpe ocurra durante la animación
	await get_tree().create_timer(0.07).timeout
	_perform_attack_hit()

	await animaciones.animation_finished
	is_attacking = false

# --- FUNCIONES DE SALUD ---
func recibir_danio(cantidad: int, source_position: Vector2 = global_position):
	if invulnerable_al_danio:
		return

	_apply_damage(cantidad, source_position, tiempo_invulnerable)

func recibir_danio_pinchos(cantidad: int, source_position: Vector2 = global_position):
	if invulnerable_al_danio:
		return

	_apply_damage(cantidad, source_position, tiempo_invulnerable_pinchos)

func _apply_damage(cantidad: int, source_position: Vector2, invuln_time: float) -> void:
	invulnerable_al_danio = true
	_start_damage_flash()
	salud_actual -= cantidad
	salud_actual = clamp(salud_actual, 0, salud_max) # No bajar de 0
	
	_ensure_barra_vida()
	if barra_vida:
		barra_vida.value = salud_actual

	var knock_direction := signf(global_position.x - source_position.x)
	if knock_direction == 0.0:
		knock_direction = -1.0 if animaciones.flip_h else 1.0
	velocity.x = knock_direction * 170.0
	velocity.y = -170.0
	
	if salud_actual <= 0:
		_stop_damage_flash()
		morir()
		return

	await get_tree().create_timer(invuln_time).timeout
	invulnerable_al_danio = false
	_stop_damage_flash()

func morir():
	print("El indígena ha muerto")
	get_tree().reload_current_scene()

func decide_animation():
	if is_attacking:
		return

	if not is_on_floor():
		if velocity.y < 0:
			animaciones.play("jump_up")
		else:
			animaciones.play("jump_down")
	else:
		if velocity.x == 0:
			animaciones.play("Idle")
		else:
			animaciones.play("walk")

	if velocity.x < 0:
		animaciones.flip_h = true
	elif velocity.x > 0:
		animaciones.flip_h = false

	attack_area.position.x = -absf(attack_area.position.x) if animaciones.flip_h else absf(attack_area.position.x)

func _perform_attack_hit() -> void:
	for body in attack_area.get_overlapping_bodies():
		if body == null or not body.has_method("take_damage"):
			continue
		if body in _already_hit_in_current_attack:
			continue

		_already_hit_in_current_attack.append(body)

		var direction := 1.0
		if animaciones.flip_h:
			direction = -1.0

		body.take_damage(ATTACK_DAMAGE, direction, ATTACK_PUSH_FORCE)
		HitStopUtils.freeze(get_tree(), 0.05, 0.0)

func bounce(force: float = 260.0) -> void:
	velocity.y = -force

func _get_move_axis() -> float:
	var axis := Input.get_axis("ui_left", "ui_right")
	if axis != 0.0:
		return axis
	var left_pressed := Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)
	var right_pressed := Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)
	return float(int(right_pressed) - int(left_pressed))

func _is_jump_pressed() -> bool:
	return Input.is_action_just_pressed("ui_accept") or Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)

func _is_attack_pressed() -> bool:
	return Input.is_action_just_pressed("click_izquierdo")

func _check_hurt_box_damage() -> void:
	if invulnerable_al_danio:
		return

	for enemy in hurt_box.get_overlapping_bodies():
		var enemy_node := enemy as Node2D
		if enemy_node == null:
			continue
		if not enemy_node.is_in_group("enemies"):
			continue

		var enemy_base := enemy as EnemyBase
		var danio := 20
		if enemy_base != null:
			danio = max(enemy_base.contact_damage * 12, 20)
		recibir_danio(danio, enemy_node.global_position)
		return

func _check_spike_damage() -> void:
	if invulnerable_al_danio:
		return

	var tree := get_tree()
	if tree == null:
		return

	var spikes := tree.get_nodes_in_group("spikes")
	if spikes.is_empty() and get_parent() != null:
		# Fallback explícito por nombre para Nivel1.
		for node_name in ["PinchosA", "PinchosB", "PinchosC"]:
			var fallback_spike := get_parent().get_node_or_null(node_name)
			if fallback_spike != null:
				spikes.append(fallback_spike)
	if spikes.is_empty():
		return

	var feet := _get_player_feet_position()
	for spike_node in spikes:
		var spike := spike_node as Node2D
		if spike == null:
			continue

		var dx := absf(global_position.x - spike.global_position.x)
		var dy := absf(global_position.y - spike.global_position.y)
		if dx <= radio_pinchos_x and dy <= rango_pinchos_y:
			recibir_danio_pinchos(danio_pinchos, spike.global_position)
			return

		if _is_point_inside_spike_collider(feet, spike):
			recibir_danio_pinchos(danio_pinchos, spike.global_position)
			return

func _check_spike_collision_damage() -> void:
	if invulnerable_al_danio:
		return

	var collisions := get_slide_collision_count()
	if collisions <= 0:
		return

	for i in range(collisions):
		var col := get_slide_collision(i)
		if col == null:
			continue
		var collider := col.get_collider() as Node
		if collider == null:
			continue
		if collider.is_in_group("spikes"):
			var source := collider as Node2D
			recibir_danio_pinchos(danio_pinchos, source.global_position if source != null else global_position)
			return

func _get_player_feet_position() -> Vector2:
	var half_height := 0.0
	if body_shape != null and body_shape.shape is RectangleShape2D:
		var rect := body_shape.shape as RectangleShape2D
		half_height = rect.size.y * 0.5 * body_shape.global_scale.y
	return Vector2(global_position.x, global_position.y + half_height)

func _is_point_inside_spike_collider(point: Vector2, spike: Node2D) -> bool:
	var shape_node := spike.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or not (shape_node.shape is RectangleShape2D):
		return false
	var rect_shape := shape_node.shape as RectangleShape2D
	var world_size := Vector2(
		rect_shape.size.x * shape_node.global_scale.x,
		rect_shape.size.y * shape_node.global_scale.y
	)
	var rect := Rect2(shape_node.global_position - world_size * 0.5, world_size)
	return rect.has_point(point)

func _start_damage_flash() -> void:
	if _damage_flash_active:
		return
	_damage_flash_active = true
	_damage_flash_loop()

func _stop_damage_flash() -> void:
	_damage_flash_active = false
	animaciones.modulate = Color(1, 1, 1, 1)

func _damage_flash_loop() -> void:
	while _damage_flash_active and invulnerable_al_danio:
		animaciones.modulate = Color(1, 0.45, 0.45, 1)
		await get_tree().create_timer(0.08).timeout
		if not _damage_flash_active or not invulnerable_al_danio:
			break
		animaciones.modulate = Color(1, 1, 1, 1)
		await get_tree().create_timer(0.08).timeout

	animaciones.modulate = Color(1, 1, 1, 1)

func _ensure_barra_vida() -> void:
	if barra_vida != null:
		return
	barra_vida = get_tree().root.find_child("VidaBarra", true, false) as TextureProgressBar
