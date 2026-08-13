extends Node

const PALETTE_PATH := "res://live_palette/palette.tres"

var _pal: LivePaletteData


func _enter_tree() -> void:
	if ResourceLoader.exists(PALETTE_PATH):
		_pal = load(PALETTE_PATH) as LivePaletteData
	else:
		_pal = LivePaletteData.new()
	get_tree().node_added.connect(_on_node_added)
	_pal.apply_to_tree(get_tree().root)


func _on_node_added(p_node: Node) -> void:
	_pal.apply_to_object(p_node, {})


func color(p_name: StringName) -> Color:
	return _pal.get_color_by_name(p_name)


func has_color(p_name: StringName) -> bool:
	return _pal.has_color_name(p_name)
