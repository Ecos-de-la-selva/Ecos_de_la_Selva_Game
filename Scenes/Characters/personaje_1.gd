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
var radio_contacto_enemigo = 56.0
var _damage_flash_active = false
# Esta línea busca la barra de vida en la escena Screen que instanciaste
@onready var barra_vida: TextureProgressBar = null

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
	_check_hurt_box_damage()
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

	await get_tree().create_timer(tiempo_invulnerable).timeout
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