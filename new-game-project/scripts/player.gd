# === player.gd ===
# The Dragonbornn™. Top-down CharacterBody2D built entirely in code (no .tscn)
# from the AI-generated LPC sprite sheets. Handles movement, melee, destruction
# magic, the FUS RO DAH shout, damage/respawn, and world interaction.
class_name Player
extends CharacterBody2D

enum State { IDLE, MOVE, ATTACK, CAST, HURT, DEAD }

const SPEED := 145.0
const SPRINT := 215.0
const MELEE_RANGE := 60.0
const MAGIC_COST := 15.0
const SHOUT_COOLDOWN := 3.0
const FACING := {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}

var state: State = State.IDLE
var facing: String = "down"
var spawn_point: Vector2 = Vector2.ZERO
var _shout_cd: float = 0.0
var _hit_flash: float = 0.0
var _regen_block: float = 0.0
var _knockback: Vector2 = Vector2.ZERO

var spr: AnimatedSprite2D
var cam: Camera2D

func _ready() -> void:
	add_to_group("player")
	collision_layer = 1
	collision_mask = 4
	# --- build sprite from AI-generated frames ---
	spr = AnimatedSprite2D.new()
	spr.name = "Spr"
	spr.sprite_frames = LPCFrames.build("hero")
	spr.offset = Vector2(0, -28)  # put origin at the feet for proper y-sorting
	add_child(spr)
	spr.animation_finished.connect(_on_anim_finished)
	# --- collision around the feet ---
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 9.0
	col.shape = shape
	col.position = Vector2(0, -6)
	add_child(col)
	# --- camera ---
	cam = Camera2D.new()
	cam.name = "Camera2D"
	cam.zoom = Vector2(2.2, 2.2)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 7.0
	add_child(cam)
	spawn_point = global_position
	_play("idle")

func _physics_process(delta: float) -> void:
	_shout_cd = maxf(0.0, _shout_cd - delta)
	_hit_flash = maxf(0.0, _hit_flash - delta)
	_regen_block = maxf(0.0, _regen_block - delta)
	spr.modulate = Color(1, 0.5, 0.5) if _hit_flash > 0.0 else Color.WHITE
	_regenerate(delta)

	if state == State.DEAD:
		velocity = velocity.move_toward(Vector2.ZERO, 800 * delta)
		move_and_slide()
		return

	if Game.ui_open:
		velocity = Vector2.ZERO
		move_and_slide()
		if state == State.MOVE:
			state = State.IDLE
			_play("idle")
		return

	# knockback decays and is added to movement
	_knockback = _knockback.move_toward(Vector2.ZERO, 600 * delta)

	if state in [State.ATTACK, State.CAST, State.HURT]:
		velocity = _knockback
		move_and_slide()
		return

	var input := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	).limit_length(1.0)

	var sprinting := Input.is_action_pressed("sprint") and Game.stamina > 1.0 and input != Vector2.ZERO
	var spd := SPRINT if sprinting else SPEED
	if sprinting:
		Game.stamina = maxf(0.0, Game.stamina - 22.0 * delta)
		Game.stats_changed.emit()

	velocity = input * spd + _knockback
	move_and_slide()

	if input != Vector2.ZERO:
		facing = LPCFrames.dir_name(input)
		state = State.MOVE
		_play("walk")
	else:
		state = State.IDLE
		_play("idle")

func _unhandled_input(event: InputEvent) -> void:
	if state == State.DEAD or Game.ui_open:
		return
	if event.is_action_pressed("attack"):
		_attack()
	elif event.is_action_pressed("magic"):
		_cast_magic()
	elif event.is_action_pressed("shout"):
		_shout()
	elif event.is_action_pressed("interact"):
		# Consume the press if we open something, so the dialogue box (which also
		# listens for "interact" to advance) doesn't immediately skip/close it.
		if _interact():
			get_viewport().set_input_as_handled()

# === COMBAT ===
func _attack() -> void:
	if state in [State.ATTACK, State.CAST, State.HURT]:
		return
	state = State.ATTACK
	_face_mouse_if_close()
	_play("slash")
	Audio.sfx("swing", -6.0, 0.15)
	get_tree().create_timer(0.16).timeout.connect(_apply_melee)

func _apply_melee() -> void:
	if state != State.ATTACK:
		return
	var fvec: Vector2 = FACING[facing]
	var hit_any := false
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node2D) or not e.has_method("take_damage"):
			continue
		var to: Vector2 = e.global_position - global_position
		if to.length() <= MELEE_RANGE and to.normalized().dot(fvec) > 0.25:
			var dmg: float = Game.weapon_damage() * randf_range(0.9, 1.15)
			e.take_damage(dmg, to.normalized() * 180.0)
			hit_any = true
	if hit_any:
		Audio.sfx("hit", -3.0, 0.1)
		if randf() < 0.5:
			Game.skill_up("one_handed")

func _cast_magic() -> void:
	if state in [State.ATTACK, State.CAST, State.HURT]:
		return
	if Game.magicka < MAGIC_COST:
		Game.notify.emit("Not enough Magickaa (out of stock)", Color(0.6, 0.7, 1.0))
		return
	state = State.CAST
	Game.magicka -= MAGIC_COST
	Game.stats_changed.emit()
	var aim := (get_global_mouse_position() - global_position)
	if aim.length() < 8.0:
		aim = FACING[facing]
	facing = LPCFrames.dir_name(aim)
	_play("cast")
	Audio.sfx("cast", -4.0, 0.1)
	var dmg: float = 16.0 * (1.0 + float(Game.skills.get("destruction", 0)) * 0.03)
	Projectile.spawn(get_parent(), global_position + Vector2(0, -16), aim, dmg, "enemies", "frostbolt", 440.0)
	if randf() < 0.6:
		Game.skill_up("destruction")

