# Simple interactable object that calls a callback when interacted with
extends Node2D
class_name Interactable

var on_interact: Callable = Callable()

func interact(player: Node2D) -> void:
	if on_interact.is_valid():
		on_interact.call(player)
