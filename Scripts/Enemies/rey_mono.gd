extends CharacterBody2D

var vida = 100
var fase = 1

var puede_recibir_danio = false
var lacayos_vivos = 0
var en_recuperacion = false
var muerto = false

var hud

@onready var audio_boss = $AudioBoss
@export var escena_lacayo = preload("res://Scenes/Enemigos/mono.tscn")
@onready var anim = $AnimatedSprite2D


func _ready():
	visible = false


# -------- INICIO PELEA --------
func iniciar_pelea(hud_ref):
	
	audio_boss.stop()
	audio_boss.pitch_scale = 0.8  # más grave = más épico
	audio_boss.play()
	hud = hud_ref
	visible = true
	
	var spawn = get_tree().current_scene.get_node("SpawnBoss")
	global_position = spawn.global_position + Vector2(500, 0)
	
	anim.play("run")
	anim.flip_h = true
	
	var tween = create_tween()
	tween.tween_property(self, "global_position", spawn.global_position, 2.0)
	await tween.finished
	
	anim.play("idle")
	
	await mostrar_dialogo([
		"El Rey Mono ha aparecido...",
		"¡Derrotalo!"
	])
	
	hud.mostrar_barra_jefe(vida)
	
	iniciar_fase()


# -------- FASE --------
func iniciar_fase():
	audio_boss.stop()
	audio_boss.pitch_scale = randf_range(0.8, 1.0)
	audio_boss.play()
	puede_recibir_danio = false
	en_recuperacion = false
	
	var cantidad = 2 + fase * 2
	spawn_lacayos(cantidad)


# -------- SPAWN --------
# -------- SPAWN --------
func spawn_lacayos(cantidad):

	lacayos_vivos = cantidad

	# buscar jugador
	var jugador = get_tree().get_first_node_in_group("jugador")

	for i in cantidad:

		var mono = escena_lacayo.instantiate()

		mono.global_position = global_position + Vector2(
			randf_range(-150,150),
			0
		)

		# tamaño secuaces
		mono.scale = Vector2(3,3)

		get_parent().call_deferred("add_child", mono)

		# conectar muerte
		mono.connect(
			"tree_exited",
			Callable(self, "_on_lacayo_muerto")
		)

		# 👇 hacer que siga al jugador
		if jugador:
			mono.jugador = jugador

# -------- MUERTE LACAYOS --------
func _on_lacayo_muerto():
	lacayos_vivos -= 1
	
	if lacayos_vivos <= 0:
		mostrar_debilidad()


# -------- VULNERABLE --------
func mostrar_debilidad():
	puede_recibir_danio = true
	
	await mostrar_dialogo([
		"Está cansado...",
		"¡Atácalo ahora!"
	])


# -------- DAÑO --------
func recibir_danio(dmg: int, _posicion: Vector2):
	if not puede_recibir_danio or en_recuperacion or muerto:
		return
	
	vida -= dmg
	
	if hud:
		hud.actualizar_vida_jefe(vida)
	
	# 👉 recuperación
	en_recuperacion = true
	puede_recibir_danio = false
	
	await mostrar_dialogo([
		"¡Retrocede!",
		"Se está recuperando..."
	])
	
	await get_tree().create_timer(2.0).timeout
	
	# siguiente fase
	fase += 1
	
	if vida <= 0:
		morir()
	else:
		iniciar_fase()


# -------- MUERTE FINAL --------
func morir():
	# 1. AUDIO Y ESTADO INICIAL
	if audio_boss:
		audio_boss.stop()
		audio_boss.pitch_scale = 0.7 
		audio_boss.play()
	
	if muerto: return
	muerto = true
	
	# 2. LIMPIEZA DE INTERFAZ Y FÍSICAS
	if hud:
		hud.ocultar_barra_jefe()

	velocity = Vector2.ZERO
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)

	if has_node("AreaAtaque"):
		$AreaAtaque.set_deferred("monitoring", false)
	if has_node("ZonaDeteccion"):
		$ZonaDeteccion.set_deferred("monitoring", false)

	anim.play("idle")

	# 3. DIÁLOGO FINAL
	await mostrar_dialogo([
		"Hemos triunfado...",
		"Hemos recolectado la basura que afectaba",
		"a estos animales.",
		"La selva comienza a sanar..."
	])

	# 4. EFECTO VISUAL DE DESAPARICIÓN (TWEEN)
	var tween = create_tween()
	for i in range(6):
		tween.tween_property(anim, "modulate:a", 0.2, 0.1)
		tween.tween_property(anim, "modulate:a", 1.0, 0.1)

	tween.tween_property(anim, "modulate:a", 0.0, 0.5)
	await tween.finished
	
	# =========================================================
	# 🏆 GUARDADO SEGURO DE PUNTOS
	# =========================================================
	if has_node("/root/Global"):
		Global.confirmar_limpieza_nivel()
		Global.guardar_puntuacion_local()
		print("Puntos asegurados en el archivo .save")

	# 5. TRANSICIÓN DE PANTALLA (FADE OUT)
	var escena_actual = get_tree().current_scene
	var anim_player = escena_actual.find_child("AnimationPlayer", true, false)
	
	if anim_player:
		if anim_player.has_animation("Fade_out"):
			anim_player.play("Fade_out")
		else:
			anim_player.play(anim_player.get_animation_list()[0])
		await anim_player.animation_finished
	else:
		await get_tree().create_timer(1.0).timeout

	# 6. CAMBIO DE NIVEL
	var nombre_fichero = escena_actual.scene_file_path.to_lower()
	
	if "mundo.tscn" in nombre_fichero:
		get_tree().change_scene_to_file("res://Scenes/Level-2/mundo2.tscn")
	elif "mundo2.tscn" in nombre_fichero:
		get_tree().change_scene_to_file("res://Scenes/Level-3/mundo3.tscn")
	elif "mundo3.tscn" in nombre_fichero:
		get_tree().change_scene_to_file("res://Scenes/Level-4/mundo4.tscn")
	else:
		get_tree().change_scene_to_file("res://Scenes/Menus/MenuPrincipal.tscn")
	
	# 7. ELIMINAR AL JEFE
	queue_free()

# -------- DIÁLOGO --------
func mostrar_dialogo(textos: Array):
	if not is_inside_tree():
		return
	if get_tree().current_scene == null:
		return
	await Global.mostrar_dialogo_modal(textos)
