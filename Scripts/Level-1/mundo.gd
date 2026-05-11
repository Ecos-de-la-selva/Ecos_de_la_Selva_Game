extends Node2D

# --- CONFIG ---
var PRE_HOMBRE = preload("res://Scenes/Characters/Personaje-1.tscn")
var PRE_MUJER = preload("res://Scenes/Characters/Personaje-2.tscn")

var camara
var jugador

@onready var jefe = $"Enemigos/Jefe/Rey Mono"
@onready var punto_aparicion = $Marker2D 
@onready var capa_pausa = $CapaPausa
@onready var hud = $HUD


# 🎵 AUDIO
@onready var musica_normal = $MusicaAmbiente
@onready var audio_boss = $AudioBossAmbiente

var evento_jefe_iniciado = false
var posicion_camara_guardada

func _ready():
	var anim_player = find_child("AnimationPlayer", true, false)
	if anim_player and anim_player.has_animation("Fade_out"):
		anim_player.play("Fade_out")
	# 🔒 Arena desactivada al inicio
	$ArenaBoss/ParedIzquierda/CollisionShape2D.disabled = true
	$ArenaBoss/ParedDerecha/CollisionShape2D.disabled = true
	
	if $Gameover:
		$Gameover.hide()
	if capa_pausa:
		capa_pausa.hide()

	# 🎵 Música normal
	if musica_normal:
		musica_normal.play()

	spawn_personaje()

	# 📖 DIÁLOGO INICIAL
	await mostrar_dialogo_y_esperar([
		"El Putumayo está en peligro...",
		"La contaminación ha transformado a los animales.",
		"Recoge los residuos que dejan para sanar la selva."
	])


# -------- SPAWN PERSONAJE --------
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
	
	if instancia.has_node("Camera2D"):
		camara = instancia.get_node("Camera2D")
		camara.make_current()


# -------- ACTIVAR ARENA --------
func activar_arena():
	$ArenaBoss/ParedIzquierda/CollisionShape2D.set_deferred("disabled", false)
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
		
		$TriggerJefe.set_deferred("monitoring", false)
		activar_arena()
		
		await iniciar_cinematica_jefe()


# -------- CINEMÁTICA --------
func iniciar_cinematica_jefe():
	fijar_camara()
	bloquear_jugador()
	
	await llevar_jugador_a_posicion()
	tremor_pantalla()
	
	# 🧠 DIÁLOGO PREVIO
	await mostrar_dialogo_y_esperar([
		"¿Qué pasa?",
		"Algo se acerca..."
	])

	# 🔇 APAGAR música normal
	if musica_normal and musica_normal.playing:
		musica_normal.stop()

	# 🔥 ENCENDER música del boss
	if audio_boss:
		audio_boss.play()

	# 👹 ENTRA EL JEFE
	if jefe:
		await jefe.iniciar_pelea(hud)
	
	desbloquear_jugador()


# -------- DIÁLOGO --------
func mostrar_dialogo_y_esperar(textos: Array) -> void:
	# Bloquea al jugador y oculta los controles táctiles mientras se muestra el diálogo
	var ya_bloqueado = jugador and not jugador.is_physics_processing()
	if jugador and not ya_bloqueado:
		bloquear_jugador()
	var touch = get_node_or_null("Controles")
	if touch and touch.has_method("bloquear"):
		touch.bloquear()
	
	var d = preload("res://Scenes/Dialogos/Dialogo1/interfaz_dialogo.tscn").instantiate()
	add_child(d)
	d.iniciar_dialogo(textos)
	await d.dialogo_terminado
	
	# Desbloquea solo si nosotros lo bloqueamos aquí
	if jugador and not ya_bloqueado:
		desbloquear_jugador()
	if touch and touch.has_method("desbloquear"):
		touch.desbloquear()


# -------- CÁMARA --------
func fijar_camara():
	posicion_camara_guardada = camara.global_position
	camara.reparent(self)
	camara.global_position = posicion_camara_guardada


# -------- MOVIMIENTO --------
func llevar_jugador_a_posicion():
	var destino = camara.global_position + Vector2(-250, 0)
	var tween = create_tween()
	tween.tween_property(jugador, "global_position", destino, 1.0)
	await tween.finished


# -------- CONTROL --------
func bloquear_jugador():
	jugador.set_physics_process(false)

func desbloquear_jugador():
	jugador.set_physics_process(true)


# -------- EFECTO --------
func tremor_pantalla():
	var tween = create_tween()
	for i in range(10):
		var offset = Vector2(randf_range(-10, 10), randf_range(-10, 10))
		tween.tween_property(camara, "offset", offset, 0.05)
	tween.tween_property(camara, "offset", Vector2.ZERO, 0.1)


# -------- DESACTIVAR ARENA (cuando gane) --------
func desactivar_arena():
	$ArenaBoss/ParedIzquierda/CollisionShape2D.set_deferred("disabled", true)
	$ArenaBoss/ParedDerecha/CollisionShape2D.set_deferred("disabled", true)

	# 🔥 detener música boss
	if audio_boss and audio_boss.playing:
		audio_boss.stop()

	# 🎵 volver música normal
	if musica_normal:
		musica_normal.play()
		
		
