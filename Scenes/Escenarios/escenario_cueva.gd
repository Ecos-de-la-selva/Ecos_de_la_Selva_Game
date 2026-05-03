extends Node2D

const CHUNK_VISUAL_WORLD_WIDTH := 768.0

## Quita repetición cuando se instancia el mismo tramo tres veces. La capa CollisionOculta no se toca.
@export_enum("Por defecto", "Espejo horizontal", "Tonalidad + techo ligeramente arriba") var chunk_decor: int = 0

func _ready() -> void:
	_apply_decor()


func _apply_decor() -> void:
	var vis := get_node_or_null("TilesTemploVisibles") as TileMapLayer
	if vis == null:
		return
	match chunk_decor:
		0:
			pass
		1:
			_flip_visual_horizontal(vis)
		2:
			vis.self_modulate = Color(0.9, 0.97, 1.05, 1.0)
			vis.position.y -= 6.0


func _flip_visual_horizontal(vis: TileMapLayer) -> void:
	vis.scale.x = -abs(vis.scale.x)
	vis.position.x += CHUNK_VISUAL_WORLD_WIDTH
