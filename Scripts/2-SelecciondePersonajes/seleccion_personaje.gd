extends Control

# --- CONFIGURACIÓN DE RUTAS ---
const ESCENA_MUNDO = "res://Scenes/Level-1/mundo.tscn" 

# --- REFERENCIAS A NODOS ---
@onready var btn_hombre = $BotonHombre
@onready var btn_mujer = $BotonMujer
@onready var anim_transition = $Transicion/AnimationPlayer2 
@onready var sonido_seleccion = $SonidoSeleccion 

func _ready():
	btn_hombre.scale = Vector2(1.5, 1.5)
	btn_mujer.scale = Vector2(1.5, 1.5)
	btn_hombre.pivot_offset = btn_hombre.size / 2
	btn_mujer.pivot_offset = btn_mujer.size / 2
	
	if has_node("BotonHombre/AnimHombre"):
		$BotonHombre/AnimHombre.play("idle")
	if has_node("BotonMujer/AnimMujer"):
		$BotonMujer/AnimMujer.play("idle")
	
	if anim_transition and anim_transition.has_animation("appear"):
		anim_transition.play_backwards("appear")

# --- CONEXIÓN DE SEÑALES ---

func _on_boton_hombre_pressed():
	seleccionar("hombre")

func _on_boton_mujer_pressed():
	seleccionar("mujer")

# --- LÓGICA DE SELECCIÓN ---

func seleccionar(genero):
	if sonido_seleccion:
		sonido_seleccion.play()
	
	btn_hombre.disabled = true
	btn_mujer.disabled = true
	Global.personaje_seleccionado = genero
	
	if genero == "hombre":
		btn_hombre.modulate = Color(1.5, 1.5, 1.5) 
		btn_hombre.scale = Vector2(1.65, 1.65)      
		btn_mujer.modulate = Color(0.5, 0.5, 0.5)
	else:
		btn_mujer.modulate = Color(1.5, 1.5, 1.5) 
		btn_mujer.scale = Vector2(1.65, 1.65)      
		btn_hombre.modulate = Color(0.5, 0.5, 0.5)

	await get_tree().create_timer(1.0).timeout
	
	if anim_transition:
		anim_transition.play("apprite") 
		await anim_transition.animation_finished
	
	# --- EXTERMINADOR DE MÚSICA RECARGADO ---
	detener_todo_el_sonido_global()
	
	get_tree().change_scene_to_file(ESCENA_MUNDO)

# Función de seguridad extra
func detener_todo_el_sonido_global():
	if is_instance_valid(MusicaGlobal):
		# 1. Si el Autoload mismo es el reproductor
		if MusicaGlobal is AudioStreamPlayer or MusicaGlobal is AudioStreamPlayer2D:
			MusicaGlobal.stop()
		
		# 2. Buscar CUALQUIER hijo que sea un reproductor de audio y apagarlo
		for hijo in MusicaGlobal.get_children():
			if hijo is AudioStreamPlayer or hijo is AudioStreamPlayer2D:
				hijo.stop()
				print("Se detuvo el nodo de audio: ", hijo.name)
		
		# 3. Intentar llamar a un método stop por si acaso
		if MusicaGlobal.has_method("stop"):
			MusicaGlobal.stop()
