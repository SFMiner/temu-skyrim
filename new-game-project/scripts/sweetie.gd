# === sweetie.gd ===
# "Sweetie" — the frost troll you drunkenly married during A Night to Remember.
# A big, slow, hard-hitting brute built like spider.gd (frame-animated battler
# sprite from the rpgbattlers "Giant", tinted icy), NOT an LPC sheet. Defeating
# her annuls the marriage. One-off, flag-gated in overworld.gd.
class_name Sweetie
extends Enemy

var spr: Sprite2D
var _frames: Array = []
var _anim_t: float = 0.0
var _frame: int = 0

func _build_visual() -> void:
	max_hp = 180.0; hp = 180.0
	damage = 20.0; xp_reward = 150; speed = 60.0
	attack_range = 70.0; attack_cd = 1.4; aggro_range = 420.0
	display_name = "Sweetie (Your Spouse?)"
	for i in range(1, 5):
		var p := "res://assets/enemies/sweetie%d.png" % i
		if ResourceLoader.exists(p):
			_frames.append(load(p))
	spr = Sprite2D.new()
	if _frames.size() > 0:
		spr.texture = _frames[0]
	spr.offset = Vector2(0, -34)
	spr.scale = Vector2(0.5, 0.5)
	spr.modulate = Color(0.66, 0.82, 1.0)  # frost-troll icy tint
	add_child(spr)

func _setup_collision() -> void:
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 18.0
	col.shape = shape
	col.position = Vector2(0, -10)
	add_child(col)

func _update_visual(moving: bool) -> void:
	if facing == "left":
		spr.flip_h = true
	elif facing == "right":
		spr.flip_h = false
	if moving and _frames.size() > 1:
		_anim_t += get_physics_process_delta_time()
		if _anim_t >= 0.18:
			_anim_t = 0.0
			_frame = (_frame + 1) % _frames.size()
			spr.texture = _frames[_frame]

func _play_attack() -> void:
	Audio.sfx("swing", -2.0, 0.1)
	var tw := create_tween()
	tw.tween_property(spr, "scale", Vector2(0.58, 0.44), 0.1)
	tw.tween_property(spr, "scale", Vector2(0.5, 0.5), 0.14)

func _on_death() -> void:
	Game.flags["night_troll"] = true
	Game.notify.emit("Marriage annulled. Sweetie keeps the ring, the goat, and the house.", Color(0.7, 0.9, 1.0))
	Game.night_check_progress()
