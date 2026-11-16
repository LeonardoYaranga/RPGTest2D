class_name InputHistory
extends Control
## MK11-style Input History Feed & Hit Counter widget.
## Displays real-time button presses (neutral, chained, dropped) on bottom-left,
## and a dynamic animated combo hit counter ("X HITS!").

@export var max_entries: int = 6
@export var fade_delay: float = 3.5

const COLOR_CHAINED := Color(0.25, 0.95, 0.45, 1.0)  # Neon green
const COLOR_NEUTRAL := Color(0.85, 0.88, 0.95, 0.9)  # White / gray
const COLOR_DROPPED := Color(1.0, 0.35, 0.35, 1.0)   # Vivid red
const BG_CHAINED := Color(0.08, 0.35, 0.15, 0.85)
const BG_NEUTRAL := Color(0.12, 0.15, 0.22, 0.80)
const BG_DROPPED := Color(0.40, 0.10, 0.12, 0.85)

@onready var feed_vbox: VBoxContainer = $Margin/HBox/FeedContainer/FeedVBox
@onready var combo_counter: VBoxContainer = $Margin/HBox/ComboCounter
@onready var hits_label: Label = $Margin/HBox/ComboCounter/HitsLabel
@onready var damage_label: Label = $Margin/HBox/ComboCounter/DamageLabel

var _fade_timer: float = 0.0
var _combo_decay_timer: float = 0.0
var _entries: Array[PanelContainer] = []


func _ready() -> void:
	if combo_counter:
		combo_counter.modulate.a = 0.0
	SignalHub.combo_input_logged.connect(_on_combo_input_logged)
	SignalHub.combo_hit_scored.connect(_on_combo_hit_scored)
	SignalHub.combo_dropped.connect(_on_combo_dropped)


func _process(delta: float) -> void:
	if _fade_timer > 0.0:
		_fade_timer = maxf(0.0, _fade_timer - delta)
		if _fade_timer <= 0.8 and feed_vbox:
			feed_vbox.modulate.a = _fade_timer / 0.8

	if _combo_decay_timer > 0.0:
		_combo_decay_timer = maxf(0.0, _combo_decay_timer - delta)
		if _combo_decay_timer <= 0.4 and combo_counter:
			combo_counter.modulate.a = _combo_decay_timer / 0.4


func _on_combo_input_logged(token: String, action_name: String, status: String) -> void:
	_fade_timer = fade_delay
	if feed_vbox:
		feed_vbox.modulate.a = 1.0

	var row := _create_feed_entry(token, action_name, status)
	feed_vbox.add_child(row)
	_entries.append(row)

	while _entries.size() > max_entries:
		var old: PanelContainer = _entries.pop_front()
		if is_instance_valid(old):
			old.queue_free()


func _create_feed_entry(token: String, action_name: String, status: String) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2

	var text_color: Color = COLOR_NEUTRAL
	var bg_color: Color = BG_NEUTRAL

	match status:
		"CHAINED":
			text_color = COLOR_CHAINED
			bg_color = BG_CHAINED
			style.border_color = COLOR_CHAINED
			style.set_border_width_all(1)
		"DROPPED":
			text_color = COLOR_DROPPED
			bg_color = BG_DROPPED
			style.border_color = COLOR_DROPPED
			style.set_border_width_all(1)
		_:
			text_color = COLOR_NEUTRAL
			bg_color = BG_NEUTRAL
			style.border_color = Color(0.3, 0.35, 0.45, 0.5)
			style.set_border_width_all(1)

	style.bg_color = bg_color
	panel.add_theme_stylebox_override(&"panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override(&"separation", 6)
	panel.add_child(hbox)

	# Key Badge
	var key_badge := Label.new()
	key_badge.text = "[%s]" % token
	key_badge.add_theme_font_size_override(&"font_size", 11)
	key_badge.modulate = text_color
	hbox.add_child(key_badge)

	# Action label
	var act_label := Label.new()
	act_label.text = action_name.to_upper()
	act_label.add_theme_font_size_override(&"font_size", 10)
	act_label.modulate = Color(0.9, 0.92, 0.96, 0.85)
	hbox.add_child(act_label)

	# Status tag
	if status != "NEUTRAL":
		var tag := Label.new()
		tag.text = status
		tag.add_theme_font_size_override(&"font_size", 9)
		tag.modulate = text_color
		hbox.add_child(tag)

	return panel


func _on_combo_hit_scored(combo_hits: int, total_damage: int, _attack_id: StringName) -> void:
	if combo_counter == null or hits_label == null:
		return
	if combo_hits < 2:
		# 1 single hit can just start tracking or show quietly
		hits_label.text = "1 HIT"
	else:
		hits_label.text = "%d HITS!" % combo_hits

	if damage_label:
		damage_label.text = "%d DAMAGE" % total_damage

	combo_counter.modulate.a = 1.0
	_combo_decay_timer = 1.35

	# Punchy hit scale pop animation
	combo_counter.pivot_offset = combo_counter.size * 0.5
	var tween := create_tween()
	combo_counter.scale = Vector2(1.28, 1.28)
	tween.tween_property(combo_counter, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_combo_dropped(_reason: String) -> void:
	# Give player a brief window to see final combo stats before fading
	if _combo_decay_timer > 0.6:
		_combo_decay_timer = 0.6
