extends Node2D

@onready var altar_text: Label = $UI/AltarText
@onready var boss_text: Label = $UI/BossText
@onready var barrier: StaticBody2D = $BarreraRaices
@onready var barrier_collision: CollisionShape2D = $BarreraRaices/CollisionShape2D
@onready var barrier_visual: Polygon2D = $BarreraRaices/Visual
@onready var exit_area: Area2D = $Salida
@onready var next_level_text: Label = $UI/NextLevelText
@onready var mid_barrier_collision: CollisionShape2D = $BarreraIntermedia/CollisionShape2D
@onready var mid_barrier_visual: Polygon2D = $BarreraIntermedia/Visual

var _mid_barrier_opened: bool = false

func _ready() -> void:
	altar_text.visible = false
	boss_text.visible = true
	next_level_text.visible = false
	exit_area.monitoring = false
	$GuardianCaido.defeated.connect(_on_guardian_defeated)

func _process(_delta: float) -> void:
	if _mid_barrier_opened:
		return

	if not is_instance_valid($LarvaA) and not is_instance_valid($LarvaB):
		_mid_barrier_opened = true
		mid_barrier_collision.disabled = true
		mid_barrier_visual.visible = false
		altar_text.text = "Paso despejado. Avanza hacia el guardian."

func _on_altar_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		altar_text.visible = true

func _on_altar_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		altar_text.visible = false

func _on_guardian_defeated() -> void:
	boss_text.text = "Guardian derrotado. Las raices se abren."
	barrier_collision.disabled = true
	barrier_visual.visible = false
	exit_area.monitoring = true
	next_level_text.visible = true

func _on_salida_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		get_tree().change_scene_to_file("res://Scenes/Screen/escreen1.tscn")

func _on_pinchos_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("recibir_danio"):
		body.recibir_danio(15, Vector2.ZERO)
