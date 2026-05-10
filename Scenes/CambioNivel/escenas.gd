extends Node

# Diccionario con las rutas exactas de tus escenas
var niveles = {
	"Mundo1": "res://Scenes/Level-1/mundo.tscn",
	"Mundo2": "res://Scenes/Level-2/mundo2.tscn",
	"Mundo3": "res://Scenes/Level-3/mundo3.tscn" ,
	"Mundo4": "res://Scenes/Level-4/mundo4.tscn"
}

func siguiente_nivel(actual: String):
	match actual:
		"Mundo1": get_tree().change_scene_to_file(niveles["Mundo2"])
		"Mundo2": get_tree().change_scene_to_file(niveles["Mundo3"])
		"Mundo3": get_tree().change_scene_to_file(niveles["Mundo4"])
		"Mundo4": print("¡Fin del juego!") # Aquí podrías poner una escena de créditos
