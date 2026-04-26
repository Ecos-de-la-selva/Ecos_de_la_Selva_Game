extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const ATTACK_DAMAGE = 1
const ATTACK_PUSH_FORCE = 150.0
const HitStopUtils = preload("res://Scripts/hit_stop.gd")

# --- VARIABLES DE SALUD ---
var salud_max = 100
var salud_actual = 100
# Esta línea busca la barra de vida en la escena Screen que instanciaste
@onready var barra_vida = get_tree().root.find_child("VidaBarra", true, false)

# VARIABLE PARA EL ATAQUE
var is_attacking = false
var _already_hit_in_current_attack: Array[Node2D] = []

@onready var animaciones: AnimatedSprite2D = $Animaciones
@onready var attack_area: Area2D = $AttackArea

func _ready():
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
	
	# --- PRUEBA DE DAÑO TEMPORAL ---
	if Input.is_action_just_pressed("ui_down"):
		recibir_danio(10)

	move_and_slide()
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
func recibir_danio(cantidad):
	salud_actual -= cantidad
	salud_actual = clamp(salud_actual, 0, salud_max) # No bajar de 0
	
	if barra_vida:
		barra_vida.value = salud_actual
	
	if salud_actual <= 0:
		morir()

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