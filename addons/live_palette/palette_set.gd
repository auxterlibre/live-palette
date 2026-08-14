@tool
class_name LivePaletteSet
extends RefCounted
## Every palette living in res://live_palette/. Several palettes coexist — a UI one
## and a world one, say — each with its own entries and variants.
##
## Bindings do not name a palette: entry ids come from generate_scene_unique_id()
## and are unique by construction, so an id is resolved by asking each palette in
## turn. That is what lets a second palette appear without touching a saved scene.

const DIR := "res://live_palette"
const DEFAULT_STEM := "palette"  # res://live_palette/palette.tres, the one 1.0 shipped

## stem -> LivePaletteData, e.g. "palette" and "ui".
var palettes: Dictionary = {}


func load_all() -> void:
	palettes.clear()
	if not DirAccess.dir_exists_absolute(DIR):
		return
	var stems: Array = []
	for file in DirAccess.get_files_at(DIR):
		if file.get_extension() == "tres":
			stems.append(file.get_basename())
	stems.sort()
	for stem in stems:
		var data: LivePaletteData = load("%s/%s.tres" % [DIR, stem]) as LivePaletteData
		if data != null:
			palettes[stem] = data
	warn_on_duplicate_ids()


## Ordered so the default palette is always first and the rest follow alphabetically.
func stems() -> Array:
	var out: Array = palettes.keys()
	out.sort()
	if DEFAULT_STEM in out:
		out.erase(DEFAULT_STEM)
		out.push_front(DEFAULT_STEM)
	return out


func get_palette(p_stem: String) -> LivePaletteData:
	return palettes.get(p_stem)


func is_empty() -> bool:
	return palettes.is_empty()


# -- apply: every palette skips ids it does not know, so one pass each is enough --

func apply_to_tree(p_root: Node) -> int:
	var changed := 0
	for stem in palettes:
		changed += (palettes[stem] as LivePaletteData).apply_to_tree(p_root)
	return changed


func apply_to_object(p_object: Object, p_visited: Dictionary) -> int:
	var changed := 0
	for stem in palettes:
		# A fresh visited set per palette: the first pass would otherwise mark every
		# object seen and the second would skip the whole tree.
		changed += (palettes[stem] as LivePaletteData).apply_to_object(p_object, p_visited.duplicate())
	return changed


# -- lookups across the whole set --

## {stem, palette, index} for the palette holding p_id, or an empty dictionary.
func find_entry(p_id: String) -> Dictionary:
	for stem in stems():
		var data: LivePaletteData = palettes[stem]
		var index := data.find_index(p_id)
		if index >= 0:
			return {"stem": stem, "palette": data, "index": index}
	return {}


func get_color_by_id(p_id: String) -> Color:
	var found := find_entry(p_id)
	if found.is_empty():
		return Color.WHITE
	return (found["palette"] as LivePaletteData).get_color_by_id(p_id)


## First match wins; pass p_stem to read one palette in particular.
func get_color_by_name(p_name: StringName, p_stem: String = "") -> Color:
	if p_stem != "" and palettes.has(p_stem):
		return (palettes[p_stem] as LivePaletteData).get_color_by_name(p_name)
	for stem in stems():
		var data: LivePaletteData = palettes[stem]
		if data.has_color_name(p_name):
			return data.get_color_by_name(p_name)
	push_warning("LivePalette: no color named '%s' in any palette" % p_name)
	return Color.WHITE


func has_color_name(p_name: StringName) -> bool:
	for stem in palettes:
		if (palettes[stem] as LivePaletteData).has_color_name(p_name):
			return true
	return false


## An id free in every palette, so two palettes can never claim the same binding.
func new_id() -> String:
	var id := Resource.generate_scene_unique_id()
	while not find_entry(id).is_empty():
		id = Resource.generate_scene_unique_id()
	return id


## Duplicating a palette file by hand copies its ids, which would make a binding
## ambiguous. Cheap to detect, miserable to debug.
func warn_on_duplicate_ids() -> void:
	var seen := {}
	for stem in stems():
		for entry in (palettes[stem] as LivePaletteData).entries:
			var id: String = str(entry["id"])
			if seen.has(id):
				push_warning("LivePalette: id '%s' is in both '%s' and '%s'; bindings to it resolve to the first. Give one of them a fresh id." % [id, seen[id], stem])
			else:
				seen[id] = stem


# -- variants across the set --

## Switches every palette that has a variant of this name, so one call can carry a
## whole theme across the UI palette and the world palette together.
func set_variant(p_variant: String) -> int:
	var switched := 0
	for stem in palettes:
		var data: LivePaletteData = palettes[stem]
		if p_variant in data.variants:
			data.set_active_variant(p_variant)
			switched += 1
	return switched


## Every variant name offered by any palette.
func variant_names() -> PackedStringArray:
	var names := PackedStringArray()
	for stem in stems():
		for variant in (palettes[stem] as LivePaletteData).variants:
			if not variant in names:
				names.append(variant)
	return names


# -- generated constants --

const CONST_PATH := "%s/palette_const.gd" % DIR
const CONST_CLASS := "LivePalette"

## The nested-class name a palette is reached through: ui.tres -> LivePalette.UI.
## Upper snake, because it reads as a namespace of constants at the call site.
static func namespace_for(p_stem: String) -> String:
	var stem := p_stem.trim_suffix("_palette").trim_suffix("palette")
	if stem.is_empty():
		stem = p_stem
	var out := ""
	for c in stem.to_snake_case().to_upper():
		out += c if (c >= "A" and c <= "Z") or (c >= "0" and c <= "9") else "_"
	while out.contains("__"):
		out = out.replace("__", "_")
	out = out.lstrip("_").rstrip("_")
	if out.is_empty() or (out[0] >= "0" and out[0] <= "9"):
		out = "P_" + out
	return out


## One file, one class: the default palette's colors sit at the top level
## (LivePalette.RED) and every other palette becomes a nested class
## (LivePalette.UI.PANEL). A single class name to keep free, and the call site
## never has to remember which palette got a bespoke class.
func build_const_script() -> String:
	var out := PackedStringArray()
	out.append("# Generated by the Live Palette addon from %s/*.tres." % DIR)
	out.append("# Do not edit — it is rewritten whenever a palette changes.")
	out.append("class_name %s" % CONST_CLASS)
	out.append("")

	var default_palette: LivePaletteData = palettes.get(DEFAULT_STEM)
	var taken := {}
	if default_palette != null:
		out.append(default_palette.build_const_body(CONST_CLASS))
		for e in default_palette.entries:
			var ident := LivePaletteData.const_identifier(str(e["name"]))
			if not ident.is_empty():
				taken[ident] = true

	for stem in stems():
		if stem == DEFAULT_STEM:
			continue
		var data: LivePaletteData = palettes[stem]
		var space := namespace_for(String(stem))
		# A nested class cannot share a name with a top-level constant, which a
		# colour called "Ui" in the default palette would produce.
		if taken.has(space):
			push_warning("LivePalette: palette '%s' wants the name %s, which a color in the default palette already uses; exposing it as %s_ instead. Rename either to settle it." % [stem, space, space])
			space += "_"
		taken[space] = true
		out.append("")
		out.append("")
		out.append("## From %s/%s.tres." % [DIR, stem])
		out.append("class %s:" % space)
		out.append(data.build_const_body("%s.%s" % [CONST_CLASS, space], "\t"))
	return "\n".join(out) + "\n"
