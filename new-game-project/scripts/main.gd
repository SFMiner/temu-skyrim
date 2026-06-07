# === main.gd ===
# Root flow controller: builds persistent UI (HUD / dialogue / menus), shows the
# title screen, runs the Temu-ified intro, loads the overworld, and handles
# global save/load + pause.
extends Node

var _hud: Hud
var _dialogue: DialogueUI
var _menu: MenuUI
var _world: Node = null
var _title: CanvasLayer = null
var _intro: CanvasLayer = null
var _pause: CanvasLayer = null

const INTRO_LINES := [
	"[Customs Wagon — outskirts of Helgen-Mart]",
	"Hey. You. You're finally awake.",
	"You tried to cross the border with a knockoff sword... walked right into that customs ambush.",
	"Same as us. And that dropshipper over there who wouldn't stop talking.",
	"We're all headed for the chopping block. Returns are FINAL. No refunds.",
	"...wait. What in Oblivion is that sound?",
	"DRAGON! Well — DraGON™. ONE STAR. RUN!",
	"(You flee in the chaos, escaping north to the town of Beigeton...)",
]

func _ready() -> void:
	randomize()
	# persistent UI lives above every screen
	_hud = Hud.new(); add_child(_hud); _hud.visible = false
	_dialogue = DialogueUI.new(); add_child(_dialogue)
	_menu = MenuUI.new(); add_child(_menu)
	Game.hud = _hud
	Game.dialogue = _dialogue
	Game.shop = _menu
	# Debug convenience: TEMU_AUTOSTART=1 boots straight into the overworld.
	if OS.has_environment("TEMU_DUNGEON_TEST"):
		Game._reset_run()
		_start_overworld()
		_dungeon_test_routine()
	elif OS.has_environment("TEMU_VERIFY_DUNGEON"):
		Game._reset_run()
		_start_overworld()
		_verify_dungeon_ready()
	elif OS.has_environment("TEMU_RESPAWN"):
		Game._reset_run()
		_start_overworld()
		_respawn_test_routine()
	elif OS.has_environment("TEMU_TEST"):
		Game._reset_run()
		_start_overworld()
		_test_routine()
	elif OS.has_environment("TEMU_SHOT"):
		Game._reset_run()
		_start_overworld()
		_shot_routine()
	elif OS.has_environment("TEMU_AUTOSTART"):
		Game._reset_run()
		_start_overworld()
	else:
		_show_title()

# Debug: kill every enemy, backdate their death, move the player to an empty
# corner, and confirm all spawn slots refill (regression test for respawning).
func _respawn_test_routine() -> void:
	await get_tree().create_timer(0.8).timeout
	var ow = _world
	var initial: int = ow._spawns.size()
	ow.player.global_position = Vector2(100, 100)
	for s in ow._spawns:
		if is_instance_valid(s.node):
			s.node.queue_free()
		s.dead_at = -100.0  # pretend it died long ago (well past RESPAWN_DELAY)
	await get_tree().process_frame
	await get_tree().process_frame
	var dead_now := 0
	for s in ow._spawns:
		if not is_instance_valid(s.node):
			dead_now += 1
	ow._respawn_t = 0.0
	await get_tree().create_timer(1.5).timeout
	var alive := 0
	for s in ow._spawns:
		if is_instance_valid(s.node):
			alive += 1
	print("RESPAWN TEST: slots=%d, killed=%d, refilled_alive=%d" % [initial, dead_now, alive])
	get_tree().quit()

