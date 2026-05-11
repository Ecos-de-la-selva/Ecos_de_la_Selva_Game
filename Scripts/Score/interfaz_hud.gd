extends CanvasLayer

@onready var label = $HBoxContainer/ScoreLabel

func _ready():
	add_to_group("interfaz")
	actualizar_visual()

# Usamos _process para que el número cambie al instante cuando recojas algo
func _process(_delta):
	actualizar_visual()

# Dentro del script del HUD
func actualizar_visual():
	if Global:
		# Mostramos: Puntos de niveles pasados + Puntos de este nivel
		var total_pantalla = Global.basura_total + Global.basura_nivel
		label.text = "Basura: " + str(total_pantalla) + " kg"
