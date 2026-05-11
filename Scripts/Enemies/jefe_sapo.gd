extends CharacterBody2D

# --- CONFIGURACIÓN DE JEFE ---
var vida = 3
var fase = 1
var muerto = false
var puede_recibir_danio = false
var lacayos_vivos = 0
var en_recuperacion = false
var hud 

# --- CONFIGURACIÓN TÉCNICA ---
@export var escena_lacayo = preload("res://Scenes/Enemigos/ranaazul.tscn") 
@onready var anim = $AnimatedSprite2D
@onready var audio_boss = $AudioBoss 

# Gravedad para que no flote
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _ready():
	visible = false
	

# Aplicamos gravedad en el proceso físico para que el jefe aterrice en el suelo
func _physics_process(delta):
	if muerto: return
	
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0
		
	move_and_slide()

# =========================================================
# -------- INICIO PELEA (Desde la derecha) --------
# =========================================================
func iniciar_pelea(hud_ref):
	hud = hud_ref
	
	if audio_boss:
		audio_boss.stop()
		audio_boss.pitch_scale = 0.7 
		audio_boss.play()
	
	# 1. Posición inicial (Aparece un poco más arriba para caer al suelo)
	global_position = Vector2(13542.0, 26) # Subimos Y para que la gravedad lo asiente
	visible = true
	
	# 2. Entrada saltando hacia la izquierda
	anim.play("attack") 
	anim.flip_h = true 
	
	var destino_pelea_x = global_position.x - 450
	
	var tween = create_tween()
	# Salto parabólico (Solo controlamos X y un impulso inicial en Y)
	tween.tween_property(self, "global_position:x", destino_pelea_x, 1.2)
	# Hacemos que suba, pero dejamos que la gravedad del physics_process lo baje
	tween.parallel().tween_property(self, "global_position:y", global_position.y - 250, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	await tween.finished
	
	# Esperar un momento a que toque el suelo si sigue en el aire
	while not is_on_floor():
		await get_tree().process_frame
	
	# Temblor al caer
	if get_tree().current_scene.has_method("tremor_pantalla"):
		get_tree().current_scene.tremor_pantalla()
		
	anim.play("idle")
	
	await lanzar_dialogo([
		"¡GRAAAAK! El pantano no necesita limpieza.",
		"¡Sapitos, defiendan nuestro hogar!"
	])
	
	if hud:
		hud.mostrar_barra_jefe(vida)
	
	iniciar_fase()

# =========================================================
# -------- SPAWN (Lacayos corregidos) --------
# =========================================================
func spawn_lacayos(cantidad):
	lacayos_vivos = cantidad
	var jugador_ref = get_tree().get_first_node_in_group("jugador")

	for i in cantidad:
		var sapito = escena_lacayo.instantiate()
		sapito.global_position = global_position + Vector2(randf_range(-200, 200), -150)
		sapito.scale = Vector2(2, 2)
		
		# --- Blindaje de Velocidad ---
		if "velocidad_patrulla" in sapito:
			sapito.velocidad_patrulla = 70.0 
		
		get_parent().add_child(sapito)
		sapito.tree_exited.connect(_on_lacayo_muerto)
		
		# ASIGNACIÓN CLAVE
		if jugador_ref:
			sapito.jugador = jugador_ref
			# Si tu script de sapito tiene una variable 'activo', la encendemos
			if "activo" in sapito:
				sapito.activo = true

# =========================================================
# -------- RESTO DE FUNCIONES (Sin cambios) --------
# =========================================================

func iniciar_fase():
	# Primero verificamos si el jefe no está muerto
	if muerto: return
	
	# REPRODUCIR AUDIO: Ajustamos el tono según la fase para que suene más intenso
	if audio_boss:
		audio_boss.stop()
		# Cada fase el grito será un poquito más agudo o diferente
		audio_boss.pitch_scale = 0.7 + (fase * 0.05) 
		audio_boss.play()
	
	puede_recibir_danio = false
	en_recuperacion = false
	
	anim.play("attack")
	await get_tree().create_timer(0.5).timeout
	anim.play("idle")
	
	var cantidad = 3 + fase 
	spawn_lacayos(cantidad)

func _on_lacayo_muerto():
	lacayos_vivos -= 1
	if lacayos_vivos <= 0 and not muerto:
		mostrar_debilidad()

func mostrar_debilidad():
	puede_recibir_danio = true
	modulate = Color(1.5, 1.5, 1.5) 
	await lanzar_dialogo([
		"El sapo se ha quedado sin aliento...",
		"¡Atácalo ahora!"
	])

func recibir_danio(dmg: int, _posicion: Vector2):
	if not puede_recibir_danio or en_recuperacion or muerto:
		return
		
	vida -= dmg
	if hud: hud.actualizar_vida_jefe(vida)
	
	en_recuperacion = true
	puede_recibir_danio = false
	modulate = Color(1, 1, 1) # Quitamos el brillo de debilidad
	
	anim.play("hurt")
	
	if vida <= 0:
		morir()
	else:
		await lanzar_dialogo(["¡Se está recuperando!", "¡Vienen más sapos!"])
		fase += 1
		iniciar_fase() # <--- Aquí llamamos a iniciar_fase y el audio volverá a sonar

func morir():
	muerto = true
	if audio_boss:
		audio_boss.stop()
		audio_boss.pitch_scale = 0.5 
		audio_boss.play()
	if hud: hud.ocultar_barra_jefe()
	
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	anim.play("die")
	
	await lanzar_dialogo([
		"El Gran Sapo ha sido derrotado...",
		"Las aguas del pantano vuelven a ser claras."
	])
	
	
	# Efecto de desaparición del sapo
	var tween = create_tween()
	for i in range(6):
		tween.tween_property(anim, "modulate:a", 0.2, 0.1)
		tween.tween_property(anim, "modulate:a", 1.0, 0.1)
	tween.tween_property(anim, "modulate:a", 0.0, 0.5)
	await tween.finished
	
	if get_tree().current_scene.has_method("desactivar_arena"):
		get_tree().current_scene.desactivar_arena()

	# =========================================================
	# 🎬 ACTIVAR TRANSICIÓN (INTENTO ROBUSTO)
	# =========================================================
	# Buscamos el AnimationPlayer en la raíz de la escena actual
	var escena_actual = get_tree().current_scene
	var anim_player = escena_actual.find_child("AnimationPlayer", true, false)
	
	if anim_player:
		# IMPORTANTE: Asegúrate de que el nombre de la animación sea el correcto
		# Si tu animación se llama "Transicion", cambia "fade_out" por "Transicion"
		if anim_player.has_animation("Fade_out"):
			anim_player.play("Fade_out")
			await anim_player.animation_finished
		else:
			# Si no encuentra la animación por nombre, intenta reproducir la primera que encuentre
			print("Advertencia: No existe 'fade_out', intentando la primera animación disponible.")
			anim_player.play(anim_player.get_animation_list()[0])
			await anim_player.animation_finished
	else:
		print("ERROR: No se encontró ningún AnimationPlayer en la escena.")

	# =========================================================
	# 🚀 CAMBIO DE NIVEL
	# =========================================================
	var nombre_actual = escena_actual.name
	if has_node("/root/Escenas"):
		Escenas.siguiente_nivel(nombre_actual)
	else:
		print("Error: Autoload 'Escenas' no configurado.")
	
	queue_free()

func lanzar_dialogo(textos: Array):
	if not is_inside_tree(): return
	await Global.mostrar_dialogo_modal(textos)
