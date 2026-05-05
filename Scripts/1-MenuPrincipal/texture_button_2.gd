extends TextureButton

# Nombres de las animaciones hijos
@onready var anim_ruptura = $AnimatedSprite2D
@onready var anim_brillo = $AnimatedSprite2D2

func _ready():
	anim_brillo.play("brillo")
	anim_ruptura.stop()
	anim_ruptura.hide() # Lo mantenemos oculto hasta que se pulse
	disabled = false
	
	# Ajusta el Pivot al centro para que el efecto de escala sea simétrico
	pivot_offset = size / 2

func _on_pressed():
	var sonido_crack = $SonidoRuptura
	disabled = true
	
	pivot_offset = size / 2

	# Efecto visual de "Click" con tu escala de 1.5
	var escala_original = Vector2(1.5, 1.5)
	var escala_click = escala_original * 1.2
	
	var tween = create_tween()
	tween.tween_property(self, "scale", escala_click, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", escala_original, 0.1)
	
	await tween.finished 
	
	# Iniciar Ruptura
	sonido_crack.play()
	anim_brillo.hide()
	anim_ruptura.show() 
	anim_ruptura.play("ruptura")
	
	# Esperar final de animación
	await anim_ruptura.animation_finished
	
	# Al cambiar de escena, la música en 'MusicaGlobal' NO se detendrá
	get_tree().change_scene_to_file("res://Scenes/2-SelecciondePersonaje/SeleccionPersonaje.tscn")
