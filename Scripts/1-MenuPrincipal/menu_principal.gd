extends Control

# Referencia al nodo azul que envuelve todo el menú de niveles
@onready var panel_niveles = $Node2D 

func _ready() -> void:
	# Nos aseguramos de que el menú de niveles empiece oculto
	panel_niveles.visible = false
	
	# TRUCO: Como Node2D no tiene "size", el pivot_offset se debe configurar
	# manualmente en el Inspector del editor para que esté en el centro del recuadro.

func _on_boton_niveles_pressed():
	panel_niveles.visible = true
	panel_niveles.scale = Vector2(0.5, 0.5)
	
	var tween = create_tween()
	# Usamos EASE_OUT en lugar de E_OUT
	tween.tween_property(panel_niveles, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
func _on_boton_cerrar_pressed() -> void:
	# 1. Animación de encogimiento
	var tween = create_tween()
	tween.tween_property(panel_niveles, "scale", Vector2(0.5, 0.5), 0.1).set_trans(Tween.TRANS_LINEAR)
	
	# 2. Esperar a que termine la animación antes de ocultar
	await  tween.finished
	panel_niveles.visible = false


# Botón para el Nivel 1
# Botón para el Nivel 1
func _on_nivel_1_pressed() -> void:
	# Cambié .gd por .tscn y la carpeta a donde suelen estar las escenas
	get_tree().change_scene_to_file("res://Scenes/Level-1/mundo.tscn")

# Botón para el Nivel 2
func _on_nivel_2_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Level-2/mundo2.tscn")
