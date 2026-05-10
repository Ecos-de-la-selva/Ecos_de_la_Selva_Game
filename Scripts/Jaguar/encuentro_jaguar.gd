extends Node2D

@export var escena_jaguar_pro: PackedScene

@onready var zona_activacion = $ZonaActivacion
@onready var jaguar_png_nodo = $JaguarHerido
@onready var area_monos = $AreaVigilancia

var evento_activo = false
var evento_terminado = false


# =========================================================
func _ready():
	add_to_group("eventos")

	# desactivar monos iniciales
	var bodies = area_monos.get_overlapping_bodies()

	for b in bodies:
		if is_instance_valid(b) and b.is_in_group("enemigos"):
			b.activo = false


# =========================================================
func _on_zona_activacion_body_entered(body):

	if body.is_in_group("jugador") and not evento_activo:

		evento_activo = true
		zona_activacion.set_deferred("monitoring", false)

		await secuencia_cinematica(body)


# =========================================================
func secuencia_cinematica(jugador):

	jugador.set_physics_process(false)
	jugador.velocity = Vector2.ZERO

	var anim = jugador.get_node_or_null("Animaciones")
	if anim:
		anim.play("walk")

	var tween = create_tween()
	tween.tween_property(
		jugador,
		"global_position:x",
		jugador.global_position.x + 120,
		1.2
	)

	await tween.finished

	if anim:
		anim.play("Idle")

	await lanzar_dialogo([
		"¡Oh, un jaguar!",
		"Está siendo atacado..."
	])

	var bodies = area_monos.get_overlapping_bodies()

	for b in bodies:
		if is_instance_valid(b) and b.is_in_group("enemigos"):
			b.activo = true

	jugador.set_physics_process(true)

	await get_tree().create_timer(0.5).timeout
	verificar_enemigos()


# =========================================================
func verificar_enemigos():

	if evento_terminado:
		return

	var enemigos = get_tree().get_nodes_in_group("enemigos")

	var vivos = false

	for e in enemigos:

		if not is_instance_valid(e):
			continue

		# 🔥 CLAVE: si existe y NO está muerto → sigue vivo
		if "muerto" in e and e.muerto == false:
			vivos = true
			break
		else:
			vivos = true
			break

	if vivos:
		return

	evento_terminado = true
	recompensa_final()


# =========================================================
func recompensa_final():

	if not evento_terminado:
		return

	if is_instance_valid(jaguar_png_nodo):

		var pos = jaguar_png_nodo.global_position
		jaguar_png_nodo.queue_free()

		if escena_jaguar_pro:

			var nuevo = escena_jaguar_pro.instantiate()
			nuevo.global_position = pos
			get_parent().add_child(nuevo)

			await lanzar_dialogo([
				"¡El jaguar se ha liberado!",
				"¡Ahora es tu aliado!"
			])


# =========================================================
func lanzar_dialogo(textos):

	var d = preload("res://Scenes/Dialogos/Dialogo1/interfaz_dialogo.tscn").instantiate()
	get_tree().current_scene.add_child(d)

	d.iniciar_dialogo(textos)
	await d.dialogo_terminado
