@tool
class_name LivePaletteData
extends Resource

const META := &"_live_palette_bindings"
const DEFAULT_VARIANT := "Default"

## [{id: String, name: String, colors: {variant_name: Color}}]. Pre-1.1 entries
## carry a single "color" instead and are read through the same accessors.
@export var entries: Array[Dictionary] = []

## Ordered; the first is the fallback for any entry a variant has no color for.
@export var variants: PackedStringArray = PackedStringArray([DEFAULT_VARIANT])

## The variant currently applied, in the editor and at startup.
@export var active_variant: String = DEFAULT_VARIANT


func find_index(p_id: String) -> int:
	for i in entries.size():
		if entries[i]["id"] == p_id:
			return i
	return -1


## Empty p_variant means the active one. Falls back to the first variant when this
## one has no color for the entry, so a half-filled variant still renders.
func get_color_by_id(p_id: String, p_variant: String = "") -> Color:
	var i := find_index(p_id)
	if i < 0:
		return Color.WHITE
	return color_of(entries[i], p_variant)


func get_color_by_name(p_name: StringName, p_variant: String = "") -> Color:
	for e in entries:
		if e["name"] == String(p_name):
			return color_of(e, p_variant)
	push_warning("LivePalette: no color named '%s'" % p_name)
	return Color.WHITE


func has_color_name(p_name: StringName) -> bool:
	for e in entries:
		if e["name"] == String(p_name):
			return true
	return false


## Reads one entry, tolerating both the 1.1 "colors" map and the pre-1.1 "color".
func color_of(p_entry: Dictionary, p_variant: String = "") -> Color:
	if not p_entry.has("colors"):
		return p_entry.get("color", Color.WHITE)
	var colors: Dictionary = p_entry["colors"]
	var wanted: String = p_variant if p_variant != "" else active_variant
	if colors.has(wanted):
		return colors[wanted]
	var fallback: String = variants[0] if not variants.is_empty() else DEFAULT_VARIANT
	if colors.has(fallback):
		return colors[fallback]
	return colors.values()[0] if not colors.is_empty() else Color.WHITE


func base_variant() -> String:
	return variants[0] if not variants.is_empty() else DEFAULT_VARIANT


# -- variants --

func add_variant(p_name: String, p_copy_from: String = "") -> void:
	if p_name.is_empty() or p_name in variants:
		return
	variants.append(p_name)
	# A new variant starts as a copy, so it is a recolor of a working set rather
	# than a screen full of white.
	var source: String = p_copy_from if p_copy_from != "" else active_variant
	for e in entries:
		if e.has("colors"):
			e["colors"][p_name] = color_of(e, source)
	emit_changed()


func remove_variant(p_name: String) -> void:
	if variants.size() <= 1 or not p_name in variants:
		return  # never leave the palette with no variant at all
	variants.remove_at(variants.find(p_name))
	for e in entries:
		if e.has("colors"):
			e["colors"].erase(p_name)
	if active_variant == p_name:
		active_variant = base_variant()
	emit_changed()


func rename_variant(p_from: String, p_to: String) -> void:
	if p_to.is_empty() or p_to in variants or not p_from in variants:
		return
	variants[variants.find(p_from)] = p_to
	for e in entries:
		if e.has("colors") and e["colors"].has(p_from):
			e["colors"][p_to] = e["colors"][p_from]
			e["colors"].erase(p_from)
	if active_variant == p_from:
		active_variant = p_to
	emit_changed()


func set_active_variant(p_name: String) -> void:
	if p_name == active_variant or not p_name in variants:
		return
	active_variant = p_name
	emit_changed()  # the editor and the autoload both re-apply from here


## Rewrites pre-1.1 entries in place. Returns true when anything changed, so the
## caller can save. Read access works without it; this just makes it permanent.
func migrate() -> bool:
	var changed := false
	if variants.is_empty():
		variants = PackedStringArray([DEFAULT_VARIANT])
		changed = true
	if not active_variant in variants:
		active_variant = base_variant()
		changed = true
	for e in entries:
		if e.has("colors"):
			continue
		e["colors"] = {base_variant(): e.get("color", Color.WHITE)}
		e.erase("color")
		changed = true
	if changed:
		emit_changed()
	return changed


func new_id() -> String:
	var id := generate_scene_unique_id()
	while find_index(id) >= 0:
		id = generate_scene_unique_id()
	return id


# -- mutators: the sole write path; each emits changed --

