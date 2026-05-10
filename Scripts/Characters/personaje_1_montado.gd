extends CharacterBody2D

# =========================================================
#              PERSONAJE MONTADO EN JAGUAR
# =========================================================

const SPEED = 420.0
const JUMP_VELOCITY = -700.0

var salud_max = 100
var salud_actual = 100

# =========================================================
# NODOS
# =========================================================
@onready var anim = $AnimatedSprite2D

@onready var attack_area = get_node_or_null("AttackArea")

@onready var colision_ataque = (
	get_node_or_null("AttackArea/CollisionShape2D")
)

@onready var sonido_dano = get_node_or_null("SonidoDano")
@onready var sonido_ataque = get_node_or_null("SonidoAttack")

# =========================================================
# VARIABLES
# =========================================================
var is_attacking = false
var esta_muerto = false

var posicion_ataque_original_x = 0.0


# =========================================================
# READY
# =========================================================
func _ready():

	add_to_group("jugador")

	# guardar posición original
	if attack_area:
		posicion_ataque_original_x = attack_area.position.x

	# desactivar hitbox inicial
	if colision_ataque:
		colision_ataque.disabled = true

	actualizar_interfaz_vida()


# =========================================================
# PHYSICS
# =========================================================
func _physics_process(delta):

	if esta_muerto:
		return

	# gravedad
	if not is_on_floor():
		velocity += get_gravity() * delta

	# ataque
	if Input.is_action_just_pressed("atacar"):

		if not is_attacking:
			attack()

	# movimiento
	if not is_attacking:

		# salto
		if Input.is_action_just_pressed("ui_accept"):

			if is_on_floor():
				velocity.y = JUMP_VELOCITY

		# dirección
		var direction = Input.get_axis(
			"ui_left",
			"ui_right"
		)

		if direction != 0:

			velocity.x = direction * SPEED

			actualizar_orientacion(direction)

		else:

			velocity.x = move_toward(
				velocity.x,
				0,
				SPEED
			)

	move_and_slide()

	decide_animation()


# =========================================================
# ORIENTACIÓN
# =========================================================
func actualizar_orientacion(direction):

	if not anim:
		return

	if direction < 0:

		anim.flip_h = true

		if attack_area:
			attack_area.position.x = -posicion_ataque_original_x

	elif direction > 0:

		anim.flip_h = false

		if attack_area:
			attack_area.position.x = posicion_ataque_original_x


# =========================================================
# ATAQUE
# =========================================================
func attack():

	if not anim:
		return

	is_attacking = true

	# sonido
	if sonido_ataque:
		sonido_ataque.play()

	# activar hitbox
	if colision_ataque:
		colision_ataque.set_deferred(
			"disabled",
			false
		)

	# animación
	if anim.sprite_frames.has_animation("attack"):
		anim.play("attack")

	await anim.animation_finished

	# desactivar hitbox
	if colision_ataque:
		colision_ataque.set_deferred(
			"disabled",
			true
		)

	is_attacking = false


# =========================================================
# RECIBIR DAÑO
# =========================================================
# =========================================================
# RECIBIR DAÑO
# =========================================================
func recibir_danio(
	cantidad: int,
	posicion_atacante: Vector2 = Vector2.ZERO
):

	# evitar daño si murió
	if esta_muerto:
		return

	# evitar recibir múltiples golpes instantáneos
	if has_meta("invulnerable"):
		return

	set_meta("invulnerable", true)

	# =========================================
	# RESTAR VIDA
	# =========================================
	salud_actual -= cantidad

	salud_actual = clamp(
		salud_actual,
		0,
		salud_max
	)

	actualizar_interfaz_vida()

	# =========================================
	# SONIDO
	# =========================================
	if sonido_dano:
		sonido_dano.play()

	# =========================================
	# EMPUJE
	# =========================================
	if posicion_atacante != Vector2.ZERO:

		var direccion = (
			global_position - posicion_atacante
		).normalized()

		velocity.x = direccion.x * 350
		velocity.y = -180

	# =========================================
	# EFECTO VISUAL FLASH
	# =========================================
	if anim:

		var tween = create_tween()

		anim.modulate = Color(5, 0.3, 0.3)

		tween.tween_property(
			anim,
			"modulate",
			Color(1,1,1),
			0.15
		)

	# =========================================
	# MUERTE
	# =========================================
	if salud_actual <= 0:

		morir()
		return

	# =========================================
	# INVULNERABILIDAD CORTA
	# =========================================
	await get_tree().create_timer(0.6).timeout

	set_meta("invulnerable", false)

# =========================================================
# VIDA UI
# =========================================================
func actualizar_interfaz_vida():

	var barra = get_tree().root.find_child(
		"VidaBarra",
		true,
		false
	)

	if barra:

		barra.max_value = salud_max
		barra.value = salud_actual


# =========================================================
# MUERTE
# =========================================================
func morir():

	if esta_muerto:
		return

	esta_muerto = true

	velocity = Vector2.ZERO

	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)

	if anim:

		if anim.sprite_frames.has_animation("die"):

			anim.play("die")

			await get_tree().create_timer(1.0).timeout


# =========================================================
# ANIMACIONES
# =========================================================
func decide_animation():

	if not anim:
		return

	if esta_muerto:
		return

	# no cambiar mientras ataca
	if is_attacking:
		return

	# =====================================================
	# SALTO
	# =====================================================
	if not is_on_floor():

		if anim.sprite_frames.has_animation("jump"):

			if anim.animation != "jump":
				anim.play("jump")

		return

	# =====================================================
	# CORRER
	# =====================================================
	if abs(velocity.x) > 15:

		if anim.sprite_frames.has_animation("run"):

			if anim.animation != "run":
				anim.play("run")

	# =====================================================
	# IDLE
	# =====================================================
	else:

		if anim.sprite_frames.has_animation("idle"):

			if anim.animation != "idle":
				anim.play("idle")
# =========================================================
# HITBOX ATAQUE
# =========================================================
func _on_attack_area_body_entered(body):

	if body.is_in_group("enemigos"):

		if body.has_method("recibir_danio"):

			body.recibir_danio(
				25,
				global_position
			)


func _on_hurt_box_body_entered(body: Node2D) -> void:

	# ignorar si murió
	if esta_muerto:
		return

	# detectar enemigos
	if body.is_in_group("enemigos"):

		# evitar daño infinito instantáneo
		if body.has_method("recibir_danio"):

			recibir_danio(
				20,
				body.global_position
			)
