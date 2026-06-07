# === temple.gd ===
# The Temple of Meridia™ — the "cleanse" dungeon for The Break of Dawn. Built in
# code like dungeon.gd, but lit by golden light beams. Filled with Malkoran's
# corrupted dead and, at the altar, the necromancer boss himself. Loaded by
# main._load_temple(); exit returns the player to the overworld shrine.
extends Node2D

const WORLD := Vector2(1600, 1200)
const PLAYER_SPAWN := Vector2(800, 1040)
const EXIT := Vector2(800, 1120)
const ALTAR := Vector2(800, 300)

var player: Player
var _overworld_exit: Vector2 = Vector2(1600, 760)

# --- respawn manager (same as dungeon) ---
const RESPAWN_DELAY := 22.0
const RESPAWN_MIN_DIST := 420.0
var _spawns: Array = []
var _respawn_t: float = 0.0

func _ready() -> void:
	y_sort_enabled = true
	Game.world = self
	if has_meta("overworld_exit_pos"):
		_overworld_exit = get_meta("overworld_exit_pos")
	_build_ground()
	_build_walls()
	_build_lights()
	_build_exit_portal()
	_spawn_corrupted()
	_spawn_boss()
	_spawn_player()
	Audio.stop_music()
	Audio.play_ambient("ambient_dungeon")
	Game.notify.emit("The Temple of Meridia™. Cleanse it. (Some assembly required.)", Color(1.0, 0.92, 0.6))

# === GROUND & WALLS ===
func _build_ground() -> void:
	var gnd := Sprite2D.new()
	gnd.texture = load("res://assets/env/tile_stone.png")
	gnd.centered = false
	gnd.region_enabled = true
	gnd.region_rect = Rect2(0, 0, WORLD.x, WORLD.y)
	gnd.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	gnd.z_index = -100
	gnd.modulate = Color(1.05, 1.02, 0.9)  # warm, sunlit stone
	add_child(gnd)

func _build_walls() -> void:
	for x in range(0, int(WORLD.x), 64):
		_wall(Vector2(x, -64)); _wall(Vector2(x, WORLD.y))
	for y in range(0, int(WORLD.y), 64):
		_wall(Vector2(-64, y)); _wall(Vector2(WORLD.x + 64, y))
	# a couple of interior colonnades to break sightlines
	_wall_v(Vector2(420, 420), 5)
	_wall_v(Vector2(1180, 420), 5)

func _wall(pos: Vector2) -> void:
	var w := Sprite2D.new()
	w.texture = load("res://assets/env/tile_dwall.png")
	w.centered = true
	w.position = pos
	w.z_index = -90
	w.modulate = Color(1.0, 0.97, 0.85)
	add_child(w)
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

func _wall_v(start: Vector2, count: int) -> void:
	for i in count:
		_wall(start + Vector2(0, i * 64))

# === GOLDEN LIGHT BEAMS ===
func _build_lights() -> void:
	for bp in [Vector2(300, 250), Vector2(1300, 250), ALTAR, Vector2(300, 900), Vector2(1300, 900)]:
		_beam(bp)

func _beam(pos: Vector2) -> void:
	var beam := Sprite2D.new()
	beam.texture = load("res://assets/fx/glow.png")
	beam.centered = true
	beam.position = pos
	beam.scale = Vector2(1.1, 5.5)
	beam.z_index = 6
	beam.modulate = Color(1.0, 0.9, 0.55, 0.5)
	add_child(beam)
	var halo := Sprite2D.new()
	halo.texture = load("res://assets/fx/glow.png")
	halo.centered = true
	halo.position = pos
	halo.scale = Vector2(1.6, 1.6)
	halo.z_index = 5
	halo.modulate = Color(1.0, 0.95, 0.7, 0.4)
	add_child(halo)

# === INTERACTABLE (copied pattern from dungeon.gd) ===
func _make_interactable(pos: Vector2, obj_name: String, callback: Callable, sprite_asset: String = "word_wall", radius: float = 28.0) -> Interactable:
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

func _build_exit_portal() -> void:
	var portal := _make_interactable(EXIT, "portal", func(_p): _exit_temple(), "word_wall", 28.0)
	var portal_spr := portal.get_child(0)
	portal_spr.modulate = Color(1.0, 0.85, 0.4)
	portal_spr.scale = Vector2(0.8, 0.8)
	add_child(portal)

func _exit_temple() -> void:
	var main = get_parent()
	if main and main.has_method("_load_overworld_from_dungeon"):
		main._load_overworld_from_dungeon()
		if main._world and main._world.player:
			main._world.player.global_position = _overworld_exit

# === ENEMIES ===
func _spawn_corrupted() -> void:
	for pos in [Vector2(500, 650), Vector2(1100, 650), Vector2(650, 480), Vector2(950, 820), Vector2(800, 600)]:
		_register_spawn(pos, _make_corrupted)

func _make_corrupted() -> Node:
	var d := HumanoidEnemy.new()
	d.char_name = "draugr"
	d.max_hp = 55.0
	d.damage = 11.0
	d.xp_reward = 40
	d.speed = 95.0
	d.display_name = "Corrupted Dead"
	d.gold_drop = randi_range(8, 18)
	d.loot = [{"id": "health_potion", "chance": 0.3}]
	return d

func _spawn_boss() -> void:
	if Game.flags.get("malkoran_slain", false):
		return
	var boss := Necromancer.new()
	boss.position = ALTAR
	add_child(boss)

func _spawn_player() -> void:
	player = Player.new()
	player.position = PLAYER_SPAWN
	add_child(player)

# === RESPAWN SYSTEM (copied from dungeon.gd) ===
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

func _process(delta: float) -> void:
	_update_respawns(delta)
