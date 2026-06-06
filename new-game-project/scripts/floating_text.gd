# === floating_text.gd ===
# Small world-space damage/loot number that floats up and fades, then frees.
class_name FloatingText
extends Label

static func spawn(parent: Node, pos: Vector2, text: String, color: Color = Color.WHITE, big: bool = false) -> void:
	var ft := FloatingText.new()
	ft.text = text
	ft.modulate = color
	ft.z_index = 100
	ft.add_theme_font_size_override("font_size", 22 if big else 15)
	ft.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	ft.add_theme_constant_override("outline_size", 4)
	parent.add_child(ft)
	ft.global_position = pos + Vector2(-12, -40) + Vector2(randf_range(-8, 8), 0)
	var tw := ft.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ft, "global_position:y", ft.global_position.y - 32, 0.8)
	tw.tween_property(ft, "modulate:a", 0.0, 0.8).set_delay(0.2)
	tw.chain().tween_callback(ft.queue_free)
