extends Node2D

# --- CONFIG ---
var PRE_HOMBRE = preload("res://Scenes/Characters/Personaje-1.tscn")
var PRE_MUJER = preload("res://Scenes/Characters/Personaje-2.tscn")

var camara
var jugador

@onready var punto_aparicion = $Marker2D
@onready var capa_pausa = $CapaPausa
@onready var hud = $HUD

#  AUDIO
@onready var musica_normal = $MusicaAmbiente

var evento_jefe_iniciado = false
var posicion_camara_guardada


func _ready():
	#  Arena desactivada al inicio (si existe en la escena)
	if has_node("ArenaBoss/ParedIzquierda/CollisionShape2D"):
		$ArenaBoss/ParedIzquierda/CollisionShape2D.disabled = true
	if has_node("ArenaBoss/ParedDerecha/CollisionShape2D"):
		$ArenaBoss/ParedDerecha/CollisionShape2D.disabled = true

	if has_node("Gameover"):
		$Gameover.hide()
	if capa_pausa:
		capa_pausa.hide()

	#  Música normal
	if musica_normal:
		musica_normal.play()

	spawn_personaje()
	await esperar_jugador_en_piso()

	#  DIÁLOGO INICIAL
	# Pausamos todo el árbol del juego para que ni el jugador ni los enemigos
	# se muevan mientras se lee el texto. El diálogo tiene
	# process_mode = ALWAYS, así que sigue funcionando.
	get_tree().paused = true
	await mostrar_dialogo_y_esperar([
		"La selva se vuelve más densa...",
		"Un antiguo templo se alza entre la maleza.",
		"Sus ecos guardan el alma corrupta de la selva.",
		"Avanza y libera lo que aún puede ser sanado."
	])
	get_tree().paused = false


# -------- ESPERAR PISO INICIAL --------
func esperar_jugador_en_piso() -> void:
	if jugador == null:
		return

	# Al iniciar, el personaje puede aparecer un poco arriba del suelo.
	# Dejamos correr la física hasta que caiga antes de mostrar el diálogo.
	var intentos := 0
	while is_instance_valid(jugador) and jugador.has_method("is_on_floor") and not jugador.is_on_floor() and intentos < 120:
		intentos += 1
		await get_tree().physics_frame


# -------- SPAWN PERSONAJE --------
func spawn_personaje():
	# Si la escena trae un personaje pre-instanciado, lo retiramos
	# para respetar la selección del jugador (hombre/mujer).
	if has_node("Personaje1"):
		$Personaje1.queue_free()
	if has_node("Personaje2"):
		$Personaje2.queue_free()

	var instancia
	if Global.personaje_seleccionado == "mujer":
		instancia = PRE_MUJER.instantiate()
		if hud and hud.has_method("configurar_hud"):
			hud.configurar_hud("mujer")
	else:
		instancia = PRE_HOMBRE.instantiate()
		if hud and hud.has_method("configurar_hud"):
			hud.configurar_hud("hombre")

	instancia.add_to_group("jugador")
	add_child(instancia)
	if punto_aparicion:
		instancia.global_position = punto_aparicion.global_position

	jugador = instancia

	if instancia.has_node("Camera2D"):
		camara = instancia.get_node("Camera2D")
		#  Los límites por defecto de la cámara del personaje son los del Nivel 1
		# (limit_bottom = 360, limit_right = 18056). En el Nivel 2 esos límites
		# atrapan la cámara y no deja seguir al jugador, así que los abrimos.
		camara.limit_left = -10000000
		camara.limit_top = -10000000
		camara.limit_right = 10000000
		camara.limit_bottom = 10000000
		camara.reset_smoothing()
		camara.make_current()


# -------- ACTIVAR ARENA --------
func activar_arena():
	if has_node("ArenaBoss/ParedIzquierda/CollisionShape2D"):
		$ArenaBoss/ParedIzquierda/CollisionShape2D.set_deferred("disabled", false)
	if has_node("ArenaBoss/ParedDerecha/CollisionShape2D"):
		$ArenaBoss/ParedDerecha/CollisionShape2D.set_deferred("disabled", false)


