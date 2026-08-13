@tool
extends EditorInspectorPlugin

var palette: LivePaletteData
var undo: EditorUndoRedoManager


func setup(p_palette: LivePaletteData, p_undo: EditorUndoRedoManager) -> void:
	palette = p_palette
	undo = p_undo


func _can_handle(p_object: Object) -> bool:
	return not (p_object is LivePaletteData)  # no self-binding on the palette itself


func _parse_property(p_object: Object, p_type: Variant.Type, p_name: String, p_hint: PropertyHint, p_hint_string: String, p_usage: int, p_wide: bool) -> bool:
	if p_type == TYPE_COLOR:
		add_property_editor(p_name, PaletteProp.new(palette, undo), true, "Palette")
	return false  # keep the built-in color picker


class PaletteProp:
	extends EditorProperty

	const COLUMNS := 8
	const CELL := 24  # swatch side, in unscaled editor pixels (matches the dock swatch)

	var _palette: LivePaletteData
	var _undo: EditorUndoRedoManager
	var _btn := Button.new()
	var _popup := PopupPanel.new()
	var _grid := GridContainer.new()
	var _unlink := Button.new()
	var _empty := Label.new()

	func _init(p_palette: LivePaletteData, p_undo: EditorUndoRedoManager) -> void:
		_palette = p_palette
		_undo = p_undo
		_btn.text = "Palette..."
		_btn.clip_text = true
		_btn.pressed.connect(_open_popup)
		add_child(_btn)
		add_focusable(_btn)
		var vb := VBoxContainer.new()
		_popup.add_child(vb)
		_grid.columns = COLUMNS
		vb.add_child(_grid)
		_empty.text = "(palette is empty)"
		vb.add_child(_empty)
		_unlink.text = "Unlink"
		_unlink.pressed.connect(func() -> void: _pick(""))
		vb.add_child(_unlink)
		add_child(_popup)
		_palette.changed.connect(update_property)

	func _open_popup() -> void:
		for c in _grid.get_children():
			_grid.remove_child(c)
			c.free()
		var cur := _current_id()
		var side := CELL * EditorInterface.get_editor_scale()
		for e in _palette.entries:
			var id := str(e["id"])
			var cell := Button.new()
			cell.custom_minimum_size = Vector2(side, side)
			cell.tooltip_text = "%s\n%s" % [e["name"], LivePaletteData.hex(e["color"])]  # name + hex on hover
			cell.add_theme_stylebox_override(&"normal", _cell_style(e["color"], id == cur))
			var hi := _cell_style(e["color"], true)
			cell.add_theme_stylebox_override(&"hover", hi)
			cell.add_theme_stylebox_override(&"pressed", hi)
			cell.add_theme_stylebox_override(&"focus", hi)
			cell.pressed.connect(func() -> void: _pick(id))
			_grid.add_child(cell)
		_empty.visible = _palette.entries.is_empty()
		_unlink.visible = not cur.is_empty()
		_popup.reset_size()
		_popup.popup_on_parent(Rect2i(Vector2i(_btn.get_global_position() + Vector2(0, _btn.size.y)), _popup.size))

	static func _cell_style(p_color: Color, p_outlined: bool) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = p_color
		if p_outlined:
			sb.set_border_width_all(2)
			sb.border_color = Color.WHITE
		return sb

	func _current_id() -> String:
		var obj := get_edited_object()
		if not obj:
			return ""
		var b: Dictionary = obj.get_meta(LivePaletteData.META, {})
		return str(b.get(str(get_edited_property()), ""))

	func _pick(p_entry_id: String) -> void:  # "" unlinks
		_popup.hide()
		var entry_id := p_entry_id
		var obj := get_edited_object()
		var prop := str(get_edited_property())
		var old_meta: Dictionary = (obj.get_meta(LivePaletteData.META, {}) as Dictionary).duplicate()
		var new_meta := old_meta.duplicate()
		var action_name := "Palette: bind %s" % prop
		if entry_id.is_empty():
			new_meta.erase(prop)
			action_name = "Palette: unlink %s" % prop
		else:
			new_meta[prop] = entry_id
		_undo.create_action(action_name)
		if not entry_id.is_empty():
			_undo.add_do_property(obj, prop, _palette.get_color_by_id(entry_id))
			_undo.add_undo_property(obj, prop, obj.get(prop))
		if new_meta.is_empty():
			_undo.add_do_method(obj, &"remove_meta", LivePaletteData.META)
		else:
			_undo.add_do_method(obj, &"set_meta", LivePaletteData.META, new_meta)
		if old_meta.is_empty():
			_undo.add_undo_method(obj, &"remove_meta", LivePaletteData.META)
		else:
			_undo.add_undo_method(obj, &"set_meta", LivePaletteData.META, old_meta)
		_undo.commit_action()
		update_property()

	func _update_property() -> void:
		var id := _current_id()
		if id.is_empty():
			_btn.text = "Palette..."
			_btn.icon = null
			return
		var i := _palette.find_index(id)
		if i < 0:
			_btn.text = "missing: %s" % id 
			_btn.icon = null
		else:
			_btn.text = str(_palette.entries[i]["name"])
			_btn.icon = _swatch(_palette.entries[i]["color"])

	func _set_read_only(p_read_only: bool) -> void:
		_btn.disabled = p_read_only

	static func _swatch(p_color: Color) -> ImageTexture:
		var img := Image.create_empty(12, 12, false, Image.FORMAT_RGBA8)
		img.fill(p_color)
		return ImageTexture.create_from_image(img)
