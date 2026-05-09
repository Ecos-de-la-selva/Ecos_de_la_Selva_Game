extends CharacterBody2D

# Configuración básica de movimiento
var velocidad = 60.0
var direccion = 1
var gravedad = 980.0

# Referencias a los nodos hijos
@onready var anim = $AnimatedSprite2D
@onready var lanza_colision = $Area2D/CollisionShape2D

func _physics_process(delta):
	# 1. Aplicar Gravedad
	if not is_on_floor():
		velocity.y += gravedad * delta

	# 2. Movimiento Horizontal
	velocity.x = direccion * velocidad
	
	# 3. Girar al chocar con una pared
	if is_on_wall():
		girar_enemigo()

	# 4. Control de Animaciones básicas
	if velocity.x != 0:
		anim.play("walk")
	else:
		anim.play("idle")

	move_and_slide()

func girar_enemigo():
	direccion *= -1
	# Voltea el sprite para que mire a donde camina
	anim.flip_h = (direccion == -1)
	
	# IMPORTANTE: Volteamos el Area2D de la lanza para que el ataque 
	# siempre apunte hacia adelante
	$Area2D.scale.x *= -1

# Función para llamar cuando quieras que el enemigo ataque
func ejecutar_ataque():
	velocity.x = 0 # Se detiene para atacar
	anim.play("attack")
	
	# Aquí es donde "encendemos" la colisión de la lanza
	# justo cuando sale el dibujo del golpe
	await get_tree().create_timer(0.3).timeout # Espera un poco a que salga la lanza
	lanza_colision.disabled = false
	
	await get_tree().create_timer(0.2).timeout # Tiempo que dura el daño
	lanza_colision.disabled = true
