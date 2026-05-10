extends CharacterBody2D

# --- CONFIGURACIÓN ---
@export var velocidad_patrulla: float = 80.0
@export var fuerza_salto_v: float = -450.0 
@export var fuerza_salto_h: float = 350.0
@export var vida: int = 30

# --- SISTEMA DE DROPS (Igual que el Mono) ---
@export var tipos_de_basura: Array[PackedScene] = []
@export var probabilidad_drop: float = 1.0

# --- ESTADOS ---
var jugador = null
var muerto = false
var atacando = false
var recibiendo_golpe = false
var direccion = 1 

# --- NODOS ---
@onready var anim = $AnimatedSprite2D
@onready var sonido = $SonidoRana

func _ready():
	add_to_group("enemigos")

func _physics_process(delta):
	if muerto: return

	# 1. Gravedad
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# 2. Control de Movimiento
	if not recibiendo_golpe and not atacando:
		if jugador:
			atacar_jugador()
		else:
			patrullar()
	elif atacando or recibiendo_golpe:
		# Frenado gradual al estar en el suelo
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0, 20)

	move_and_slide()

# --- COMPORTAMIENTOS ---

func patrullar():
	if not is_on_floor(): return
	anim.play("walk")
	velocity.x = direccion * velocidad_patrulla
	actualizar_giro(direccion)
	
	if is_on_wall():
		direccion *= -1

func atacar_jugador():
	if atacando or muerto or recibiendo_golpe: return 
	atacando = true
	
	velocity.x = 0
	anim.play("attack") 
	
	if jugador:
		var dir_h = sign(jugador.global_position.x - global_position.x)
		actualizar_giro(dir_h)
		
		# Anticipación (Igual que el Mono/Jefe)
		await get_tree().create_timer(0.6).timeout 
		
		if muerto or recibiendo_golpe or jugador == null: 
			atacando = false
			return

		if sonido: sonido.play()
		velocity.x = dir_h * fuerza_salto_h
		velocity.y = fuerza_salto_v
	
	await get_tree().create_timer(0.2).timeout
	await esperar_suelo()
	
	velocity.x = 0
	anim.play("idle")
	await get_tree().create_timer(1.2).timeout
	atacando = false

func esperar_suelo():
	while not is_on_floor() and not muerto:
		await get_tree().process_frame

func actualizar_giro(dir):
	anim.flip_h = (dir < 0)

# --- SISTEMA DE DAÑO ---

func recibir_danio(dmg: int, posicion_atacante: Vector2):
	if muerto or recibiendo_golpe: return
	
	vida -= dmg
	recibiendo_golpe = true
	atacando = false 
	
	# Retroceso (Knockback)
	var dir_retroceso = (global_position - posicion_atacante).normalized()
	velocity = Vector2(dir_retroceso.x * 500, -250) 
	
	anim.play("hurt")
	
	# Efecto flash de daño
	var tw = create_tween()
	tw.tween_property(anim, "modulate", Color(10, 10, 10), 0.05)
	tw.tween_property(anim, "modulate", Color(1, 1, 1), 0.05)
	
	if vida <= 0:
		morir()
	else:
		await get_tree().create_timer(0.4).timeout
		recibiendo_golpe = false

# --- MUERTE Y SOLTAR BASURA ---

func morir():
	if muerto: return
	muerto = true
	
	# Desactivar colisiones e inteligencia
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	
	anim.play("die")
	
	# Soltar basura (Lógica heredada del Mono)
	_soltar_basura()
	
	# Efecto de desaparición suave
	var tween = create_tween()
	for i in range(5):
		tween.tween_property(anim, "modulate:a", 0.2, 0.1)
		tween.tween_property(anim, "modulate:a", 1.0, 0.1)
	
	tween.tween_property(anim, "modulate:a", 0.0, 0.3)
	await tween.finished
	queue_free()

func _soltar_basura():
	# Si no hay escenas en la lista o falla la probabilidad, salimos
	if tipos_de_basura.is_empty() or randf() > probabilidad_drop: 
		return
		
	var escena = tipos_de_basura.pick_random()
	if escena:
		var instancia = escena.instantiate()
		# Lo añadimos a la escena principal para que no muera con la rana
		get_tree().current_scene.call_deferred("add_child", instancia)
		instancia.set_deferred("global_position", global_position)
		print("La rana soltó: ", instancia.name)

# --- SEÑALES ---

func _on_zona_deteccion_body_entered(body):
	if body.is_in_group("jugador"): 
		jugador = body

func _on_zona_deteccion_body_exited(body):
	if body == jugador: 
		jugador = null

func _on_area_ataque_body_entered(body):
	if muerto: return
	if body.is_in_group("jugador") and body.has_method("recibir_danio"):
		body.recibir_danio(15, global_position)
