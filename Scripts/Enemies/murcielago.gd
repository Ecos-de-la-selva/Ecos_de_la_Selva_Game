extends CharacterBody2D

# --- CONFIGURACIÓN ---
@export var velocidad_persecucion: float = 120.0
@export var velocidad_patrulla: float = 50.0  # Más lento al patrullar
@export var vida: int = 3
@export var tipos_de_basura: Array[PackedScene] = [] 
@export var probabilidad_drop: float = 0.8 

# --- NUEVAS VARIABLES DE PATRULLA ---
var tiempo_estado = 0.0
var direccion_patrulla = Vector2.ZERO

# --- NODOS ---
@onready var anim = $AnimatedSprite2D
@onready var sonido_bat = $SonidoMurcielago

# --- ESTADOS ---
var jugador = null
var muerto = false
var atacando = false
var esta_retrocediendo = false 

func _ready():
	add_to_group("enemigos")
	anim.play("idle")
	
func _physics_process(delta):
	if muerto:
		velocity = Vector2.ZERO
		return 

	# 1. LÓGICA DE RETROCESO (Knockback)
	if esta_retrocediendo:
		velocity = velocity.move_toward(Vector2.ZERO, 10)
		if velocity.length() < 5:
			esta_retrocediendo = false
	
	# 2. LÓGICA DE PERSECUCIÓN (Prioridad si hay jugador)
	elif jugador and not atacando:
		var direccion = (jugador.global_position - global_position).normalized()
		velocity = direccion * velocidad_persecucion
		actualizar_giro_y_areas(velocity.x)
		
		if anim.animation != "attack":
			anim.play("idle") # O "fly" si tienes la animación
	
	# 3. LÓGICA DE PATRULLA (Si no hay jugador)
	elif not atacando:
		tiempo_estado -= delta
		
		if tiempo_estado <= 0:
			# Elige una nueva dirección al azar (puede ser quieto o moverse)
			if randf() > 0.3: # 70% de probabilidad de moverse
				direccion_patrulla = Vector2(randf_range(-1, 1), randf_range(-0.5, 0.5)).normalized()
				tiempo_estado = randf_range(1.5, 3.0)
			else: # 30% de probabilidad de quedarse flotando quieto
				direccion_patrulla = Vector2.ZERO
				tiempo_estado = randf_range(1.0, 2.0)
		
		# Aplicar movimiento de patrulla + efecto flotante de seno
		var flotado = Vector2(0, sin(Time.get_ticks_msec() * 0.005) * 15)
		velocity = (direccion_patrulla * velocidad_patrulla) + flotado
		
		if direccion_patrulla != Vector2.ZERO:
			actualizar_giro_y_areas(velocity.x)
		
		anim.play("idle")

	move_and_slide()

# --- FUNCIONES DE APOYO NUEVAS ---

func actualizar_giro_y_areas(vel_x: float):
	if vel_x > 0:
		anim.flip_h = true  # Mira a la Derecha
		if has_node("AreaAtaque"): $AreaAtaque.scale.x = -1
		if has_node("ZonaDeteccion"): $ZonaDeteccion.scale.x = -1
	elif vel_x < 0:
		anim.flip_h = false # Mira a la Izquierda
		if has_node("AreaAtaque"): $AreaAtaque.scale.x = 1
		if has_node("ZonaDeteccion"): $ZonaDeteccion.scale.x = 1

# --- SEÑALES DE DETECCIÓN ---

func _on_zona_deteccion_body_entered(body):
	if body.is_in_group("jugador"):
		jugador = body
		
		if sonido_bat and not sonido_bat.playing:
			sonido_bat.play()
			
func _on_zona_deteccion_body_exited(body):
	if body == jugador:
		jugador = null

# --- LÓGICA DE ATAQUE ---

func _on_area_ataque_body_entered(body):
	if muerto or atacando or esta_retrocediendo: return 
	
	if body.is_in_group("jugador"):
		atacando = true
		if body.has_method("recibir_danio"):
			body.recibir_danio(10)
		
		if anim.sprite_frames.has_animation("attack"):
			anim.play("attack")
		
		# Salto de alejamiento tras atacar
		var direccion_retroceso = (global_position - body.global_position).normalized()
		velocity = direccion_retroceso * 250 
		
		await get_tree().create_timer(0.6).timeout
		atacando = false

# --- SISTEMA DE DAÑO RECIBIDO ---
func recibir_danio(dmg: int, posicion_atacante: Vector2): 
	if muerto: return
	
	vida -= dmg # Antes restaba 1 fijo, ahora usa el daño recibido
	
	# Retroceso
	if posicion_atacante != Vector2.ZERO:
		esta_retrocediendo = true
		var direccion_empuje = (global_position - posicion_atacante).normalized()
		# Ajusté esto para que use el 350 que tenías originalmente en el murciélago
		velocity = direccion_empuje * 350 
	
	# Efecto golpe (Flash blanco)
	var tween_hit = create_tween()
	tween_hit.tween_property(anim, "modulate", Color(10, 10, 10), 0.05)
	tween_hit.tween_property(anim, "modulate", Color(1, 1, 1), 0.05)
	
	if vida <= 0:
		morir_con_estilo()

# --- MUERTE Y LIMPIEZA ---

func morir_con_estilo():
	if muerto: return
	muerto = true
	
	velocity = Vector2.ZERO
	atacando = false 
	
	_soltar_basura_segura()
	
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	_desactivar_nodo_fisico("AreaAtaque")
	_desactivar_nodo_fisico("ZonaDeteccion")

	var efecto = create_tween().set_parallel(true)
	efecto.tween_property(anim, "modulate:a", 0.0, 0.4)
	efecto.tween_property(anim, "scale", Vector2.ZERO, 0.4)
	
	await efecto.finished
	queue_free()

# --- FUNCIONES DE APOYO (ARREGLADAS) ---

func _soltar_basura_segura():
	if tipos_de_basura.is_empty() or randf() > probabilidad_drop:
		return
		
	var escena_basura = tipos_de_basura.pick_random()
	if escena_basura:
		var instancia = escena_basura.instantiate()
		var pos_muerte = global_position 
		
		get_tree().current_scene.call_deferred("add_child", instancia)
		instancia.set_deferred("global_position", pos_muerte)
		
		get_tree().create_timer(0.05).timeout.connect(func():
			if is_instance_valid(instancia):
				var tw = instancia.create_tween()
				tw.tween_property(instancia, "global_position:y", pos_muerte.y - 30, 0.3)
				
				await tw.finished
				if is_instance_valid(instancia) and instancia.has_method("empezar_caida"):
					instancia.empezar_caida()
		)

func _desactivar_nodo_fisico(nombre_nodo: String):
	var nodo = get_node_or_null(nombre_nodo)
	if nodo:
		nodo.set_deferred("monitoring", false)
		nodo.set_deferred("monitorable", false)
		for child in nodo.get_children():
			if child is CollisionShape2D:
				child.set_deferred("disabled", true)
