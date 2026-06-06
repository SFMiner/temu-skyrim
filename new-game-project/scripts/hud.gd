# === hud.gd ===
# Heads-up display: health/magicka/stamina bars, level + gold, an active-quest
# tracker, a boss health bar, and a toast feed for Game.notify messages.
class_name Hud
extends CanvasLayer

var _hp_fill: ColorRect
var _mp_fill: ColorRect
var _sp_fill: ColorRect
var _hp_text: Label
var _mp_text: Label
var _sp_text: Label
var _level_label: Label
var _gold_label: Label
var _quest_label: RichTextLabel
var _toast_box: VBoxContainer
var _boss_panel: PanelContainer
var _boss_fill: ColorRect
var _boss_name: Label
var _shout_label: Label

const BAR_W := 230.0

func _ready() -> void:
	layer = 20
	_build()
	Game.stats_changed.connect(_refresh)
	Game.gold_changed.connect(func(_g): _refresh())
	Game.leveled_up.connect(func(_l): _refresh())
	Game.quest_updated.connect(func(_q): _refresh_quests())
	Game.notify.connect(_toast)
	Game.shout_unlocked.connect(_refresh)
	_refresh()
	_refresh_quests()

func _make_bar(parent: Node, color: Color) -> Array:
	var bg := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.09, 0.85)
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(2)
	sb.border_color = Color(0, 0, 0, 0.6)
	bg.add_theme_stylebox_override("panel", sb)
	bg.custom_minimum_size = Vector2(BAR_W, 22)
	parent.add_child(bg)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(BAR_W, 22)
	bg.add_child(holder)
	var fill := ColorRect.new()
	fill.color = color
	fill.position = Vector2(2, 2)
	fill.size = Vector2(BAR_W - 4, 18)
	holder.add_child(fill)
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.position = Vector2(8, 2)
	holder.add_child(lbl)
	return [fill, lbl]

func _build() -> void:
	# --- top-left: title + bars ---
	var left := VBoxContainer.new()
	left.position = Vector2(18, 14)
	left.add_theme_constant_override("separation", 4)
	add_child(left)

	var title := Label.new()
	title.text = "TEMU SKYRIM"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.45, 0.2))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("outline_size", 4)
	left.add_child(title)

	var hp := _make_bar(left, Color(0.78, 0.18, 0.18))
	_hp_fill = hp[0]; _hp_text = hp[1]
	var mp := _make_bar(left, Color(0.2, 0.45, 0.85))
	_mp_fill = mp[0]; _mp_text = mp[1]
	var sp := _make_bar(left, Color(0.25, 0.7, 0.35))
	_sp_fill = sp[0]; _sp_text = sp[1]

	var info := HBoxContainer.new()
	info.add_theme_constant_override("separation", 16)
	left.add_child(info)
	_level_label = _mini_label("Lv 1")
	_gold_label = _mini_label("0 G")
	_gold_label.add_theme_color_override("font_color", Color(1, 0.84, 0.3))
	info.add_child(_level_label)
	info.add_child(_gold_label)

	_shout_label = _mini_label("")
	_shout_label.add_theme_color_override("font_color", Color(0.8, 0.92, 1.0))
	left.add_child(_shout_label)

	# --- top-right: quest tracker ---
	var qpanel := PanelContainer.new()
	qpanel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	qpanel.offset_left = -320; qpanel.offset_right = -16
	qpanel.offset_top = 14; qpanel.offset_bottom = 130
	var qsb := StyleBoxFlat.new()
	qsb.bg_color = Color(0.08, 0.09, 0.12, 0.8)
	qsb.set_corner_radius_all(6)
	qsb.border_color = Color(1.0, 0.45, 0.2, 0.7)
	qsb.set_border_width_all(2)
	qsb.content_margin_left = 10; qsb.content_margin_right = 10
	qsb.content_margin_top = 8; qsb.content_margin_bottom = 8
	qpanel.add_theme_stylebox_override("panel", qsb)
	add_child(qpanel)
	_quest_label = RichTextLabel.new()
	_quest_label.bbcode_enabled = true
	_quest_label.fit_content = true
	_quest_label.scroll_active = false
	_quest_label.add_theme_font_size_override("normal_font_size", 14)
	qpanel.add_child(_quest_label)

	# --- top-center: boss bar ---
	_boss_panel = PanelContainer.new()
	_boss_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss_panel.offset_left = -200; _boss_panel.offset_right = 200
	_boss_panel.offset_top = 16; _boss_panel.offset_bottom = 56
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.06, 0.07, 0.09, 0.9)
	bsb.set_corner_radius_all(4)
	bsb.border_color = Color(0.8, 0.2, 0.15)
	bsb.set_border_width_all(2)
	_boss_panel.add_theme_stylebox_override("panel", bsb)
	add_child(_boss_panel)
	var bh := Control.new()
	bh.custom_minimum_size = Vector2(400, 30)
	_boss_panel.add_child(bh)
	_boss_fill = ColorRect.new()
	_boss_fill.color = Color(0.7, 0.15, 0.12)
	_boss_fill.position = Vector2(2, 18)
	_boss_fill.size = Vector2(396, 10)
	bh.add_child(_boss_fill)
	_boss_name = Label.new()
	_boss_name.add_theme_font_size_override("font_size", 15)
	_boss_name.add_theme_color_override("font_color", Color.WHITE)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name.size = Vector2(400, 16)
	bh.add_child(_boss_name)
	_boss_panel.visible = false

	# --- toasts (center) ---
	_toast_box = VBoxContainer.new()
	_toast_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_box.offset_left = -300; _toast_box.offset_right = 300
	_toast_box.offset_top = 90
	_toast_box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_toast_box)

	# --- controls hint bottom-right ---
	var hint := Label.new()
	hint.text = "WASD move · J/LMB attack · K/RMB magic · Q shout · E talk · I bag · F5 save"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.7, 0.74, 0.8, 0.8))
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	hint.add_theme_constant_override("outline_size", 3)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -26
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)

