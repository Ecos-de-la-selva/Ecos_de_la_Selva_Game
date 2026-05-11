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
	# 1. DETECTAR SUELO (Se detiene al tocar plataformas)
	if body is TileMapLayer or body.is_in_group("suelo") or body.name.contains("Tile"):
		cayendo = false
	
	# 2. DETECTAR JUGADOR (Recolección)
	if body.is_in_group("jugador"):
		# Sumar al Autoload Global (Variable Temporal)
		if has_node("/root/Global"):
			Global.sumar_basura(1)
		
		# Actualizar el HUD inmediatamente
		var hud = get_tree().get_first_node_in_group("interfaz")
		if hud:
			# Probamos ambos nombres de función por si acaso
			if hud.has_method("actualizar_visual"):
				hud.actualizar_visual()
			elif hud.has_method("actualizar_score"):
				hud.actualizar_score()
		
		# Eliminar el objeto del mundo
		queue_free()
