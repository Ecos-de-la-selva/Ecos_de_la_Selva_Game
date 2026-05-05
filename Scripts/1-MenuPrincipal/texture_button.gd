extends TextureButton

# Les damos nombres diferentes a las variables
@onready var anim_ruptura = $AnimatedSprite2D
@onready var anim_brillo = $AnimatedSprite2D2

func _ready():
	# Usamos la de brillo al empezar
	anim_brillo.play("brillo")
	
	# Asegúrate de que la de ruptura esté quieta al inicio
	anim_ruptura.stop()
	
	disabled = false
	scale = Vector2(1, 1)

func _on_pressed():
	# Ajustamos el nombre del AudioStreamPlayer2D como vimos en tu escena
	var musica = get_tree().current_scene.get_node("AudioStreamPlayer2D")
	var sonido_crack = $SonidoRuptura
	
	disabled = true
	
	# Desvanecer música
	var tween_audio = create_tween()
	tween_audio.tween_property(musica, "volume_db", -80, 1.2)
	
	# Efecto de escala
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.05)
	await tween.finished
	
	# Acciones de ruptura
	sonido_crack.play()
	
	# Detenemos el brillo y activamos la ruptura
	anim_brillo.hide() # Opcional: ocultas el brillo para que no estorbe
	anim_ruptura.play("ruptura")
	
	await anim_ruptura.animation_finished
	
	# Cambiamos a la escena (Verifica que esta ruta sea la real en tu panel)
	get_tree().change_scene_to_file("res://Scenes/2-SelecciondePersonaje/SeleccionPersonaje.tscn")
