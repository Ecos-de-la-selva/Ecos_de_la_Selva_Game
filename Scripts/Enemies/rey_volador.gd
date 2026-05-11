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

	audio_boss.pitch_scale = 0.8 # Un tono más grave para que suene imponente
	audio_boss.play()

	var spawn = get_tree().current_scene.get_node("SpawnBoss")
	global_position = spawn.global_position + Vector2(900, -200)

	anim.play("fly")
	
	# Entrada suave con Tween
	var tween = create_tween()
	tween.tween_property(self, "global_position", spawn.global_position, 3.0)
	await tween.finished

	await mostrar_dialogo([
		"El Rey Peste apareció...",
		"¡Cuidado con sus ataques aéreos!"
	])

	if hud: hud.mostrar_barra_jefe(vida)
	
	bloqueado = false
	iniciar_fase()

# =========================================================
# CONTROL DE FASES (AQUÍ SE REPITE EL CICLO)
# =========================================================
func iniciar_fase():
	if muerto: return
	vulnerable = false
	atacando = false
	
	# FASE IMPAR -> ATAQUE
	if fase % 2 != 0:
		bloqueado = true
		await mostrar_dialogo(["¡Va a lanzarse!"])
		bloqueado = false
		iniciar_picado()

	# FASE PAR -> INVOCAR
	else:
		bloqueado = true
		await mostrar_dialogo(["Está invocando criaturas..."])
		anim.play("idle")
		
		spawn_lacayos(2 + fase) 
		
		# IMPORTANTE: No ponemos código después de aquí. 
		# El jefe se quedará en IDLE (flotando) porque bloqueado = true.
		# El ciclo continuará SOLO cuando el último lacayo muera 
		# y ejecute la señal que llama a 'mostrar_debilidad()'.
		print("Jefe esperando a que mueran los lacayos...")
		
		
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
	if muerto or not vulnerable: return

	vida -= dmg
	if hud: hud.actualizar_vida_jefe(vida)
	
	vulnerable = false
	recibiendo_golpe = true

	audio_boss.pitch_scale = 0.8 # Un tono más grave para que suene imponente
	audio_boss.play()
	# Retroceso
	velocity = (global_position - posicion_atacante).normalized() * 350
	
	# Flash
	var tw = create_tween()
	tw.tween_property(anim, "modulate", Color(10,10,10), 0.05)
	tw.tween_property(anim, "modulate", Color(1,1,1), 0.05)

	await get_tree().create_timer(0.4).timeout
	recibiendo_golpe = false

	if vida <= 0:
		morir()
		return

	# Pausa para cambiar de fase
	bloqueado = true
	await mostrar_dialogo(["¡Argh!", "¡No me vencerás tan fácil!"])
	await get_tree().create_timer(1.0).timeout
	
	fase += 1 # Aquí cambiamos a la siguiente fase (si era 1 pasa a 2, etc.)
	iniciar_fase()

# =========================================================
# LACAYOS
# =========================================================
func spawn_lacayos(cantidad):
	lacayos_vivos = cantidad

	for i in range(cantidad):
		var enemigo = escena_lacayo.instantiate()
		enemigo.global_position = global_position + Vector2(
			randf_range(-250,250),
			randf_range(-120,120)
		)

		enemigo.scale = Vector2(2,2)
		get_parent().add_child(enemigo) # Añadir al padre (la escena)

		enemigo.jugador = jugador
		
		# Conectar la señal de cuando el lacayo sale de la escena (muere)
		if not enemigo.is_connected("tree_exited", _on_lacayo_muerto):
			enemigo.tree_exited.connect(_on_lacayo_muerto)

func _on_lacayo_muerto():
	lacayos_vivos -= 1
	print("Lacayo eliminado. Quedan: ", lacayos_vivos)
	
	# Si ya no quedan lacayos y estábamos en la fase de espera
	if lacayos_vivos <= 0:
		print("¡Todos los lacayos han muerto! El jefe se debilita.")
		# Llamamos directamente a mostrar_debilidad para continuar el ciclo
		mostrar_debilidad()

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

func morir():
	if muerto: return # Seguridad para no ejecutar dos veces
	muerto = true
	bloqueado = true
	
	# 1. Detener sonidos y ocultar interfaz
	if audio_boss:
		audio_boss.stop()
	if hud: 
		hud.ocultar_barra_jefe()

	# 2. Reproducir animación de muerte
	if anim.sprite_frames.has_animation("die"):
		anim.play("die")
	
	# 3. Mostrar el mensaje final de victoria
	await mostrar_dialogo([
		"El Rey Peste ha caído...",
		"El cielo vuelve a respirar...",
		"La selva está sanando..."
	])

	# 4. Efecto de desvanecimiento (Tween)
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(anim, "modulate:a", 0.0, 1.5) 
	tw.tween_property(self, "global_position:y", global_position.y + 100, 1.5) 
	
	await tw.finished

	# 5. TRANSICIÓN Y CAMBIO AL NIVEL 3
	# Buscamos el AnimationPlayer del nivel para el efecto visual
	var escena_actual = get_tree().current_scene
	var anim_player = escena_actual.find_child("AnimationPlayer", true, false)
	
	if anim_player and anim_player.has_animation("Fade_out"):
		anim_player.play("Fade_out")
		await anim_player.animation_finished
	else:
		# Si no hay animación, esperamos un segundo para que no sea brusco
		await get_tree().create_timer(1.0).timeout

	# 6. CARGAR MUNDO 3
	# Revisa que esta ruta sea EXACTAMENTE igual a la de tus archivos
	var ruta_nivel_3 = "res://Scenes/Level-3/mundo3.tscn"
	
	var error = get_tree().change_scene_to_file(ruta_nivel_3)
	
	if error != OK:
		print("Error al cargar Nivel 3. Verificando ruta...")
		# Si falla por la ruta, intentamos volver al menú principal
		get_tree().change_scene_to_file("res://Scenes/Menus/MenuPrincipal.tscn")
	
	# 7. Eliminar al jefe de la escena
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
