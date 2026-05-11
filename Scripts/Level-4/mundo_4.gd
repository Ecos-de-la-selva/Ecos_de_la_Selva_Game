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
		"Se nos Anochecio..",
		"Ten Cuidado con los murcielagos",
		"Hay mas en la noche",
		"Vamos con cuidado..."
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

	
	# 🧠 DIÁLOGO PREVIO
	await mostrar_dialogo_y_esperar([
		"¿Y ahora que?",
		"Algo se acerca...",
		"Tu otra vez?"
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
	await Global.mostrar_dialogo_modal(textos)


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
		
		
