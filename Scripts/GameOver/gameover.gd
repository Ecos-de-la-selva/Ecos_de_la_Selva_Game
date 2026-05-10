extends Control

@onready var animador = $Fade/AnimationPlayer
@onready var timer = $Timer
@onready var boton = $Reintentar
@onready var musica_muerte = $MusicaMuerte


func _ready():

	print("El menú de Game Over se ha cargado")

	self.hide()

	boton.disabled = true
	boton.modulate.a = 0.0


# =========================================================
# APARECER GAME OVER
# =========================================================
func aparecer():

	# mostrar menú
	get_parent().show()
	self.show()

	# reproducir música
	if musica_muerte:
		musica_muerte.play()

	# animación fade
	if animador and animador.has_animation("aparecer"):
		animador.play("aparecer")

	# pausar juego
	get_tree().paused = true

	# iniciar timer botón
	timer.start()


# =========================================================
# REINTENTAR
# =========================================================
func _on_reintentar_pressed() -> void:
	if musica_muerte:
		musica_muerte.stop()

	# IMPORTANTE: Quitar la pausa ANTES o JUSTO al recargar
	get_tree().paused = false
	
	# Recargar la escena actual
	get_tree().reload_current_scene()

# =========================================================
# MOSTRAR BOTÓN
# =========================================================
func _on_timer_timeout() -> void:

	var tween = create_tween()

	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	tween.tween_property(
		boton,
		"modulate:a",
		1.0,
		1.5
	)

	tween.finished.connect(
		func():
			boton.disabled = false
	)
