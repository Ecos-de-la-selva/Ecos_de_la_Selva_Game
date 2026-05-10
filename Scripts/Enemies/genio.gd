extends CharacterBody2D

# --- CONFIGURACIÓN ---
@export var velocidad := 80.0
# Distancia (en px) que se aleja del punto inicial antes de devolverse.
# Así el genio "patrulla" en el aire sin chocar con paredes.
@export var rango_patrulla := 250.0

# Combate
@export var vida: int = 4
@export var dano_ataque: int = 30
@export var retroceso_fuerza := 200.0

# Disparo a distancia
@export var rango_deteccion := 450.0
@export var cooldown_disparo := 1.8
@export var dano_proyectil: int = 20
const PROYECTIL_MAGICO := preload("res://Scenes/Enemies/proyectil_magico.tscn")

# --- Drop de basura al morir (igual que en el nivel 1) ---
@export var tipos_de_basura: Array[PackedScene] = []
@export var probabilidad_drop: float = 0.7

const BASURA_BOLSA := preload("res://Scenes/Score/BasuraBolsa.tscn")
const BASURA_LATA1 := preload("res://Scenes/Score/basura_lata_1.tscn")
const BASURA_LATA2 := preload("res://Scenes/Score/basura_lata_2.tscn")

# --- ESTADO INTERNO ---
var direccion := -1
var atacando := false
var puede_atacar := true
var muerto := false
var esta_retrocediendo := false
var posicion_inicial := Vector2.ZERO
var jugador: Node2D = null

# --- NODOS ---
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var area_ataque: Area2D = $Area2D
@onready var colision_ataque: CollisionShape2D = $Area2D/CollisionShape2D


func _ready() -> void:
	add_to_group("enemigos")
	# Mantenemos el área de ataque por si el jugador llega a tocar al genio
	# (golpe cuerpo a cuerpo de respaldo).
	area_ataque.monitoring = true
	posicion_inicial = global_position
	reproducir_movimiento()
	# Si no se asignaron basuras a este enemigo, usar las tres por defecto.
	if tipos_de_basura.is_empty():
		tipos_de_basura = [BASURA_BOLSA, BASURA_LATA1, BASURA_LATA2]


func _physics_process(_delta: float) -> void:
	if muerto:
		velocity = Vector2.ZERO
		return

	# Buscar al jugador (lo cacheamos por rendimiento)
	if jugador == null or not is_instance_valid(jugador):
		jugador = get_tree().get_first_node_in_group("jugador")

	# El genio vuela: NO se le aplica gravedad.
	if esta_retrocediendo:
		velocity = velocity.move_toward(Vector2.ZERO, 25)
		if velocity.length() < 5:
			esta_retrocediendo = false
	elif atacando:
		velocity = Vector2.ZERO
	else:
		velocity.x = direccion * velocidad
		velocity.y = 0  # vuelo plano

		# Si se aleja demasiado de su posición inicial → girar
		var desvio := global_position.x - posicion_inicial.x
		if desvio > rango_patrulla and direccion == 1:
			girar_enemigo()
		elif desvio < -rango_patrulla and direccion == -1:
			girar_enemigo()

		# Si el jugador está cerca y mirando hacia él → disparar
		if jugador and puede_atacar:
			var distancia := global_position.distance_to(jugador.global_position)
			if distancia <= rango_deteccion:
				# Mira al jugador antes de disparar
				direccion = -1 if jugador.global_position.x < global_position.x else 1
				disparar_proyectil()

	# Animación de movimiento
	if not atacando and not _en_animacion_unica():
		reproducir_movimiento()

	# Voltear sprite (sprite original mira a la derecha)
	anim.flip_h = (direccion == -1)

	move_and_slide()
	revisar_colisiones()


func _en_animacion_unica() -> bool:
	return anim.animation in ["hurt", "death", "attack", "magic_attack"] and anim.is_playing()


func reproducir_movimiento() -> void:
	if anim.sprite_frames.has_animation("flight"):
		anim.play("flight")
	elif anim.sprite_frames.has_animation("idle"):
		anim.play("idle")


func reproducir_ataque() -> void:
	# La animación "attack" muestra al genio lanzando el proyectil con la mano,
	# así que la usamos al disparar. "magic_attack" queda como respaldo.
	if anim.sprite_frames.has_animation("attack"):
		anim.play("attack")
	elif anim.sprite_frames.has_animation("magic_attack"):
		anim.play("magic_attack")


