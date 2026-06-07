# === steve.gd ===
# "Steve" — the regular guy you drunkenly challenged to a dawn duel during
# A Night to Remember. A one-off foe (flag-gated in overworld.gd). On death the
# duel is settled. Pattern mirrors beacon_bandit.gd.
class_name Steve
extends HumanoidEnemy

func _build_visual() -> void:
	char_name = "steve"
	super._build_visual()
	max_hp = 80.0; hp = 80.0
	damage = 12.0; xp_reward = 60; speed = 95.0
	display_name = "Steve (You Challenged Him)"
	gold_drop = randi_range(10, 25)

func _on_death() -> void:
	FloatingText.spawn(get_parent(), global_position + Vector2(0, -30), "I yield! ...wait, did I win?", Color(1, 0.95, 0.7))
	Game.flags["night_duel"] = true
	Game.notify.emit("Dawn duel honored. Steve respects you now. Weird guy.", Color(0.8, 1, 0.8))
	Game.night_check_progress()
