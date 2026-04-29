extends Control

# Ruta a la escena del mundo (Nivel 1)
const ESCENA_MUNDO = "res://Mundo.tscn" 

func _ready():
	# Iniciamos las animaciones de los personajes en el menú
	$ContenedorBotones/BotonHombre/AnimHombre.play("idle")
	$ContenedorBotones/BotonMujer/AnimMujer.play("idle")

func _on_boton_hombre_pressed():
	# Guardamos que eligió al hombre (usaremos el Global después)
	print("Elegiste Hombre")
	Global.personaje_seleccionado = "hombre"
	ir_al_mundo()

func _on_boton_mujer_pressed():
	# Guardamos que eligió a la mujer
	print("Elegiste Mujer")
	Global.personaje_seleccionado = "mujer"
	ir_al_mundo()

func ir_al_mundo():
	# Cambiamos a la escena del nivel 1
	get_tree().change_scene_to_file(ESCENA_MUNDO)