func revisar_colisiones() -> void:
	if atacando or muerto:
		return

	for i in get_slide_collision_count():
		var colision := get_slide_collision(i)
		if abs(colision.get_normal().x) < 0.5:
			continue

		var cuerpo := colision.get_collider()
		if cuerpo and cuerpo.is_in_group("jugador"):
			# Golpe cuerpo a cuerpo de respaldo
			if puede_atacar:
				ejecutar_ataque_cercano()
			return

		girar_enemigo()
		break


func girar_enemigo() -> void:
	direccion *= -1
	area_ataque.scale.x *= -1


# --- DISPARO A DISTANCIA ---
func disparar_proyectil() -> void:
	if muerto or jugador == null:
		return
	atacando = true
	puede_atacar = false
	velocity = Vector2.ZERO
	reproducir_ataque()

	# La animación "attack" tiene ~4 frames a 14 FPS (~0.28s).
	# Esperamos hasta el frame en el que el genio extiende la mano (~0.15s)
	# para que el proyectil aparezca exactamente cuando "lanza" el conjuro.
	await get_tree().create_timer(0.15).timeout
	if muerto or jugador == null or not is_instance_valid(jugador):
		atacando = false
		await get_tree().create_timer(cooldown_disparo).timeout
		puede_atacar = true
		return

	# Instanciar el proyectil hacia el jugador
	var proyectil := PROYECTIL_MAGICO.instantiate()
	proyectil.direccion = (jugador.global_position - global_position).normalized()
	proyectil.dano = dano_proyectil
	# Posición inicial: un poquito al frente del genio (a la altura de su mano)
	proyectil.global_position = global_position + proyectil.direccion * 25.0
	get_tree().current_scene.add_child(proyectil)

	# Dejar terminar la animación de ataque
	await get_tree().create_timer(0.2).timeout
	atacando = false

	# Cooldown
	await get_tree().create_timer(cooldown_disparo).timeout
	puede_atacar = true


# --- ATAQUE CUERPO A CUERPO (respaldo) ---
func ejecutar_ataque_cercano() -> void:
	atacando = true
	puede_atacar = false
	velocity = Vector2.ZERO
	reproducir_ataque()

	await get_tree().create_timer(0.5).timeout
	if muerto:
		return
	colision_ataque.disabled = false

	await get_tree().create_timer(0.3).timeout
	colision_ataque.disabled = true

	await get_tree().create_timer(0.4).timeout
	atacando = false

	await get_tree().create_timer(1.0).timeout
	puede_atacar = true


func _on_area_2d_body_entered(body: Node2D) -> void:
	if muerto:
		return
	if body.is_in_group("jugador") and body.has_method("recibir_danio"):
		body.recibir_danio(dano_ataque)


# --- RECIBIR DAÑO DEL JUGADOR ---
func recibir_danio(dmg: int, posicion_atacante: Vector2 = Vector2.ZERO) -> void:
	if muerto:
		return

	vida -= dmg

	if posicion_atacante != Vector2.ZERO:
		esta_retrocediendo = true
		var direccion_empuje := (global_position - posicion_atacante).normalized()
		velocity = direccion_empuje * retroceso_fuerza

	var tween_hit := create_tween()
	tween_hit.tween_property(anim, "modulate", Color(10, 10, 10), 0.05)
	tween_hit.tween_property(anim, "modulate", Color(1, 1, 1), 0.05)

	if vida > 0 and anim.sprite_frames.has_animation("hurt"):
		anim.play("hurt")

	if vida <= 0:
		morir()


func morir() -> void:
	if muerto:
		return
	muerto = true
	velocity = Vector2.ZERO

	# Soltar basura antes de desaparecer
	_soltar_basura()

	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	colision_ataque.set_deferred("disabled", true)
	area_ataque.set_deferred("monitoring", false)

	if anim.sprite_frames.has_animation("death"):
		anim.play("death")
		await anim.animation_finished

	var fade := create_tween()
	fade.tween_property(anim, "modulate:a", 0.0, 0.5)
	await fade.finished
	queue_free()


# Suelta una basura aleatoria en la posición del enemigo (igual que en mundo).
# Como el genio vuela, llamamos a empezar_caida() para que aterrice en el piso.
func _soltar_basura() -> void:
	if tipos_de_basura.is_empty() or randf() > probabilidad_drop:
		return
	var escena: PackedScene = tipos_de_basura.pick_random()
	if escena == null:
		return
	var instancia := escena.instantiate()
	var pos_muerte := global_position
	get_tree().current_scene.call_deferred("add_child", instancia)
	instancia.set_deferred("global_position", pos_muerte)
	get_tree().create_timer(0.01).timeout.connect(func():
		if is_instance_valid(instancia) and instancia.has_method("empezar_caida"):
			instancia.empezar_caida()
	)