# Debug: simulate walking up to a villager and pressing E, to verify the
# single-line dialogue opens AND stays open (regression test for the input bug).
func _test_routine() -> void:
	await get_tree().create_timer(1.0).timeout
	var v: Node = null
	for n in get_tree().get_nodes_in_group("npc"):
		if n.npc_name in ["Sigrid", "Ysolda"]:
			v = n; break
	if v == null:
		print("TEST: no villager found"); get_tree().quit(); return
	v.can_wander = false
	_world.player.global_position = v.global_position + Vector2(22, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_press("interact")
	await get_tree().process_frame
	await get_tree().process_frame
	print("TEST after 1st E -> ui_open=%s dialogue_active=%s text='%s'" % [Game.ui_open, _dialogue.is_active(), _dialogue._text_label.text])
	_release("interact")
	await get_tree().process_frame
	_press("interact")
	await get_tree().process_frame
	await get_tree().process_frame
	print("TEST after 2nd E -> ui_open=%s dialogue_active=%s (expect closed)" % [Game.ui_open, _dialogue.is_active()])
	get_tree().quit()

# Debug: test the dungeon flow - enter cave, spawn in dungeon, check draugr exist, exit
func _dungeon_test_routine() -> void:
	var results := []
	results.append("=== DUNGEON TEST START ===")

	await get_tree().create_timer(0.8).timeout
	var ow = _world
	var player = ow.player
	if not player:
		results.append("FAIL: no player in overworld")
		_write_test_results(results)
		get_tree().quit()
		return

	# Move player to cave entrance
	var cave_pos := Vector2(2800, 800)
	player.global_position = cave_pos + Vector2(0, 40)
	await get_tree().physics_frame

	# Find cave entrance in interactable group
	var cave_entrance = null
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is Interactable and n.global_position.distance_to(cave_pos + Vector2(0, 40)) < 5.0:
			cave_entrance = n
			break

	if cave_entrance == null:
		results.append("FAIL: cave entrance not found")
		_write_test_results(results)
		get_tree().quit()
		return

	results.append("✓ Cave entrance found")
	cave_entrance.interact(player)
	await get_tree().create_timer(0.5).timeout

	# Check if we transitioned to dungeon
	var dungeon = _world
	var dungeon_player = dungeon.player if dungeon else null
	if dungeon_player == null:
		results.append("FAIL: player not in dungeon")
		_write_test_results(results)
		get_tree().quit()
		return

	results.append("✓ Entered dungeon, player at %s" % dungeon_player.global_position)

	# Check if draugr enemies exist
	var draugr_count = 0
	for n in get_tree().get_nodes_in_group("enemies"):
		if n.display_name and n.display_name == "Draugr":
			draugr_count += 1

	results.append("✓ Found %d draugr enemies" % draugr_count)
	if draugr_count == 0:
		results.append("WARN: Expected at least 1 draugr")

	# Check for interactive objects
	var interactables = get_tree().get_nodes_in_group("interactable")
	var chest_count = 0
	var portal_count = 0
	for n in interactables:
		if n is Interactable:
			var dist_to_chest = n.global_position.distance_to(Vector2(1300, 300))
			var dist_to_portal = n.global_position.distance_to(Vector2(800, 100))
			if dist_to_chest < 10:
				chest_count += 1
			if dist_to_portal < 10:
				portal_count += 1

	results.append("✓ Found %d chest, %d exit portal" % [chest_count, portal_count])

	# Find and interact with exit portal
	var exit_portal = null
	for n in interactables:
		if n is Interactable and n.global_position.distance_to(Vector2(800, 100)) < 10:
			exit_portal = n
			break

	if exit_portal == null:
		results.append("FAIL: exit portal not found")
		_write_test_results(results)
		get_tree().quit()
		return

	results.append("✓ Exit portal found, exiting dungeon...")
	exit_portal.interact(dungeon_player)
	await get_tree().create_timer(0.5).timeout

	# Check if we returned to overworld
	var new_overworld = _world
	var new_overworld_player = new_overworld.player if new_overworld else null
	if new_overworld_player == null:
		results.append("FAIL: player not back in overworld")
		_write_test_results(results)
		get_tree().quit()
		return

	results.append("✓ Returned to overworld, player at %s" % new_overworld_player.global_position)
	results.append("=== DUNGEON TEST PASSED ===")
	_write_test_results(results)
	get_tree().quit()

func _verify_dungeon_ready() -> void:
	await get_tree().create_timer(1.0).timeout

	var results := ["=== DUNGEON VERIFICATION ==="]

	# Check overworld loaded
	if _world and _world.get_script().get_path() == "res://scripts/overworld.gd":
		results.append("✓ Overworld loaded")
	else:
		results.append("✗ Overworld not loaded")

	# Check player in overworld
	var ow_player = _world.player if _world else null
	if ow_player:
		results.append("✓ Player in overworld at %s" % ow_player.global_position)
	else:
		results.append("✗ No player in overworld")

	# Check cave entrance exists
	var cave_found = false
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is Interactable and n.global_position.distance_to(Vector2(2800, 840)) < 50:
			cave_found = true
			results.append("✓ Cave entrance found at %s" % n.global_position)
			break
	if not cave_found:
		results.append("✗ Cave entrance not found")

	# Check all required assets exist
	var assets_ok = true
	for asset in ["res://assets/props/cave.png", "res://assets/audio/ambient_dungeon.mp3", "res://assets/props/word_wall.png"]:
		if not ResourceLoader.exists(asset):
			results.append("✗ Missing asset: %s" % asset)
			assets_ok = false
	if assets_ok:
		results.append("✓ All dungeon assets present")

	# Check draugr sprites exist
	var draugr_ok = true
	for anim in ["idle", "walk", "slash", "hurt", "spellcast", "thrust"]:
		if not ResourceLoader.exists("res://assets/chars/draugr_%s.png" % anim):
			results.append("✗ Missing draugr animation: %s" % anim)
			draugr_ok = false
	if draugr_ok:
		results.append("✓ All draugr animations present")

	results.append("=== READY TO TEST DUNGEON ===")
	_write_test_results(results)
	get_tree().quit()

func _write_test_results(results: Array) -> void:
	var output = "\n".join(results)
	# Print all results to console
	for line in results:
		print(line)
	# Try multiple paths
	for path in ["res://dungeon_test_results.txt", "user://dungeon_test_results.txt"]:
		var file = FileAccess.open(path, FileAccess.WRITE)
		if file:
			file.store_string(output)
			print("Test results written to: " + path)
			break

func _press(action: String) -> void:
	var e := InputEventAction.new(); e.action = action; e.pressed = true
	Input.parse_input_event(e)

func _release(action: String) -> void:
	var e := InputEventAction.new(); e.action = action; e.pressed = false
	Input.parse_input_event(e)

# Debug: render a few screenshots then quit (run with a real renderer).
func _shot_routine() -> void:
	await get_tree().create_timer(1.4).timeout
	await RenderingServer.frame_post_draw
	_save_shot("shot1_town")
	# dragon
	Game.set_quest("main", 1)
	if _world and _world.player:
		_world.player.global_position = _world.LAIR + Vector2(0, 230)
	await get_tree().create_timer(1.6).timeout
	await RenderingServer.frame_post_draw
	_save_shot("shot2_dragon")
	# bandit camp
	if _world and _world.player:
		_world.player.global_position = _world.CAMP + Vector2(0, 170)
	await get_tree().create_timer(1.4).timeout
	await RenderingServer.frame_post_draw
	_save_shot("shot3_camp")
	get_tree().quit()

func _save_shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://%s.png" % name)

# === TITLE ===
func _show_title() -> void:
	Game.ui_open = true
	_title = CanvasLayer.new()
	_title.layer = 80
	add_child(_title)
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.09, 0.14)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.add_child(bg)
	_title_snow(_title)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -300; box.offset_right = 300; box.offset_top = -200; box.offset_bottom = 200
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	_title.add_child(box)

	var logo := TextureRect.new()
	if ResourceLoader.exists("res://assets/ui/temu_logo.png"):
		logo.texture = load("res://assets/ui/temu_logo.png")
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(0, 60)
	box.add_child(logo)

	var title := Label.new()
	title.text = "TEMU SKYRIM"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 6)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var tag := Label.new()
	tag.text = "THE ELDER SCROLLS V: but it shipped from a 1-star seller\nFREE SHIPPING ON ALL SHOUTS"
	tag.add_theme_font_size_override("font_size", 16)
	tag.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tag)

	box.add_child(_spacer(20))
	var new_btn := _menu_button("⚔  New Game")
	new_btn.pressed.connect(_new_game)
	box.add_child(new_btn)
	if Game.has_save():
		var cont := _menu_button("☁  Continue (from cloud)")
		cont.pressed.connect(_continue_game)
		box.add_child(cont)
	var quit := _menu_button("✕  Quit")
	quit.pressed.connect(func(): get_tree().quit())
	box.add_child(quit)

	var credit := Label.new()
	credit.text = "One-shot built by Claude Opus 4.8 · sprites via natural-language LPC generator"
	credit.add_theme_font_size_override("font_size", 12)
	credit.add_theme_color_override("font_color", Color(0.5, 0.55, 0.62))
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(credit)

