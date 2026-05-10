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
	audio_boss.stop()
	audio_boss.pitch_scale = 0.7  # más grave aún
	audio_boss.play()
	if muerto:
		return
	
	muerto = true
	
	if hud:
		hud.ocultar_barra_jefe()

	velocity = Vector2.ZERO

	# ❌ Desactivar colisiones
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)

	if has_node("AreaAtaque"):
		$AreaAtaque.set_deferred("monitoring", false)
	if has_node("ZonaDeteccion"):
		$ZonaDeteccion.set_deferred("monitoring", false)

	anim.play("idle")

	# 🟢 DIÁLOGO FINAL
	await mostrar_dialogo([
		"Hemos triunfado...",
		"Hemos recolectado la basura que afectaba a estos pobres animales.",
		"La selva comienza a sanar..."
	])

	# ⚡ PARPADEO
	var tween = create_tween()

	for i in range(6):
		tween.tween_property(anim, "modulate:a", 0.2, 0.1)
		tween.tween_property(anim, "modulate:a", 1.0, 0.1)

	# 🌫️ DESAPARECER
	tween.tween_property(anim, "modulate:a", 0.0, 0.5)

	await tween.finished

	queue_free()


# -------- DIÁLOGO --------
func mostrar_dialogo(textos: Array):
	if not is_inside_tree():
		return
	
	var escena = get_tree().current_scene
	if escena == null:
		return
	
	var d = preload("res://Scenes/Dialogos/Dialogo1/interfaz_dialogo.tscn").instantiate()
	escena.add_child(d)
	d.iniciar_dialogo(textos)
	await d.dialogo_terminado
