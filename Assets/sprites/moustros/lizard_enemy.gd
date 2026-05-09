extends CharacterBody2D

# Configuración básica de movimiento
@export var velocidad := 60.0
@export var gravedad := 980.0

# --- Combate ---
@export var vida: int = 3
@export var dano_ataque: int = 20
@export var retroceso_fuerza := 350.0

# --- Detección del jugador ---
# Si el jugador está más cerca que esto y dentro del mismo nivel
# vertical, el lizard se gira hacia él (aunque venga por detrás).
@export var rango_deteccion := 220.0
@export var altura_deteccion := 90.0

# --- Estado interno ---
var direccion := 1
var atacando := false
var puede_atacar := true
var muerto := false
var esta_retrocediendo := false

# Referencias a los nodos hijos
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var lanza_area: Area2D = $Area2D
@onready var lanza_colision: CollisionShape2D = $Area2D/CollisionShape2D


func _ready() -> void:
	# La lanza siempre debe poder detectar al jugador
	lanza_area.monitoring = true


func _physics_process(delta: float) -> void:
	if muerto:
		velocity = Vector2.ZERO
		return

	# 1. Aplicar Gravedad
	if not is_on_floor():
		velocity.y += gravedad * delta

	# 2. Detectar al jugador (incluso si está detrás)
	detectar_jugador()

	# 3. Movimiento horizontal
	if esta_retrocediendo:
		velocity.x = move_toward(velocity.x, 0, 20)
		if abs(velocity.x) < 5:
			esta_retrocediendo = false
	elif atacando:
		velocity.x = 0
	else:
		velocity.x = direccion * velocidad

	# 4. Animaciones (mientras NO estemos en attack/hurt/death)
	if not atacando and not _en_animacion_unica():
		if velocity.x != 0:
			anim.play("walk")
		else:
			anim.play("idle")

	move_and_slide()
	revisar_colisiones()


# Si el jugador está cerca y a su espalda → girarse hacia él.
# Así el lizard no se queda quieto mientras lo atacan por detrás.
func detectar_jugador() -> void:
	if atacando or esta_retrocediendo:
		return
	var jugador := get_tree().get_first_node_in_group("jugador")
	if jugador == null or not is_instance_valid(jugador):
		return

	var dx: float = jugador.global_position.x - global_position.x
	var dy: float = jugador.global_position.y - global_position.y

	# Solo nos importan jugadores en el mismo "piso" (rango vertical pequeño)
	# y dentro del rango horizontal
	if abs(dy) > altura_deteccion:
		return
	if abs(dx) > rango_deteccion:
		return
	# Pequeña zona muerta para que no tiemble cuando el jugador está justo encima
	if abs(dx) < 8.0:
		return

	var direccion_objetivo := -1 if dx < 0 else 1
	if direccion_objetivo != direccion:
		girar_enemigo()


func _en_animacion_unica() -> bool:
	return anim.animation in ["hurt", "death", "attack"] and anim.is_playing()


# Recorre las colisiones del último move_and_slide:
# - si tocó al jugador → ataca
# - si tocó una pared real → gira
func revisar_colisiones() -> void:
	if atacando or muerto:
		return

	for i in get_slide_collision_count():
		var colision := get_slide_collision(i)
		# Solo nos interesan colisiones laterales (no el suelo)
		if abs(colision.get_normal().x) < 0.5:
			continue

		var cuerpo := colision.get_collider()
		if cuerpo and cuerpo.is_in_group("jugador"):
			if puede_atacar:
				ejecutar_ataque()
			return

		# Pared o bloque del mapa → girar
		girar_enemigo()
		break


func girar_enemigo() -> void:
	direccion *= -1
	anim.flip_h = (direccion == -1)
	# Volteamos el Area2D de la lanza para que el ataque siempre apunte
	# hacia adelante
	lanza_area.scale.x *= -1


# --- ATAQUE ---
func ejecutar_ataque() -> void:
	atacando = true
	puede_atacar = false
	velocity.x = 0
	anim.play("attack")

	# Espera a que salga la lanza
	await get_tree().create_timer(0.3).timeout
	if muerto:
		return
	lanza_colision.disabled = false

	# Tiempo que la lanza puede hacer daño
	await get_tree().create_timer(0.2).timeout
	lanza_colision.disabled = true

	# Pequeña pausa después del golpe
	await get_tree().create_timer(0.2).timeout
	atacando = false

	# Cooldown antes del siguiente ataque
	await get_tree().create_timer(0.6).timeout
	puede_atacar = true


# Cuando la lanza toca al jugador → daño
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

	# Retroceso
	if posicion_atacante != Vector2.ZERO:
		esta_retrocediendo = true
		var direccion_empuje := (global_position - posicion_atacante).normalized()
		velocity.x = direccion_empuje.x * retroceso_fuerza
		velocity.y = -150

	# Flash blanco al recibir golpe
	var tween_hit := create_tween()
	tween_hit.tween_property(anim, "modulate", Color(10, 10, 10), 0.05)
	tween_hit.tween_property(anim, "modulate", Color(1, 1, 1), 0.05)

	# Animación de daño si todavía está vivo
	if vida > 0 and anim.sprite_frames.has_animation("hurt"):
		anim.play("hurt")

	if vida <= 0:
		morir()


func morir() -> void:
	if muerto:
		return
	muerto = true
	velocity = Vector2.ZERO

	# Desactivar todas las colisiones / áreas para que no haga daño después
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	lanza_colision.set_deferred("disabled", true)
	lanza_area.set_deferred("monitoring", false)

	if anim.sprite_frames.has_animation("death"):
		anim.play("death")
		await anim.animation_finished

	# Desvanecer y eliminar
	var fade := create_tween()
	fade.tween_property(anim, "modulate:a", 0.0, 0.4)
	await fade.finished
	queue_free()
