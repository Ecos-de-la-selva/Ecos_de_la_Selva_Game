extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -650.0

var salud_max = 100
var salud_actual = 100

@onready var anim = $Animaciones 
@onready var attack_area = $AttackArea
@onready var colision_ataque = $AttackArea/CollisionShape2D
@onready var sonido_dano = $SonidoDano
@onready var sonido_ataque = $SonidoAttack
@onready var posicion_ataque_original_x = attack_area.position.x

var is_attacking = false
var esta_muerto = false 

func _ready():
	add_to_group("jugador") 
	if colision_ataque:
		colision_ataque.disabled = true
	
	# Llamamos a actualizar vida al inicio para que la barra se llene
	actualizar_interfaz_vida()

func _physics_process(delta: float) -> void:
	if esta_muerto: return 

	if not is_on_floor():
		velocity += get_gravity() * delta

	if not is_attacking:
		if Input.is_action_just_pressed("ui_accept") and is_on_floor():
			velocity.y = JUMP_VELOCITY

		var direction := Input.get_axis("ui_left", "ui_right")
		if direction:
			velocity.x = direction * SPEED
			actualizar_orientacion(direction)
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
	
	move_and_slide()
	decide_animation()
	limitar_movimiento()

# El ataque se gestiona en _unhandled_input para que los Botones de la UI
# (joystick, saltar, etc.) puedan absorber el clic sin disparar el ataque.
func _unhandled_input(event: InputEvent) -> void:
	if esta_muerto:
		return
	if not is_attacking and (event.is_action_pressed("click_izquierdo") or event.is_action_pressed("atacar")):
		attack()

func limitar_movimiento():
	var mundo = get_tree().current_scene
	
	if mundo.has_node("ArenaBoss/LimiteIzq") and mundo.has_node("ArenaBoss/LimiteDer"):
		var izq = mundo.get_node("ArenaBoss/LimiteIzq").global_position.x
		var der = mundo.get_node("ArenaBoss/LimiteDer").global_position.x
		
		global_position.x = clamp(global_position.x, izq, der)


func actualizar_orientacion(direction):
	if direction < 0:
		anim.flip_h = true
		attack_area.position.x = -posicion_ataque_original_x
	elif direction > 0:
		anim.flip_h = false
		attack_area.position.x = posicion_ataque_original_x

func attack():
	is_attacking = true
	
	# 2. Reproducir el sonido al iniciar el ataque
	if sonido_ataque:
		sonido_ataque.play()
	
	if colision_ataque:
		colision_ataque.set_deferred("disabled", false)
	
	var anim_name = "attack" if is_on_floor() else "attackair"
	anim.play(anim_name)
	
	await anim.animation_finished
	
	if colision_ataque:
		colision_ataque.set_deferred("disabled", true)
	is_attacking = false

func recibir_danio(cantidad: int, posicion_atacante: Vector2 = Vector2.ZERO):
	if esta_muerto: 
		return
	
	salud_actual -= cantidad
	salud_actual = clamp(salud_actual, 0, salud_max)
	
	actualizar_interfaz_vida()
	
	if salud_actual <= 0:
		morir()
	else:
		if sonido_dano:
			sonido_dano.play()
		
		# Animación de recibir golpe
		anim.play("damage")
		
		# Opcional: Si quieres que el jugador salte un poco hacia atrás al ser golpeado
		if posicion_atacante != Vector2.ZERO:
			var direccion_empuje = (global_position - posicion_atacante).normalized()
			velocity = direccion_empuje * 300 # Ajusta la fuerza del impacto

# --- FUNCIÓN DE VIDA CORREGIDA ---
func actualizar_interfaz_vida():
	# Intentamos buscar la barra en el HUD de la escena actual
	# Buscamos en el nodo "HUD" que debería estar al mismo nivel que el jugador o en la raíz
	var barra = get_tree().root.find_child("VidaBarra", true, false)
	if barra:
		barra.max_value = salud_max
		barra.value = salud_actual
	else:
		# Si no la encuentra por nombre, intentamos buscarla dentro de un nodo HUD
		var hud = get_parent().get_node_or_null("HUD")
		if hud and hud.has_method("actualizar_vida"):
			hud.actualizar_vida(salud_actual, salud_max)

# --- FUNCIÓN DE MUERTE CORREGIDA ---
func morir():
	if esta_muerto: return
	esta_muerto = true
	
	# 1. Resetear puntos
	if has_node("/root/Global"):
		Global.reiniciar_basura_nivel()
	
	# 2. Físicas
	velocity = Vector2.ZERO
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	
	# 3. Animación de muerte
	if anim.sprite_frames.has_animation("die"):
		anim.play("die")
		# Esperamos a que la animación se vea
		await get_tree().create_timer(1.2).timeout 

	# 4. BUSCAR EL GAMEOVER (Forma correcta y robusta)
	# Buscamos primero en la escena donde estamos jugando
	var canvas_gameover = get_tree().current_scene.find_child("Gameover", true, false)
	
	# Si no lo encuentra, lo buscamos en toda la raíz
	if not canvas_gameover:
		canvas_gameover = get_tree().root.find_child("Gameover", true, false)
	
	# 5. MOSTRARLO
	if canvas_gameover:
		print("¡Gameover encontrado!")
		canvas_gameover.visible = true
		if canvas_gameover is CanvasLayer:
			canvas_gameover.show()
		
		# Forzar que los hijos se vean (por si el panel interno estaba oculto)
		for hijo in canvas_gameover.get_children():
			if hijo is Control:
				hijo.visible = true

		# Ejecutar función aparecer
		if canvas_gameover.has_method("aparecer"):
			canvas_gameover.aparecer()
		elif canvas_gameover.get_child_count() > 0:
			var primer_hijo = canvas_gameover.get_child(0)
			if primer_hijo.has_method("aparecer"):
				primer_hijo.aparecer()
	else:
		print("ERROR: El nodo 'Gameover' no existe en esta escena. Revisa el nombre.")
		# Plan B: Reiniciar si no hay menú
		await get_tree().create_timer(1.0).timeout
		get_tree().reload_current_scene()
		
func decide_animation():
	if esta_muerto or is_attacking: return
	if anim.animation == "damage" and anim.is_playing(): return
	if not is_on_floor():
		anim.play("jump_up" if velocity.y < 0 else "jump_down")
	else:
		anim.play("Idle" if velocity.x == 0 else "walk")

func _on_attack_area_body_entered(body: Node2D) -> void:
	# Este print saldrá CUALQUIER cosa que toque el arma
	print("El arma tocó algo: ", body.name) 
	
	if body.is_in_group("enemigos"):
		print("Confirmado: Es del grupo enemigos")
		if body.has_method("recibir_danio"):
			body.recibir_danio(15, global_position)
		else:
			print("ERROR: El enemigo no tiene la función recibir_danio")
	else:
		print("ERROR: El objeto ", body.name, " no está en el grupo 'enemigos'")

# --- NUEVA FUNCIÓN PARA EL CHONTADURO ---
# --- FUNCIÓN DE CURAR CORREGIDA ---
func curar(cantidad):
	if esta_muerto: return
	
	# Si por alguna razón salud_actual es Nil, le damos el valor máximo antes de sumar
	if salud_actual == null:
		salud_actual = salud_max
	
	salud_actual += cantidad
	salud_actual = clamp(salud_actual, 0, salud_max)
	
	actualizar_interfaz_vida()
	print("Vida recuperada. Ahora tienes: ", salud_actual)
