extends Area2D

# --- CONFIGURACIÓN ---
@export var velocidad := 250.0
@export var dano: int = 20
# Tiempo (segundos) que vive el proyectil antes de auto-destruirse
@export var tiempo_vida := 4.0

# Dirección normalizada hacia donde se mueve el proyectil
var direccion := Vector2.RIGHT


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Si viaja hacia la izquierda, voltear el sprite
	if direccion.x < 0 and has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.flip_h = true

	# Auto-destrucción
	await get_tree().create_timer(tiempo_vida).timeout
	if is_instance_valid(self):
		queue_free()


func _physics_process(delta: float) -> void:
	global_position += direccion * velocidad * delta


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("jugador") and body.has_method("recibir_danio"):
		body.recibir_danio(dano)
		queue_free()
