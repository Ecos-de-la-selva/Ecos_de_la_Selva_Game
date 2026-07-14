extends CharacterBody2D

# =========================================================
#                    REY PESTE - BOSS
# =========================================================

# ---------------- VIDA ----------------
var vida = 90
var fase = 1

# ---------------- ESTADOS ----------------
var muerto = false
var atacando = false
var en_picado = false
var preparando_picado = false
var recibiendo_golpe = false
var vulnerable = false
var bloqueado = true # Controla si el jefe puede actuar o está pausado por diálogos

# ---------------- REFERENCIAS ----------------
var hud
var jugador

# ---------------- CONFIG ----------------
@export var velocidad_vuelo = 220.0
@export var velocidad_picado: float = 1200.0

# ---------------- INVOCACIONES ----------------
@export var escena_lacayo = preload("res://Scenes/Enemigos/volador.tscn")
var lacayos_vivos = 0

# ---------------- NODOS ----------------
@onready var anim = $AnimatedSprite2D
@onready var audio_boss = $SonidoPeste

func _ready():
	visible = false
	add_to_group("enemigos")
	bloqueado = true 

# =========================================================
# INICIAR PELEA
# =========================================================
func iniciar_pelea(hud_ref):
	hud = hud_ref
	visible = true
	jugador = get_tree().get_first_node_in_group("jugador")

	audio_boss.pitch_scale = 0.8 
	audio_boss.play()

	# Posicionar al jefe a la derecha del Spawn antes de entrar
	var spawn = get_tree().current_scene.get_node("SpawnBoss")
	global_position = spawn.global_position + Vector2(900, -200)

	anim.play("fly")
	
	# Entrada suave con Tween (Derecha a Izquierda)
	var tween = create_tween()
	# Usamos transiciones suaves aptas para mobile
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", spawn.global_position, 3.0)
	
	# Retornamos el tween para que el mundo sepa exactamente cuándo termina de moverse
	return tween
# =========================================================
# CONTROL DE FASES (AQUÍ SE REPITE EL CICLO)
# =========================================================
# =========================================================
# CONTROL DE FASES (REVISADO)
# =========================================================
func iniciar_fase():
	if muerto: return
	vulnerable = false
	atacando = false
	
	# FASE IMPAR (1, 3, 5...) -> ATAQUE
	if fase % 2 != 0:
		bloqueado = true
		await mostrar_dialogo(["¡Va a lanzarse!"])
		bloqueado = false
		iniciar_picado()

	# FASE PAR (2, 4, 6...) -> INVOCAR
	else:
		bloqueado = true
		await mostrar_dialogo(["Está invocando criaturas..."])
		
		# Cambiamos a animación de idle/invocar
		anim.play("idle")
		
		# Llamamos al spawn (Asegúrate de que la función spawn_lacayos esté abajo)
		var cantidad = 2 + (fase / 2) 
		spawn_lacayos(cantidad)
		
		print("Jefe esperando a que mueran los ", cantidad, " lacayos...")
		# El código se detiene aquí porque bloqueado = true. 
		# Seguirá en _on_lacayo_muerto() cuando lacayos_vivos == 0.
		
		
		# Después de los lacayos, se vuelve vulnerable
	
	

# =========================================================
# PHYSICS (ANIMACIÓN Y MOVIMIENTO)
# =========================================================
func _physics_process(delta):
	if muerto: return

	# --- VISUALES (Siempre activos) ---
	if jugador:
		anim.flip_h = jugador.global_position.x > global_position.x

	# Flotación constante (Idle/Fly)
	var frecuencia = 0.004
	var amplitud = 25 if (bloqueado or vulnerable) else 40
	position.y += sin(Time.get_ticks_msec() * frecuencia) * delta * amplitud

	# --- BLOQUEO DE ACCIONES ---
	if bloqueado:
		anim.play("idle")
		return

	if recibiendo_golpe:
		move_and_slide()
		return

	if en_picado:
		var colision = move_and_collide(velocity * delta)
		if colision:
			var obj = colision.get_collider()
			if obj.is_in_group("suelo") or obj.name.contains("Tile"):
				terminar_picado()
		return

	# Movimiento normal si no está haciendo nada más
	if not atacando and not vulnerable:
		anim.play("fly")
		if jugador:
			# Seguir x al jugador
			var dir_x = sign(jugador.global_position.x - global_position.x)
			global_position.x += dir_x * velocidad_vuelo * delta * 0.3

# =========================================================
# LÓGICA DE ATAQUE
# =========================================================
func iniciar_picado():
	if atacando or muerto: return
	atacando = true
	
	# Preparación
	var tw = create_tween()
	tw.tween_property(self, "global_position:y", global_position.y - 80, 0.25)
	await tw.finished

	if jugador:
		var tw2 = create_tween()
		tw2.tween_property(self, "global_position", jugador.global_position + Vector2(0, -250), 0.45)
		anim.play("attack")
		await tw2.finished

	preparando_picado = false
	en_picado = true
	set_collision_mask_value(1, false) 

	velocity = Vector2(0, float(velocidad_picado))

func terminar_picado():
	en_picado = false
	velocity = Vector2.ZERO
	
	# REACTIVAR colisión con el jugador
	set_collision_mask_value(1, true) 

	anim.play("idle")
	await get_tree().create_timer(1.0).timeout
	mostrar_debilidad()

func mostrar_debilidad():
	vulnerable = true
	bloqueado = true
	await mostrar_dialogo(["¡Está debilitado!", "¡Atácalo ahora!"])
	bloqueado = false

