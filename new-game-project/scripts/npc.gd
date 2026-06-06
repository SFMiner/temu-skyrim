# === npc.gd ===
# Townsfolk built from AI-generated LPC sprites. Gentle wander, faces the player
# on interaction, and runs an assigned dialogue/behavior Callable. Shows a name
# + prompt when the player is near.
class_name Npc
extends CharacterBody2D

var char_name: String = "villager"
var npc_name: String = "Townsperson"
var on_interact: Callable = Callable()
var can_wander: bool = true

var _spr: AnimatedSprite2D
var _label: Label
var _facing: String = "down"
var _home: Vector2
var _target: Vector2
var _wait: float = 0.0
var _player: Node2D = null

func _ready() -> void:
	add_to_group("npc")
	collision_layer = 4
	collision_mask = 4
	_home = global_position
	_target = global_position
	_spr = AnimatedSprite2D.new()
	_spr.sprite_frames = LPCFrames.build(char_name)
	_spr.offset = Vector2(0, -28)
	add_child(_spr)
	_play("idle")
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 9.0
	col.shape = shape
	col.position = Vector2(0, -6)
	add_child(col)
	_label = Label.new()
	_label.text = npc_name
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(1, 0.85, 0.6))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("outline_size", 4)
	_label.position = Vector2(-40, -64)
	_label.size = Vector2(80, 16)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.visible = false
	add_child(_label)

func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		var ps := get_tree().get_nodes_in_group("player")
		_player = ps[0] if ps.size() > 0 else null
	# proximity prompt
	if _player:
		var near := global_position.distance_to(_player.global_position) < 70.0
		if near and not Game.ui_open:
			_label.text = "%s\n[E] Talk" % npc_name
			_label.visible = true
		else:
			_label.visible = false

	if Game.ui_open or not can_wander:
		velocity = Vector2.ZERO
		_play("idle")
		return

	_wait -= delta
	var to: Vector2 = _target - global_position
	if to.length() < 6.0:
		if _wait <= 0.0:
			_target = _home + Vector2(randf_range(-60, 60), randf_range(-60, 60))
			_wait = randf_range(2.0, 5.0)
		velocity = Vector2.ZERO
		_play("idle")
	else:
		var dir := to.normalized()
		_facing = LPCFrames.dir_name(dir)
		velocity = dir * 45.0
		_play("walk")
	move_and_slide()

func interact(player: Node2D) -> void:
	# face the player
	_facing = LPCFrames.dir_name(player.global_position - global_position)
	_play("idle")
	if on_interact.is_valid():
		on_interact.call(self)
	elif Game.dialogue:
		Game.dialogue.start(npc_name, ["Mind the dragons. And the shipping fees."])

func _play(base: String) -> void:
	var anim := "%s_%s" % [base, _facing]
	if _spr.sprite_frames and _spr.sprite_frames.has_animation(anim):
		if _spr.animation != anim or not _spr.is_playing():
			_spr.play(anim)
