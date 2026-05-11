extends CharacterBody2D

# =============================================================
#  JEFE GENIO – Boss del Nivel 2
#  Vuela, dispara salvas de proyectiles mágicos y lanza ráfagas
#  en abanico cuando está enojado.
# =============================================================

# --- CONFIGURACIÓN ---
@export var vida_max: int = 30
@export var velocidad := 110.0
@export var rango_patrulla := 320.0

# Daño al jugador
@export var dano_proyectil: int = 15
@export var dano_contacto: int = 35

# Tiempos de ataque por fase
@export var cooldown_disparo_normal := 1.4
@export var cooldown_disparo_furioso := 0.7

const PROYECTIL_MAGICO := preload("res://Scenes/Enemies/proyectil_magico.tscn")

# --- ESTADO INTERNO ---
var vida: int
var fase: int = 1   # 1 = normal, 2 = furioso (mitad de vida)
var direccion := -1
var atacando := false
var puede_atacar := false   # se activa cuando empieza la pelea
var muerto := false
var pelea_iniciada := false
var posicion_inicial := Vector2.ZERO
var jugador: Node2D = null
var hud

# --- NODOS ---
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var area_ataque: Area2D = $Area2D
@onready var colision_ataque: CollisionShape2D = $Area2D/CollisionShape2D


func _ready() -> void:
	add_to_group("enemigos")
	vida = vida_max
	# Mantenemos el área de ataque encendida solo como golpe de respaldo cuerpo a cuerpo
	area_ataque.monitoring = true
	# El boss empieza invisible / inactivo hasta que empieza la pelea
	visible = false
	set_physics_process(false)


func _physics_process(_delta: float) -> void:
	if muerto:
		velocity = Vector2.ZERO
		return
	if not pelea_iniciada:
		return

	# Buscar al jugador
	if jugador == null or not is_instance_valid(jugador):
		jugador = get_tree().get_first_node_in_group("jugador")

	# Movimiento: el jefe persigue al jugador horizontalmente.
	# Las paredes de la arena (ParedIzquierda / ParedDerecha) ya
	# encierran al jefe, así que aquí NO hay rebote por rango_patrulla
	# (causaba oscilaciones que peleaban con la persecución).
	if not atacando:
		if jugador and is_instance_valid(jugador):
			var dx := jugador.global_position.x - global_position.x
			# Pequeña zona muerta para no temblar cuando está justo encima
			if abs(dx) > 8.0:
				direccion = -1 if dx < 0 else 1
				velocity.x = sign(dx) * velocidad
			else:
				velocity.x = 0
		else:
			velocity.x = direccion * velocidad

		velocity.y = 0
	else:
		velocity = Vector2.ZERO

	# Animación de movimiento
	if not atacando and not _en_animacion_unica():
		if anim.sprite_frames.has_animation("flight"):
			anim.play("flight")
		elif anim.sprite_frames.has_animation("idle"):
			anim.play("idle")

	# Voltear sprite
	anim.flip_h = (direccion == -1)

	move_and_slide()


func _en_animacion_unica() -> bool:
	return anim.animation in ["hurt", "death", "attack", "magic_attack"] and anim.is_playing()


# =====================================================
#  INICIO DE LA PELEA (lo llama level-2.gd)
# =====================================================
func iniciar_pelea(hud_ref) -> void:
	hud = hud_ref
	visible = true

	# Posición de aparición y referencia ANTES de mover nada,
	# para que el cálculo de patrulla no use Vector2.ZERO.
	var spawn := get_tree().current_scene.get_node_or_null("SpawnBoss")
	if spawn:
		posicion_inicial = spawn.global_position
		# Aparece desde arriba en una entrada dramática
		global_position = spawn.global_position + Vector2(0, -200)
	else:
		posicion_inicial = global_position

	# Activar física DESPUÉS de tener posicion_inicial lista
	set_physics_process(true)
	pelea_iniciada = true

	if spawn:
		var tween := create_tween()
		tween.tween_property(self, "global_position", spawn.global_position, 1.5)
		await tween.finished
		# refresca por si la escena ya lo había desplazado un poco
		posicion_inicial = global_position

	if anim.sprite_frames.has_animation("flight"):
		anim.play("flight")

	await mostrar_dialogo([
		"¡El Genio del templo despierta!",
		"Sus ojos arden de furia ancestral...",
		"¡Detenlo antes de que destruya la selva!"
	])

	if hud and hud.has_method("mostrar_barra_jefe"):
		hud.mostrar_barra_jefe(vida_max)

	# Asegurar referencia al jugador antes de empezar el bucle
	if jugador == null or not is_instance_valid(jugador):
		jugador = get_tree().get_first_node_in_group("jugador")

	puede_atacar = true
	bucle_de_ataque()


# =====================================================
#  BUCLE DE ATAQUE
# =====================================================
func bucle_de_ataque() -> void:
	while not muerto and pelea_iniciada:
		if puede_atacar and is_instance_valid(jugador):
			if fase == 1:
				await disparar_simple()
				await get_tree().create_timer(cooldown_disparo_normal).timeout
			else:
				# Fase furiosa: alterna entre simple y abanico
				if randi() % 2 == 0:
					await disparar_abanico()
				else:
					await disparar_simple()
				await get_tree().create_timer(cooldown_disparo_furioso).timeout
		else:
			await get_tree().create_timer(0.3).timeout


