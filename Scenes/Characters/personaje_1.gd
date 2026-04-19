extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

# VARIABLE NUEVA: Para controlar si estamos atacando
var is_attacking = false

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# DETECTAR CLICK IZQUIERDO (Ataque)
	# Nota: Asegúrate que "click_izquierdo" esté en Project Settings -> Input Map
	# O puedes usar Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if Input.is_action_just_pressed("click_izquierdo") and not is_attacking:
		attack()

	# Solo permitimos saltar y movernos si NO estamos atacando 
	# (Opcional: quita el "and not is_attacking" si quieres que ataque mientras corre)
	if not is_attacking:
		if Input.is_action_just_pressed("ui_accept") and is_on_floor():
			velocity.y = JUMP_VELOCITY

		var direction := Input.get_axis("ui_left", "ui_right")
		if direction:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
	else:
		# Si quieres que se detenga al atacar, descomenta la siguiente línea:
		# velocity.x = 0 
		pass

	move_and_slide()
	decide_animation()

func attack():
	is_attacking = true
	
	# REVISAMOS SI ESTÁ EN EL AIRE O EN EL SUELO
	if is_on_floor():
		$Animaciones.play("attack")
	else:
		$Animaciones.play("attackair")
	
	# Esperamos a que la animación que elegimos termine
	await $Animaciones.animation_finished 
	
	is_attacking = false

func decide_animation():
	# Si estamos atacando, NO dejes que las otras animaciones interrumpan
	if is_attacking:
		return

	# 1. PRIORIDAD: ¿Está en el aire?
	if not is_on_floor():
		if velocity.y < 0:
			$Animaciones.play("jump_up")
		else:
			$Animaciones.play("jump_down")
	
	# 2. Si NO está en el aire (está en el suelo)
	else:
		if velocity.x == 0:
			$Animaciones.play("Idle")
		else:
			$Animaciones.play("walk")
	
	# 3. DIRECCIÓN (Flip)
	if velocity.x < 0:
		$Animaciones.flip_h = true
	elif velocity.x > 0:
		$Animaciones.flip_h = false
