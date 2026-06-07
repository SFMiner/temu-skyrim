# === dungeon.gd ===
# A stone dungeon filled with draugr—ancient undead enemies. Built entirely in
# code: stone tile floors, walls with torches, an interactive chest, a word wall
# for lore, and an exit portal back to the overworld.
extends Node2D

const WORLD := Vector2(1600, 1200)
const PLAYER_SPAWN := Vector2(800, 1000)
const EXIT := Vector2(800, 100)

var player: Player
var overworld_exit_pos: Vector2 = Vector2.ZERO

# --- enemy respawn manager (same as overworld) ---
const RESPAWN_DELAY := 20.0
const RESPAWN_MIN_DIST := 400.0
var _spawns: Array = []
var _respawn_t: float = 0.0

func _ready() -> void:
	y_sort_enabled = true
	Game.world = self
	_build_ground()
	_build_walls()
	_build_torches()
	_build_chest()
	_build_word_wall()
	_build_exit_portal()
	_spawn_draugr()
	_spawn_spiders()
	_spawn_lair()
	_spawn_player()
	Audio.stop_music()
	Audio.play_ambient("ambient_dungeon")
	Game.notify.emit("You enter the depths. Ancient tombs lie ahead.", Color(0.8, 0.7, 1.0))

# === GROUND & WALLS ===
func _build_ground() -> void:
	var gnd := Sprite2D.new()
	gnd.texture = load("res://assets/env/tile_stone.png")
	gnd.centered = false
	gnd.region_enabled = true
	gnd.region_rect = Rect2(0, 0, WORLD.x, WORLD.y)
	gnd.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	gnd.z_index = -100
	add_child(gnd)

func _build_walls() -> void:
	# Top wall
	for x in range(0, int(WORLD.x), 64):
		_wall(Vector2(x, -64))
	# Bottom wall
	for x in range(0, int(WORLD.x), 64):
		_wall(Vector2(x, WORLD.y))
	# Left wall
	for y in range(0, int(WORLD.y), 64):
		_wall(Vector2(-64, y))
	# Right wall
	for y in range(0, int(WORLD.y), 64):
		_wall(Vector2(WORLD.x + 64, y))
	# Add some interior walls for maze-like layout
	_wall_h(Vector2(400, 300), 6)
	_wall_v(Vector2(1200, 500), 5)
	_wall_h(Vector2(200, 800), 8)

func _wall(pos: Vector2) -> void:
	var w := Sprite2D.new()
	w.texture = load("res://assets/env/tile_dwall.png")
	w.centered = true
	w.position = pos
	w.z_index = -90
	add_child(w)
	# solid collision
	var body := StaticBody2D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	body.position = pos
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(64, 64)
	col.shape = shape
	body.add_child(col)
	add_child(body)

func _wall_h(start: Vector2, count: int) -> void:
	for i in count:
		_wall(start + Vector2(i * 64, 0))

func _wall_v(start: Vector2, count: int) -> void:
	for i in count:
		_wall(start + Vector2(0, i * 64))

# === TORCHES WITH GLOW ===
func _build_torches() -> void:
	for tp in [
		Vector2(200, 150),
		Vector2(1400, 150),
		Vector2(200, 1050),
		Vector2(1400, 1050),
		Vector2(800, 350),
	]:
		_torch(tp)

func _torch(pos: Vector2) -> void:
	var torch_spr := Sprite2D.new()
	torch_spr.texture = load("res://assets/props/torch.png")
	torch_spr.centered = true
	torch_spr.position = pos
	torch_spr.z_index = 10
	add_child(torch_spr)
	# glow halo
	var glow := Sprite2D.new()
	glow.texture = load("res://assets/fx/glow.png")
	glow.centered = true
	glow.position = pos
	glow.z_index = 5
	glow.modulate = Color(1.0, 0.8, 0.5, 0.5)
	glow.scale = Vector2(1.2, 1.2)
	add_child(glow)

