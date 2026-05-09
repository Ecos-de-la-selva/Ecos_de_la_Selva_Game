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

# --- ESTADO INTERNO ---
var direccion := -1
var atacando := false
var puede_atacar := true
var muerto := false
var esta_retrocediendo := false
var posicion_inicial := Vector2.ZERO

# --- NODOS ---
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var area_ataque: Area2D = $Area2D
@onready var colision_ataque: CollisionShape2D = $Area2D/CollisionShape2D


func _ready() -> void:
	add_to_group("enemigos")
	area_ataque.monitoring = true
	posicion_inicial = global_position
	anim.play("flight")


func _physics_process(_delta: float) -> void:
	if muerto:
		velocity = Vector2.ZERO
		return

	# El genio vuela: NO se le aplica gravedad.
	# 1. Movimiento horizontal
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

	# 2. Animaciones cuando no está en attack/hurt/death
	if not atacando and not _en_animacion_unica():
		anim.play("flight")

	# 3. Voltear sprite según dirección
	# El sprite original mira a la derecha → solo lo volteamos al ir a la izquierda
	anim.flip_h = (direccion == -1)

	move_and_slide()
	revisar_colisiones()


func _en_animacion_unica() -> bool:
	return anim.animation in ["hurt", "death", "attack", "magic_attack"] and anim.is_playing()


# Recorre las colisiones del último move_and_slide:
# - si tocó al jugador → ataque mágico
# - si tocó una pared → gira
func revisar_colisiones() -> void:
	if atacando or muerto:
		return

	for i in get_slide_collision_count():
		var colision := get_slide_collision(i)
		# Solo nos interesan colisiones laterales (en caso de que tope con algo)
		if abs(colision.get_normal().x) < 0.5:
			continue

		var cuerpo := colision.get_collider()
		if cuerpo and cuerpo.is_in_group("jugador"):
			if puede_atacar:
				ejecutar_ataque()
			return

		girar_enemigo()
		break


func girar_enemigo() -> void:
	direccion *= -1
	area_ataque.scale.x *= -1


# --- ATAQUE MÁGICO ---
func ejecutar_ataque() -> void:
	atacando = true
	puede_atacar = false
	velocity = Vector2.ZERO

	# Usamos magic_attack si existe, si no la animación attack normal
	if anim.sprite_frames.has_animation("magic_attack"):
		anim.play("magic_attack")
	else:
		anim.play("attack")

	# El conjuro tarda en formarse antes de hacer daño
	await get_tree().create_timer(0.5).timeout
	if muerto:
		return
	colision_ataque.disabled = false

	# Tiempo que el ataque puede hacer daño
	await get_tree().create_timer(0.3).timeout
	colision_ataque.disabled = true

	await get_tree().create_timer(0.4).timeout
	atacando = false

	# Cooldown antes del siguiente ataque
	await get_tree().create_timer(1.0).timeout
	puede_atacar = true


# Cuando el conjuro toca al jugador → daño
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

	# Retroceso (más suave porque está volando)
	if posicion_atacante != Vector2.ZERO:
		esta_retrocediendo = true
		var direccion_empuje := (global_position - posicion_atacante).normalized()
		velocity = direccion_empuje * retroceso_fuerza

	# Flash blanco
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
