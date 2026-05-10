extends CharacterBody2D

# Configuración
const SPEED = 60.0
const FLY_SPEED = 80.0
const JUMP_FORCE = -200.0 # Impulso inicial para despegar

@onready var ap = $AnimatedSprite2D 

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var direccion = Vector2.ZERO
var estado = "idle" # idle, walk, fly
var tiempo_estado = 0.0

func _ready():
	_decidir_proximo_paso()

func _physics_process(delta):
	# 1. Aplicar Gravedad (solo si no está volando activamente)
	if estado != "fly":
		if not is_on_floor():
			velocity.y += gravity * delta
	else:
		# Si está volando, flota un poco hacia arriba o se mantiene
		velocity.y = move_toward(velocity.y, direccion.y * FLY_SPEED, 2.0)

	# 2. Movimiento Horizontal
	if estado == "idle":
		velocity.x = move_toward(velocity.x, 0, SPEED)
	else:
		velocity.x = direccion.x * (FLY_SPEED if estado == "fly" else SPEED)
	
	# 3. Control de Tiempos
	tiempo_estado -= delta
	if tiempo_estado <= 0:
		_decidir_proximo_paso()

	# 4. Voltear el sprite según la dirección X
	if direccion.x != 0:
		# Cambia > por < si vuelve a caminar al revés
		ap.flip_h = (direccion.x > 0) 

	move_and_slide()
	_gestionar_animaciones()

func _decidir_proximo_paso():
	var r = randi() % 100 # Usamos probabilidades del 0 al 100
	
	if r < 30: # 30% probabilidad de estar quieta
		estado = "idle"
		direccion = Vector2.ZERO
	elif r < 70: # 40% probabilidad de caminar
		estado = "walk"
		direccion.x = 1 if randf() > 0.5 else -1
	else: # 30% probabilidad de volar
		estado = "fly"
		# Elige una dirección diagonal hacia arriba
		direccion.x = 1 if randf() > 0.5 else -1
		direccion.y = -0.5 # Sube un poco
		if is_on_floor():
			velocity.y = JUMP_FORCE # Pequeño impulso para despegar
			
	tiempo_estado = randf_range(2.0, 5.0)

func _gestionar_animaciones():
	if not is_on_floor() or estado == "fly":
		ap.play("fly")
	elif estado == "walk":
		ap.play("walk")
	else:
		ap.play("Idle_Cantando")
