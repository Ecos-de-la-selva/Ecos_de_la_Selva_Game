extends Node2D

@onready var objective_text: Label = $UI/ObjectiveText
@onready var boss_text: Label = $UI/BossText
@onready var exit_text: Label = $UI/ExitText
@onready var exit_area: Area2D = $SalidaNivel3
@onready var boss_gate: StaticBody2D = $BarreraBoss
@onready var boss_gate_shape: CollisionShape2D = $BarreraBoss/CollisionShape2D
@onready var boss_gate_visual: Polygon2D = $BarreraBoss/Visual
@onready var mini_boss: Node2D = $GuardianCaidoN2

func _ready() -> void:
	objective_text.visible = true
	boss_text.visible = true
	exit_text.visible = false
	exit_area.monitoring = false
	if mini_boss.has_signal("defeated"):
		mini_boss.defeated.connect(_on_miniboss_defeated)

func _on_miniboss_defeated() -> void:
	boss_gate_shape.disabled = true
	boss_gate_visual.visible = false
	exit_area.monitoring = true
	exit_text.visible = true
	boss_text.text = "La salida a la zona industrial esta abierta."

func _on_salida_nivel3_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	# Placeholder temporal: hasta crear Nivel3, vuelve a screen1.
	get_tree().change_scene_to_file("res://Scenes/Screen/screen1.tscn")
