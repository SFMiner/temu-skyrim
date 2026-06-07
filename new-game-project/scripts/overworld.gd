# === overworld.gd ===
# Builds the snowy province of Beigeton entirely in code: tiled ground + roads,
# the town (keep, houses, stalls, NPCs), wilderness (trees, wolves), a bandit
# camp, and the dragon lair trigger. Y-sorted so actors and props overlap right.
extends Node2D

const WORLD := Vector2(3200, 2400)
const TOWN := Vector2(1600, 1750)
const PLAYER_SPAWN := Vector2(1600, 1980)
const KEEP_POS := Vector2(1600, 1430)
const LAIR := Vector2(1600, 470)
const CAMP := Vector2(2560, 1380)

var player: Player
var _dragon_spawned: bool = false
var _in_battle: bool = false

# --- enemy respawn manager ---
# Skyrim-style: enemies repopulate at their spawn point after a delay, but only
# while the player is far enough away that they won't pop in on-screen.
const RESPAWN_DELAY := 20.0       # seconds after death before a slot refills
const RESPAWN_MIN_DIST := 650.0   # player must be this far from the spawn point
var _spawns: Array = []           # each: {pos, make:Callable, node, dead_at:float}
var _respawn_t: float = 0.0

func _ready() -> void:
	y_sort_enabled = true
	Game.world = self
	_build_ground()
	_build_roads()
	_scatter_snow_detail()
	_build_town()
	_build_wilderness()
	_build_bandit_camp()
	_build_lair_decor()
	_build_cave_entrance()
	_build_shrine()
	_spawn_beacon_bandit()
	_build_apology_board()
	_spawn_night_foes()
	_build_borders()
	_spawn_player()
	Audio.play_music("music_overworld")
	Audio.play_ambient("ambient_wind")
	Game.notify.emit("Welcome to Beigeton. Talk to the Jarl [E].", Color(0.9, 0.95, 1.0))

# === GROUND ===
func _build_ground() -> void:
	var gnd := Sprite2D.new()
	gnd.texture = load("res://assets/env/tile_snow.png")
	gnd.centered = false
	gnd.region_enabled = true
	gnd.region_rect = Rect2(0, 0, WORLD.x, WORLD.y)
	gnd.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	gnd.z_index = -100
	add_child(gnd)

func _road(center: Vector2, size: Vector2) -> void:
	var r := Sprite2D.new()
	r.texture = load("res://assets/env/tile_path.png")
	r.centered = true
	r.region_enabled = true
	r.region_rect = Rect2(0, 0, size.x, size.y)
	r.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	r.position = center
	r.z_index = -95
	r.modulate = Color(1, 1, 1, 0.9)
	add_child(r)

func _build_roads() -> void:
	_road(Vector2(1600, 1200), Vector2(130, 1900))   # main north road
	_road(Vector2(1600, 1750), Vector2(1100, 130))   # town cross street
	_road(Vector2(2080, 1400), Vector2(980, 110))    # road to camp

func _scatter_snow_detail() -> void:
	var rock_tex := load("res://assets/env/tile_snowrock.png")
	var ice_tex := load("res://assets/env/tile_ice.png")
	for i in 40:
		var s := Sprite2D.new()
		s.texture = rock_tex if randf() < 0.6 else ice_tex
		s.position = Vector2(randf_range(80, WORLD.x - 80), randf_range(80, WORLD.y - 80))
		s.z_index = -90
		s.modulate.a = 0.8
		add_child(s)

# === PROP HELPERS ===
func _prop(tex_name: String, pos: Vector2, sub: String = "props", solid: Vector2 = Vector2.ZERO) -> Sprite2D:
	var tex: Texture2D = load("res://assets/%s/%s.png" % [sub, tex_name])
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = true
	s.offset = Vector2(0, -tex.get_height() / 2.0)  # base sits on the node origin
	s.position = pos
	add_child(s)
	if solid != Vector2.ZERO:
		_solid(pos + Vector2(0, -solid.y / 2.0 - 2), solid)
	return s