func _title_snow(parent: CanvasLayer) -> void:
	var snow := CPUParticles2D.new()
	snow.texture = load("res://assets/fx/snow.png") if ResourceLoader.exists("res://assets/fx/snow.png") else null
	snow.amount = 120
	snow.lifetime = 6.0
	snow.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	snow.emission_rect_extents = Vector2(700, 10)
	snow.position = Vector2(640, -20)
	snow.gravity = Vector2(10, 40)
	snow.initial_velocity_min = 20.0
	snow.initial_velocity_max = 50.0
	snow.modulate = Color(1, 1, 1, 0.6)
	parent.add_child(snow)

func _menu_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 22)
	b.custom_minimum_size = Vector2(280, 44)
	return b

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

# === GAME START ===
func _new_game() -> void:
	Game._reset_run()
	if _title: _title.queue_free(); _title = null
	_play_intro()

func _continue_game() -> void:
	Game.load_game()
	if _title: _title.queue_free(); _title = null
	_start_overworld()

func _play_intro() -> void:
	Game.ui_open = true
	_intro = CanvasLayer.new()
	_intro.layer = 80
	add_child(_intro)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.03)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_intro.add_child(bg)

	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.offset_left = -440; label.offset_right = 440; label.offset_top = -120; label.offset_bottom = 120
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color(0.9, 0.92, 0.96))
	_intro.add_child(label)

	var hint := Label.new()
	hint.text = "[E / Space] to continue   ·   [Esc] to skip"
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -40
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.55, 0.6, 0.68))
	_intro.add_child(hint)

	_intro.set_meta("idx", 0)
	_intro.set_meta("label", label)
	_intro_show()

