extends Sprite2D

@onready var anim = $AnimationPlayer

func _ready():
	# Ajustamos posición al centro y escala para cubrir pantalla
	var screen_size = get_viewport_rect().size
	global_position = screen_size / 2
	
	if texture:
		var sprite_size = texture.get_size()
		scale = screen_size / sprite_size
	
	# Empezamos totalmente transparente para no estorbar
	modulate.a = 0

func cambiar_escena(ruta_escena: String):
	# 1. Ejecutamos la animación de "Apagar" (Fade_out)
	# Asegúrate de que esta animación termine con el Sprite en negro total
	anim.play("Fade_out")
	await anim.animation_finished
	
	# 2. Cambiamos la escena mientras está todo oscuro
	get_tree().change_scene_to_file(ruta_escena)
	
	# 3. Ejecutamos la nueva animación de "Aparecer" (appear)
	# Esta animación debería ir de negro a transparente
	anim.play("appear")
	await anim.animation_finished
	
	# Por seguridad, nos aseguramos de que termine en transparencia 0
	modulate.a = 0
