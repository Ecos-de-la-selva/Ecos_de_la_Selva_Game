extends Control

# Referencias
@onready var panel_niveles = $Node2D 
@onready var panel_ranking = $Node2D2/BotonRanking/PanelRanking
@onready var label_datos = $Node2D2/BotonRanking/PanelRanking/LabelDatos

# 💡 REFERENCIA AL NODO QUE CONTIENE EL BOTÓN DE RANKING
# Asumo que Node2D2 es el que contiene los botones del menú principal
@onready var menu_botones_principales = $Node2D2

func _ready() -> void:
	panel_niveles.visible = false
	
func _on_boton_niveles_pressed():
	# 1. Escondemos los botones principales (incluyendo el ranking)
	menu_botones_principales.visible = false
	
	panel_niveles.visible = true
	panel_niveles.scale = Vector2(0.5, 0.5)
	
	var tween = create_tween()
	tween.tween_property(panel_niveles, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
func _on_boton_cerrar_pressed() -> void:
	var tween = create_tween()
	tween.tween_property(panel_niveles, "scale", Vector2(0.5, 0.5), 0.1).set_trans(Tween.TRANS_LINEAR)
	
	await tween.finished
	panel_niveles.visible = false
	
	# 2. Volvemos a mostrar los botones principales al cerrar niveles
	menu_botones_principales.visible = true

func _on_boton_ranking_pressed():
	var datos = Global.cargar_puntuacion_local()
	
	if datos:
		var puntos = datos["record_basura"]
		var fecha = datos["fecha"]
		var pj = datos["personaje"]
		
		label_datos.text = "MEJOR RÉCORD:\n\n" + \
						   "Basura: " + str(puntos) + " kg\n" + \
						   "Personaje: " + pj + "\n" + \
						   "Fecha: " + fecha
	else:
		label_datos.text = "Aún no hay récords.\n¡Derrota al jefe final para aparecer aquí!"
	
	panel_ranking.visible = true

func _on_texture_button_pressed() -> void:
	panel_ranking.visible = false

# --- NAVEGACIÓN DE NIVELES ---
func _on_nivel_1_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Level-1/mundo.tscn")

func _on_nivel_2_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Level-2/mundo2.tscn")

func _on_nivel_3_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Level-3/mundo3.tscn")

func _on_nivel_4_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Level-4/mundo4.tscn")