# -------- PAUSA --------
func _on_boton_pausa_pressed() -> void:
	get_tree().paused = true
	if capa_pausa:
		capa_pausa.show()


# -------- TRIGGER --------
func _on_trigger_jefe_body_entered(body: Node2D) -> void:
	if body.is_in_group("jugador") and not evento_jefe_iniciado:
		evento_jefe_iniciado = true

		if has_node("TriggerJefe"):
			$TriggerJefe.set_deferred("monitoring", false)
		activar_arena()

		await iniciar_cinematica_jefe()


# -------- CINEMÁTICA --------
func iniciar_cinematica_jefe():
	fijar_camara()
	bloquear_jugador()

	await llevar_jugador_a_posicion()
	tremor_pantalla()

	#  DIÁLOGO PREVIO
	await mostrar_dialogo_y_esperar([
		"El aire se ha vuelto pesado...",
		"Algo enorme se acerca desde las sombras."
	])

	#  APAGAR música normal
	if musica_normal and musica_normal.playing:
		musica_normal.stop()

	#  ENCENDER música del boss (si existe)
	if has_node("AudioBossAmbiente"):
		$AudioBossAmbiente.play()

	#  ENTRA EL JEFE (Genio del templo)
	var jefe = get_node_or_null("Enemigos/Jefe/JefeGenio")
	if jefe == null:
		# Compatibilidad con jefes anteriores
		jefe = get_node_or_null("Enemigos/Jefe/Rey Mono")
	if jefe and jefe.has_method("iniciar_pelea"):
		await jefe.iniciar_pelea(hud)

	desbloquear_jugador()


# -------- DIÁLOGO --------
func mostrar_dialogo_y_esperar(textos: Array) -> void:
	var d = preload("res://Scenes/Dialogos/Dialogo1/interfaz_dialogo.tscn").instantiate()
	add_child(d)
	d.iniciar_dialogo(textos)
	await d.dialogo_terminado


# -------- CÁMARA --------
func fijar_camara():
	if camara == null:
		return
	posicion_camara_guardada = camara.global_position
	camara.reparent(self)
	camara.global_position = posicion_camara_guardada


# -------- MOVIMIENTO --------
func llevar_jugador_a_posicion():
	if camara == null or jugador == null:
		return
	var destino = camara.global_position + Vector2(-250, 0)
	var tween = create_tween()
	tween.tween_property(jugador, "global_position", destino, 1.0)
	await tween.finished


# -------- CONTROL --------
func bloquear_jugador():
	if jugador:
		jugador.set_physics_process(false)


func desbloquear_jugador():
	if jugador:
		jugador.set_physics_process(true)


# -------- EFECTO --------
func tremor_pantalla():
	if camara == null:
		return
	var tween = create_tween()
	for i in range(10):
		var offset = Vector2(randf_range(-10, 10), randf_range(-10, 10))
		tween.tween_property(camara, "offset", offset, 0.05)
	tween.tween_property(camara, "offset", Vector2.ZERO, 0.1)


# -------- DESACTIVAR ARENA (cuando gane) --------
func desactivar_arena():
	if has_node("ArenaBoss/ParedIzquierda/CollisionShape2D"):
		$ArenaBoss/ParedIzquierda/CollisionShape2D.set_deferred("disabled", true)
	if has_node("ArenaBoss/ParedDerecha/CollisionShape2D"):
		$ArenaBoss/ParedDerecha/CollisionShape2D.set_deferred("disabled", true)

	#  detener música boss
	if has_node("AudioBossAmbiente"):
		var audio_boss = $AudioBossAmbiente
		if audio_boss.playing:
			audio_boss.stop()

	#  volver música normal
	if musica_normal:
		musica_normal.play()