## A new entry gets p_color in every variant: an entry that exists in one variant
## and not another is the one state the fallback cannot paper over sensibly.
func add_entry(p_id: String, p_name: String, p_color: Color, p_index: int = -1) -> void:
	var colors := {}
	for variant in variants:
		colors[variant] = p_color
	var e := {"id": p_id, "name": p_name, "colors": colors}
	if p_index < 0 or p_index >= entries.size():
		entries.append(e)
	else:
		entries.insert(p_index, e)
	emit_changed()


func remove_entry(p_id: String) -> void:
	var i := find_index(p_id)
	if i >= 0:
		entries.remove_at(i)
		emit_changed()


func rename_entry(p_id: String, p_name: String) -> void:
	var i := find_index(p_id)
	if i >= 0:
		entries[i]["name"] = p_name
		emit_changed()


## p_to_index is the entry's index in the resulting array, so undo is move_entry(id, old_index).
func move_entry(p_id: String, p_to_index: int) -> void:
	var i := find_index(p_id)
	if i < 0:
		return
	var e: Dictionary = entries[i]
	entries.remove_at(i)
	entries.insert(clampi(p_to_index, 0, entries.size()), e)
	emit_changed()


## Empty p_variant writes the active one, so the dock edits what it is showing.
func set_color(p_id: String, p_color: Color, p_variant: String = "") -> void:
	var i := find_index(p_id)
	if i < 0:
		return
	var variant: String = p_variant if p_variant != "" else active_variant
	if not entries[i].has("colors"):
		entries[i]["colors"] = {base_variant(): entries[i].get("color", Color.WHITE)}
		entries[i].erase("color")
	entries[i]["colors"][variant] = p_color
	emit_changed()


# -- constants script generation (text only; the plugin writes the file) --

## "Sky Blue" -> "SKY_BLUE". Returns "" when nothing usable is left.
static func const_identifier(p_name: String) -> String:
	var out := ""
	for c in p_name.to_upper():
		out += c if (c >= "A" and c <= "Z") or (c >= "0" and c <= "9") else "_"
	while out.contains("__"):
		out = out.replace("__", "_")
	out = out.lstrip("_").rstrip("_")
	if out.is_empty():
		return ""
	if out[0] >= "0" and out[0] <= "9":
		out = "C_" + out  # identifiers can't start with a digit
	return out


## Named slots, not positional: the template repeats the class name three times and
## a miscount silently shifts every substitution.
const CONST_TEMPLATE := """# Generated by the Live Palette addon from {source}.
# Do not edit — it is rewritten whenever the palette changes.
# The constants are the "{base}" variant; switching variants at runtime goes through
# the LivePaletteRuntime autoload, which re-applies bound properties for you.
class_name {class}

{consts}

## Palette name -> color, for lookups by a name held in a variable.
## Prefer the constants above: {class}.MY_COLOR is checked at compile time.
const BY_NAME := {
{pairs}
}

## Variant name -> {palette name -> color}, for reading a variant you are not on.
const VARIANTS := {
{variants}
}


static func color(p_name: StringName) -> Color:
	var key := str(p_name)
	if BY_NAME.has(key):
		return BY_NAME[key]
	push_warning("{class}: no color named '%s'" % p_name)
	return Color.WHITE


static func has_color(p_name: StringName) -> bool:
	return BY_NAME.has(str(p_name))


## A color from a specific variant, falling back to the generated base variant.
static func color_in(p_variant: StringName, p_name: StringName) -> Color:
	var table: Dictionary = VARIANTS.get(str(p_variant), {})
	if table.has(str(p_name)):
		return table[str(p_name)]
	return color(p_name)


static func variant_names() -> PackedStringArray:
	return PackedStringArray(VARIANTS.keys())
"""


## GDScript source exposing every entry as a Color constant, for autocompleted access.
## Constants come from the base variant so they never move when the active variant
## changes; every variant is also emitted in the VARIANTS table.
func build_const_script(p_class_name: String, p_source_path: String) -> String:
	var consts := PackedStringArray()
	var pairs := PackedStringArray()
	var used := {}
	var base := base_variant()
	for e in entries:
		var ident := const_identifier(str(e["name"]))
		if ident.is_empty():
			ident = "C_" + str(e["id"]).to_upper()
		var stem := ident
		var n := 2
		while used.has(ident):  # two names can sanitize to the same identifier
			ident = "%s_%d" % [stem, n]
			n += 1
		used[ident] = true
		consts.append("const %s := %s" % [ident, var_to_str(color_of(e, base))])
		pairs.append("\t%s: %s," % [var_to_str(str(e["name"])), ident])

	var variant_rows := PackedStringArray()
	for variant in variants:
		var cells := PackedStringArray()
		for e in entries:
			cells.append("\t\t%s: %s," % [var_to_str(str(e["name"])), var_to_str(color_of(e, variant))])
		variant_rows.append("\t%s: {\n%s\n\t}," % [var_to_str(variant), "\n".join(cells)])

	return CONST_TEMPLATE.format({
		"source": p_source_path,
		"base": base,
		"class": p_class_name,
		"consts": "\n".join(consts),
		"pairs": "\n".join(pairs),
		"variants": "\n".join(variant_rows),
	})


