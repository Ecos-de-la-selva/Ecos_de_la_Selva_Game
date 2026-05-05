extends Area2D

# --- VARIABLES ---
var cayendo = false
var velocidad_caida = 300.0

# Esta función la llama el enemigo al soltarla
func empezar_caida():
	cayendo = true

func _physics_process(delta):
	if cayendo:
		global_position.y += velocidad_caida * delta

func _on_body_entered(body):
	# 1. DETECTAR SUELO
	if body is TileMapLayer or body.is_in_group("suelo") or body.name.contains("Tile"):
		cayendo = false
		# print("Basura tocó el suelo")
	
	# 2. DETECTAR JUGADOR
	if body.is_in_group("jugador"):
		# Sumar al Autoload Global
		if Global:
			Global.sumar_basura(1)
		
		# Buscar la interfaz y llamar a la función que REALMENTE tienes
		var hud = get_tree().get_first_node_in_group("interfaz")
		if hud:
			if hud.has_method("actualizar_score"):
				hud.actualizar_score() # <--- Corregido el nombre aquí
			elif hud.has_method("actualizar_visual"):
				hud.actualizar_visual()
		
		# Eliminar la basura del mundo al recogerla
		queue_free()
