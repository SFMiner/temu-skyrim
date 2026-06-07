# === enemy.gd ===
# Base class for ground enemies. Handles stats, simple chase/attack FSM,
# knockback, damage, loot and XP on death. Subclasses provide the visuals
# (_build_visual / _update_visual / _play_attack) so the same brain drives
# both LPC humanoids and the hand-drawn wolf.
class_name Enemy
extends CharacterBody2D

enum State { IDLE, CHASE, ATTACK, DEAD }

var max_hp: float = 40.0
var hp: float = 40.0
var damage: float = 8.0
var xp_reward: int = 20
var speed: float = 95.0
var aggro_range: float = 330.0
var attack_range: float = 52.0
var attack_cd: float = 1.1
var display_name: String = "Bandit"
var loot: Array = []  # array of {"id": String, "chance": float, "count": int}
var gold_drop: int = 0

var state: State = State.IDLE
var facing: String = "down"
var _cd: float = 0.0
var _flash: float = 0.0
var _knockback: Vector2 = Vector2.ZERO
var _player: Node2D = null
var _home: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 4
	hp = max_hp
	_home = global_position
	_build_visual()
	_setup_collision()

func _setup_collision() -> void:
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 10.0
	col.shape = shape
	col.position = Vector2(0, -6)
	add_child(col)

func _physics_process(delta: float) -> void:
	_cd = maxf(0.0, _cd - delta)
	_flash = maxf(0.0, _flash - delta)
	_tint()
	if state == State.DEAD:
		return
	# Freeze while a menu/dialogue/pause blocks gameplay (same gate the player uses).
	if Game.ui_open:
		velocity = Vector2.ZERO
		return
	_knockback = _knockback.move_toward(Vector2.ZERO, 700 * delta)
	if _player == null or not is_instance_valid(_player):
		var ps := get_tree().get_nodes_in_group("player")
		_player = ps[0] if ps.size() > 0 else null

	if state == State.ATTACK:
		velocity = _knockback
		move_and_slide()
		return

	var moving := false
	if _player and is_instance_valid(_player):
		var to: Vector2 = _player.global_position - global_position
		var dist := to.length()
		if dist <= attack_range and _cd <= 0.0:
			_begin_attack()
		elif dist <= aggro_range:
			state = State.CHASE
			var dir := to.normalized()
			facing = LPCFrames.dir_name(dir)
			velocity = dir * speed + _separation() + _knockback
			moving = true
		else:
			state = State.IDLE
			velocity = _knockback
	else:
		velocity = _knockback
	move_and_slide()
	_update_visual(moving)

func _begin_attack() -> void:
	state = State.ATTACK
	_cd = attack_cd
	if _player and is_instance_valid(_player):
		facing = LPCFrames.dir_name(_player.global_position - global_position)
	_play_attack()
	get_tree().create_timer(0.35).timeout.connect(_land_attack)

func _land_attack() -> void:
	if state == State.DEAD or Game.ui_open:
		return
	if _player and is_instance_valid(_player) and _player.has_method("take_damage"):
		var to: Vector2 = _player.global_position - global_position
		if to.length() <= attack_range + 16.0:
			_player.take_damage(damage * randf_range(0.85, 1.1), to.normalized() * 160.0)
	# recover to chase after the swing
	get_tree().create_timer(0.25).timeout.connect(func() -> void:
		if state == State.ATTACK:
			state = State.CHASE)

func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO) -> void:
	if state == State.DEAD:
		return
	hp -= amount
	_flash = 0.18
	_knockback = knockback
	FloatingText.spawn(get_parent(), global_position, str(int(amount)), Color(1, 0.9, 0.5))
	_spawn_blood()
	if hp <= 0.0:
		_die()

func _die() -> void:
	state = State.DEAD
	collision_layer = 0
	Game.add_xp(xp_reward)
	if gold_drop > 0:
		Game.add_gold(gold_drop)
		FloatingText.spawn(get_parent(), global_position, "+%d gold" % gold_drop, Color(1, 0.84, 0.3))
	for entry in loot:
		if randf() <= entry.get("chance", 1.0):
			var id: String = entry.id
			Game.add_item(id, entry.get("count", 1))
			Game.notify.emit("Looted: %s" % Game.item_def(id).name, Color(0.8, 1, 0.8))
	_on_death()
	# fade and remove
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)

# --- virtuals for subclasses ---
func _build_visual() -> void:
	pass

func _update_visual(_moving: bool) -> void:
	pass

func _play_attack() -> void:
	pass

func _on_death() -> void:
	pass

# Gentle boids-style repulsion so a pack fans out around the player
# instead of stacking into a single sprite.
func _separation() -> Vector2:
	var push := Vector2.ZERO
	for o in get_tree().get_nodes_in_group("enemies"):
		if o == self or not (o is Node2D):
			continue
		var d: Vector2 = global_position - o.global_position
		var l := d.length()
		if l > 0.1 and l < 34.0:
			push += (d / l) * (34.0 - l)
	return push * 4.0

# --- helpers ---
func _tint() -> void:
	if state == State.DEAD:
		return
	modulate = Color(1, 0.5, 0.5) if _flash > 0.0 else Color.WHITE

func _spawn_blood() -> void:
	if not ResourceLoader.exists("res://assets/fx/blood.png"):
		return
	var b := Sprite2D.new()
	b.texture = load("res://assets/fx/blood.png")
	b.z_index = 30
	get_parent().add_child(b)
	b.global_position = global_position + Vector2(0, -14)
	var tw := b.create_tween()
	tw.tween_property(b, "modulate:a", 0.0, 0.6)
	tw.tween_callback(b.queue_free)
