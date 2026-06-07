# === menu_ui.gd ===
# Inventory and shop screens, styled as a budget marketplace. Use/equip items,
# buy from merchants, sell your junk at a tragic markdown.
class_name MenuUI
extends CanvasLayer

var _dim: ColorRect
var _panel: PanelContainer
var _title: Label
var _gold_label: Label
var _list: VBoxContainer
var _mode: String = ""  # "inv" | "shop"
var _stock: Array = []

func _ready() -> void:
	layer = 40
	_build()
	_close_now()
	Game.inventory_changed.connect(func(): if _mode != "": _populate())
	Game.gold_changed.connect(func(_g): if _gold_label: _gold_label.text = "%d G" % Game.gold)

func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.55)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -360; _panel.offset_right = 360
	_panel.offset_top = -260; _panel.offset_bottom = 260
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.11, 0.14, 0.98)
	sb.border_color = Color(1.0, 0.42, 0.18)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 18; sb.content_margin_right = 18
	sb.content_margin_top = 14; sb.content_margin_bottom = 14
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_panel.add_child(vb)

	var header := HBoxContainer.new()
	vb.add_child(header)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
	header.add_child(_title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 20)
	_gold_label.add_theme_color_override("font_color", Color(1, 0.84, 0.3))
	header.add_child(_gold_label)

	var sub := Label.new()
	sub.text = "Free shipping on orders over 9,999 G · Returns accepted within 0 days"
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(0.6, 0.65, 0.72))
	vb.add_child(sub)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(700, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	var hint := Label.new()
	hint.text = "[I] or [Esc] to close"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.6, 0.65, 0.72))
	vb.add_child(hint)

func open_inventory() -> void:
	_mode = "inv"
	_title.text = "🎒 Inventory"
	_show()

func open_shop(stock: Array) -> void:
	_mode = "shop"
	_stock = stock
	_title.text = "🛒 Temu Marketplace"
	_show()

func _show() -> void:
	Game.ui_open = true
	_dim.show(); _panel.show()
	_gold_label.text = "%d G" % Game.gold
	_populate()
	Audio.sfx("open", -6.0)

func close() -> void:
	_close_now()
	Game.ui_open = false

func _close_now() -> void:
	_mode = ""
	if _dim: _dim.hide()
	if _panel: _panel.hide()

func _clear() -> void:
	for c in _list.get_children():
		c.queue_free()

func _section(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	_list.add_child(l)

func _populate() -> void:
	_clear()
	if _mode == "inv":
		_section("Equipped: %s" % Game.item_def(Game.equipped_weapon).name)
		if Game.inventory.is_empty():
			_section("(empty — even the warehouse is out of stock)")
		for e in Game.inventory:
			_add_row(e.id, e.count, "inv")
	elif _mode == "shop":
		_section("— For Sale —")
		for id in _stock:
			_add_row(id, 1, "buy")
		_section("— Your Items (sell at 50%) —")
		for e in Game.inventory:
			_add_row(e.id, e.count, "sell")

func _add_row(id: String, count: int, kind: String) -> void:
	var d := Game.item_def(id)
	var row := PanelContainer.new()
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = Color(1, 1, 1, 0.04)
	rsb.set_corner_radius_all(6)
	rsb.content_margin_left = 8; rsb.content_margin_right = 8
	rsb.content_margin_top = 6; rsb.content_margin_bottom = 6
	row.add_theme_stylebox_override("panel", rsb)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_child(row)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	row.add_child(h)

	var icon := TextureRect.new()
	var ipath := "res://assets/items/%s.png" % d.get("icon", "book")
	if ResourceLoader.exists(ipath):
		icon.texture = load(ipath)
	icon.custom_minimum_size = Vector2(40, 40)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(info)
	var nm := Label.new()
	var cnt := "  x%d" % count if (kind != "buy" and count > 1) else ""
	nm.text = "%s%s   ⭐%.1f" % [d.name, cnt, d.get("rating", 1.0)]
	nm.add_theme_font_size_override("font_size", 16)
	info.add_child(nm)
	var ds := Label.new()
	ds.text = d.get("desc", "")
	ds.add_theme_font_size_override("font_size", 12)
	ds.add_theme_color_override("font_color", Color(0.65, 0.7, 0.78))
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ds.custom_minimum_size = Vector2(360, 0)
	info.add_child(ds)

	var btn := Button.new()
	btn.add_theme_font_size_override("font_size", 15)
	var val: int = int(d.get("value", 0))
	match kind:
		"inv":
			var t: String = d.get("type", "misc")
			if t == "weapon":
				btn.text = "Equipped" if id == Game.equipped_weapon else "Equip"
				btn.disabled = (id == Game.equipped_weapon)
				btn.pressed.connect(func(): _equip(id))
			elif t in ["potion", "food"]:
				btn.text = "Use"
				btn.pressed.connect(func(): _use(id))
			else:
				btn.text = "—"
				btn.disabled = true
		"buy":
			btn.text = "Buy %d G" % val
			btn.disabled = Game.gold < val
			btn.pressed.connect(func(): _buy(id, val))
		"sell":
			if Game.item_def(id).get("no_sell", false):
				btn.text = "CURSED — No Returns"
				btn.pressed.connect(func(): Game.beacon_boom())
			else:
				var sp: int = maxi(1, val / 2)
				btn.text = "Sell %d G" % sp
				btn.pressed.connect(func(): _sell(id, sp))
	h.add_child(btn)

func _equip(id: String) -> void:
	Game.equipped_weapon = id
	Game.notify.emit("Equipped %s" % Game.item_def(id).name, Color(0.8, 1, 0.8))
	Audio.sfx("confirm", -6.0)
	_populate()

func _use(id: String) -> void:
	var d := Game.item_def(id)
	if d.has("heal"):
		Game.health = minf(Game.max_health, Game.health + d.heal)
	if d.has("magicka"):
		Game.magicka = minf(Game.max_magicka, Game.magicka + d.magicka)
	if d.has("stamina"):
		Game.stamina = minf(Game.max_stamina, Game.stamina + d.stamina)
	Game.stats_changed.emit()
	Game.remove_item(id, 1)
	Audio.sfx("confirm", -6.0)
	_populate()

func _buy(id: String, price: int) -> void:
	if Game.spend_gold(price):
		Game.add_item(id, 1)
		Game.notify.emit("Purchased %s" % Game.item_def(id).name, Color(0.8, 1, 0.8))
		_populate()

func _sell(id: String, price: int) -> void:
	if Game.remove_item(id, 1):
		Game.add_gold(price)
		_populate()

func _unhandled_input(event: InputEvent) -> void:
	if _mode == "":
		# allow opening the bag from the field
		if event.is_action_pressed("inventory") and not Game.ui_open:
			get_viewport().set_input_as_handled()
			open_inventory()
		return
	if event.is_action_pressed("inventory") or event.is_action_pressed("ui_cancel_game"):
		get_viewport().set_input_as_handled()
		close()
