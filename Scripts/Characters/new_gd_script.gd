extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

# --- VARIABLES DE SALUD ---
var salud_max = 100
var salud_actual = 100
# Esta línea busca la barra de vida en la escena Screen que instanciaste
@onready var barra_vida = get_tree().root.find_child("VidaBarra", true, false)

# VARIABLE PARA EL ATAQUE
var is_attacking = false

func _ready():
	# Al empezar, aseguramos que la barra esté llena
	if barra_vida:
		barra_vida.max_value = salud_max
		barra_vida.value = salud_actual

func _physics_process(delta: float) -> void:
	# Gravedad
	if not is_on_floor():
		velocity += get_gravity() * delta

	# ATAQUE (Click Izquierdo)
	if Input.is_action_just_pressed("click_izquierdo") and not is_attacking:
		attack()

	# Movimiento y Salto
	if not is_attacking:
		if Input.is_action_just_pressed("ui_accept") and is_on_floor():
			velocity.y = JUMP_VELOCITY

		var direction := Input.get_axis("ui_left", "ui_right")
		if direction:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
	
	# --- PRUEBA DE DAÑO TEMPORAL ---
	# Presiona la tecla "Abajo" para probar si la barra baja
	if Input.is_action_just_pressed("ui_down"):
		recibir_danio(10)

	move_and_slide()
	decide_animation()

func attack():
	is_attacking = true
	
	if is_on_floor():
		$Animaciones.play("attack")
	else:
		$Animaciones.play("attackair")
	
	await $Animaciones.animation_finished 
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
	# Reinicia la escena actual para reaparecer
	get_tree().reload_current_scene()

func decide_animation():
	if is_attacking:
		return

	if not is_on_floor():
		if velocity.y < 0:
			$Animaciones.play("jump_up")
		else:
			$Animaciones.play("jump_down")
	else:
		if velocity.x == 0:
			$Animaciones.play("Idle")
		else:
			$Animaciones.play("walk")
	
	if velocity.x < 0:
		$Animaciones.flip_h = true
	elif velocity.x > 0:
		$Animaciones.flip_h = false