# =========================================================
# RECIBIR DAÑO Y CAMBIO DE FASE
# =========================================================
func recibir_danio(dmg: int, posicion_atacante: Vector2):
	# Si ya está muerto, no procesar nada (evita llamadas fantasmales)
	if muerto or not vulnerable: return

	vida -= dmg
	if hud: hud.actualizar_vida_jefe(vida)
	
	vulnerable = false
	recibiendo_golpe = true
	audio_boss.play()

	var tw = create_tween()
	tw.tween_property(anim, "modulate", Color(10,10,10), 0.05)
	tw.tween_property(anim, "modulate", Color(1,1,1), 0.05)

	if vida <= 0:
		# Llamada segura
		call_deferred("morir")
		return

	await get_tree().create_timer(0.4).timeout
	if not is_inside_tree() or muerto: return # Candado tras timer
	
	recibiendo_golpe = false
	fase += 1
	iniciar_fase()
# =========================================================
# LACAYOS
# =========================================================
# =========================================================
# LACAYOS (REVISADO Y CORREGIDO)
# =========================================================
# =========================================================
# LACAYOS (APARICIÓN CONCENTRADA)
# =========================================================
func spawn_lacayos(cantidad):
	lacayos_vivos = cantidad
	print("Invocando ", cantidad, " lacayos sobre el jefe...")

	for i in range(cantidad):
		var enemigo = escena_lacayo.instantiate()
		
		# 🟢 POSICIÓN: Justo en el jefe con un pequeño margen de 50 píxeles
		# Esto evita que aparezcan dispersos por todo el mapa
		var variacion_minima = Vector2(randf_range(-50, 50), randf_range(-50, 50))
		enemigo.global_position = global_position + variacion_minima
		
		# Escala 2x para que se vean como esbirros del jefe
		enemigo.scale = Vector2(2, 2)
		
		# IMPORTANTE: Añadir al padre (la escena de nivel)
		get_parent().add_child(enemigo) 

		# Pasar la referencia del jugador para que el volador empiece a perseguirlo
		enemigo.jugador = jugador
		
		# Conectar la señal de muerte para que el jefe sepa cuándo debilitarse
		if not enemigo.is_connected("tree_exited", _on_lacayo_muerto):
			enemigo.tree_exited.connect(_on_lacayo_muerto)
			
		print("Lacayo ", i, " invocado en posición: ", enemigo.global_position)

func _on_lacayo_muerto():
	# Si el jefe ya murió o no está en el mapa, ignorar la señal
	if muerto or not is_inside_tree(): 
		return
		
	lacayos_vivos -= 1
	if lacayos_vivos <= 0:
		# call_deferred ejecuta la función en el siguiente frame libre
		call_deferred("mostrar_debilidad")
		
func esperar_lacayos():
	# Ya no necesitamos el bucle while. 
	# Esta función solo servirá para imprimir un mensaje o esperar un segundo inicial
	print("Esperando a que el jugador elimine a los lacayos...")
	return

# =========================================================
# DIÁLOGOS Y MUERTE
# =========================================================
func mostrar_dialogo(textos: Array):
	var d = preload("res://Scenes/Dialogos/Dialogo1/interfaz_dialogo.tscn").instantiate()
	get_tree().current_scene.add_child(d)
	d.iniciar_dialogo(textos)
	await d.dialogo_terminado

# =========================================================
# DIÁLOGOS Y MUERTE (MODIFICADO PARA PUNTUACIÓN)
# =========================================================
func morir():
	if muerto: return 
	muerto = true
	bloqueado = true
	
	# CANDADO 1: Detener procesos de Godot para este nodo
	set_physics_process(false)
	set_process(false)

	if audio_boss: audio_boss.stop()
	if hud: hud.ocultar_barra_jefe()

	if anim.sprite_frames.has_animation("die"):
		anim.play("die")
	
	# CANDADO 2: Referencia segura antes de los diálogos
	if is_inside_tree():
		await mostrar_dialogo([
			"El Rey Peste ha caído...",
			"El cielo vuelve a respirar...",
			"La selva está sanando..."
		])

	# CANDADO 3: Verificar si el jefe sigue vivo en memoria tras el diálogo
	if not is_inside_tree(): return

	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(anim, "modulate:a", 0.0, 1.5) 
	tw.tween_property(self, "global_position:y", global_position.y + 100, 1.5) 
	
	await tw.finished

	# PUNTOS
	if has_node("/root/Global"):
		Global.confirmar_limpieza_nivel()
		Global.guardar_puntuacion_local()

	# TRANSICIÓN
	var escena_actual = get_tree().current_scene
	var anim_player = escena_actual.find_child("AnimationPlayer", true, false)
	
	if anim_player and anim_player.has_animation("Fade_out"):
		anim_player.play("Fade_out")
		await anim_player.animation_finished
	
	# CAMBIO DE ESCENA
	var ruta_nivel_3 = "res://Scenes/Level-3/mundo3.tscn"
	var error = get_tree().change_scene_to_file(ruta_nivel_3)
	
	if error != OK:
		get_tree().change_scene_to_file("res://Scenes/Menus/MenuPrincipal.tscn")
	
	# Solo liberamos memoria al final de TODO
	queue_free()
	
func _on_area_ataque_body_entered(body):
	if muerto:
		return

	if body.is_in_group("jugador"):
		# Si el jefe está cayendo (picado), aplica daño al atravesar
		if en_picado:
			if body.has_method("recibir_danio"):
				body.recibir_danio(30, global_position) # Enviamos daño y posición
				print("¡Jefe atravesó al jugador causando daño!")
