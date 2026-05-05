extends CanvasLayer

signal dialogo_terminado

var dialogos = []
var frase_actual = 0
var escribiendo = false
var saltar_frase = false

@onready var texto_label = $NinePatchRect/Label
@onready var timer_letras = $NinePatchRect/Label/TimerLetras
@onready var sonido_escritura = $NinePatchRect/Label/SonidoEscritura

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	timer_letras.process_mode = Node.PROCESS_MODE_ALWAYS

func iniciar_dialogo(nuevos_dialogos: Array):
	dialogos = nuevos_dialogos
	frase_actual = 0
	mostrar_frase()

func mostrar_frase():
	if frase_actual < dialogos.size():
		escribiendo = true
		saltar_frase = false
		texto_label.text = ""
		
		var frase = dialogos[frase_actual]
		
		for letra in frase:
			if saltar_frase:
				texto_label.text = frase
				break
			
			texto_label.text += letra
			
			if sonido_escritura and not sonido_escritura.playing:
				sonido_escritura.play()
			
			timer_letras.start(0.05)
			await timer_letras.timeout
		
		escribiendo = false
	else:
		emit_signal("dialogo_terminado")
		queue_free()

func _on_skip_pressed() -> void:
	if escribiendo:
		saltar_frase = true
	else:
		frase_actual += 1
		mostrar_frase()

func _on_panel_gui_input(event: InputEvent) -> void:
	var click = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var touch = event is InputEventScreenTouch and event.pressed
	
	if click or touch:
		_on_skip_pressed()
