# === projectile.gd ===
# Generic magic/breath projectile. Travels in a direction, damages the first
# member of its target group it touches, then frees. Distance-based hit test
# keeps collision setup simple and reliable.
class_name Projectile
extends Node2D

var velocity: Vector2 = Vector2.ZERO
var damage: float = 10.0
var target_group: String = "enemies"
var life: float = 2.5
var hit_radius: float = 22.0
var knockback: float = 120.0
var _spr: Sprite2D

static func spawn(parent: Node, pos: Vector2, dir: Vector2, dmg: float, target: String,
		icon: String = "frostbolt", speed: float = 420.0) -> Projectile:
	var p := Projectile.new()
	p.velocity = dir.normalized() * speed
	p.damage = dmg
	p.target_group = target
	parent.add_child(p)
	p.global_position = pos
	p.z_index = 50
	var tex_path := "res://assets/fx/%s.png" % icon
	if ResourceLoader.exists(tex_path):
		p._spr.texture = load(tex_path)
	return p

func _ready() -> void:
	_spr = Sprite2D.new()
	add_child(_spr)
	rotation = velocity.angle()

func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	for t in get_tree().get_nodes_in_group(target_group):
		if not (t is Node2D):
			continue
		if global_position.distance_to(t.global_position) <= hit_radius:
			if t.has_method("take_damage"):
				t.take_damage(damage, (t.global_position - global_position).normalized() * knockback)
			_impact()
			return

func _impact() -> void:
	Audio.sfx("frost", -4.0, 0.1)
	queue_free()
