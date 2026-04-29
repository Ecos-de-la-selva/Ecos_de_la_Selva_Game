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
	# 1. Referencias a los sonidos
	var musica = get_tree().current_scene.get_node("AudioStreamPlayer")
	var sonido_crack = $SonidoRuptura # El nodo que acabamos de crear
	
	disabled = true
	
	# 2. Desvanecer música de fondo
	var tween_audio = create_tween()
	tween_audio.tween_property(musica, "volume_db", -80, 1.2)
	
	# 3. Efecto visual de escala
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.05)
	await tween.finished
	
	# 4. ¡AQUÍ suena la ruptura!
	sonido_crack.play()
	anim.play("ruptura")
	
	# 5. Esperamos a que termine la animación para irnos
	await anim.animation_finished
	get_tree().change_scene_to_file("res://scenes/SeleccionPersonaje.tscn")
