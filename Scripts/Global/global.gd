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
var basura_total : int = 0         # Los puntos que ya son tuyos para siempre
var basura_nivel : int = 0          # Puntos conseguidos EN EL INTENTO ACTUAL
var jaguar_desbloqueado : bool = false 

const SAVE_FILE = "user://record_limpieza.save"

# --- FUNCIONES DE CONTROL ---

# Llama a esta función cuando un enemigo normal muera o recojas basura suelta
func sumar_basura(cantidad: int):
	basura_nivel += cantidad
	print("Basura en este intento: ", basura_nivel)

# Llama a esta función SOLO cuando el JEFE muera
func confirmar_limpieza_nivel():
	basura_total += basura_nivel
	basura_nivel = 0 # Se limpia la temporal porque ya pasó a la total
	print("¡Nivel superado! Total acumulado: ", basura_total)

# Llama a esta función cuando el jugador MUERA o se reinicie el nivel
func reiniciar_basura_nivel():
	basura_nivel = 0
	print("Puntos del intento perdidos.")

func reiniciar_progreso():
	basura_total = 0
	basura_nivel = 0
	jaguar_desbloqueado = false

# --- SISTEMA DE GUARDADO LOCAL ---
func guardar_puntuacion_local():
	# Primero nos aseguramos de cargar lo que había en disco
	var datos_viejos = cargar_puntuacion_local()
	var basura_historia = basura_total 
	
	if datos_viejos:
		# Sumamos el récord histórico con lo conseguido en esta sesión
		basura_historia += datos_viejos.get("record_basura", 0)
	
	var file = FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	var nuevos_datos = {
		"record_basura": basura_historia,
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