# -- GIMP .gpl import/export (the palette format Lospec, Aseprite and Krita speak) --

## Parses .gpl text into [{name: String, color: Color}]. Unparseable lines are skipped.
static func parse_gpl(p_text: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rgba := false
	for raw in p_text.split("\n"):
		var line := raw.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var lower := line.to_lower()
		if lower.begins_with("gimp palette") or lower.begins_with("name:") or lower.begins_with("columns:"):
			continue
		if lower.begins_with("channels:"):  # Krita writes "Channels: RGBA" for 4-value lines
			rgba = lower.contains("rgba")
			continue
		var tokens := line.replace("\t", " ").split(" ", false)
		var want := 4 if rgba else 3
		if tokens.size() < want:
			continue
		var numeric := true
		for i in want:
			if not tokens[i].is_valid_int():
				numeric = false
				break
		if not numeric:
			continue
		var a := clampi(tokens[3].to_int(), 0, 255) if rgba else 255
		var c := Color8(clampi(tokens[0].to_int(), 0, 255), clampi(tokens[1].to_int(), 0, 255), clampi(tokens[2].to_int(), 0, 255), a)
		out.append({"name": " ".join(tokens.slice(want)), "color": c})
	return out


## The format is RGB: alpha is flattened on export.
func to_gpl(p_palette_name: String) -> String:
	var lines := PackedStringArray(["GIMP Palette",
			"Name: %s (%s)" % [p_palette_name, active_variant], "Columns: 8", "#"])
	for e in entries:
		var c: Color = color_of(e)  # the active variant: what the dock is showing
		lines.append("%d %d %d\t%s" % [c.r8, c.g8, c.b8, e["name"]])
	return "\n".join(lines) + "\n"


# -- uses scan --

## Counts references to p_id inside _live_palette_bindings blocks of a .tscn/.tres text.
## Ignores the id appearing anywhere else in the file.
static func find_uses_in_text(p_text: String, p_id: String) -> int:
	var needle := "\"%s\"" % p_id
	var n := 0
	var from := p_text.find(String(META))
	while from >= 0:
		var close := p_text.find("}", from)  # binding dict holds only strings: first } closes it
		if close < 0:
			close = p_text.length()
		n += p_text.substr(from, close - from).count(needle)
		from = p_text.find(String(META), close + 1)
	return n


static func hex(p_color: Color) -> String:
	return "#" + p_color.to_html(p_color.a < 1.0).to_upper()


func apply_to_tree(p_root: Node) -> int:
	return _apply_recursive(p_root, {})


func _apply_recursive(p_node: Node, p_visited: Dictionary) -> int:
	var n := apply_to_object(p_node, p_visited)
	for c in p_node.get_children():
		n += _apply_recursive(c, p_visited)
	return n


func apply_to_object(p_obj: Object, p_visited: Dictionary) -> int:
	var iid := p_obj.get_instance_id()
	if p_visited.has(iid):
		return 0
	p_visited[iid] = true
	var n := 0
	if p_obj.has_meta(META):
		var bindings: Dictionary = p_obj.get_meta(META)
		for prop in bindings:
			var i := find_index(str(bindings[prop]))
			if i < 0:
				continue
			var c: Color = color_of(entries[i])  # whichever variant is active
			var cur: Variant = p_obj.get(prop)
			if cur is Color and not cur.is_equal_approx(c):
				p_obj.set(prop, c)
				n += 1
	for p in p_obj.get_property_list():
		if p["type"] == TYPE_OBJECT and (p["usage"] & PROPERTY_USAGE_STORAGE) and p["name"] != "script":
			var v: Variant = p_obj.get(p["name"])
			if v is Resource:
				n += apply_to_object(v, p_visited)
	return n
