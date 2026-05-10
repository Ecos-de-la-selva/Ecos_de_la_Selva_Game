extends Node

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
