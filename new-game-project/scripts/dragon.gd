# === dragon.gd ===
# DraGON™ — the boss. Hovers, breathes fire, occasionally swoops. On death it
# plays the iconic soul-absorption that unlocks the player's FUS RO DAH shout.
class_name Dragon
extends CharacterBody2D

enum State { HOVER, FIRE, SWOOP, DEAD }

var max_hp: float = 340.0
var hp: float = 340.0
var display_name: String = "DraGON™ (Free Returns)"
var state: State = State.HOVER
var _player: Node2D = null
var _spr: Sprite2D
var _frames: Array = []
var _frame: int = 0
var _flap_t: float = 0.0
var _flash: float = 0.0
var _action_t: float = 2.0
var _bob_t: float = 0.0
var _swoop_target: Vector2 = Vector2.ZERO
var _swoop_hit: bool = false

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	collision_layer = 0
	collision_mask = 0
	hp = max_hp
	for i in 2:
		var p := "res://assets/enemies/dragon_%d.png" % i
		if ResourceLoader.exists(p):
			_frames.append(load(p))
	_spr = Sprite2D.new()
	if _frames.size() > 0:
		_spr.texture = _frames[0]
	_spr.z_index = 60
	add_child(_spr)
	Audio.sfx("dragon_roar", 2.0)
	Game.notify.emit("A dragon! It's DraGON™. Reviews were mixed.", Color(1, 0.5, 0.3))

func _physics_process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	_spr.modulate = Color(1, 0.5, 0.5) if _flash > 0.0 else Color.WHITE
	_flap_t += delta
	if _flap_t >= 0.22 and _frames.size() > 1:
		_flap_t = 0.0
		_frame = 1 - _frame
		_spr.texture = _frames[_frame]
	_bob_t += delta
	_spr.position.y = sin(_bob_t * 2.0) * 8.0

	if state == State.DEAD:
		return
	if Game.ui_open:  # freeze attacks/movement while paused or in dialogue
		return
	if _player == null or not is_instance_valid(_player):
		var ps := get_tree().get_nodes_in_group("player")
		_player = ps[0] if ps.size() > 0 else null
	if _player == null:
		return

	match state:
		State.HOVER:
			_hover(delta)
		State.SWOOP:
			_swoop(delta)
		State.FIRE:
			velocity = Vector2.ZERO

func _hover(delta: float) -> void:
	# keep a stand-off distance and orbit the player
	var to: Vector2 = _player.global_position - global_position
	var dist := to.length()
	var desired := 230.0
	var dir := to.normalized()
	if dist > desired + 40.0:
		velocity = dir * 90.0
	elif dist < desired - 40.0:
		velocity = -dir * 90.0
	else:
		# orbit
		velocity = Vector2(-dir.y, dir.x) * 70.0
	global_position += velocity * delta
	_spr.flip_h = to.x < 0.0
	_action_t -= delta
	if _action_t <= 0.0:
		if randf() < 0.65:
			_breathe_fire()
		else:
			_start_swoop()

func _breathe_fire() -> void:
	state = State.FIRE
	Audio.sfx("dragon_roar", 0.0, 0.05)
	var base := (_player.global_position - global_position).normalized()
	for a in [-0.25, 0.0, 0.25]:
		var d := base.rotated(a)
		Projectile.spawn(get_parent(), global_position, d, 14.0, "player", "fireball", 300.0)
	get_tree().create_timer(0.9).timeout.connect(func() -> void:
		if state == State.FIRE:
			state = State.HOVER
			_action_t = randf_range(2.0, 3.2))

func _start_swoop() -> void:
	state = State.SWOOP
	_swoop_hit = false
	_swoop_target = _player.global_position
	Audio.sfx("dragon_roar", 1.0, 0.05)

func _swoop(delta: float) -> void:
	var to: Vector2 = _swoop_target - global_position
	_spr.flip_h = to.x < 0.0
	velocity = to.normalized() * 320.0
	global_position += velocity * delta
	if not _swoop_hit and _player and global_position.distance_to(_player.global_position) < 70.0:
		_swoop_hit = true
		if _player.has_method("take_damage"):
			_player.take_damage(18.0, (_player.global_position - global_position).normalized() * 280.0)
	if to.length() < 36.0 or _swoop_hit:
		state = State.HOVER
		_action_t = randf_range(1.6, 2.6)

func take_damage(amount: float, _knockback: Vector2 = Vector2.ZERO) -> void:
	if state == State.DEAD:
		return
	hp -= amount
	_flash = 0.15
	FloatingText.spawn(get_parent(), global_position + Vector2(0, -30), str(int(amount)), Color(1, 0.8, 0.4))
	if hp <= 0.0:
		_die()

func _die() -> void:
	state = State.DEAD
	Game.dragons_slain += 1
	Audio.sfx("dragon_roar", 3.0, 0.0)
	Game.notify.emit("DraGON™ defeated! Absorbing dragon soul...", Color(1, 0.84, 0.3))
	# soul absorption FX
	var soul := Sprite2D.new()
	if ResourceLoader.exists("res://assets/fx/dragonsoul.png"):
		soul.texture = load("res://assets/fx/dragonsoul.png")
	soul.z_index = 80
	get_parent().add_child(soul)
	soul.global_position = global_position
	if _player:
		var tw := soul.create_tween()
		tw.tween_property(soul, "global_position", _player.global_position, 1.3).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(soul, "scale", Vector2(0.2, 0.2), 1.3)
		tw.tween_callback(soul.queue_free)
	Audio.sfx("soul", 2.0)
	# rewards + progression
	Game.add_xp(220)
	Game.add_gold(120)
	Game.add_item("dragonbone_sword", 1)
	Game.add_item("ancient_tome", 1)
	get_tree().create_timer(1.4).timeout.connect(_finish_death)
	# fade the corpse
	var t2 := create_tween()
	t2.tween_interval(0.6)
	t2.tween_property(_spr, "modulate:a", 0.0, 1.0)

func _finish_death() -> void:
	Game.unlock_shout()
	if Game.quests.get("main", 0) < 3:
		Game.set_quest("main", 3)
	Game.notify.emit("Quest complete: DraGON™ Returns. New gear in your inventory!", Color(0.8, 1, 0.8))
	queue_free()