func _shout() -> void:
	if not Game.known_shout:
		Game.notify.emit("You don't know any shouts yet. (Slay the dragon to unlock!)", Color(1, 0.8, 0.5))
		return
	if _shout_cd > 0.0 or state in [State.ATTACK, State.CAST, State.HURT]:
		return
	_shout_cd = SHOUT_COOLDOWN
	state = State.CAST
	_face_mouse_if_close()
	_play("cast")
	Audio.sfx("shout", 2.0)
	Game.notify.emit("FUS RO DAH!", Color(0.81, 0.91, 1.0))
	_spawn_shout_fx()
	_shake(8.0)
	var fvec: Vector2 = FACING[facing]
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node2D) or not e.has_method("take_damage"):
			continue
		var to: Vector2 = e.global_position - global_position
		if to.length() <= 230.0 and to.normalized().dot(fvec) > -0.1:
			e.take_damage(22.0, to.normalized() * 520.0)

func _spawn_shout_fx() -> void:
	var fx := Sprite2D.new()
	if ResourceLoader.exists("res://assets/fx/shout.png"):
		fx.texture = load("res://assets/fx/shout.png")
	fx.z_index = 40
	get_parent().add_child(fx)
	fx.global_position = global_position + FACING[facing] * 60.0 + Vector2(0, -16)
	fx.rotation = FACING[facing].angle()
	fx.scale = Vector2(0.4, 0.4)
	var tw := fx.create_tween()
	tw.set_parallel(true)
	tw.tween_property(fx, "scale", Vector2(2.6, 2.6), 0.35)
	tw.tween_property(fx, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(fx.queue_free)

# === DAMAGE / DEATH ===
func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO) -> void:
	if state == State.DEAD:
		return
	# Block skill gives a little flat reduction
	amount = maxf(1.0, amount - Game.skills.get("block", 0) * 0.15)
	Game.health = maxf(0.0, Game.health - amount)
	Game.stats_changed.emit()
	_hit_flash = 0.25
	_regen_block = 4.0
	_knockback = knockback
	FloatingText.spawn(get_parent(), global_position, "-%d" % int(amount), Color(1, 0.4, 0.4))
	Audio.sfx("hurt", -2.0, 0.15)
	if Game.health <= 0.0:
		_die()
	elif state != State.ATTACK:
		state = State.HURT
		_play("hurt")

func _die() -> void:
	state = State.DEAD
	_play("hurt")
	Game.notify.emit("YOU DIED. Reloading from cloud (Temu Basic tier)...", Color(1, 0.3, 0.3))
	get_tree().create_timer(2.2).timeout.connect(_respawn)

func _respawn() -> void:
	global_position = spawn_point
	Game.health = Game.max_health * 0.6
	Game.magicka = Game.max_magicka
	Game.stamina = Game.max_stamina
	Game.stats_changed.emit()
	state = State.IDLE
	_play("idle")

# === INTERACTION ===
# Returns true if an NPC/interactable was engaged.
func _interact() -> bool:
	var nearest: Node2D = null
	var best := 72.0  # match the NPC's "[E] Talk" prompt range
	for g in ["npc", "interactable"]:
		for n in get_tree().get_nodes_in_group(g):
			if n is Node2D and n.has_method("interact"):
				var d: float = global_position.distance_to(n.global_position)
				if d < best:
					best = d
					nearest = n
	if nearest:
		nearest.interact(self)
		return true
	return false

# === HELPERS ===
func _regenerate(delta: float) -> void:
	if Game.stamina < Game.max_stamina and not Input.is_action_pressed("sprint"):
		Game.stamina = minf(Game.max_stamina, Game.stamina + 18.0 * delta)
		Game.stats_changed.emit()
	if Game.magicka < Game.max_magicka:
		Game.magicka = minf(Game.max_magicka, Game.magicka + 6.0 * delta)
		Game.stats_changed.emit()
	if _regen_block <= 0.0 and Game.health < Game.max_health:
		Game.health = minf(Game.max_health, Game.health + 4.0 * delta)
		Game.stats_changed.emit()

func _face_mouse_if_close() -> void:
	var aim := get_global_mouse_position() - global_position
	if aim.length() > 8.0:
		facing = LPCFrames.dir_name(aim)

func _play(base_state: String) -> void:
	var anim := "%s_%s" % [base_state, facing]
	if spr.sprite_frames and spr.sprite_frames.has_animation(anim):
		if spr.animation != anim or not spr.is_playing():
			spr.play(anim)
	elif spr.sprite_frames and spr.sprite_frames.has_animation("idle_down"):
		spr.play("idle_down")

func _on_anim_finished() -> void:
	if state in [State.ATTACK, State.CAST, State.HURT]:
		state = State.IDLE
		_play("idle")

func _shake(amount: float) -> void:
	var t := cam.create_tween()
	for i in 6:
		t.tween_property(cam, "offset", Vector2(randf_range(-amount, amount), randf_range(-amount, amount)), 0.04)
	t.tween_property(cam, "offset", Vector2.ZERO, 0.05)

static func create() -> Player:
	var p := Player.new()
	return p
