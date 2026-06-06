# === wolf.gd ===
# Hand-drawn (PIL) 2-frame wolf enemy. Fast, low HP, bites.
class_name Wolf
extends Enemy

var spr: Sprite2D
var _frames: Array = []
var _anim_t: float = 0.0
var _frame: int = 0

func _build_visual() -> void:
	max_hp = 28.0; hp = 28.0
	damage = 7.0; xp_reward = 15; speed = 135.0
	attack_range = 44.0; attack_cd = 0.9
	display_name = "Snow Wolf"
	for i in 2:
		var p := "res://assets/enemies/wolf_%d.png" % i
		if ResourceLoader.exists(p):
			_frames.append(load(p))
	spr = Sprite2D.new()
	if _frames.size() > 0:
		spr.texture = _frames[0]
	spr.offset = Vector2(0, -10)
	add_child(spr)

func _update_visual(moving: bool) -> void:
	if facing == "left":
		spr.flip_h = true
	elif facing == "right":
		spr.flip_h = false
	if moving and _frames.size() > 1:
		_anim_t += get_physics_process_delta_time()
		if _anim_t >= 0.12:
			_anim_t = 0.0
			_frame = 1 - _frame
			spr.texture = _frames[_frame]

func _play_attack() -> void:
	Audio.sfx("wolf", -4.0, 0.15)
	var tw := create_tween()
	tw.tween_property(spr, "scale", Vector2(1.25, 0.85), 0.08)
	tw.tween_property(spr, "scale", Vector2.ONE, 0.12)
