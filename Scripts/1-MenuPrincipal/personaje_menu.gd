extends AnimatedSprite2D

# --- CONFIGURACIÓN ---
var limite_caminata : float = 250.0  # Rango de movimiento
var velocidad_caminata : float = 50.0 # Píxeles por segundo
var tiempo_descanso_min : float = 2.0 # Mínimo tiempo quieto
var tiempo_descanso_max : float = 5.0 # Máximo tiempo quieto

var inicio_x : float

func _ready():
	# Guardamos el centro exacto donde pusiste al personaje
	inicio_x = position.x
	
	# Iniciamos la "rutina de vida" del personaje
	rutina_personaje()

func rutina_personaje():
	# Este bucle se ejecutará para siempre mientras el juego esté abierto
	while true:
		
		# --- FASE 1: CAMINAR ---
		# Elegimos destino
		var destino_x = randf_range(inicio_x - limite_caminata, inicio_x + limite_caminata)
		
		# Girar el sprite
		flip_h = (destino_x < position.x)
		
		# Reproducir animación de caminar
		play("walk")
		
		# Crear el movimiento
		var distancia = abs(destino_x - position.x)
		var duracion = distancia / velocidad_caminata
		
		var tween = create_tween()
		tween.tween_property(self, "position:x", destino_x, duracion)
		
		# ¡CLAVE!: Esperamos a que el Tween termine antes de seguir con el código
		await tween.finished
		
		
		# --- FASE 2: DESCANSAR (IDLE) ---
		# Ya llegó, ahora ponemos idle
		play("idle")
		
		# Elegimos un tiempo al azar para quedarse quieto
		var tiempo_espera = randf_range(tiempo_descanso_min, tiempo_descanso_max)
		
		# ¡CLAVE!: Esperamos ese tiempo antes de volver a empezar el bucle
		await get_tree().create_timer(tiempo_espera).timeout

		# El bucle vuelve a empezar desde arriba (Fase 1)
