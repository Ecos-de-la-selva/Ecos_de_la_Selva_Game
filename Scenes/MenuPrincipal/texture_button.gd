extends TextureButton

@onready var anim = $AnimatedSprite2D

func _ready():
	# Esto 'limpia' cualquier frame viejo y arranca el brillo
	anim.stop() # Detiene lo que sea que esté haciendo (el frame 5 de ruptura)
	anim.play("brillo") # Pone la animación correcta
	
	# Asegúrate de que el botón empiece habilitado
	disabled = false
	# Forzamos que empiece con el brillo
	
	# Si el botón se mueve con el personaje, asegúrate de que 
	# su escala inicial sea 1
	scale = Vector2(1, 1)

func _on_pressed():
	# Desactivamos para evitar errores
	disabled = true
	
	# Efecto de escala (Juice)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.05)
	await tween.finished
	
	# AHORA SÍ: Ruptura
	anim.play("ruptura")
	
	await anim.animation_finished
	get_tree().change_scene_to_file("res://scenes/Mundo.tscn")
