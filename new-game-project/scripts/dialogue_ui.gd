# === dialogue_ui.gd ===
# Bottom-of-screen dialogue box with a speaker name, paged lines, and optional
# choice buttons. Blocks gameplay input via Game.ui_open while open.
class_name DialogueUI
extends CanvasLayer

var _panel: PanelContainer
var _name_label: Label
var _text_label: RichTextLabel
var _hint: Label
var _choice_box: VBoxContainer
var _lines: Array = []
var _idx: int = 0
var _choices: Array = []
var _active: bool = false

func _ready() -> void:
	layer = 50
	_build()
	hide_box()

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = 40; _panel.offset_right = -40
	_panel.offset_top = -210; _panel.offset_bottom = -24
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.11, 0.14, 0.96)
	sb.border_color = Color(1.0, 0.42, 0.18)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 18; sb.content_margin_right = 18
	sb.content_margin_top = 12; sb.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", sb)
	root.add_child(_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_panel.add_child(vb)

	_name_label = Label.new()
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.62, 0.3))
	_name_label.add_theme_font_size_override("font_size", 22)
	vb.add_child(_name_label)

	_text_label = RichTextLabel.new()
	_text_label.fit_content = true
	_text_label.bbcode_enabled = true
	_text_label.scroll_active = false
	_text_label.custom_minimum_size = Vector2(0, 90)
	_text_label.add_theme_font_size_override("normal_font_size", 19)
	vb.add_child(_text_label)

	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 4)
	vb.add_child(_choice_box)

	_hint = Label.new()
	_hint.text = "[E / Space] continue"
	_hint.add_theme_color_override("font_color", Color(0.6, 0.65, 0.72))
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vb.add_child(_hint)

func start(speaker: String, lines: Array, choices: Array = []) -> void:
	_lines = lines.duplicate()
	_choices = choices
	_idx = 0
	_active = true
	Game.ui_open = true
	_name_label.text = speaker
	_clear_choices()
	_panel.show()
	_show_line()
	Audio.sfx("open", -8.0)

func _show_line() -> void:
	if _idx < _lines.size():
		_text_label.text = str(_lines[_idx])
		_hint.show()
	else:
		_present_choices()

func _present_choices() -> void:
	if _choices.is_empty():
		close()
		return
	_text_label.text = _lines.back() if _lines.size() > 0 else ""
	_hint.hide()
	for c in _choices:
		var b := Button.new()
		b.text = "  " + str(c.get("text", "..."))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 18)
		var act: Callable = c.get("action", Callable())
		b.pressed.connect(func() -> void:
			Audio.sfx("confirm", -6.0)
			close()
			if act.is_valid():
				act.call())
		_choice_box.add_child(b)

func _clear_choices() -> void:
	for ch in _choice_box.get_children():
		ch.queue_free()

func close() -> void:
	_active = false
	Game.ui_open = false
	_clear_choices()
	hide_box()

func hide_box() -> void:
	if _panel:
		_panel.hide()

func is_active() -> bool:
	return _active

func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if not _choices.is_empty() and _idx >= _lines.size():
		return  # waiting on a choice click
	if event.is_action_pressed("interact") or event.is_action_pressed("attack") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_idx += 1
		_show_line()
	elif event.is_action_pressed("ui_cancel_game"):
		get_viewport().set_input_as_handled()
		if _choices.is_empty():
			close()
