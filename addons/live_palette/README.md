# Live Palette

A centralized, named color palette for Godot 4 — pick palette colors anywhere in the
Inspector, and when you change a palette entry, **every place it was used updates**:
open scenes instantly, other scenes when opened, and the running game at startup.

<!-- screenshot: the Palette dock next to the Inspector -->
<!-- screenshot: the Palette row under a Color property, with the swatch-grid popup open -->

## Features

- **Palette dock** — add, rename, recolor, delete and drag-to-reorder named colors.
  Every operation is undoable.
- **Inspector integration** — every `Color` property on **nodes and resources**
  (theme overrides, StyleBoxes, Theme items, ShaderMaterial `source_color` uniforms)
  gets a *Palette* row: pick an entry from a swatch grid to set the color **and link it**.
  The built-in color picker stays available.
- **Live propagation** — links are stored per use (in object metadata, by stable id, so
  renaming palette entries never breaks them). Editing the palette re-applies everywhere;
  a small runtime autoload re-applies at game start, so stale baked colors can never ship.
- **Generated constants** — `res://live_palette/palette_const.gd` is (re)generated
  automatically as `class_name LivePalette`:

  ```gdscript
  $Sprite2D.modulate = LivePalette.SKY_BLUE          # autocompleted, compile-checked
  var c := LivePalette.color("Sky Blue")             # static lookup by display name
  if LivePalette.has_color("Sky Blue"): ...
  ```

- **GIMP `.gpl` import/export** — pull palettes from Lospec, Aseprite, Krita or GIMP
  straight into the dock (one undoable action), or export yours.
- **Find Uses** — each palette row has a search button that lists every saved
  scene/resource linking that color; double-click a result to open it.

## Install

1. Copy `addons/live_palette/` into your project (or install via the Asset Library).
2. Enable **Live Palette** in *Project Settings > Plugins*.

Enabling registers the `LivePaletteRuntime` autoload and creates `res://live_palette/`
(the palette resource + generated constants). Requires **Godot 4.4+**.

## Quick start

1. Open the **Palette** dock (tabbed next to the Inspector) and add a few colors.
2. Select any node, find any Color property, and use its **Palette** row to link a color.
3. Change that color in the dock — everything linked follows, in-editor and in-game.
4. In code, use `LivePalette.MY_COLOR` (constants) or `LivePalette.color("My Color")`.

## How it works

Picking a palette color stores `{property: entry_id}` in the object's
`_live_palette_bindings` metadata (hidden, serialized with the scene/resource). The
editor plugin re-applies bindings to open scenes when the palette changes and to scenes
as they open; the `LivePaletteRuntime` autoload re-applies at startup and on every
`node_added`, then stays out of the way. Ids are stable, so entry renames are free.

## Notes & limitations

- `LivePalette.*` constants are a **snapshot** (regenerated on every palette save). If
  you mutate the palette at runtime, read live values via `LivePaletteRuntime.color()`.
- Colors inside `Array`/`Dictionary` properties of resources are not walked (direct
  resource properties are).
- *Find Uses* scans saved **text** formats (`.tscn`, `.tres`, `.escn`, `.theme`);
  binary `.scn`/`.res` and unsaved changes are not seen.
- `.gpl` is an RGB format — alpha is flattened on export (RGBA import via Krita's
  `Channels: RGBA` variant is supported).
- Exports: the palette lives at `res://live_palette/palette.tres`; the default
  "export all resources" setting includes it automatically.
- The names `LivePalette`, `LivePaletteRuntime` and `LivePaletteData` must stay free in
  your project (Godot forbids an autoload sharing a name with a global class). The
  plugin detects collisions and reports them clearly instead of failing cryptically.

## License

[MIT](LICENSE) © Thiago Rocha
