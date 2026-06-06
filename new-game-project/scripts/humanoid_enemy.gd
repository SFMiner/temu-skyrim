# === humanoid_enemy.gd ===
# LPC-sprite enemy (bandits, draugr). Set `char_name` before adding to the tree.
class_name HumanoidEnemy
extends Enemy

var char_name: String = "bandit"
var spr: AnimatedSprite2D

func _build_visual() -> void:
	spr = AnimatedSprite2D.new()
	spr.sprite_frames = LPCFrames.build(char_name)
	spr.offset = Vector2(0, -28)
	add_child(spr)
	spr.animation_finished.connect(_on_anim_finished)
	_play("idle")

func _update_visual(moving: bool) -> void:
	if state == State.ATTACK:
		return
	_play("walk" if moving else "idle")

func _play_attack() -> void:
	_play("slash")
	Audio.sfx("swing", -10.0, 0.2)

func _play(base: String) -> void:
	var anim := "%s_%s" % [base, facing]
	if spr.sprite_frames and spr.sprite_frames.has_animation(anim):
		if spr.animation != anim or not spr.is_playing():
			spr.play(anim)

func _on_anim_finished() -> void:
	if state == State.ATTACK:
		_play("idle")
