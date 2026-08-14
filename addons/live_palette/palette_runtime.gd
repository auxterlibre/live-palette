extends Node

signal variant_changed(variant: String)

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


func color(p_name: StringName, p_variant: String = "") -> Color:
	return _pal.get_color_by_name(p_name, p_variant)


func has_color(p_name: StringName) -> bool:
	return _pal.has_color_name(p_name)


# -- variants --

## Switches the whole game over: every bound property is re-applied in place, so a
## light/dark swap costs one call rather than a per-scene retint.
## Runtime only — the palette resource on disk is not rewritten.
func set_variant(p_variant: String) -> bool:
	if not p_variant in _pal.variants:
		push_warning("LivePalette: no variant named '%s'" % p_variant)
		return false
	if p_variant == _pal.active_variant:
		return true
	_pal.active_variant = p_variant
	_pal.apply_to_tree(get_tree().root)
	variant_changed.emit(p_variant)
	return true


func get_variant() -> String:
	return _pal.active_variant


func variants() -> PackedStringArray:
	return _pal.variants