func _mini_label(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 3)
	return l

func _process(_delta: float) -> void:
	_update_boss()

func _refresh() -> void:
	_hp_fill.size.x = (BAR_W - 4) * clampf(Game.health / Game.max_health, 0, 1)
	_mp_fill.size.x = (BAR_W - 4) * clampf(Game.magicka / Game.max_magicka, 0, 1)
	_sp_fill.size.x = (BAR_W - 4) * clampf(Game.stamina / Game.max_stamina, 0, 1)
	_hp_text.text = "HP %d/%d" % [int(Game.health), int(Game.max_health)]
	_mp_text.text = "MP %d/%d" % [int(Game.magicka), int(Game.max_magicka)]
	_sp_text.text = "SP %d/%d" % [int(Game.stamina), int(Game.max_stamina)]
	_level_label.text = "Lv %d  (XP %d/%d)" % [Game.level, Game.xp, Game.xp_next]
	_gold_label.text = "%d G" % Game.gold
	_shout_label.text = ("Thu'um: FUS RO DAH [Q]" if Game.known_shout else "")

func _refresh_quests() -> void:
	var lines := "[b]Quests[/b]\n"
	var q := Game.quests
	if q.get("main", 0) == 1:
		lines += "• DraGON™ Returns: slay the dragon north of town\n"
	elif q.get("main", 0) == 2:
		lines += "• DraGON™ Returns: report to the Jarl\n"
	elif q.get("main", 0) == 3:
		lines += "• [color=#88dd88]DraGON™ Returns — COMPLETE[/color]\n"
	if q.get("sweetroll", 0) == 1:
		lines += "• The Sweetroll Heist: recover the stolen sweetroll\n"
	elif q.get("sweetroll", 0) == 3:
		lines += "• [color=#88dd88]The Sweetroll Heist — COMPLETE[/color]\n"
	if q.get("freetrial", 0) == 1:
		lines += "• Free Trial: bring the merchant 3 wolf pelts\n"
	if lines.strip_edges().ends_with("Quests[/b]"):
		lines += "[color=#888888](none active)[/color]"
	_quest_label.text = lines

func _update_boss() -> void:
	var bosses := get_tree().get_nodes_in_group("boss")
	if bosses.size() > 0 and is_instance_valid(bosses[0]):
		var b = bosses[0]
		_boss_panel.visible = true
		_boss_name.text = str(b.display_name)
		_boss_fill.size.x = 396 * clampf(b.hp / b.max_hp, 0, 1)
	else:
		_boss_panel.visible = false

func _toast(text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_box.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)
