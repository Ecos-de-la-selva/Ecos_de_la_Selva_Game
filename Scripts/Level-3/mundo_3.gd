extends Node2D

# =========================================================
#                     MUNDO 2
# =========================================================

# -------- PERSONAJES --------
var PRE_HOMBRE = preload("res://Scenes/Characters/Personaje-1.tscn")
var PRE_MUJER = preload("res://Scenes/Characters/Personaje-2.tscn")

# -------- REFERENCIAS --------
var camara
var jugador

# 👹 NUEVO JEFE VOLADOR
@onready var jefe = $Enemigos/Jefe/volador
@onready var punto_aparicion = $Marker2D
@onready var capa_pausa = $CapaPausa
@onready var hud = $HUD

# 🎵 AUDIO
@onready var musica_normal = $MusicaAmbiente
@onready var audio_boss = $AudioBossAmbiente

# -------- VARIABLES --------
var evento_jefe_iniciado = false
var posicion_camara_guardada


# =========================================================
# READY
# =========================================================
func _ready():

	# 🔒 paredes arena boss
	$ArenaBoss/ParedIzquierda/CollisionShape2D.disabled = true
	$ArenaBoss/ParedDerecha/CollisionShape2D.disabled = true

	# ocultar gameover
	if $Gameover:
		$Gameover.hide()

	# ocultar pausa
	if capa_pausa:
		capa_pausa.hide()

	# 🎵 música normal
	if musica_normal:
		musica_normal.play()

	# 👤 crear jugador
	spawn_personaje()

	# 📖 diálogo inicial
	await mostrar_dialogo_y_esperar([
		"El sol se oculta tras la selva...",
		"Debemos recoger los desechos antes de que",
		"la oscuridad nos alcance."
	])

# =========================================================
# SPAWN PERSONAJE
# =========================================================
func spawn_personaje():

	var instancia

	if Global.personaje_seleccionado == "mujer":

		instancia = PRE_MUJER.instantiate()

		if hud.has_method("configurar_hud"):
			hud.configurar_hud("mujer")

	else:

		instancia = PRE_HOMBRE.instantiate()

		if hud.has_method("configurar_hud"):
			hud.configurar_hud("hombre")

	instancia.add_to_group("jugador")

	add_child(instancia)

	instancia.global_position = punto_aparicion.global_position

	jugador = instancia

	# 🎥 cámara
	if instancia.has_node("Camera2D"):

		camara = instancia.get_node("Camera2D")

		camara.make_current()


# =========================================================
# ACTIVAR ARENA
# =========================================================
func activar_arena():

	$ArenaBoss/ParedIzquierda/CollisionShape2D.set_deferred(
		"disabled",
		false
	)

	$ArenaBoss/ParedDerecha/CollisionShape2D.set_deferred(
		"disabled",
		false
	)


# =========================================================
# DESACTIVAR ARENA
# =========================================================
func desactivar_arena():

	$ArenaBoss/ParedIzquierda/CollisionShape2D.set_deferred(
		"disabled",
		true
	)

	$ArenaBoss/ParedDerecha/CollisionShape2D.set_deferred(
		"disabled",
		true
	)

	# 🔥 detener música boss
	if audio_boss and audio_boss.playing:
		audio_boss.stop()

	# 🎵 volver música normal
	if musica_normal:
		musica_normal.play()


# =========================================================
# PAUSA
# =========================================================
func _on_boton_pausa_pressed() -> void:

	get_tree().paused = true

	if capa_pausa:
		capa_pausa.show()


# =========================================================
# TRIGGER JEFE
# =========================================================
func _on_trigger_jefe_body_entered(body: Node2D) -> void:

	if body.is_in_group("jugador") and not evento_jefe_iniciado:

		evento_jefe_iniciado = true

		$TriggerJefe.set_deferred("monitoring", false)

		activar_arena()

		await iniciar_cinematica_jefe()


# =========================================================
# CINEMÁTICA
# =========================================================
func iniciar_cinematica_jefe():

	# 🎥 fijar cámara
	fijar_camara()

	# 🔒 bloquear jugador
	bloquear_jugador()

	# 🚶 mover jugador
	await llevar_jugador_a_posicion()

	# 📳 temblor
	tremor_pantalla()

	# 💬 diálogo
	await mostrar_dialogo_y_esperar([
		"¿Escuchaste eso...?",
		"Algo viene desde el cielo..."
	])

	# 🔇 apagar música normal
	if musica_normal and musica_normal.playing:
		musica_normal.stop()

	# 🔥 música boss
	if audio_boss:
		audio_boss.play()

	# 👹 iniciar pelea
	if jefe:
		await jefe.iniciar_pelea(hud)

	# 🔓 devolver control
	desbloquear_jugador()


# =========================================================
# DIÁLOGOS
# =========================================================
func mostrar_dialogo_y_esperar(textos: Array) -> void:

	var d = preload(
		"res://Scenes/Dialogos/Dialogo1/interfaz_dialogo.tscn"
	).instantiate()

	add_child(d)

	d.iniciar_dialogo(textos)

	await d.dialogo_terminado


# =========================================================
# FIJAR CÁMARA
# =========================================================
func fijar_camara():

	posicion_camara_guardada = camara.global_position

	camara.reparent(self)

	camara.global_position = posicion_camara_guardada


# =========================================================
# MOVER JUGADOR
# =========================================================
func llevar_jugador_a_posicion():

	var destino = camara.global_position + Vector2(-250, 0)

	var tween = create_tween()

	tween.tween_property(
		jugador,
		"global_position",
		destino,
		1.0
	)

	await tween.finished


# =========================================================
# BLOQUEAR
# =========================================================
func bloquear_jugador():

	jugador.set_physics_process(false)


# =========================================================
# DESBLOQUEAR
# =========================================================
func desbloquear_jugador():

	jugador.set_physics_process(true)


# =========================================================
# TEMBLOR
# =========================================================
func tremor_pantalla():

	var tween = create_tween()

	for i in range(12):

		var offset = Vector2(
			randf_range(-15, 15),
			randf_range(-15, 15)
		)

		tween.tween_property(
			camara,
			"offset",
			offset,
			0.04
		)

	tween.tween_property(
		camara,
		"offset",
		Vector2.ZERO,
		0.1
	)
