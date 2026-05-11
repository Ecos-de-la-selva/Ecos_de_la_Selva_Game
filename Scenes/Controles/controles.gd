extends CanvasLayer

# Definimos el color de presionado una sola vez para no repetir números
var color_presionado = Color(0.357, 0.357, 0.678, 1.0)
var color_normal = Color(1, 1, 1, 1)

# Oculta los controles y suelta cualquier accion presionada.
# Util durante dialogos o cinematicas para que el jugador no se mueva.
func bloquear() -> void:
	hide()
	for accion in [&"ui_left", &"ui_right", &"ui_up", &"ui_down", &"ui_accept", &"click_izquierdo", &"atacar"]:
		if Input.is_action_pressed(accion):
			Input.action_release(accion)

func desbloquear() -> void:
	show()

# IZQUIERDA
func _on_izq_pressed() -> void:
	$Node2D/izq.modulate = color_presionado
	
func _on_izq_released() -> void:
	$Node2D/izq.modulate = color_normal

# DERECHA
func _on_der_pressed() -> void:
	$Node2D/der.modulate = color_presionado
	
func _on_der_released() -> void:
	$Node2D/der.modulate = color_normal
	
# SALTAR
func _on_saltar_pressed() -> void:
	$Node2D2/saltar.modulate = color_presionado

func _on_saltar_released() -> void:
	$Node2D2/saltar.modulate = color_normal

# ATAQUE
func _on_ataque_pressed() -> void:
	$Node2D2/ataque.modulate = color_presionado

func _on_ataque_released() -> void:
	$Node2D2/ataque.modulate = color_normal