func _intro_show() -> void:
	var idx: int = _intro.get_meta("idx")
	var label: Label = _intro.get_meta("label")
	if idx >= INTRO_LINES.size():
		_finish_intro()
		return
	label.text = INTRO_LINES[idx]
	label.modulate.a = 0.0
	var tw := label.create_tween()
	tw.tween_property(label, "modulate:a", 1.0, 0.6)
	if idx == 6:
		Audio.sfx("dragon_roar", 3.0)

func _finish_intro() -> void:
	if _intro:
		_intro.queue_free(); _intro = null
	_start_overworld()

func _start_overworld() -> void:
	if _world and is_instance_valid(_world):
		_world.queue_free()
	_world = Node2D.new()
	_world.set_script(load("res://scripts/overworld.gd"))
	add_child(_world)
	_hud.visible = true
	Game.ui_open = false

func _load_dungeon(exit_pos: Vector2) -> void:
	if _world and is_instance_valid(_world):
		_world.queue_free()
	_world = Node2D.new()
	_world.set_script(load("res://scripts/dungeon.gd"))
	add_child(_world)
	_world.set_meta("overworld_exit_pos", exit_pos)
	Game.ui_open = false

func _load_overworld_from_dungeon() -> void:
	_start_overworld()

# === GLOBAL INPUT: save / load / pause / intro ===
func _unhandled_input(event: InputEvent) -> void:
	# intro paging
	if _intro:
		if event.is_action_pressed("interact") or event.is_action_pressed("attack") or event.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled()
			_intro.set_meta("idx", int(_intro.get_meta("idx")) + 1)
			_intro_show()
		elif event.is_action_pressed("ui_cancel_game"):
			get_viewport().set_input_as_handled()
			_finish_intro()
		return
	if _title:
		return
	# save / load
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F5 and not Game.ui_open:
			get_viewport().set_input_as_handled()
			Game.save_game()
		elif event.keycode == KEY_F9:
			get_viewport().set_input_as_handled()
			if Game.load_game():
				Game.notify.emit("Loaded from cloud.", Color(0.7, 1, 0.7))
	# pause
	if event.is_action_pressed("ui_cancel_game") and _world and not Game.ui_open:
		get_viewport().set_input_as_handled()
		_toggle_pause()

func _toggle_pause() -> void:
	if _pause and is_instance_valid(_pause):
		_pause.queue_free(); _pause = null
		Game.ui_open = false
		return
	Game.ui_open = true
	_pause = CanvasLayer.new()
	_pause.layer = 70
	add_child(_pause)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -140; box.offset_right = 140; box.offset_top = -120; box.offset_bottom = 120
	box.add_theme_constant_override("separation", 12)
	_pause.add_child(box)
	var t := Label.new()
	t.text = "PAUSED"
	t.add_theme_font_size_override("font_size", 36)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var resume := _menu_button("Resume")
	resume.pressed.connect(_toggle_pause)
	box.add_child(resume)
	var save := _menu_button("Save Game")
	save.pressed.connect(func(): Game.save_game())
	box.add_child(save)
	var menu := _menu_button("Main Menu")
	menu.pressed.connect(func():
		_pause.queue_free(); _pause = null
		if _world: _world.queue_free(); _world = null
		_hud.visible = false
		_show_title())
	box.add_child(menu)
