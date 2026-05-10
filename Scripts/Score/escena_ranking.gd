extends Control

@onready var label_total = $LabelTotal # Un Label que diga "Total recolectado"
@onready var label_record = $LabelRecord # Un Label que diga "Tu mejor récord"

func _ready():
	# 1. Mostrar lo que acaba de conseguir en esta partida
	label_total.text = "Basura eliminada hoy: " + str(Global.basura_total) + " kg"
	
	# 2. Comparar con el récord guardado
	var datos_guardados = Global.cargar_puntuacion_local()
	
	if datos_guardados:
		var record = datos_guardados["record_basura"]
		label_record.text = "Récord Histórico: " + str(record) + " kg"
		
		# Si superó el récord en esta partida
		if Global.basura_total >= record:
			$LabelMensaje.text = "¡NUEVO RÉCORD DE LIMPIEZA!"
	else:
		label_record.text = "¡Primer viaje completado!"

func _on_boton_menu_principal_pressed():
	Global.reiniciar_progreso() # Limpiamos para una nueva partida
	get_tree().change_scene_to_file("res://Scenes/Menus/MenuPrincipal.tscn")
