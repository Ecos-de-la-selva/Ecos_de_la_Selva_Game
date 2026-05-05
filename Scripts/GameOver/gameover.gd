extends Control

@onready var animador =  $Fade/AnimationPlayer
@onready var timer = $Timer
@onready var boton = $Reintentar 
@onready var musica_muerte = $MusicaMuerte


func _ready():
	print("El menú de Game Over se ha cargado")
	self.hide() # Fuerza a esconderse
	


func aparecer():
	# 1. Mostrar el menú
	get_parent().show() 
	self.show()
	
	# 2. Reproducir el Sad Piano
	musica_muerte.play()
	
	# 3. Lanzar la animación visual (la transición que ya lograste)
	if animador.has_animation("aparecer"):
		animador.play("aparecer")
	
	# 4. Pausar el juego para que nada se mueva atrás
	get_tree().paused = true
	
	# 5. Iniciar el tiempo para el botón
	$Timer.start()

# Esta función se creó sola al conectar la señal 'pressed'
func _on_reintentar_pressed() -> void:
	print("Reintentando nivel...")
	musica_muerte.stop() # Paramos la música de muerte
	get_tree().paused = false # Quitar pausa es vital
	get_tree().reload_current_scene() # Reiniciar

# Esta función se creó sola al conectar la señal 'timeout' del Timer
func _on_timer_timeout() -> void:
	# El Tween se encarga de la transición suave
	var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	
	# Transición: de 0 a 1 en 1.5 segundos
	tween.tween_property(boton, "modulate:a", 1.0, 1.5)
	
	# Solo habilitamos el clic cuando la animación termina
	tween.finished.connect(func(): boton.disabled = false)
