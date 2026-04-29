class_name HitStop
extends RefCounted

static var _is_active: bool = false
static var _previous_time_scale: float = 1.0

static func freeze(tree: SceneTree, duration: float = 0.05, frozen_scale: float = 0.0) -> void:
	if _is_active:
		return

	_is_active = true
	_previous_time_scale = Engine.time_scale
	Engine.time_scale = frozen_scale

	await tree.create_timer(duration, true, false, true).timeout

	Engine.time_scale = _previous_time_scale
	_is_active = false
