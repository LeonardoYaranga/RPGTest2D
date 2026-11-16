class_name PinnedCombos
extends Control
## MK11-style Pinned Combos widget for 2.5D beat 'em up training.
## Displays target combo strings, highlights active progress as buttons are pressed,
## and flashes green on successful combo completion.

const PINNED_LIST: Array[Dictionary] = [
	{
		"id": "triple_jab",
		"name": "Triple Jab",
		"sequence": ["H", "H", "H"],
		"finisher": "hook",
	},
	{
		"id": "kick_finisher",
		"name": "Kick Finisher",
		"sequence": ["H", "H", "K"],
		"finisher": "kick_finisher",
	},
	{
		"id": "air_launch",
		"name": "Sky Launcher",
		"sequence": ["H", "H", "H", "K"],
		"finisher": "kick_finisher_big",
	},
	{
		"id": "heavy_punch",
		"name": "Heavy Stagger",
		"sequence": ["J"],
		"finisher": "heavy",
	},
	{
		"id": "low_sweep",
		"name": "Low Sweep",
		"sequence": ["K"],
		"finisher": "kick",
	},
]

const COLOR_NORMAL := Color(0.72, 0.75, 0.82, 0.85)
const COLOR_ACTIVE := Color(1.0, 0.84, 0.2, 1.0)       # Bright gold
const COLOR_COMPLETE := Color(0.3, 1.0, 0.45, 1.0)     # Neon green
const COLOR_DROPPED := Color(1.0, 0.35, 0.35, 0.9)     # Soft red
const BADGE_BG_NORMAL := Color(0.12, 0.14, 0.20, 0.85)
const BADGE_BG_ACTIVE := Color(0.45, 0.35, 0.05, 0.95)
const BADGE_BG_COMPLETE := Color(0.08, 0.4, 0.15, 0.95)

@onready var combo_vbox: VBoxContainer = $Margin/VBox/ComboList

var _rows: Array[Dictionary] = []


func _ready() -> void:
	_build_ui()
	SignalHub.combo_buffer_changed.connect(_on_combo_buffer_changed)
	SignalHub.combo_completed.connect(_on_combo_completed)
	SignalHub.combo_dropped.connect(_on_combo_dropped)


func _build_ui() -> void:
	if combo_vbox == null:
		return
	for child in combo_vbox.get_children():
		child.queue_free()
	_rows.clear()

	for entry in PINNED_LIST:
		var row := _create_combo_row(entry)
		combo_vbox.add_child(row.container)
		_rows.append(row)


func _create_combo_row(entry: Dictionary) -> Dictionary:
	var row_panel := PanelContainer.new()
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0.06, 0.07, 0.11, 0.72)
	row_style.corner_radius_top_left = 4
	row_style.corner_radius_top_right = 4
	row_style.corner_radius_bottom_left = 4
	row_style.corner_radius_bottom_right = 4
	row_style.content_margin_left = 8
	row_style.content_margin_right = 8
	row_style.content_margin_top = 4
	row_style.content_margin_bottom = 4
	row_panel.add_theme_stylebox_override(&"panel", row_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override(&"separation", 8)
	row_panel.add_child(hbox)

	var name_label := Label.new()
	name_label.text = entry["name"]
	name_label.custom_minimum_size = Vector2(105, 0)
	name_label.add_theme_font_size_override(&"font_size", 12)
	name_label.modulate = COLOR_NORMAL
	hbox.add_child(name_label)

	var badges_box := HBoxContainer.new()
	badges_box.add_theme_constant_override(&"separation", 4)
	hbox.add_child(badges_box)

	var badge_panels: Array[PanelContainer] = []
	var seq: Array = entry["sequence"]
	for token in seq:
		var badge := PanelContainer.new()
		var b_style := StyleBoxFlat.new()
		b_style.bg_color = BADGE_BG_NORMAL
		b_style.border_color = Color(0.3, 0.35, 0.45, 0.7)
		b_style.set_border_width_all(1)
		b_style.set_corner_radius_all(3)
		b_style.content_margin_left = 5
		b_style.content_margin_right = 5
		b_style.content_margin_top = 1
		b_style.content_margin_bottom = 1
		badge.add_theme_stylebox_override(&"panel", b_style)

		var lbl := Label.new()
		lbl.text = String(token)
		lbl.add_theme_font_size_override(&"font_size", 11)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.modulate = COLOR_NORMAL
		badge.add_child(lbl)

		badges_box.add_child(badge)
		badge_panels.append(badge)

	var status_label := Label.new()
	status_label.text = ""
	status_label.add_theme_font_size_override(&"font_size", 11)
	status_label.modulate = COLOR_COMPLETE
	hbox.add_child(status_label)

	return {
		"id": entry["id"],
		"entry": entry,
		"container": row_panel,
		"name_label": name_label,
		"badge_panels": badge_panels,
		"status_label": status_label,
		"row_style": row_style,
	}


func _on_combo_buffer_changed(buffer: String, _attack_id: StringName) -> void:
	for row in _rows:
		var seq: Array = row["entry"]["sequence"]
		var seq_str := "".join(seq)

		if buffer != "" and seq_str.begins_with(buffer):
			row["name_label"].modulate = COLOR_ACTIVE
			for i in range(row["badge_panels"].size()):
				var badge: PanelContainer = row["badge_panels"][i]
				var b_lbl: Label = badge.get_child(0) as Label
				var b_style: StyleBoxFlat = badge.get_theme_stylebox(&"panel") as StyleBoxFlat
				if i < buffer.length():
					b_lbl.modulate = COLOR_ACTIVE
					if b_style:
						b_style.bg_color = BADGE_BG_ACTIVE
						b_style.border_color = COLOR_ACTIVE
				else:
					b_lbl.modulate = COLOR_NORMAL
					if b_style:
						b_style.bg_color = BADGE_BG_NORMAL
						b_style.border_color = Color(0.3, 0.35, 0.45, 0.7)
		else:
			row["name_label"].modulate = COLOR_NORMAL
			for badge in row["badge_panels"]:
				var b_lbl: Label = badge.get_child(0) as Label
				var b_style: StyleBoxFlat = badge.get_theme_stylebox(&"panel") as StyleBoxFlat
				b_lbl.modulate = COLOR_NORMAL
				if b_style:
					b_style.bg_color = BADGE_BG_NORMAL
					b_style.border_color = Color(0.3, 0.35, 0.45, 0.7)


func _on_combo_completed(buffer: String, _attack_id: StringName) -> void:
	for row in _rows:
		var seq_str := "".join(row["entry"]["sequence"])
		if seq_str == buffer:
			_flash_complete(row)
			break


func _flash_complete(row: Dictionary) -> void:
	var name_lbl: Label = row["name_label"]
	var status_lbl: Label = row["status_label"]
	name_lbl.modulate = COLOR_COMPLETE
	status_lbl.text = "✓ COMBO!"
	status_lbl.modulate = COLOR_COMPLETE

	for badge in row["badge_panels"]:
		var b_lbl: Label = badge.get_child(0) as Label
		var b_style: StyleBoxFlat = badge.get_theme_stylebox(&"panel") as StyleBoxFlat
		b_lbl.modulate = COLOR_COMPLETE
		if b_style:
			b_style.bg_color = BADGE_BG_COMPLETE
			b_style.border_color = COLOR_COMPLETE

	var tween := create_tween()
	tween.tween_interval(0.65)
	tween.tween_callback(func():
		status_lbl.text = ""
		_on_combo_buffer_changed("", &"")
	)


func _on_combo_dropped(_reason: String) -> void:
	_on_combo_buffer_changed("", &"")
