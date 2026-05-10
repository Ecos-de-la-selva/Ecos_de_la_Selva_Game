extends CharacterBody2D

# =========================================================
#                          MONO
# =========================================================

# ---------------- CONFIG ----------------
@export var activo: bool = true
@export var velocidad: float = 100.0
@export var velocidad_patrulla: float = 40.0
@export var vida: int = 50
@export var retroceso_fuerza: float = 400.0

@export var tipos_de_basura: Array[PackedScene] = []
@export var probabilidad_drop: float = 0.7


# ---------------- NODOS ----------------
@onready var anim = $AnimatedSprite2D
@onready var sonido_mono = $SonidoMono


# ---------------- VARIABLES ----------------
var tiempo_estado: float = 0.0
var direccion_patrulla: int = 0

var gravity = ProjectSettings.get_setting(
	"physics/2d/default_gravity"
)

var jugador = null

var muerto: bool = false
var esta_retrocediendo: bool = false


# =========================================================
# READY
# =========================================================
func _ready():

	add_to_group("enemigos")
	add_to_group("monos_jaguar")

	if not activo:

		velocity = Vector2.ZERO

		reproducir_idle()


# =========================================================
# PHYSICS
# =========================================================
func _physics_process(delta):

	# =====================================================
	# MUERTO
	# =====================================================
	if muerto:

		velocity = Vector2.ZERO
		return


	# =====================================================
	# BLOQUEADO POR CINEMÁTICA
	# =====================================================
	if not activo:

		velocity.x = 0

		if not is_on_floor():
			velocity.y += gravity * delta

		reproducir_idle()

		move_and_slide()
		return


	# =====================================================
	# GRAVEDAD
	# =====================================================
	if not is_on_floor():
		velocity.y += gravity * delta


	# =====================================================
	# RETROCESO
	# =====================================================
	if esta_retrocediendo:

		velocity.x = move_toward(
			velocity.x,
			0,
			15
		)

		if abs(velocity.x) < 5:
			esta_retrocediendo = false


	# =====================================================
	# PERSEGUIR JUGADOR
	# =====================================================
	elif jugador:

		var direccion_x = sign(
			jugador.global_position.x
			- global_position.x
		)

		velocity.x = direccion_x * velocidad

		actualizar_giro_y_areas(
			velocity.x
		)

		if anim.animation != "attack":
			reproducir_movimiento()


	# =====================================================
	# PATRULLA
	# =====================================================
	else:

		tiempo_estado -= delta

		if tiempo_estado <= 0:

			var eleccion = randi() % 3

			direccion_patrulla = (
				0 if eleccion == 0
				else (-1 if eleccion == 1 else 1)
			)

			tiempo_estado = randf_range(
				1.0,
				4.0
			)

		velocity.x = (
			direccion_patrulla
			* velocidad_patrulla
		)

		if anim.animation != "attack":

			if direccion_patrulla != 0:

				actualizar_giro_y_areas(
					velocity.x
				)

				reproducir_movimiento()

			elif is_on_floor():

				reproducir_idle()


	move_and_slide()

	limitar_movimiento()


# =========================================================
# ANIMACIONES
# =========================================================
func reproducir_movimiento():

	# intenta run primero
	if anim.sprite_frames.has_animation("run"):

		if anim.animation != "run":
			anim.play("run")

	# si no existe run usa walk
	elif anim.sprite_frames.has_animation("walk"):

		if anim.animation != "walk":
			anim.play("walk")


func reproducir_idle():

	if anim.sprite_frames.has_animation("idle"):

		if anim.animation != "idle":
			anim.play("idle")


# =========================================================
# LIMITAR MOVIMIENTO
# =========================================================
func limitar_movimiento():

	var mundo = get_tree().current_scene

	if mundo.has_node("ArenaBoss/LimiteIzq") and mundo.has_node("ArenaBoss/LimiteDer"):

		var izq = mundo.get_node(
			"ArenaBoss/LimiteIzq"
		).global_position.x

		var der = mundo.get_node(
			"ArenaBoss/LimiteDer"
		).global_position.x

		global_position.x = clamp(
			global_position.x,
			izq,
			der
		)


# =========================================================
# GIRO
# =========================================================
func actualizar_giro_y_areas(vel_x: float):

	if vel_x < 0:

		anim.flip_h = true

		if has_node("AreaAtaque"):
			$AreaAtaque.scale.x = 1

		if has_node("ZonaDeteccion"):
			$ZonaDeteccion.scale.x = 1


	elif vel_x > 0:

		anim.flip_h = false

		if has_node("AreaAtaque"):
			$AreaAtaque.scale.x = -1

		if has_node("ZonaDeteccion"):
			$ZonaDeteccion.scale.x = -1


# =========================================================
# RECIBIR DAÑO
# =========================================================
func recibir_danio(
	dmg: int,
	posicion_atacante: Vector2
):

	if muerto:
		return

	vida -= dmg

	if posicion_atacante != Vector2.ZERO:

		esta_retrocediendo = true

		var direccion_empuje = (
			global_position
			- posicion_atacante
		).normalized()

		velocity.x = (
			direccion_empuje.x
			* retroceso_fuerza
		)

		velocity.y = -150


	var tween_hit = create_tween()

	tween_hit.tween_property(
		anim,
		"modulate",
		Color(10,10,10),
		0.05
	)

	tween_hit.tween_property(
		anim,
		"modulate",
		Color(1,1,1),
		0.05
	)

	if vida <= 0:
		morir_con_estilo()


# =========================================================
# MUERTE
# =========================================================
func morir_con_estilo():

	if muerto:
		return

	muerto = true

	velocity = Vector2.ZERO

	# 🔥 soltar basura
	_soltar_basura()

	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)

	var efecto = create_tween()

	efecto.tween_property(
		anim,
		"modulate:a",
		0.0,
		0.5
	)

	await efecto.finished

	queue_free()

# =========================================================
# DETECCIÓN
# =========================================================
func _on_zona_deteccion_body_entered(body):

	if not activo:
		return

	if body.is_in_group("jugador"):

		jugador = body

		if sonido_mono and not sonido_mono.playing:
			sonido_mono.play()


func _on_zona_deteccion_body_exited(body):

	if body == jugador:
		jugador = null


# =========================================================
# ATAQUE
# =========================================================
func _on_area_ataque_body_entered(body):

	if muerto:
		return

	if esta_retrocediendo:
		return

	if not activo:
		return

	if body.is_in_group("jugador"):

		if body.has_method("recibir_danio"):

			if anim.sprite_frames.has_animation("attack"):
				anim.play("attack")

			body.recibir_danio(20)


# =========================================================
# UTILIDADES
# =========================================================
func _cambiar_estado_colision(
	nombre_area: String,
	desactivar: bool
):

	var shape = get_node_or_null(
		nombre_area + "/CollisionShape2D"
	)

	if shape:

		shape.set_deferred(
			"disabled",
			desactivar
		)


func _desactivar_area_totalmente(
	nombre_area: String
):

	var area = get_node_or_null(
		nombre_area
	)

	if area:

		area.set_deferred(
			"monitoring",
			false
		)

		_cambiar_estado_colision(
			nombre_area,
			true
		)


# =========================================================
# DROPS DE BASURA
# =========================================================
func _soltar_basura():

	if tipos_de_basura.is_empty():
		return

	if randf() > probabilidad_drop:
		return

	var escena = tipos_de_basura.pick_random()

	if escena:

		var instancia = escena.instantiate()

		get_tree().current_scene.call_deferred(
			"add_child",
			instancia
		)

		instancia.set_deferred(
			"global_position",
			global_position
		)
