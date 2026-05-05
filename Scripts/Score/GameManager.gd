# GameManager.gd
extends Node

var basura_recolectada = 0

signal score_actualizado(nuevo_valor)

func sumar_basura():
	basura_recolectada += 1
	score_actualizado.emit(basura_recolectada)
