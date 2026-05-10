extends Area2D

@export var puntos_vida = 15 

func _on_body_entered(body):
	# Si lo que toca la fruta es el jugador...
	if body.is_in_group("jugador") and body.has_method("curar"):
		body.curar(puntos_vida) # Llama a la función que acabas de poner en el personaje
		queue_free() # Borra la fruta
