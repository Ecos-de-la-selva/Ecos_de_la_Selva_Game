extends CharacterBody2D

# =========================================================
#                JEFE: MURCIÉLAGO REY
# =========================================================

var vida = 90
var fase = 1

var puede_recibir_danio = false
var lacayos_vivos = 0
var en_recuperacion = false
var muerto = false

var hud

# 🟢 CORRECCIÓN: Usando el nodo correcto de audio
@onready var sonido_murcielago = $SonidoMurcielago
@export var escena_lacayo = preload("res://Scenes/Enemigos/murcielago.tscn") 
@onready var anim = $AnimatedSprite2D

func _ready():
	visible = false

# -------- PREPARAR ENTRADA (Llamado desde el Mundo) --------
func preparar_entrada():
	visible = true
	if sonido_murcielago:
		sonido_murcielago.pitch_scale = 0.8
		sonido_murcielago.play()
	
	var spawn = get_tree().current_scene.get_node("SpawnBoss")
	global_position = Vector2(spawn.global_position.x + 500, spawn.global_position.y)
	
	anim.play("idle") # O el nombre real de tu animación
	
	# 🟢 CAMBIA ESTO A FALSE para que mire a la izquierda durante el viaje
	anim.flip_h = false

# -------- INICIAR OLEADAS (Llamado tras los diálogos del Mundo) --------
func empezar_combate():
	if hud: 
		hud.mostrar_barra_jefe(vida)
	iniciar_fase()

# -------- FASE --------
func iniciar_fase():
	if muerto: return
	if sonido_murcielago:
		sonido_murcielago.stop()
		sonido_murcielago.pitch_scale = randf_range(0.8, 1.0)
		sonido_murcielago.play()
		
	puede_recibir_danio = false
	en_recuperacion = false
	
	anim.play("idle")
	var cantidad = 2 + fase * 2
	spawn_lacayos(cantidad)

# -------- SPAWN --------
func spawn_lacayos(cantidad):
	lacayos_vivos = cantidad
	var jugador = get_tree().get_first_node_in_group("jugador")

	for i in cantidad:
		var mini_bat = escena_lacayo.instantiate()
		mini_bat.global_position = global_position + Vector2(randf_range(-150, 150), randf_range(-50, 50))
		
		# Tamaño secuaces
		mini_bat.scale = Vector2(3, 3)
		get_parent().call_deferred("add_child", mini_bat)

		mini_bat.tree_exited.connect(_on_lacayo_muerto)

		if jugador:
			mini_bat.jugador = jugador

# -------- MUERTE LACAYOS --------
func _on_lacayo_muerto():
	if muerto: return
	lacayos_vivos -= 1
	
	if lacayos_vivos <= 0:
		call_deferred("mostrar_debilidad")

# -------- VULNERABLE --------
func mostrar_debilidad():
	if muerto or en_recuperacion: return
	puede_recibir_danio = true
	anim.play("idle")
	
	var mundo = get_tree().current_scene
	if mundo.has_method("mostrar_dialogo_y_esperar"):
		await mundo.mostrar_dialogo_y_esperar([
			"¡El Murciélago Rey se ha cansado!",
			"¡Atácalo ahora!"
		])

# -------- DAÑO --------
func recibir_danio(dmg: int, _posicion: Vector2):
	if not puede_recibir_danio or en_recuperacion or muerto:
		return
	
	vida -= dmg
	if hud:
		hud.actualizar_vida_jefe(vida)
	
	en_recuperacion = true
	puede_recibir_danio = false
	
	if sonido_murcielago:
		sonido_murcielago.play() # Sonido de dolor/grito
	
	var mundo = get_tree().current_scene
	if mundo.has_method("mostrar_dialogo_y_esperar"):
		await mundo.mostrar_dialogo_y_esperar([
			"¡Retrocede!",
			"Se está recuperando..."
		])
	
	await get_tree().create_timer(1.5).timeout
	
	fase += 1
	
	if vida <= 0:
		morir()
	else:
		iniciar_fase()

# -------- MUERTE FINAL --------
func morir():
	if muerto: return
	muerto = true
	
	if sonido_murcielago:
		sonido_murcielago.stop()
		sonido_murcielago.pitch_scale = 0.6 
		sonido_murcielago.play()
	
	if hud:
		hud.ocultar_barra_jefe()

	velocity = Vector2.ZERO
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)

	anim.play("idle")

	var mundo = get_tree().current_scene
	if mundo.has_method("mostrar_dialogo_y_esperar"):
		await mundo.mostrar_dialogo_y_esperar([
			"Hemos triunfado...",
			"La plaga de murciélagos se dispersa.",
			"La selva comienza a sanar..."
		])

	var tween = create_tween()
	for i in range(6):
		tween.tween_property(anim, "modulate:a", 0.2, 0.08)
		tween.tween_property(anim, "modulate:a", 1.0, 0.08)

	tween.tween_property(anim, "modulate:a", 0.0, 0.5)
	await tween.finished
	
	if has_node("/root/Global"):
		Global.confirmar_limpieza_nivel()
		Global.guardar_puntuacion_local()

	var escena_actual = get_tree().current_scene
	var anim_player = escena_actual.find_child("AnimationPlayer", true, false)
	
	if anim_player and anim_player.has_animation("Fade_out"):
		anim_player.play("Fade_out")
		await anim_player.animation_finished
	else:
		await get_tree().create_timer(1.0).timeout

	var nombre_fichero = escena_actual.scene_file_path.to_lower()
	if "mundo.tscn" in nombre_fichero:
		get_tree().change_scene_to_file("res://Scenes/Level-2/mundo2.tscn")
	elif "mundo2.tscn" in nombre_fichero:
		get_tree().change_scene_to_file("res://Scenes/Level-3/mundo3.tscn")
	else:
		get_tree().change_scene_to_file("res://Scenes/Menus/MenuPrincipal.tscn")
	
	queue_free()
