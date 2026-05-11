extends CharacterBody2D

 ## VOLADOR SECUAZ ###
# --- CONFIGURACIÓN ---
@export var velocidad_vuelo: float = 140.0
@export var velocidad_patrulla: float = 60.0 # Velocidad tranquila al patrullar
@export var velocidad_picado: float = 900.0 
@export var vida: int = 30
@export var tipos_de_basura: Array[PackedScene] = []
@export var probabilidad_drop: float = 0.6


# --- VARIABLES DE PATRULLA ---
var tiempo_estado = 0.0
var direccion_patrulla = Vector2.ZERO

# --- NODOS ---
@onready var anim = $AnimatedSprite2D
@onready var sonido_peste = $SonidoPeste

# --- ESTADOS ---
var jugador = null
var muerto = false
var atacando = false
var en_picado = false
var preparando_picado = false
var recibiendo_golpe = false

func _ready():
	add_to_group("enemigos")
	anim.play("fly")

func _physics_process(delta):
	if muerto: 
		velocity = Vector2.ZERO
		return

	# 1. ESTADO: RECIBIENDO GOLPE
	if recibiendo_golpe:
		velocity = velocity.move_toward(Vector2.ZERO, 15)
		move_and_slide()
		return 

	# 2. ESTADO: PICADO
	if en_picado:
		var colision = move_and_collide(velocity * delta)
		if colision:
			var objeto = colision.get_collider()
			if objeto is TileMapLayer or objeto.name.contains("Tile") or objeto.is_in_group("suelo"):
				terminar_picado()
		return # Saltamos el resto del movimiento físico durante el picado

	# 3. ESTADO: PREPARACIÓN (Tween maneja la posición)
	elif preparando_picado:
		return 
		
	# 4. ESTADO: PERSECUCIÓN
	elif jugador and not atacando:
		var direccion = (jugador.global_position - global_position).normalized()
		velocity = direccion * velocidad_vuelo
		actualizar_giro_y_areas(velocity.x)
		anim.play("fly")
		move_and_slide()
	
	# 5. ESTADO: PATRULLA / IDLE (Cuando no hay jugador)
	elif not atacando:
		tiempo_estado -= delta
		
		if tiempo_estado <= 0:
			# 70% de probabilidad de patrullar, 30% de flotar en el sitio
			if randf() > 0.3:
				direccion_patrulla = Vector2(randf_range(-1, 1), randf_range(-0.3, 0.3)).normalized()
				tiempo_estado = randf_range(2.0, 4.0)
			else:
				direccion_patrulla = Vector2.ZERO
				tiempo_estado = randf_range(1.0, 2.0)
		
		# Movimiento suave + ondulación de seno
		var flotado = Vector2(0, sin(Time.get_ticks_msec() * 0.004) * 30)
		velocity = (direccion_patrulla * velocidad_patrulla) + flotado
		
		if direccion_patrulla != Vector2.ZERO:
			actualizar_giro_y_areas(velocity.x)
		
		anim.play("idle")
		move_and_slide()

# --- FUNCIONES DE APOYO ---

func actualizar_giro_y_areas(vel_x: float):
	if vel_x > 0:
		anim.flip_h = true  # Mira a la Derecha
		if has_node("AreaAtaque"): $AreaAtaque.scale.x = -1
		if has_node("ZonaDeteccion"): $ZonaDeteccion.scale.x = -1
	elif vel_x < 0:
		anim.flip_h = false # Mira a la Izquierda
		if has_node("AreaAtaque"): $AreaAtaque.scale.x = 1
		if has_node("ZonaDeteccion"): $ZonaDeteccion.scale.x = 1

# --- LÓGICA DE ATAQUE PICADO ---

