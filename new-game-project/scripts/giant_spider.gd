# === giant_spider.gd ===
# The Giant Frostbite Spider™ — dungeon boss guarding the Golden Dragon Claw.
# Reuses the Spider visuals at a much larger scale and joins the "boss" group so
# the HUD shows its health bar. On death it drops the claw and trips a flag so it
# never respawns (no infinite-claw farming on repeat dungeon visits).
class_name GiantSpider
extends Spider

func _build_visual() -> void:
	super._build_visual()
	add_to_group("boss")
	max_hp = 280.0; hp = 280.0
	damage = 20.0; xp_reward = 200; speed = 74.0
	attack_range = 64.0; attack_cd = 1.3
	aggro_range = 460.0
	display_name = "Giant Frostbite Spider™ (1.9★)"
	gold_drop = 80
	loot = [{"id": "dragon_claw", "chance": 1.0}]
	spr.offset = Vector2(0, -46)
	spr.scale = Vector2(1.35, 1.35)
	spr.modulate = Color(0.62, 0.78, 1.0)
	spr.z_index = 20

func _update_visual(moving: bool) -> void:
	if facing == "left":
		spr.flip_h = true
	elif facing == "right":
		spr.flip_h = false
	if moving and _frames.size() > 1:
		_anim_t += get_physics_process_delta_time()
		if _anim_t >= 0.16:
			_anim_t = 0.0
			_frame = (_frame + 1) % _frames.size()
			spr.texture = _frames[_frame]

func _play_attack() -> void:
	Audio.sfx("wolf", -2.0, 0.0)
	var tw := create_tween()
	tw.tween_property(spr, "scale", Vector2(1.55, 1.15), 0.1)
	tw.tween_property(spr, "scale", Vector2(1.35, 1.35), 0.14)

func _on_death() -> void:
	Game.flags["giant_spider_slain"] = true
	Game.notify.emit("The Giant Frostbite Spider™ has been returned to sender.", Color(0.7, 0.9, 1.0))
