extends Control

func _ready():
	# Forzamos que este nodo ignore la pausa del juego
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("--- Script de Pausa Iniciado ---")

func _process(_delta):
	# ESTO ES PARA PROBAR: 
	# Si presionas la tecla "P" mientras el menú está abierto, 
	# el juego debería despausarse sí o sí.
	if Input.is_key_pressed(KEY_P):
		print("Prueba: Forzando despausa con tecla P")
		_on_boton_continuar_pressed()

# --- DETECTOR DE ENTRADA GENERAL ---
func _gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		print("¡El nodo Control recibió un clic en la posición: ", event.position)

# --- TUS BOTONES CON PRINT DE SEGURIDAD ---
# Esta función se crea sola al conectar la señal
func _on_boton_continuar_pressed() -> void:
	print("¡Señal recibida! El botón funciona.") # Para estar 100% seguros
	get_tree().paused = false
	get_parent().hide()

func _on_boton_salir_pressed() -> void:
	print("Saliendo al menú...")
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/1-MenuPrincipal/menu_principal.tscn")
