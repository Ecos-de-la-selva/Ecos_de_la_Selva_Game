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
@onready var jefe = $Enemigos/Jefe/JefeMurcielago
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
	var anim_player = find_child("AnimationPlayer", true, false)
	if anim_player and anim_player.has_animation("Fade_out"):
		anim_player.play("Fade_out")

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
		"Qué hermosa fauna tienen estas aves...",
		"¡En el Putumayo existen casi 1,000 especies!",
		"La contaminación también afecta los cielos...",
		"Debemos salvar este paraíso natural."
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
	# 🎥 fijar cámara y bloquear inputs
	fijar_camara()
	bloquear_jugador()

	# 🚶 mover jugador al centro de la arena
	await llevar_jugador_a_posicion()
	tremor_pantalla()

	# 💬 diálogo previo ambiental
	await mostrar_dialogo_y_esperar([
		"¿Escuchaste eso...?",
		"Algo gigante viene desde el cielo..."
	])

	# 🔇 apagar música normal
	if musica_normal and musica_normal.playing:
		musica_normal.stop()

	# 🔥 encender música del boss ambiente
	if audio_boss:
		audio_boss.play()

	# 👹 Configurar posición inicial del jefe a la derecha
	if jefe:
		jefe.preparar_entrada()
		
		# 🟢 CORRECCIÓN: Buscamos el nodo correcto donde debe terminar el Jefe
		var spawn = get_node_or_null("SpawnBoss")
		if spawn == null:
			# Si el nodo está dentro de otro grupo o carpeta, búscalo directamente en la escena actual
			spawn = get_tree().current_scene.get_node("SpawnBoss")
			
		# EL TWEEN SE EJECUTA AQUÍ EN EL MUNDO: Movimiento Derecha a Izquierda
		var tween_movimiento = create_tween()
		tween_movimiento.tween_property(jefe, "global_position", spawn.global_position, 2.0)
		await tween_movimiento.finished
		
		# El jefe frena y se queda quieto
		if jefe.has_node("AnimatedSprite2D"):
			jefe.get_node("AnimatedSprite2D").play("idle")

		# 💬 Diálogo de presentación del jefe
		await mostrar_dialogo_y_esperar([
			"¡El Murciélago Rey ha aparecido!",
			"¡Prepárate para combatir a la plaga!"
		])

		# 🟢 LÍNEA CLAVE AÑADIDA: Conectamos el HUD del mapa con el script del jefe
		if jefe and hud:
			jefe.hud = hud

		# 🚀 Arrancamos oficialmente el combate del jefe y su HUD
		jefe.empezar_combate()

	# 🔓 Devolver control al jugador de forma segura en mobile
	desbloquear_jugador()

# =========================================================
# DIÁLOGOS
# =========================================================
func mostrar_dialogo_y_esperar(textos: Array) -> void:

	var ya_bloqueado = jugador and not jugador.is_physics_processing()
	if jugador and not ya_bloqueado:
		bloquear_jugador()
	var touch = get_node_or_null("Controles")
	if touch and touch.has_method("bloquear"):
		touch.bloquear()

	var d = preload(
		"res://Scenes/Dialogos/Dialogo1/interfaz_dialogo.tscn"
	).instantiate()

	add_child(d)

	d.iniciar_dialogo(textos)

	await d.dialogo_terminado

	if jugador and not ya_bloqueado:
		desbloquear_jugador()
	if touch and touch.has_method("desbloquear"):
		touch.desbloquear()


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
