extends Node

# --- DATOS PERSISTENTES ---
var personaje_seleccionado : String = ""
var basura_total : int = 0  # Este es el nombre correcto

# --- FUNCIONES DE CONTROL ---
func sumar_basura(cantidad: int):
	basura_total += cantidad
	print("Progreso global: ", basura_total)

func reiniciar_progreso():
	basura_total = 0