func _solid(center: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	body.position = center
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	add_child(body)

# === TOWN ===
func _build_town() -> void:
	# Jarl's keep
	_prop("keep", KEEP_POS, "props", Vector2(170, 90))
	# longhouses & houses
	_prop("longhouse", TOWN + Vector2(-420, -40), "props", Vector2(150, 70))
	_prop("house", TOWN + Vector2(-300, 160), "props", Vector2(100, 60))
	_prop("house", TOWN + Vector2(360, -30), "props", Vector2(100, 60))
	_prop("longhouse", TOWN + Vector2(430, 170), "props", Vector2(150, 70))
	# market stalls
	_prop("stall", TOWN + Vector2(-60, 60))
	_prop("stall", TOWN + Vector2(120, 70))
	# decor
	_prop("campfire", TOWN + Vector2(40, -40))
	_prop("banner", KEEP_POS + Vector2(-120, 120))
	_prop("banner", KEEP_POS + Vector2(120, 120))
	_prop("barrel", TOWN + Vector2(-130, 30))
	_prop("barrel", TOWN + Vector2(200, 0))
	_prop("sign", TOWN + Vector2(-40, 220))
	for tp in [TOWN + Vector2(-220, -120), TOWN + Vector2(240, -120), KEEP_POS + Vector2(-90, 30), KEEP_POS + Vector2(90, 30)]:
		_prop("torch", tp)
	_prop("chest", TOWN + Vector2(300, 90))

	# --- NPCs ---
	_spawn_npc("jarl", "Jarl BalgReuf", KEEP_POS + Vector2(0, 130), _talk_jarl, false)
	_spawn_npc("guard", "Beigeton Guard", TOWN + Vector2(-40, 150), _talk_guard, true)
	_spawn_npc("shopkeep", "Belethor (Reseller)", TOWN + Vector2(90, 30), _talk_shopkeep, false)
	_spawn_npc("sigrid", "Sigrid", TOWN + Vector2(-160, 120), _talk_villager, true)
	_spawn_npc("ysolda", "Ysolda", TOWN + Vector2(260, 130), _talk_villager, true)
	_spawn_npc("mage", "Farengar Secret-Fire", KEEP_POS + Vector2(-80, 160), _talk_farengar, false)
	_spawn_npc("camilla", "Camilla", TOWN + Vector2(150, 160), _talk_camilla, true)
	_spawn_npc("sam", "Sam", TOWN + Vector2(-10, -10), _talk_sam, false)

func _spawn_npc(char_name: String, npc_name: String, pos: Vector2, cb: Callable, wander: bool) -> void:
	var n := Npc.new()
	n.char_name = char_name
	n.npc_name = npc_name
	n.on_interact = cb
	n.can_wander = wander
	n.position = pos
	add_child(n)

# === WILDERNESS ===
func _build_wilderness() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	for i in 70:
		var pos := Vector2(rng.randf_range(120, WORLD.x - 120), rng.randf_range(120, WORLD.y - 120))
		# keep trees off the roads / town core
		if pos.distance_to(TOWN) < 520:
			continue
		if absf(pos.x - 1600) < 110 and pos.y < 2000:
			continue
		var pick := rng.randf()
		if pick < 0.6:
			_prop("pine_big" if rng.randf() < 0.5 else "pine_small", pos)
		elif pick < 0.8:
			_prop("rock" if rng.randf() < 0.5 else "boulder", pos)
		else:
			_prop("shrub", pos)
	# wolves roaming the north & flanks
	for wp in [Vector2(1100, 900), Vector2(2000, 850), Vector2(800, 1500), Vector2(2400, 1900), Vector2(1300, 700), Vector2(2100, 1100)]:
		_spawn_wolf(wp)

func _spawn_wolf(pos: Vector2) -> void:
	_register_spawn(pos, _make_wolf)

func _make_wolf() -> Node:
	var w := Wolf.new()
	w.gold_drop = randi_range(2, 8)
	w.loot = [{"id": "sweetroll", "chance": 0.15}]
	return w

# === BANDIT CAMP ===
func _build_bandit_camp() -> void:
	_prop("campfire", CAMP)
	_prop("barrel", CAMP + Vector2(-50, 20))
	_prop("chest", CAMP + Vector2(60, 10))
	_prop("sign", CAMP + Vector2(0, -80))
	for tp in [CAMP + Vector2(-80, -30), CAMP + Vector2(80, -30)]:
		_prop("torch", tp)
	_register_spawn(CAMP + Vector2(-70, 40), _make_bandit_chief)
	_register_spawn(CAMP + Vector2(80, 50), _make_bandit)
	_register_spawn(CAMP + Vector2(0, 90), _make_bandit)

func _make_bandit() -> Node:
	var b := HumanoidEnemy.new()
	b.char_name = "bandit"
	b.max_hp = 60.0
	b.damage = 11.0
	b.xp_reward = 35
	b.speed = 90.0
	b.display_name = "Bandit"
	b.gold_drop = randi_range(8, 20)
	b.loot = [{"id": "bandit_axe", "chance": 0.3}]
	return b

func _make_bandit_chief() -> Node:
	var b := HumanoidEnemy.new()
	b.char_name = "bandit"
	b.display_name = "Bandit Chief"
	b.max_hp = 95.0
	b.damage = 14.0
	b.xp_reward = 70
	b.speed = 90.0
	b.gold_drop = randi_range(8, 20)
	# the chief carries the stolen sweetroll (for the guard's quest) — but only
	# until that quest is done, so respawned chiefs don't farm infinite sweetrolls
	if Game.quests.get("sweetroll", 0) >= 3:
		b.loot = [{"id": "bandit_axe", "chance": 0.8}, {"id": "iron_helmet", "chance": 0.5}]
	else:
		b.loot = [{"id": "bandit_axe", "chance": 0.8}, {"id": "sweetroll", "chance": 1.0}, {"id": "iron_helmet", "chance": 0.5}]
	return b

# === DRAGON LAIR ===
func _build_lair_decor() -> void:
	for gp in [LAIR + Vector2(-120, 60), LAIR + Vector2(120, 50), LAIR + Vector2(-40, 110), LAIR + Vector2(70, 120)]:
		_prop("grave", gp)
	_prop("boulder", LAIR + Vector2(-180, 0))
	_prop("boulder", LAIR + Vector2(180, 10))
	_prop("sign", LAIR + Vector2(0, 160))

# === CAVE ===
func _build_cave_entrance() -> void:
	var cave_pos := Vector2(2800, 800)
	_prop("cave", cave_pos)
	# interactive entrance (use Interactable class so has_method works)
	var entrance := Interactable.new()
	entrance.position = cave_pos + Vector2(0, 40)
	entrance.add_to_group("interactable")
	entrance.on_interact = func(_player): _enter_dungeon()
	var col := Area2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 36.0
	var col_shape := CollisionShape2D.new()
	col_shape.shape = shape
	col.add_child(col_shape)
	entrance.add_child(col)
	add_child(entrance)

func _enter_dungeon() -> void:
	if player:
		var exit_pos: Vector2 = player.global_position
		Game.notify.emit("Entering dungeon...", Color(0.8, 0.7, 1.0))
		await get_tree().create_timer(0.3).timeout
		var main = get_parent()
		if main and main.has_method("_load_dungeon"):
			main._load_dungeon(exit_pos)

# === BREAK OF DAWN: beacon bandit + Shrine of Meridia™ ===
const SHRINE := Vector2(700, 760)

# The doomed Beacon-bearer — spawned once, gated so only one Beacon exists.
func _spawn_beacon_bandit() -> void:
	if Game.flags.get("beacon_taken", false):
		return
	var b := BeaconBandit.new()
	b.position = Vector2(1180, 1760)  # on the town cross street, hard to miss
	add_child(b)

# A radiant altar: golden light beam + a glowing pedestal you interact with.
func _build_shrine() -> void:
	_prop("boulder", SHRINE)
	var beam := Sprite2D.new()
	beam.texture = load("res://assets/fx/glow.png")
	beam.centered = true
	beam.position = SHRINE + Vector2(0, -20)
	beam.scale = Vector2(1.0, 5.0)
	beam.z_index = 8
	beam.modulate = Color(1.0, 0.9, 0.55, 0.5)
	add_child(beam)
	var orb := Sprite2D.new()
	orb.texture = load("res://assets/fx/glow.png")
	orb.centered = true
	orb.position = SHRINE + Vector2(0, -34)
	orb.z_index = 9
	orb.modulate = Color(1.0, 0.95, 0.7, 0.85)
	add_child(orb)
	var shrine := Interactable.new()
	shrine.position = SHRINE
	shrine.add_to_group("interactable")
	shrine.on_interact = func(_p): _touch_shrine()
	var col := Area2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 40.0
	var col_shape := CollisionShape2D.new()
	col_shape.shape = shape
	col.add_child(col_shape)
	shrine.add_child(col)
	add_child(shrine)

func _touch_shrine() -> void:
	var stage: int = Game.quests.get("break_of_dawn", 0)
	if stage >= 2:
		# already cleansing — re-enter the temple if Malkoran still lives
		if Game.flags.get("malkoran_slain", false):
			Game.meridia_say(["My temple is cleansed. Five stars. Now stop touching things."])
		else:
			_enter_temple()
	elif stage == 1 and Game.count_of("meridia_beacon") > 0:
		# THE PLACEMENT — grandiose beam-of-light cutscene, then into the temple
		Game.set_quest("break_of_dawn", 2)
		Game.beacon_boom("THE BEACON IS PLACED. BEHOLD MY RADIANCE!")
		Game.meridia_say([
			"YES. The Beacon sings! My light floods the altar (LED, 6500K, daylight white).",
			"Now I lift you into my temple — express delivery, no signature required.",
			"CLEANSE it. Destroy Malkoran. Do not, under any circumstances, request a refund.",
		])
		await get_tree().create_timer(1.2).timeout
		_enter_temple()
	elif stage == 0:
		Game.dialogue.start("Shrine of Meridia™", ["A radiant altar hums. A QR code flickers: 'Scan to begin your journey.' You have no phone."])
	else:
		Game.meridia_say(["Bring me my Beacon, mortal. You'll know it — it won't stop glowing."])

func _enter_temple() -> void:
	Game.notify.emit("A beam of light engulfs you...", Color(1.0, 0.92, 0.6))
	await get_tree().create_timer(0.3).timeout
	var main = get_parent()
	if main and main.has_method("_load_temple"):
		main._load_temple(SHRINE + Vector2(0, 60))

# === A NIGHT TO REMEMBER: Sam, the blackout, and the cleanup ===
# Steve (dawn duel) on the east road; Sweetie (frost-troll spouse) up north.
# Spawned once the quest is active; flag-gated so the dead stay dead.
func _spawn_night_foes() -> void:
	if Game.quests.get("night", 0) < 1:
		return
	if not Game.flags.get("night_duel", false):
		var steve := Steve.new()
		steve.position = Vector2(2100, 1360)
		add_child(steve)
	if not Game.flags.get("night_troll", false):
		var sweetie := Sweetie.new()
		sweetie.position = Vector2(1080, 620)
		add_child(sweetie)

# The town notice board: post your court-ordered public apology here.
func _build_apology_board() -> void:
	var board := Interactable.new()
	board.position = TOWN + Vector2(70, 205)
	board.add_to_group("interactable")
	board.on_interact = func(_p): _post_apology()
	var spr := Sprite2D.new()
	spr.texture = load("res://assets/props/sign.png")
	spr.centered = true
	spr.offset = Vector2(0, -16)
	board.add_child(spr)
	var col := Area2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 32.0
	var col_shape := CollisionShape2D.new()
	col_shape.shape = shape
	col.add_child(col_shape)
	board.add_child(col)
	add_child(board)

func _post_apology() -> void:
	if Game.quests.get("night", 0) != 1 or Game.flags.get("night_reviews", false):
		Game.dialogue.start("Town Notice Board", ["A board of grievances — most of them 1-star reviews about you."])
		return
	Game.flags["night_reviews"] = true
	Game.notify.emit("Public apology posted. (It is, itself, faintly passive-aggressive.)", Color(0.8, 1, 0.8))
	Game.night_check_progress()

func _talk_sam(_npc) -> void:
	var stage: int = Game.quests.get("night", 0)
	if stage == 0:
		Game.dialogue.start("Sam", [
			"Well met! Sam's the name. You look like someone who can hold their mead.",
			"Care for a friendly drinking contest? First to forget their own name buys the next round.",
		], [
			{"text": "You're on. (Accept)", "action": func(): _accept_night_contest()},
			{"text": "I'd better not.", "action": Callable()},
		])
	elif stage == 1:
		Game.dialogue.start("Sam", ["Rough morning? HA! Go on, tidy up your little mess. I'll wait here. I'm enjoying this immensely."])
	elif stage == 2:
		Game.set_quest("night", 3)
		Game.add_item("okayest_drinker", 1)
		Game.add_gold(300)
		Game.add_xp(250)
		if Game.hud and Game.hud.has_method("flash"):
			Game.hud.flash(Color(0.7, 0.2, 0.4))
		Game.dialogue.start("SANGUINE™ — Prince of Two-for-One Tuesdays", [
			"You cleaned it ALL up. The troll, the duel, the reviews, the sweetrolls. MAGNIFICENT.",
			"Sam was never real, friend. I am SANGUINE™ — Prince of Two-for-One Tuesdays.",
			"Best night I've had in an age. Take this trophy, 300 gold, and my eternal subscription. First month free.",
		])
	else:
		Game.dialogue.start("Sam", ["Same time next Tuesday? Two-for-one, you know. Bring the goat."])

func _accept_night_contest() -> void:
	Game.set_quest("night", 1)
	Game.notify.emit("Sam raises a tankard. 'To poor decisions!'", Color(1, 0.85, 0.4))
	if Game.hud and Game.hud.has_method("fade_black"):
		Game.hud.fade_black(_wake_at_camp)
	else:
		_wake_at_camp()

# Runs at peak-black: teleport to the bandit camp and play the wake-up.
func _wake_at_camp() -> void:
	if player and is_instance_valid(player):
		player.global_position = CAMP + Vector2(-200, 150)
	_spawn_night_foes()
	Game.notify.emit("You wake at the bandit camp in a paper crown. Ask around town.", Color(0.9, 0.9, 1.0))
	Game.dialogue.start("Confused Bandit", [
		"Oi! CHIEF! You're awake! ...You don't remember a thing, do you.",
		"Last night you out-drank the whole camp, crowned yourself Honorary Chief, and signed... a LOT of things.",
		"Town's in an uproar. Best go sort out whatever you did. Your Highness.",
	])

# === BORDERS ===
func _build_borders() -> void:
	var t := 60.0
	_solid(Vector2(WORLD.x / 2, -t / 2), Vector2(WORLD.x, t))
	_solid(Vector2(WORLD.x / 2, WORLD.y + t / 2), Vector2(WORLD.x, t))
	_solid(Vector2(-t / 2, WORLD.y / 2), Vector2(t, WORLD.y))
	_solid(Vector2(WORLD.x + t / 2, WORLD.y / 2), Vector2(t, WORLD.y))

# === PLAYER + SNOW ===
func _spawn_player() -> void:
	player = Player.new()
	player.position = PLAYER_SPAWN
	add_child(player)
	# falling snow that follows the player
	var snow := CPUParticles2D.new()
	snow.texture = load("res://assets/fx/snow.png")
	snow.amount = 90
	snow.lifetime = 4.0
	snow.local_coords = false
	snow.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	snow.emission_rect_extents = Vector2(420, 20)
	snow.direction = Vector2(0.2, 1)
	snow.spread = 20.0
	snow.gravity = Vector2(8, 30)
	snow.initial_velocity_min = 30.0
	snow.initial_velocity_max = 60.0
	snow.position = Vector2(0, -260)
	snow.z_index = 90
	snow.modulate = Color(1, 1, 1, 0.7)
	player.add_child(snow)

# Register an enemy slot that respawns over time. `make` returns a fresh,
# configured (but unpositioned) enemy node.
func _register_spawn(pos: Vector2, make: Callable) -> void:
	var node: Node = make.call()
	node.position = pos
	add_child(node)
	# dead_at == INF means "alive / not yet recorded as dead"
	_spawns.append({"pos": pos, "make": make, "node": node, "dead_at": INF})

func _update_respawns(delta: float) -> void:
	_respawn_t -= delta
	if _respawn_t > 0.0:
		return
	_respawn_t = 1.0  # only check once a second
	var now := float(Time.get_ticks_msec()) / 1000.0
	for s in _spawns:
		if is_instance_valid(s.node):
			continue
		if s.dead_at == INF:
			s.dead_at = now  # just noticed it's gone — start the timer
		elif now - s.dead_at >= RESPAWN_DELAY:
			if player and player.global_position.distance_to(s.pos) > RESPAWN_MIN_DIST:
				var n: Node = s.make.call()
				n.position = s.pos
				add_child(n)
				s.node = n
				s.dead_at = INF

func _process(delta: float) -> void:
	_update_respawns(delta)
	# dragon lair trigger: enter the lair with the main quest active
	if not _dragon_spawned and player and Game.quests.get("main", 0) == 1:
		if player.global_position.distance_to(LAIR) < 360.0:
			_spawn_dragon()
	# battle music management
	var boss_alive := get_tree().get_nodes_in_group("boss").size() > 0
	if boss_alive and not _in_battle:
		_in_battle = true
		Audio.play_music("music_battle", -6.0)
	elif not boss_alive and _in_battle:
		_in_battle = false
		Audio.play_music("music_overworld")
		if Game.quests.get("main", 0) >= 3:
			Game.notify.emit("Return to the Jarl to claim your reward.", Color(0.9, 0.95, 1.0))

func _spawn_dragon() -> void:
	_dragon_spawned = true
	var d := Dragon.new()
	d.position = LAIR + Vector2(0, -40)
	add_child(d)
	if Game.quests.get("main", 0) < 2:
		Game.set_quest("main", 2)

# === DIALOGUE CALLBACKS ===
func _talk_jarl(_npc) -> void:
	var stage: int = Game.quests.get("main", 0)
	if stage == 0:
		Game.dialogue.start("Jarl Balgreuf", [
			"So. You're the [i]Dragonbornn™[/i]. The reviews said you'd come.",
			"A dragon — calls itself DraGON™ — has been terrorizing the road north. One star. Refused all refunds.",
			"Slay it, and Beigeton will reward you. Free shipping included.",
		], [
			{"text": "I'll do it. (Accept quest)", "action": func(): _accept_main()},
			{"text": "What's in it for me?", "action": func(): Game.dialogue.start("Jarl Balgreuf", ["Gold. Glory. And a coupon code.", "Take the north road."], [{"text": "Fine, I'll go.", "action": func(): _accept_main()}])},
		])
	elif stage < 3:
		Game.dialogue.start("Jarl Balgreuf", ["The dragon still lives. Head NORTH up the road. You'll know it when it review-bombs you."])
	else:
		if not Game.flags.get("jarl_rewarded", false):
			Game.flags["jarl_rewarded"] = true
			Game.add_gold(150)
			Game.skill_up("speech", 2)
			Game.dialogue.start("Jarl Balgreuf", ["You did it! DraGON™ has been permanently deactivated.", "Here — 150 gold and our 5-star seller badge. You are truly Dragonbornn™."])
		else:
			Game.dialogue.start("Jarl Balgreuf", ["Hail, Dragonbornn™. Mind the wolves. And the shipping fees."])

func _accept_main() -> void:
	Game.set_quest("main", 1)
	Game.notify.emit("Quest started: DraGON™ Returns. Head north!", Color(1, 0.85, 0.4))

func _talk_guard(_npc) -> void:
	if Game.quests.get("night", 0) == 1 and not Game.flags.get("night_duel", false):
		Game.dialogue.start("Beigeton Guard", [
			"There he is — the man, the legend, the menace. Last night you challenged a fellow named Steve to a duel at dawn.",
			"Signed AND witnessed. He's pacing the east road, working up his nerve. Honor it, or you're a coward and a vandal.",
		])
		return
	var sr: int = Game.quests.get("sweetroll", 0)
	if sr == 0:
		Game.dialogue.start("Beigeton Guard", [
			"I used to be an adventurer like you. Then I took an arrow in the knee.",
			"...Also a bandit chief stole my sweetroll. Out east at the camp. It was a [i]limited edition[/i].",
			"Bring it back and there's coin in it for you.",
		], [{"text": "I'll find your sweetroll.", "action": func(): _accept_sweetroll()}])
	elif sr == 1:
		if Game.count_of("sweetroll") > 0:
			Game.dialogue.start("Beigeton Guard", [
				"My sweetroll! You found it! And only slightly nibbled.",
				"Here's your reward. No cap, you're cracked at this hero stuff.",
			], [{"text": "(Hand over sweetroll)", "action": func(): _complete_sweetroll()}])
		else:
			Game.dialogue.start("Beigeton Guard", ["No sweetroll yet? The bandit chief at the east camp has it. Watch the knee."])
	else:
		Game.dialogue.start("Beigeton Guard", ["Stay safe out there. Free shipping won't protect you from dragons."])

func _accept_sweetroll() -> void:
	Game.set_quest("sweetroll", 1)
	Game.notify.emit("Quest started: The Sweetroll Heist.", Color(1, 0.85, 0.4))

func _complete_sweetroll() -> void:
	Game.remove_item("sweetroll", 1)
	Game.add_gold(60)
	Game.skill_up("speech")
	Game.set_quest("sweetroll", 3)
	Game.notify.emit("Quest complete: The Sweetroll Heist (+60 G)", Color(0.8, 1, 0.8))

func _talk_shopkeep(_npc) -> void:
	# Belethor will buy anything — except the cursed Beacon.
	if Game.count_of("meridia_beacon") > 0 and not Game.flags.get("belethor_beacon", false):
		Game.flags["belethor_beacon"] = true
		Game.dialogue.start("Belethor", [
			"Everything's for sale, my friend! Everything! ...except THAT.",
			"The glowing one. The Beacon. No. I've seen what happens to resellers. It's non-returnable for a REASON.",
		], [{"text": "Let me shop anyway", "action": func(): _open_shop()}, {"text": "Leave", "action": Callable()}])
		return
	# A Night to Remember — the 200-sweetroll store-credit bender.
	if Game.quests.get("night", 0) == 1 and not Game.flags.get("night_sweetrolls", false):
		Game.dialogue.start("Belethor", [
			"AH. The big spender returns. Last night you one-click-ordered TWO HUNDRED sweetrolls. On store credit.",
			"You hugged each one. That's 100 gold, friend. Pay up, or I start a podcast about you.",
		], [
			{"text": "Pay 100 G", "action": func(): _pay_sweetroll_debt()},
			{"text": "Two HUNDRED?!", "action": func(): Game.dialogue.start("Belethor", ["Two. Hundred. There's security footage. Pay the 100 gold."], [{"text": "Pay 100 G", "action": func(): _pay_sweetroll_debt()}, {"text": "Later", "action": Callable()}])},
		])
		return
	if not Game.flags.get("free_sample", false):
		Game.flags["free_sample"] = true
		Game.add_item("health_potion", 1)
		Game.dialogue.start("Belethor", [
			"Belethor's General Goods — everything's for sale, my friend! Everything!",
			"First order's got a FREE SAMPLE. One (1) Healthe Potion, added to your bag. Terms apply.",
		], [{"text": "Let me shop", "action": func(): _open_shop()}, {"text": "Maybe later", "action": Callable()}])
	else:
		Game.dialogue.start("Belethor", ["Back again? Spend, spend, spend!"], [{"text": "Shop", "action": func(): _open_shop()}, {"text": "Leave", "action": Callable()}])

func _open_shop() -> void:
	if Game.shop:
		Game.shop.open_shop(["iron_sword", "steel_sword", "health_potion", "magicka_potion", "stamina_potion", "sweetroll", "iron_helmet"])

func _pay_sweetroll_debt() -> void:
	if Game.spend_gold(100):
		Game.flags["night_sweetrolls"] = true
		Game.notify.emit("Debt cleared. Belethor keeps the sweetrolls 'for inventory.'", Color(0.8, 1, 0.8))
		Game.night_check_progress()
	else:
		Game.dialogue.start("Belethor", ["Not enough gold? Tragic. Come back when you're solvent, Chief."])

func _talk_villager(npc) -> void:
	# A Night to Remember — Ysolda recounts the frost-troll wedding.
	if Game.quests.get("night", 0) == 1 and npc.npc_name == "Ysolda" and not Game.flags.get("night_troll", false):
		Game.dialogue.start("Ysolda", [
			"You don't remember? Oh, this is RICH. You got married last night.",
			"To a frost troll. Named Sweetie. There were vows. A goat officiated.",
			"She's up north, expecting you home for dinner. You'll want to... annul that. Carefully.",
		])
		return
	var lines := [
		["Have you been to the Cloud District? ...That's the keep. We only have the one district."],
		["Everything's cheaper in Beigeton. Quality not guaranteed."],
		["I hear the Greybeards do free 2-day shouting now."],
		["My cousin ordered a sword. Got a picture of a sword. Tragic."],
		["Careful north — DraGON™ has a 47% return rate, mostly of arrows."],
	]
	Game.dialogue.start(npc.npc_name, lines[randi() % lines.size()])

func _talk_farengar(_npc) -> void:
	var stage: int = Game.quests.get("golden_claw", 0)
	if stage == 0:
		Game.dialogue.start("Farengar Secret-Fire", [
			"Hm? I am Farengar Secret-Fire, court wizard. Do not touch the alembics, they're financed.",
			"The Jarl wants me to research the dragons. Naturally, I outsourced it.",
			"There is a [i]Golden Dragon Claw[/i] in the old barrow to the south — an ancient 5-star unlock device.",
			"A thief already 'expedited' it for us, then never delivered. Last tracking ping: deep in the tomb.",
			"Fetch it. I'll make it worth your while — gold, and a glowing seller rating.",
		], [
			{"text": "I'll retrieve the claw. (Accept)", "action": func(): _accept_golden_claw()},
			{"text": "Sounds like YOUR job.", "action": func(): Game.dialogue.start("Farengar Secret-Fire", ["I have a fragile constitution and a no-refunds policy on adventuring.", "The barrow is south. Mind the webbing."], [{"text": "Fine, I'll go.", "action": func(): _accept_golden_claw()}])},
		])
	elif stage < 3:
		if Game.count_of("dragon_claw") > 0:
			Game.dialogue.start("Farengar Secret-Fire", [
				"You have it! The Golden Dragon Claw — authentic, barely chewed.",
				"Marvelous. The solution's engraved right on the palm. Of course it is.",
				"Here is your payment. Cleared instantly, no 14-day hold.",
			], [{"text": "(Hand over the claw)", "action": func(): _complete_golden_claw()}])
		else:
			Game.dialogue.start("Farengar Secret-Fire", ["Still no claw? The barrow is SOUTH. Past the draugr, past the spiders, past the regret."])
	else:
		Game.dialogue.start("Farengar Secret-Fire", ["The claw performs as described. Five stars. Would be enchanted-by again."])

func _accept_golden_claw() -> void:
	Game.set_quest("golden_claw", 1)
	Game.notify.emit("Quest started: The Golden Claw. Head south to the barrow!", Color(1, 0.85, 0.4))

func _complete_golden_claw() -> void:
	Game.remove_item("dragon_claw", 1)
	Game.add_gold(200)
	Game.skill_up("speech", 3)
	Game.set_quest("golden_claw", 3)
	Game.notify.emit("Quest complete: The Golden Claw (+200 G)", Color(0.8, 1, 0.8))

func _talk_camilla(npc) -> void:
	# A Night to Remember — Camilla recounts the 1-star review rampage.
	if Game.quests.get("night", 0) == 1 and not Game.flags.get("night_reviews", false):
		Game.dialogue.start("Camilla", [
			"YOU. You left ONE-STAR reviews on every stall, shrine, and goat in town last night.",
			"'Belethor smells of ham. 0/10.' 'This well is wet. Would not drink again.' We held an emergency town meeting.",
			"Post a public apology on the notice board by the square. Today.",
		])
		return
	if Game.quests.get("golden_claw", 0) == 0:
		Game.dialogue.start(npc.npc_name, [
			"My brother and I run the trading post. Well, we DID, until the claw got 'borrowed'.",
			"Some smooth-talker named Arvel swiped our golden claw and bolted into the south barrow.",
			"Go see Farengar at the keep — that wizard's been desperate to get it back.",
		])
	else:
		Game.dialogue.start(npc.npc_name, ["Arvel ran into the barrow with our claw. I hope a spider got him. ...Is that harsh?"])