func iniciar_picado():
	if atacando or muerto: return
	atacando = true
	preparando_picado = true
	
	# Fase 1: Impulso inicial hacia arriba
	var pos_impulso = global_position + Vector2(0, -50)
	var tw = create_tween()
	tw.tween_property(self, "global_position", pos_impulso, 0.2)
	await tw.finished
	
	if muerto or recibiendo_golpe: return
	
	# Fase 2: Posicionarse sobre el jugador
	var pos_preparacion = jugador.global_position + Vector2(0, -200)
	var tw2 = create_tween().set_trans(Tween.TRANS_CUBIC)
	tw2.tween_property(self, "global_position", pos_preparacion, 0.4)
	
	if anim.sprite_frames.has_animation("attack"):
		anim.play("attack")
	
	await tw2.finished
	
	if muerto or recibiendo_golpe: return
	
	# Fase 3: El Picado
	preparando_picado = false
	en_picado = true
	set_collision_mask_value(1, false) # Traspasar jugador
	velocity = Vector2(0, velocidad_picado)

func terminar_picado():
	en_picado = false
	velocity = Vector2.ZERO
	set_collision_mask_value(1, true) # Recuperar colisión
	
	if anim.sprite_frames.has_animation("idle"):
		anim.play("idle")
		
	await get_tree().create_timer(1.0).timeout # Aturdimiento
	atacando = false

# --- RECIBIR DAÑO Y MUERTE ---

# Añadimos 'dmg: int' al inicio para que coincida con el jugador
func recibir_danio(dmg: int, posicion_atacante: Vector2):
	if muerto: return
	
	vida -= dmg # Ahora usamos el daño real que viene del jugador
	recibiendo_golpe = true
	en_picado = false 
	preparando_picado = false
	set_collision_mask_value(1, true)
	
	if anim.sprite_frames.has_animation("hit"):
		anim.play("hit")
	
	# El cálculo de retroceso ahora funcionará perfecto porque posicion_atacante
	# recibirá el Vector2 correcto desde el segundo argumento.
	var direccion_empuje = (global_position - posicion_atacante).normalized()
	velocity = direccion_empuje * 400
	
	var tw = create_tween()
	tw.tween_property(anim, "modulate", Color(10, 10, 10), 0.05)
	tw.tween_property(anim, "modulate", Color(1, 1, 1), 0.05)
	
	await get_tree().create_timer(0.3).timeout
	
	if vida <= 0:
		morir()
	else:
		recibiendo_golpe = false

func morir():
	if muerto: return
	muerto = true
	velocity = Vector2.ZERO
	
	# 🟢 SOLTAR BASURA (FÍSICA)
	# Se ha eliminado Global.sumar_basura(10) para que solo sume 1 
	# cuando el jugador recoja el objeto del suelo.
	_soltar_basura()
	
	# Desactivar físicas
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	
	# Animación de muerte
	if anim.sprite_frames.has_animation("die"):
		anim.play("die")
		await anim.animation_finished
	
	# Eliminar el nodo de la escena
	queue_free()
	
# --- SEÑALES Y DROPS ---

func _on_area_ataque_body_entered(body):
	if muerto or recibiendo_golpe: return
	
	if body.is_in_group("jugador"):
		if en_picado:
			if body.has_method("recibir_danio"):
				body.recibir_danio(20)
		elif not atacando:
			iniciar_picado()

func _on_zona_deteccion_body_entered(body):
	if body.is_in_group("jugador"):
		jugador = body
		
		if sonido_peste and not sonido_peste.playing:
			sonido_peste.play()

func _on_zona_deteccion_body_exited(body):
	if body == jugador:
		jugador = null
		
func _soltar_basura():
	if tipos_de_basura.is_empty() or randf() > probabilidad_drop: return
	
	var item = tipos_de_basura.pick_random().instantiate()
	var pos_muerte = global_position 
	
	get_tree().current_scene.call_deferred("add_child", item)
	item.set_deferred("global_position", pos_muerte)
	
	get_tree().create_timer(0.01).timeout.connect(func():
		if is_instance_valid(item) and item.has_method("empezar_caida"):
			item.empezar_caida()
	)