# === HELPER: create interactable object ===
func _make_interactable(pos: Vector2, obj_name: String, callback: Callable, sprite_asset: String = "chest", radius: float = 24.0) -> Interactable:
	var obj := Interactable.new()
	obj.name = obj_name
	obj.position = pos
	obj.add_to_group("interactable")
	obj.on_interact = callback
	var spr := Sprite2D.new()
	spr.texture = load("res://assets/props/%s.png" % sprite_asset)
	spr.centered = true
	obj.add_child(spr)
	var col := Area2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	var col_shape := CollisionShape2D.new()
	col_shape.shape = shape
	col.add_child(col_shape)
	obj.add_child(col)
	return obj

# === INTERACTIVE OBJECTS ===
func _build_chest() -> void:
	var chest := _make_interactable(Vector2(1300, 300), "chest", func(_p): _open_chest())
	add_child(chest)

func _open_chest() -> void:
	if not Game.flags.get("dungeon_chest_opened", false):
		Game.flags["dungeon_chest_opened"] = true
		Game.add_item("dragonbone_sword", 1)
		Game.add_item("health_potion", 2)
		Game.add_gold(100)
		Game.notify.emit("Chest opened! Found dragonbone sword and gold.", Color(1.0, 0.9, 0.5))
	else:
		Game.notify.emit("The chest is already empty.", Color(0.7, 0.7, 0.7))

func _build_word_wall() -> void:
	var wall := _make_interactable(Vector2(400, 150), "word_wall", func(_p): _read_word_wall(), "word_wall", 32.0)
	add_child(wall)

func _read_word_wall() -> void:
	Game.dialogue.start("Word Wall", [
		"The stone is covered in ancient runes, glowing with a faint blue light.",
		"[i]FUS RO DAH[/i] — The Voice of a Thousand Dragons.",
		"By absorbing the soul of DraGON™, you may learn to harness this power.",
	])

# === EXIT PORTAL ===
func _build_exit_portal() -> void:
	var portal = _make_interactable(EXIT, "portal", func(_p): _exit_dungeon(), "word_wall", 28.0)
	var portal_spr = portal.get_child(0)
	portal_spr.modulate = Color(0.3, 0.6, 1.0)
	portal_spr.scale = Vector2(0.8, 0.8)
	add_child(portal)

func _exit_dungeon() -> void:
	# Store the player position before exiting (for respawn near cave entrance)
	var exit_pos = Vector2(2800, 800) if not player else player.global_position
	var main = get_parent()
	if main and main.has_method("_load_overworld_from_dungeon"):
		main.set_meta("dungeon_exit_pos", exit_pos)
		main._load_overworld_from_dungeon()
		if main._world and main._world.player:
			main._world.player.global_position = exit_pos

# === DRAUGR SPAWNING ===
func _spawn_draugr() -> void:
	var positions: Array[Vector2] = [
		Vector2(600, 500),
		Vector2(900, 600),
		Vector2(400, 700),
		Vector2(1200, 400),
		Vector2(800, 300),
	]
	for pos in positions:
		_register_spawn(pos, _make_draugr)

func _make_draugr() -> Node:
	var d := HumanoidEnemy.new()
	d.char_name = "draugr"
	d.max_hp = 65.0
	d.damage = 13.0
	d.xp_reward = 50
	d.speed = 100.0
	d.display_name = "Draugr"
	d.gold_drop = randi_range(12, 25)
	d.loot = [
		{"id": "iron_sword", "chance": 0.2},
		{"id": "health_potion", "chance": 0.4},
		{"id": "draugr_dagger", "chance": 0.6},
	]
	return d

# === PLAYER ===
func _spawn_player() -> void:
	player = Player.new()
	player.position = PLAYER_SPAWN
	add_child(player)

# === RESPAWN SYSTEM (copied from overworld) ===
func _register_spawn(pos: Vector2, make: Callable) -> void:
	var node: Node = make.call()
	node.position = pos
	add_child(node)
	_spawns.append({"pos": pos, "make": make, "node": node, "dead_at": INF})

func _update_respawns(delta: float) -> void:
	_respawn_t -= delta
	if _respawn_t > 0.0:
		return
	_respawn_t = 1.0
	var now := float(Time.get_ticks_msec()) / 1000.0
	for s in _spawns:
		if is_instance_valid(s.node):
			continue
		if s.dead_at == INF:
			s.dead_at = now
		elif now - s.dead_at >= RESPAWN_DELAY:
			if player and player.global_position.distance_to(s.pos) > RESPAWN_MIN_DIST:
				var n: Node = s.make.call()
				n.position = s.pos
				add_child(n)
				s.node = n
				s.dead_at = INF

