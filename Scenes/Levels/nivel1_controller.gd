extends Node2D

@onready var altar_text: Label = $UI/AltarText
@onready var boss_text: Label = $UI/BossText
@onready var barrier: StaticBody2D = $BarreraRaices
@onready var barrier_collision: CollisionShape2D = $BarreraRaices/CollisionShape2D
@onready var barrier_visual: Polygon2D = $BarreraRaices/Visual
@onready var exit_area: Area2D = $Salida
@onready var next_level_text: Label = $UI/NextLevelText

func _ready() -> void:
	altar_text.visible = false
	boss_text.visible = true
	next_level_text.visible = false
	exit_area.monitoring = false
	$GuardianCaido.defeated.connect(_on_guardian_defeated)

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