# Disparo simple hacia el jugador
func disparar_simple() -> void:
	if muerto or jugador == null:
		return
	atacando = true
	if anim.sprite_frames.has_animation("attack"):
		anim.play("attack")

	await get_tree().create_timer(0.2).timeout
	if muerto or not is_instance_valid(jugador):
		atacando = false
		return

	_lanzar_proyectil_hacia(jugador.global_position)

	await get_tree().create_timer(0.25).timeout
	atacando = false


# Disparo en abanico de 3 proyectiles
func disparar_abanico() -> void:
	if muerto or jugador == null:
		return
	atacando = true
	if anim.sprite_frames.has_animation("magic_attack"):
		anim.play("magic_attack")
	elif anim.sprite_frames.has_animation("attack"):
		anim.play("attack")

	await get_tree().create_timer(0.3).timeout
	if muerto or not is_instance_valid(jugador):
		atacando = false
		return

	var dir_central := (jugador.global_position - global_position).normalized()
	# Lanzar 3 proyectiles en abanico (-15°, 0°, +15°)
	for angulo_grados in [-15.0, 0.0, 15.0]:
		var dir := dir_central.rotated(deg_to_rad(angulo_grados))
		_lanzar_proyectil_en_direccion(dir)
		await get_tree().create_timer(0.08).timeout

	await get_tree().create_timer(0.3).timeout
	atacando = false


func _lanzar_proyectil_hacia(destino: Vector2) -> void:
	var dir := (destino - global_position).normalized()
	_lanzar_proyectil_en_direccion(dir)


func _lanzar_proyectil_en_direccion(dir: Vector2) -> void:
	var proyectil := PROYECTIL_MAGICO.instantiate()
	proyectil.direccion = dir
	proyectil.dano = dano_proyectil
	proyectil.global_position = global_position + dir * 30.0
	get_tree().current_scene.add_child(proyectil)


# Golpe cuerpo a cuerpo si el jugador llega a chocar al jefe
func _on_area_2d_body_entered(body: Node2D) -> void:
	if muerto:
		return
	if body.is_in_group("jugador") and body.has_method("recibir_danio"):
		body.recibir_danio(dano_contacto)


# =====================================================
#  RECIBIR DAÑO DEL JUGADOR
# =====================================================
func recibir_danio(dmg: int, _posicion_atacante: Vector2 = Vector2.ZERO) -> void:
	if muerto or not pelea_iniciada:
		return

	vida -= dmg
	if hud and hud.has_method("actualizar_vida_jefe"):
		hud.actualizar_vida_jefe(vida)

	# Flash blanco
	var tween_hit := create_tween()
	tween_hit.tween_property(anim, "modulate", Color(10, 10, 10), 0.05)
	tween_hit.tween_property(anim, "modulate", Color(1, 1, 1), 0.05)

	# Animación hurt si todavía está vivo
	if vida > 0 and anim.sprite_frames.has_animation("hurt"):
		anim.play("hurt")

	# Cambio a fase furiosa al bajar de la mitad de vida
	if fase == 1 and vida <= vida_max / 2:
		entrar_en_furia()

	if vida <= 0:
		morir()


func entrar_en_furia() -> void:
	fase = 2
	# Tinte rojizo permanente para indicar la fase
	anim.modulate = Color(1.4, 0.8, 0.8, 1)


# =====================================================
#  MUERTE
# =====================================================
func morir() -> void:
	if muerto:
		return
	muerto = true
	puede_atacar = false
	velocity = Vector2.ZERO

	if hud and hud.has_method("ocultar_barra_jefe"):
		hud.ocultar_barra_jefe()

	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	colision_ataque.set_deferred("disabled", true)
	area_ataque.set_deferred("monitoring", false)

	if anim.sprite_frames.has_animation("death"):
		anim.play("death")
		await anim.animation_finished

	# Avisar al nivel para que abra la arena, si tiene esa función
	var nivel = get_tree().current_scene
	if nivel and nivel.has_method("desactivar_arena"):
		nivel.desactivar_arena()

	await mostrar_dialogo([
		"¡El Genio ha sido derrotado!",
		"El templo recupera su silencio...",
		"La selva podrá sanar de nuevo."
	])

	var tween := create_tween()
	for i in range(6):
		tween.tween_property(anim, "modulate:a", 0.2, 0.1)
		tween.tween_property(anim, "modulate:a", 1.0, 0.1)
	tween.tween_property(anim, "modulate:a", 0.0, 0.5)
	await tween.finished

	queue_free()


# =====================================================
#  DIÁLOGO (igual que rey_mono)
# =====================================================
func mostrar_dialogo(textos: Array):
	if not is_inside_tree():
		return
	if get_tree().current_scene == null:
		return
	await Global.mostrar_dialogo_modal(textos)
