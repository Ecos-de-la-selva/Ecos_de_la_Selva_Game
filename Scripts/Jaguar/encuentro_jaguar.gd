extends Node2D

# =========================================================
#                  EVENTO JAGUAR
# =========================================================

# 🔥 ESCENAS MONTADAS
@export var personaje_montado_hombre: PackedScene
@export var personaje_montado_mujer: PackedScene

@onready var zona_activacion = $ZonaActivacion
@onready var jaguar_png_nodo = $JaguarHerido
@onready var area_jaguar = $AreaJaguar

var evento_activo = false
var evento_terminado = false


# =========================================================
# READY
# =========================================================
func _ready():

	# conectar trigger final
	if not area_jaguar.body_entered.is_connected(_on_area_jaguar_body_entered):

		area_jaguar.body_entered.connect(
			_on_area_jaguar_body_entered
		)

	# =====================================================
	# DESACTIVAR MONOS
	# =====================================================
	var monos = get_tree().get_nodes_in_group(
		"monos_jaguar"
	)

	for m in monos:

		if not is_instance_valid(m):
			continue

		m.activo = false

		# dejar en idle
		if m.has_node("AnimatedSprite2D"):

			var anim_mono = m.get_node(
				"AnimatedSprite2D"
			)

			if anim_mono.sprite_frames.has_animation(
				"idle"
			):
				anim_mono.play("idle")


# =========================================================
# INICIO EVENTO
# =========================================================
func _on_zona_activacion_body_entered(body):

	if not body.is_in_group("jugador"):
		return

	if evento_activo:
		return

	evento_activo = true

	zona_activacion.set_deferred(
		"monitoring",
		false
	)

	await secuencia_cinematica(body)


# =========================================================
# CINEMÁTICA
# =========================================================
func secuencia_cinematica(jugador):

	# bloquear jugador
	jugador.set_physics_process(false)

	jugador.velocity = Vector2.ZERO

	# =====================================================
	# ANIMACIÓN CAMINAR
	# =====================================================
	var anim = jugador.get_node_or_null(
		"Animaciones"
	)

	if anim:

		if anim.sprite_frames.has_animation("walk"):
			anim.play("walk")

	# =====================================================
	# MOVIMIENTO AUTOMÁTICO
	# =====================================================
	var tween = create_tween()

	tween.tween_property(
		jugador,
		"global_position:x",
		jugador.global_position.x + 120,
		1.2
	)

	await tween.finished

	# =====================================================
	# IDLE
	# =====================================================
	if anim:

		if anim.sprite_frames.has_animation("Idle"):
			anim.play("Idle")

	# =====================================================
	# DIÁLOGO
	# =====================================================
	await lanzar_dialogo([
		"¡Oh, un jaguar!",
		"¡Debemos ayudarlo!"
	])

	# =====================================================
	# ACTIVAR MONOS
	# =====================================================
	var monos = get_tree().get_nodes_in_group(
		"monos_jaguar"
	)

	for m in monos:

		if not is_instance_valid(m):
			continue

		m.activo = true

		# asignar jugador
		m.jugador = jugador

	# devolver control
	jugador.set_physics_process(true)


# =========================================================
# FINAL EVENTO
# =========================================================
func _on_area_jaguar_body_entered(body):

	if evento_terminado:
		return

	if not body.is_in_group("jugador"):
		return

	evento_terminado = true

	area_jaguar.set_deferred(
		"monitoring",
		false
	)

	# =====================================================
	# DIÁLOGO FINAL
	# =====================================================
	await lanzar_dialogo([
		"¡El jaguar está a salvo!",
		"¡Ahora será tu aliado!"
	])

	# =====================================================
	# REEMPLAZAR POR PERSONAJE MONTADO
	# =====================================================
	if is_instance_valid(jaguar_png_nodo):

		var pos = jaguar_png_nodo.global_position

		# eliminar jaguar herido
		jaguar_png_nodo.queue_free()

		# crear personaje montado
		reemplazar_por_montado(body, pos)


# =========================================================
# REEMPLAZAR JUGADOR
# =========================================================
func reemplazar_por_montado(
	jugador_actual,
	posicion_spawn
):

	var nueva_escena: PackedScene = null

	# =====================================================
	# DETECTAR PERSONAJE
	# =====================================================
	if jugador_actual.name.to_lower().contains(
		"personaje1"
	):

		nueva_escena = personaje_montado_hombre

	else:

		nueva_escena = personaje_montado_mujer

	# =====================================================
	# VALIDACIÓN
	# =====================================================
	if nueva_escena == null:

		print(
			"ERROR: No asignaste la escena montada"
		)

		return

	# =====================================================
	# GUARDAR VIDA
	# =====================================================
	var vida_actual = 100

	if "salud_actual" in jugador_actual:

		vida_actual = jugador_actual.salud_actual

	# =====================================================
	# GUARDAR DIRECCIÓN
	# =====================================================
	var flip_h = false

	if jugador_actual.has_node("Animaciones"):

		flip_h = jugador_actual.get_node(
			"Animaciones"
		).flip_h

	# =====================================================
	# CREAR PERSONAJE MONTADO
	# =====================================================
	var nuevo_jugador = nueva_escena.instantiate()

	nuevo_jugador.global_position = posicion_spawn

	get_parent().add_child(nuevo_jugador)

	# =====================================================
	# TRANSFERIR VIDA
	# =====================================================
	if "salud_actual" in nuevo_jugador:

		nuevo_jugador.salud_actual = vida_actual

		if nuevo_jugador.has_method(
			"actualizar_interfaz_vida"
		):

			nuevo_jugador.actualizar_interfaz_vida()

	# =====================================================
	# TRANSFERIR DIRECCIÓN
	# =====================================================
	if nuevo_jugador.has_node("Animaciones"):

		nuevo_jugador.get_node(
			"Animaciones"
		).flip_h = flip_h

	# =====================================================
	# TRANSFERIR CÁMARA
	# =====================================================
	var camara_vieja = jugador_actual.get_node_or_null(
		"Camera2D"
	)

	if camara_vieja:

		camara_vieja.reparent(
			nuevo_jugador
		)

		camara_vieja.position = Vector2.ZERO

		camara_vieja.enabled = true

	# =====================================================
	# ELIMINAR JUGADOR VIEJO
	# =====================================================
	jugador_actual.queue_free()


# =========================================================
# DIÁLOGOS
# =========================================================
func lanzar_dialogo(textos):
	if not is_inside_tree():
		return
	await Global.mostrar_dialogo_modal(textos)
