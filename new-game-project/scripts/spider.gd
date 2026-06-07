# === spider.gd ===
# Frostbite Spider — multi-frame battler sprite enemy. Skitters fast, low-ish HP,
# venomous bite. Drives off the shared Enemy brain; only supplies the visuals.
# Frost-blue tint sells the "frostbite" flavor on the recolored Gray Spider art.
class_name Spider
extends Enemy

var spr: Sprite2D
var _frames: Array = []
var _anim_t: float = 0.0
var _frame: int = 0

func _build_visual() -> void:
	max_hp = 50.0; hp = 50.0
	damage = 10.0; xp_reward = 35; speed = 92.0
	attack_range = 46.0; attack_cd = 1.0
	display_name = "Frostbite Spider"
	for i in range(1, 5):
		var p := "res://assets/enemies/spider%d.png" % i
		if ResourceLoader.exists(p):
			_frames.append(load(p))
	spr = Sprite2D.new()
	if _frames.size() > 0:
		spr.texture = _frames[0]
	spr.offset = Vector2(0, -16)
	spr.scale = Vector2(0.5, 0.5)
	spr.modulate = Color(0.72, 0.85, 1.0)  # icy frost tint
	add_child(spr)

func _update_visual(moving: bool) -> void:
	if facing == "left":
		spr.flip_h = true
	elif facing == "right":
		spr.flip_h = false
	if moving and _frames.size() > 1:
		_anim_t += get_physics_process_delta_time()
		if _anim_t >= 0.13:
			_anim_t = 0.0
			_frame = (_frame + 1) % _frames.size()
			spr.texture = _frames[_frame]

func _play_attack() -> void:
	Audio.sfx("wolf", -6.0, 0.2)  # reuse the bite-ish snarl, pitched down
	var tw := create_tween()
	tw.tween_property(spr, "scale", Vector2(0.62, 0.42), 0.08)
	tw.tween_property(spr, "scale", Vector2(0.5, 0.5), 0.12)
