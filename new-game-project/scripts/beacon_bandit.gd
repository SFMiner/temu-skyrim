# === beacon_bandit.gd ===
# The doomed previous owner of The Beacon™. An ordinary bandit who, on death,
# is RELIEVED to finally be rid of the cursed artifact — which promptly curses
# the player instead (Game.beacon_acquired starts The Break of Dawn quest).
# Spawned once and flag-gated in overworld.gd so only one Beacon ever exists.
class_name BeaconBandit
extends HumanoidEnemy

func _build_visual() -> void:
	char_name = "bandit"
	super._build_visual()
	max_hp = 70.0; hp = 70.0
	damage = 12.0; xp_reward = 45; speed = 92.0
	display_name = "Beacon-Cursed Bandit"
	gold_drop = randi_range(10, 22)

func _on_death() -> void:
	FloatingText.spawn(get_parent(), global_position + Vector2(0, -30), "Free at last!", Color(1, 0.95, 0.6))
	# hand the curse to the player and kick off Meridia's booming intro
	Game.beacon_acquired()
