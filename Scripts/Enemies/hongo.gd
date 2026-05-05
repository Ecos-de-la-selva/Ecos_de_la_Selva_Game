extends CharacterBody2D

# --- CONFIGURACIÓN ---
@export var velocidad: float = 100.0
@export var vida: int = 4
@export var tipos_de_basura: Array[PackedScene] = []
@export var probabilidad_drop: float = 0.7

# --- NODOS ---
@onready var anim = $AnimatedSprite2D
@onready var sonido_hongo = $SonidoHongo

# --- ESTADOS ---
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
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

	# Gravedad
	if not is_on_floor():
		velocity.y += gravity * delta

	# Lógica de Retroceso (Knockback)
	if esta_retrocediendo:
		velocity.x = move_toward(velocity.x, 0, 10)
		if abs(velocity.x) < 5:
			esta_retrocediendo = false
	
	# Lógica de Persecución
	elif jugador and not atacando:
		var direccion = (jugador.global_position.x - global_position.x)
		velocity.x = sign(direccion) * velocidad
		
		# --- GIRO SINCRONIZADO ---
		if velocity.x > 0:
			anim.flip_h = true 
			# Invertimos todas las áreas para que miren a la derecha
			if has_node("AreaAtaque"): $AreaAtaque.scale.x = -1 
			if has_node("ZonaDeteccion"): $ZonaDeteccion.scale.x = -1
		elif velocity.x < 0:
			anim.flip_h = false 
			# Volvemos las áreas a su posición original (izquierda)
			if has_node("AreaAtaque"): $AreaAtaque.scale.x = 1
			if has_node("ZonaDeteccion"): $ZonaDeteccion.scale.x = 1
			
		anim.play("run")
		
	# Estado de Reposo
	elif not atacando:
		velocity.x = move_toward(velocity.x, 0, velocidad)
		if is_on_floor():
			anim.play("idle")

	move_and_slide()

# --- DETECCIÓN Y ATAQUE ---

func _on_zona_deteccion_body_entered(body):
	if body.is_in_group("jugador"):
		jugador = body
		
		if sonido_hongo and not sonido_hongo.playing:
			sonido_hongo.play()

func _on_zona_deteccion_body_exited(body):
	if body == jugador:
		jugador = null

func _on_area_ataque_body_entered(body):
	if muerto or atacando or esta_retrocediendo: return
	if body.is_in_group("jugador"):
		atacando = true
		velocity.x = 0
		anim.play("attack")
		if body.has_method("recibir_danio"):
			body.recibir_danio(15)
		await anim.animation_finished
		atacando = false

# --- DAÑO Y MUERTE ---
# Ahora coincide con el estándar: (daño, posición)
func recibir_danio(dmg: int, posicion_atacante: Vector2 = Vector2.ZERO):
	if muerto: return
	
	vida -= dmg # Usamos la variable dmg en lugar de 1 fijo
	
	if posicion_atacante != Vector2.ZERO:
		esta_retrocediendo = true
		var dir = (global_position - posicion_atacante).normalized()
		velocity.x = dir.x * 300
		velocity.y = -150

	var tw = create_tween()
	tw.tween_property(anim, "modulate", Color(10, 10, 10), 0.05)
	tw.tween_property(anim, "modulate", Color(1, 1, 1), 0.05)
	
	if vida <= 0: 
		morir()

func morir():
	if muerto: return
	muerto = true
	velocity = Vector2.ZERO
	
	# CAMBIO AQUÍ: Llamada segura
	_instanciar_basura()
	
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	_apagar_areas()
	
	anim.play("die")
	var tw = create_tween()
	tw.tween_property(anim, "modulate:a", 0, 1.0).set_delay(0.5)
	await tw.finished
	queue_free()

# --- EL ARREGLO PARA LA BASURA ---

func _instanciar_basura():
	if tipos_de_basura.is_empty() or randf() > probabilidad_drop: return
	
	var item = tipos_de_basura.pick_random().instantiate()
	var pos_muerte = global_position # Guardamos la posición antes del free
	
	# Usamos call_deferred para añadirlo al nivel raíz
	get_tree().current_scene.call_deferred("add_child", item)
	
	# En lugar de una conexión compleja, usamos un set_deferred
	# y un pequeño timer para activar la caída
	item.set_deferred("global_position", pos_muerte)
	
	# Timer de 1 solo frame para asegurar que el item ya "existe" en el árbol
	get_tree().create_timer(0.01).timeout.connect(func():
		if is_instance_valid(item) and item.has_method("empezar_caida"):
			item.empezar_caida()
	)

func _apagar_areas():
	for area_name in ["ZonaDeteccion", "AreaAtaque"]:
		var area = get_node_or_null(area_name)
		if area:
			area.set_deferred("monitoring", false)
			area.set_deferred("monitorable", false)