# === FROST SPIDER SPAWNING ===
# Frostbite spiders share the tomb with the draugr. They respawn like the others;
# stats live in Spider._build_visual, so here we only set drops.
func _spawn_spiders() -> void:
	for pos in [Vector2(300, 600), Vector2(1100, 700), Vector2(500, 400), Vector2(1300, 800)]:
		_register_spawn(pos, _make_spider)

func _make_spider() -> Node:
	var s := Spider.new()
	s.gold_drop = randi_range(5, 12)
	s.loot = [{"id": "health_potion", "chance": 0.3}]
	return s

# === GIANT SPIDER LAIR ===
# Deep in the tomb: Arvel the Swift, webbed up by the boss, plus the Giant
# Frostbite Spider™ that drops the Golden Dragon Claw. The boss is a one-shot
# spawn (gated by a flag) so it can't be farmed on repeat dungeon visits.
const LAIR := Vector2(650, 520)

func _spawn_lair() -> void:
	# Webbing chokes the whole chamber — evidence of the nest. Each web is a
	# distinct static frame (the sheet's frames sway, so animating them scrolls
	# sideways); a gentle alpha pulse gives an in-place glimmer instead.
	var webs := [
		{"p": LAIR + Vector2(-140, -30), "s": 2.6, "f": 0}, {"p": LAIR + Vector2(150, -10), "s": 2.2, "f": 3},
		{"p": LAIR + Vector2(-70, 90), "s": 2.0, "f": 5}, {"p": LAIR + Vector2(90, 110), "s": 2.4, "f": 1},
		{"p": LAIR + Vector2(10, -90), "s": 3.0, "f": 6}, {"p": LAIR + Vector2(-120, 60), "s": 1.8, "f": 2},
	]
	for w in webs:
		_web(w.p, w.s, w.f)

	# Arvel — the thief who stole the claw and got webbed for his trouble.
	var arvel := Npc.new()
	arvel.char_name = "bandit"
	arvel.npc_name = "Arvel the Swift"
	arvel.can_wander = false
	arvel.on_interact = _talk_arvel
	arvel.position = LAIR + Vector2(-90, 30)
	add_child(arvel)

	if not Game.flags.get("giant_spider_slain", false):
		var boss := GiantSpider.new()
		boss.position = LAIR
		add_child(boss)
		Game.notify.emit("Webbing chokes the passage ahead. Something big nests here.", Color(0.7, 0.85, 1.0))

# One static web frame from props/SpiderWeb-Sheet.png (480x32 -> 8x 60x32),
# with a slow alpha pulse so it glimmers in place without scrolling sideways.
func _web(pos: Vector2, scale: float, frame: int) -> void:
	var at := AtlasTexture.new()
	at.atlas = load("res://assets/props/SpiderWeb-Sheet.png")
	at.region = Rect2(frame * 60, 0, 60, 32)
	var web := Sprite2D.new()
	web.texture = at
	web.position = pos
	web.scale = Vector2(scale, scale)
	web.z_index = -85
	web.modulate = Color(0.85, 0.92, 1.0, 0.55)
	add_child(web)
	# desynced shimmer — vary duration so the webs don't pulse in lockstep
	var tw := web.create_tween().set_loops()
	var dur := randf_range(1.1, 1.8)
	tw.tween_property(web, "modulate:a", 0.82, dur).set_trans(Tween.TRANS_SINE)
	tw.tween_property(web, "modulate:a", 0.5, dur).set_trans(Tween.TRANS_SINE)

func _talk_arvel(_npc) -> void:
	if not Game.flags.get("giant_spider_slain", false):
		Game.dialogue.start("Arvel the Swift", [
			"You! Cut me down, I'm STUCK in this webbing! Two-day shipping my eye!",
			"I nicked the golden claw fair and square — then the big spider left a 1-star review on ME.",
			"Kill it and the claw's yours. I just want OUT of this gift-wrapping.",
		])
	else:
		Game.dialogue.start("Arvel the Swift", [
			"You squished it! Take the claw, take it — I'm never thieving artifacts again.",
			"...Probably. The resale value is just SO good.",
		])

func _process(delta: float) -> void:
	_update_respawns(delta)
