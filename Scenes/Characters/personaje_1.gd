extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	print(velocity)
	move_and_slide()
	decide_animation()
	
	
func decide_animation():
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
	
	# 3. DIRECCIÓN (Flip): Esto va fuera de los IF de arriba para que
	# el personaje pueda voltearse incluso mientras salta.
	if velocity.x < 0:
		$Animaciones.flip_h = true
	elif velocity.x > 0:
		$Animaciones.flip_h = false
