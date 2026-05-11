extends Node2D

# =========================================================
#                     MUNDO 3 - PANTANO
# =========================================================

# -------- PERSONAJES --------
var PRE_JAGUAR = preload("res://Scenes/Characters/Personaje1_Montado.tscn")
var PRE_HOMBRE = preload("res://Scenes/Characters/Personaje-1.tscn")
var PRE_MUJER = preload("res://Scenes/Characters/Personaje-2.tscn")

# -------- REFERENCIAS --------
var camara
var jugador

# 👹 JEFE (Ruta corregida según tus errores previos)
@onready var jefe = $Enemigos/Jefe/RanaVenenosa
@onready var punto_aparicion = $Marker2D
@onready var capa_pausa = $CapaPausa
@onready var hud = $HUD

# 🎵 AUDIO
@onready var musica_normal = $MusicaAmbiente
@onready var audio_boss = $AudioBossAmbiente

# -------- VARIABLES --------
var evento_jefe_iniciado = false
var evento_terminado = false # Nueva: Para saber si el jefe ya murió
var posicion_camara_guardada

# =========================================================
# READY
# =========================================================
func _ready():
	var anim_player = find_child("AnimationPlayer", true, false)
	if anim_player and anim_player.has_animation("Fade_out"):
		anim_player.play("Fade_out")
	
	if has_node("ArenaBoss/ParedIzquierda"):
		$ArenaBoss/ParedIzquierda/CollisionShape2D.disabled = true
	if has_node("ArenaBoss/ParedDerecha"):
		$ArenaBoss/ParedDerecha/CollisionShape2D.disabled = true

	if $Gameover: $Gameover.hide()
	if capa_pausa: capa_pausa.hide()
	if musica_normal: musica_normal.play()

	spawn_personaje()

	await mostrar_dialogo_y_esperar([
		"El pantano es traicionero...",
		"Los desechos químicos están alterando a la fauna.",
		"Debemos movernos con cuidado."
	])

# =========================================================
# SPAWN PERSONAJE
# =========================================================
func spawn_personaje():
	var instancia
	if Global.get("jaguar_desbloqueado") == true:
		if PRE_JAGUAR:
			instancia = PRE_JAGUAR.instantiate()
			instancia.controlado = true 
	else:
		if Global.personaje_seleccionado == "mujer":
			instancia = PRE_MUJER.instantiate()
		else:
			instancia = PRE_HOMBRE.instantiate()

	if instancia == null: return

	instancia.add_to_group("jugador")
	add_child(instancia)
	instancia.global_position = punto_aparicion.global_position
	jugador = instancia 

	if instancia.has_node("Camera2D"):
		camara = instancia.get_node("Camera2D")
		camara.make_current()
		

func _on_boton_pausa_pressed() -> void:

	get_tree().paused = true

	if capa_pausa:
		capa_pausa.show()


# =========================================================
# CINEMÁTICA JEFE
# =========================================================
# =========================================================
# CINEMÁTICA JEFE (Corregida con temblor inicial)
# =========================================================
func iniciar_cinematica_jefe():
	fijar_camara()     # 🔒 La cámara se clava en la arena
	bloquear_jugador() # 🚫 El jugador no se mueve

	# 📳 Sacudida inicial ANTES del diálogo para dar susto
	tremor_pantalla() 
	
	# 💬 1. Diálogo de advertencia
	await mostrar_dialogo_y_esperar([
		"¿Qué es ese olor a azufre?",
		"¡Algo se mueve rápidamente bajo el lodo!"
	])

	# 🚶 2. Retroceso del Jaguar (Para alejarse del peligro)
	await retroceder_jugador()

	# 📳 3. Otro pequeño temblor cuando el sapo está por saltar
	tremor_pantalla()

	# 🎵 4. Cambio de música
	if musica_normal: musica_normal.stop()
	if audio_boss: audio_boss.play()

	# 👹 5. El Sapo entra a escena
	if jefe:
		await jefe.iniciar_pelea(hud)

	# 🔓 Liberamos al jugador para pelear
	if is_instance_valid(jugador):
		jugador.set_physics_process(true)

# =========================================================
# FUNCIONES DE CÁMARA Y CONTROL
# =========================================================

func fijar_camara():
	if not is_instance_valid(camara): return
	
	posicion_camara_guardada = camara.global_position
	camara.reparent(self) # Se vuelve hija del mundo
	
	# La centramos exactamente donde está el Trigger (el centro de la arena)
	camara.global_position = $TriggerJefe.global_position
	
	# Quitamos el suavizado para que no se mueva nada
	if camara is Camera2D:
		camara.position_smoothing_enabled = false

func desbloquear_jugador():
	# Esta función la llamará el Sapo al morir mediante desactivar_arena()
	if is_instance_valid(jugador):
		jugador.set_physics_process(true)
		
		# Solo devolvemos la cámara si el jefe ya murió
		if evento_terminado:
			if is_instance_valid(camara):
				camara.reparent(jugador)
				camara.position = Vector2.ZERO
				camara.position_smoothing_enabled = true
	else:
		print("ADVERTENCIA: El jugador no existe al intentar desbloquear.")

func retroceder_jugador():
	if not is_instance_valid(jugador): return
	var destino = jugador.global_position.x - 150
	var tween = create_tween()
	if jugador.has_node("AnimatedSprite2D"):
		jugador.get_node("AnimatedSprite2D").play("run")
		jugador.get_node("AnimatedSprite2D").flip_h = true
	tween.tween_property(jugador, "global_position:x", destino, 0.8).set_trans(Tween.TRANS_SINE)
	await tween.finished
	if is_instance_valid(jugador) and jugador.has_node("AnimatedSprite2D"):
		jugador.get_node("AnimatedSprite2D").play("idle")
		jugador.get_node("AnimatedSprite2D").flip_h = false

# =========================================================
# GESTIÓN DE ARENA
# =========================================================

func activar_arena():
	$ArenaBoss/ParedIzquierda/CollisionShape2D.set_deferred("disabled", false)
	$ArenaBoss/ParedDerecha/CollisionShape2D.set_deferred("disabled", false)

func desactivar_arena():
	evento_terminado = true # Marcamos que la pelea acabó
	$ArenaBoss/ParedIzquierda/CollisionShape2D.set_deferred("disabled", true)
	$ArenaBoss/ParedDerecha/CollisionShape2D.set_deferred("disabled", true)
	
	if audio_boss: audio_boss.stop()
	if musica_normal: musica_normal.play()
	
	# Ahora sí devolvemos la cámara al Jaguar
	desbloquear_jugador()

func bloquear_jugador():
	if is_instance_valid(jugador):
		jugador.set_physics_process(false)
		if jugador.has_node("AnimatedSprite2D"):
			jugador.get_node("AnimatedSprite2D").play("idle")

func tremor_pantalla():
	var tween = create_tween()
	for i in range(15):
		var offset = Vector2(randf_range(-10, 10), randf_range(-10, 10))
		tween.tween_property(camara, "offset", offset, 0.03)
	tween.tween_property(camara, "offset", Vector2.ZERO, 0.1)

func mostrar_dialogo_y_esperar(textos: Array) -> void:
	await Global.mostrar_dialogo_modal(textos)

func _on_trigger_jefe_body_entered(body: Node2D) -> void:
	if body.is_in_group("jugador") and not evento_jefe_iniciado:
		evento_jefe_iniciado = true
		$TriggerJefe.set_deferred("monitoring", false)
		activar_arena()
		await iniciar_cinematica_jefe()
