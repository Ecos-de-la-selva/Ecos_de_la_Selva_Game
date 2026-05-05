extends CanvasLayer

# -------- JUGADOR --------
@onready var barra_vida = $Control/TextureProgressBar_Vida
@onready var foto_perfil = $Control/TextureRect_Cabeza

# -------- JEFE --------
@onready var contenedor_jefe = $Control/ContenedorJefe
@onready var barra_jefe = $Control/ContenedorJefe/BarraJefe

# -------- TEXTURAS --------
var cara_personaje_1 = preload("res://Assets/UI/cara_hombre.png")
var cara_personaje_2 = preload("res://Assets/UI/cara_mujer.png")

# -------- INIT --------
func _ready():
	contenedor_jefe.hide()
	
# -------- CONFIG JUGADOR --------
func configurar_hud(genero):
	if genero == "mujer":
		foto_perfil.texture = cara_personaje_2
	else:
		foto_perfil.texture = cara_personaje_1

func actualizar_vida(actual, maximo):
	barra_vida.max_value = maximo
	barra_vida.value = actual

# -------- JEFE --------
func mostrar_barra_jefe(max_vida):
	contenedor_jefe.show()
	barra_jefe.max_value = max_vida
	barra_jefe.value = max_vida

func actualizar_vida_jefe(vida):
	barra_jefe.value = vida

func ocultar_barra_jefe():
	contenedor_jefe.hide()
