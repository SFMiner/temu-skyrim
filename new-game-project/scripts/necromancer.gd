# === necromancer.gd ===
# Malkoran (Drop-Shipper of the Dead) — the temple boss for The Break of Dawn.
# A robed caster that lobs frostbolts and raises shades. Built on the shared
# Enemy brain (HumanoidEnemy) + the "boss" group so the HUD shows its health bar
# (same pattern as giant_spider.gd). On death, Game.meridia_victory() hands over
# DawnBreaker™ and frees the player of the Beacon.
class_name Necromancer
extends HumanoidEnemy

var _cast_t: float = 3.0
var _shades: int = 0

func _build_visual() -> void:
	char_name = "mage"  # reuse the robed-wizard sprite, tinted sickly
	super._build_visual()
	add_to_group("boss")
	max_hp = 240.0; hp = 240.0
	damage = 16.0; xp_reward = 200; speed = 70.0
	attack_range = 56.0; attack_cd = 1.3; aggro_range = 520.0
	display_name = "Malkoran (Drop-Shipper of the Dead)"
	gold_drop = 120
	spr.modulate = Color(0.55, 0.95, 0.6)  # necrotic green over the blue robe

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if state == State.DEAD or Game.ui_open:
		return
	_cast_t -= delta
	if _cast_t <= 0.0 and _player and is_instance_valid(_player):
		_cast_t = randf_range(2.4, 3.8)
		if randf() < 0.4 and _shades < 3:
			_raise_shade()
		else:
			_cast_frost()

func _cast_frost() -> void:
	if spr.sprite_frames.has_animation("cast_%s" % facing):
		_play("cast")
	else:
		_play("slash")
	Audio.sfx("cast", -4.0, 0.1)
	var base := (_player.global_position - global_position).normalized()
	for a in [-0.18, 0.0, 0.18]:
		Projectile.spawn(get_parent(), global_position + Vector2(0, -20), base.rotated(a), 12.0, "player", "frostbolt", 300.0)

func _raise_shade() -> void:
	_shades += 1
	Game.notify.emit("Malkoran raises a shade! (drop-shipped, 5-9 day delivery)", Color(0.6, 0.9, 0.7))
	var shade := HumanoidEnemy.new()
	shade.char_name = "draugr"
	shade.position = global_position + Vector2(randf_range(-40, 40), randf_range(20, 50))
	get_parent().add_child(shade)
	shade.max_hp = 35.0; shade.hp = 35.0
	shade.damage = 8.0; shade.xp_reward = 15; shade.display_name = "Drop-Shipped Shade"
	# near-black silhouette so shades read as shadows, not reused draugr
	shade.spr.modulate = Color(0.12, 0.12, 0.16)

func _on_death() -> void:
	Game.flags["malkoran_slain"] = true
	Game.meridia_victory()
