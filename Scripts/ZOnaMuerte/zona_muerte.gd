extends Area2D

func _on_body_entered(body: Node2D) -> void:
	# Si el cuerpo que entra tiene el método "morir", lo llamamos
	if body.has_method("morir"):
		body.morir()
	# O si prefieres usar grupos:
	elif body.is_in_group("Jugador"):
		get_tree().reload_current_scene()
