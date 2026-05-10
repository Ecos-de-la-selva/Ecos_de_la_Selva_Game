extends CanvasLayer

# Controles táctiles (joystick + botones) que disparan las mismas acciones
# del Input Map que el teclado, para que los scripts del jugador no cambien.

@export var solo_en_touchscreen: bool = false  ## Si true, se ocultan en PC

@onready var btn_saltar: BaseButton = $Botones/BotonSaltar
@onready var btn_atacar: BaseButton = $Botones/BotonAtacar

func _ready() -> void:
	if solo_en_touchscreen and not DisplayServer.is_touchscreen_available():
		hide()
		return

	btn_saltar.button_down.connect(_on_saltar_down)
	btn_saltar.button_up.connect(_on_saltar_up)
	btn_atacar.button_down.connect(_on_atacar_down)
	btn_atacar.button_up.connect(_on_atacar_up)

func _on_saltar_down() -> void:
	_emitir_accion("ui_accept", true)

func _on_saltar_up() -> void:
	_emitir_accion("ui_accept", false)

func _on_atacar_down() -> void:
	_emitir_accion("click_izquierdo", true)

func _on_atacar_up() -> void:
	_emitir_accion("click_izquierdo", false)

# Envía la acción como un InputEvent real para que llegue tanto a
# Input.is_action_just_pressed como a _unhandled_input del jugador.
func _emitir_accion(accion: StringName, presionado: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = accion
	ev.pressed = presionado
	Input.parse_input_event(ev)
