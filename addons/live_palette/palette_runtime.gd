extends Node

signal variant_changed(variant: String)

const PALETTE_PATH := "res://live_palette/palette.tres"

var _set: LivePaletteSet


func _enter_tree() -> void:
	_set = LivePaletteSet.new()
	_set.load_all()  # every palette in the folder, not just the default one
	get_tree().node_added.connect(_on_node_added)
	_set.apply_to_tree(get_tree().root)


func _on_node_added(p_node: Node) -> void:
	_set.apply_to_object(p_node, {})


## The palettes themselves, keyed by file stem, for code that wants one directly.
func palettes() -> Dictionary:
	return _set.palettes


func get_palette(p_stem: String) -> LivePaletteData:
	return _set.get_palette(p_stem)


## Searches every palette; pass p_stem ("ui") to read one in particular.
func color(p_name: StringName, p_stem: String = "") -> Color:
	return _set.get_color_by_name(p_name, p_stem)


func has_color(p_name: StringName) -> bool:
	return _set.has_color_name(p_name)


# -- variants --

## Switches every palette that has a variant of this name, so one call can carry a
## theme across the UI palette and the world palette together. Each bound property
## is re-applied in place, so a light/dark swap costs one call.
## Runtime only — the palette resources on disk are not rewritten.
func set_variant(p_variant: String) -> bool:
	var switched := _set.set_variant(p_variant)
	if switched == 0:
		push_warning("LivePalette: no palette has a variant named '%s'" % p_variant)
		return false
	_set.apply_to_tree(get_tree().root)
	variant_changed.emit(p_variant)
	return true


## The active variant of one palette (the default palette unless p_stem says otherwise).
func get_variant(p_stem: String = LivePaletteSet.DEFAULT_STEM) -> String:
	var data := _set.get_palette(p_stem)
	return data.active_variant if data else ""


## Every variant name offered by any palette.
func variants() -> PackedStringArray:
	return _set.variant_names()
