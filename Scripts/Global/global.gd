extends Node

const ESCENA_INTERFAZ_DIALOGO := preload("res://Scenes/Dialogos/Dialogo1/interfaz_dialogo.tscn")

func _ready() -> void:
	# Necesario para poder await el diálogo mientras get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS


## Pausa el juego, oculta controles táctiles y el botón de pausa, muestra el diálogo y restaura al terminar.
func mostrar_dialogo_modal(textos: Array) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var escena := tree.current_scene
	if escena == null:
		return

	var ya_pausado := tree.paused
	if not ya_pausado:
		tree.paused = true

	var ctrl := escena.get_node_or_null("Controles")
	if ctrl and ctrl.has_method("bloquear"):
		ctrl.bloquear()

	var hud_btn := escena.get_node_or_null("HUDBotones")
	var hud_btn_visible := true
	if hud_btn:
		hud_btn_visible = hud_btn.visible
		hud_btn.hide()

	var d := ESCENA_INTERFAZ_DIALOGO.instantiate()
	escena.add_child(d)
	d.iniciar_dialogo(textos)
	await d.dialogo_terminado

	if hud_btn:
		hud_btn.visible = hud_btn_visible
	if ctrl and ctrl.has_method("desbloquear"):
		ctrl.desbloquear()
	if not ya_pausado:
		tree.paused = false


# --- DATOS PERSISTENTES ---
var personaje_seleccionado : String = ""
var basura_total : int = 0  
var jaguar_desbloqueado : bool = false # Por si lo necesitas para el Mundo 3

const SAVE_FILE = "user://record_limpieza.save"

# --- FUNCIONES DE CONTROL ---
func sumar_basura(cantidad: int):
	basura_total += cantidad
	print("Progreso global: ", basura_total)

func reiniciar_progreso():
	basura_total = 0
	jaguar_desbloqueado = false

# --- SISTEMA DE GUARDADO LOCAL ---
func guardar_puntuacion_local():
	# 1. Primero cargamos lo que ya había guardado
	var datos_viejos = cargar_puntuacion_local()
	var basura_acumulada = basura_total # Empezamos con lo de esta partida
	
	if datos_viejos:
		# 2. Le sumamos lo que ya estaba guardado en el archivo
		basura_acumulada += datos_viejos["record_basura"]
	
	# 3. Guardamos el nuevo total
	var file = FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	var nuevos_datos = {
		"record_basura": basura_acumulada,
		"personaje": personaje_seleccionado,
		"fecha": Time.get_date_string_from_system()
	}
	file.store_var(nuevos_datos)
	file.close()

func cargar_puntuacion_local():
	if FileAccess.file_exists(SAVE_FILE):
		var file = FileAccess.open(SAVE_FILE, FileAccess.READ)
		var datos = file.get_var()
		file.close()
		return datos
	return null
