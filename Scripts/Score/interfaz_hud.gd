extends CanvasLayer

@onready var label = $HBoxContainer/ScoreLabel

func _ready():
	add_to_group("interfaz")
	actualizar_visual() # Para que aparezca 0 al empezar

# Esta función SIEMPRE debe estar en el HUD
func actualizar_visual():
	if Global:
		# Lee la variable 'basura_total' del Global
		label.text = "Basura: " + str(Global.basura_total) 
	else:
		label.text = "Basura: Error"
