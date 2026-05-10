extends CharacterBody2D

# --- CONFIGURACIÓN ---
@export var activo: bool = true  # Asegúrate de DESMARCAR esto en el Inspector para los 5 monos
@export var velocidad: float = 100.0
@export var velocidad_patrulla: float = 40.0
@export var vida: int = 50
@export var retroceso_fuerza: float = 400.0
@export var tipos_de_basura: Array[PackedScene] = []
@export var probabilidad_drop: float = 0.7

# --- NODOS ---
@onready var anim = $AnimatedSprite2D
@onready var sonido_mono = $SonidoMono

# --- VARIABLES ---
var tiempo_estado: float = 0.0
var direccion_patrulla: int = 0
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var jugador = null
var muerto: bool = false
var esta_retrocediendo: bool = false 

func _ready():
	add_to_group("enemigos")
	if not activo:
		anim.play("idle")

func _physics_process(delta):
	# 1. SI ESTÁ MUERTO: No hace nada
	if muerto:
		velocity = Vector2.ZERO
		return
	
	# 2. BLOQUEO DE CINEMÁTICA: Si no está activo, ignoramos todo el código de abajo
	if not activo:
		velocity.x = 0
		if not is_on_floor():
			velocity.y += gravity * delta
		
		# Aseguramos que se vea en IDLE
		if anim.animation != "idle":
			anim.play("idle")
			
		move_and_slide()
		return # <--- ESTE ES EL MURO: Nada después de aquí se ejecuta si activo es false

	# 3. GRAVEDAD NORMAL
	if not is_on_floor():
		velocity.y += gravity * delta

	# 4. LÓGICA DE RETROCESO (DAÑO)
	if esta_retrocediendo:
		velocity.x = move_toward(velocity.x, 0, 15) 
		if abs(velocity.x) < 5:
			esta_retrocediendo = false
	
	# 5. LÓGICA DE PERSECUCIÓN
	elif jugador:
		var direccion_x = sign(jugador.global_position.x - global_position.x)
		velocity.x = direccion_x * velocidad
		actualizar_giro_y_areas(velocity.x)
		
		if anim.animation != "attack" or not anim.is_playing():
			anim.play("run")
			
	# 6. LÓGICA DE PATRULLA (SOLO SI NO HAY JUGADOR)
	else:
		tiempo_estado -= delta
		if tiempo_estado <= 0:
			var eleccion = randi() % 3
			direccion_patrulla = 0 if eleccion == 0 else (-1 if eleccion == 1 else 1)
			tiempo_estado = randf_range(1.0, 4.0)
		
		velocity.x = direccion_patrulla * velocidad_patrulla
		
		if anim.animation != "attack":
			if direccion_patrulla != 0:
				actualizar_giro_y_areas(velocity.x)
				anim.play("run")
			elif is_on_floor():
				anim.play("idle")

	move_and_slide()
	limitar_movimiento()

# --- FUNCIONES ADICIONALES ---

func limitar_movimiento():
	var mundo = get_tree().current_scene
	if mundo.has_node("ArenaBoss/LimiteIzq") and mundo.has_node("ArenaBoss/LimiteDer"):
		var izq = mundo.get_node("ArenaBoss/LimiteIzq").global_position.x
		var der = mundo.get_node("ArenaBoss/LimiteDer").global_position.x
		global_position.x = clamp(global_position.x, izq, der)

func actualizar_giro_y_areas(vel_x: float):
	if vel_x < 0:
		anim.flip_h = true
		if has_node("AreaAtaque"): $AreaAtaque.scale.x = 1
		if has_node("ZonaDeteccion"): $ZonaDeteccion.scale.x = 1
	elif vel_x > 0:
		anim.flip_h = false
		if has_node("AreaAtaque"): $AreaAtaque.scale.x = -1
		if has_node("ZonaDeteccion"): $ZonaDeteccion.scale.x = -1

func recibir_danio(dmg: int, posicion_atacante: Vector2):
	if muerto: return
	vida -= dmg
	
	if posicion_atacante != Vector2.ZERO:
		esta_retrocediendo = true
		var direccion_empuje = (global_position - posicion_atacante).normalized()
		velocity.x = direccion_empuje.x * retroceso_fuerza
		velocity.y = -150 
	
	var tween_hit = create_tween()
	tween_hit.tween_property(anim, "modulate", Color(10, 10, 10), 0.05)
	tween_hit.tween_property(anim, "modulate", Color(1, 1, 1), 0.05)
	
	if vida <= 0:
		morir_con_estilo()

func esta_vivo() -> bool:
	return not muerto
func morir_con_estilo():
	if muerto:
		return

	muerto = true

	velocity = Vector2.ZERO

	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)

	_desactivar_area_totalmente("AreaAtaque")
	_desactivar_area_totalmente("ZonaDeteccion")

	var efecto = create_tween()
	efecto.tween_property(anim, "modulate:a", 0.0, 0.5)

	await efecto.finished

	queue_free()

# --- SEÑALES ---

func _on_zona_deteccion_body_entered(body):
	# Si el mono está bloqueado por la cinemática, IGNORA al jugador
	if not activo: 
		return 
	
	if body.is_in_group("jugador"):
		jugador = body
		if sonido_mono and not sonido_mono.playing:
			sonido_mono.play()

func _on_zona_deteccion_body_exited(body):
	if body == jugador: jugador = null

func _on_area_ataque_body_entered(body):
	if muerto or esta_retrocediendo or not activo: return
	if body.is_in_group("jugador") and body.has_method("recibir_danio"):
		if anim.sprite_frames.has_animation("attack"):
			anim.play("attack")
		body.recibir_danio(20)
		_cambiar_estado_colision("AreaAtaque", true)
		await get_tree().create_timer(1.2).timeout
		if not muerto:
			_cambiar_estado_colision("AreaAtaque", false)

# --- UTILIDADES ---

func _cambiar_estado_colision(nombre_area: String, desactivar: bool):
	var shape = get_node_or_null(nombre_area + "/CollisionShape2D")
	if shape: shape.set_deferred("disabled", desactivar)

func _desactivar_area_totalmente(nombre_area: String):
	var area = get_node_or_null(nombre_area)
	if area:
		area.set_deferred("monitoring", false)
		_cambiar_estado_colision(nombre_area, true)

func _soltar_basura():
	if tipos_de_basura.is_empty() or randf() > probabilidad_drop: return
	var escena = tipos_de_basura.pick_random()
	if escena:
		var instancia = escena.instantiate()
		get_tree().current_scene.call_deferred("add_child", instancia)
		instancia.set_deferred("global_position", global_position)
