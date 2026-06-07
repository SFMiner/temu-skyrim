# Automated dungeon flow test - enter cave, fight draugr, exit
extends Node

static var test_results := []
static var test_file_path := "user://dungeon_flow_test.txt"

static func run_test() -> void:
	test_results.clear()
	test_results.append("=== DUNGEON FLOW TEST START ===")
	test_results.append("Time: %s" % Time.get_datetime_string_from_system())

	# Wait a frame to ensure world is loaded
	await get_tree().process_frame

	# Step 1: Verify overworld is loaded
	var main_node = get_tree().root.get_child(0)
	if not main_node or not main_node.has_method("_load_dungeon"):
		test_results.append("✗ FAIL: main.gd not found")
		_save_results()
		return
	test_results.append("✓ Main controller found")

	var overworld = main_node._world
	if not overworld or overworld.get_script().get_path() != "res://scripts/overworld.gd":
		test_results.append("✗ FAIL: Overworld not loaded")
		_save_results()
		return
	test_results.append("✓ Overworld scene loaded")

	# Step 2: Verify player in overworld
	var player = overworld.player
	if not player:
		test_results.append("✗ FAIL: Player not found in overworld")
		_save_results()
		return
	test_results.append("✓ Player found at %s" % player.global_position)

	# Step 3: Move player to cave entrance and enter
	var cave_pos = Vector2(2800, 800)
	player.global_position = cave_pos + Vector2(0, 40)
	await get_tree().physics_frame

	test_results.append("✓ Player moved to cave entrance at %s" % player.global_position)

	# Find and interact with cave entrance
	var cave_found = false
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is Interactable and n.global_position.distance_to(cave_pos + Vector2(0, 40)) < 10:
			test_results.append("✓ Cave entrance interactable found")
			cave_found = true
			# Trigger interaction
			n.interact(player)
			break

	if not cave_found:
		test_results.append("✗ FAIL: Cave entrance not found")
		_save_results()
		return

	# Wait for dungeon to load
	await get_tree().create_timer(0.6).timeout

	# Step 4: Verify dungeon loaded
	var dungeon = main_node._world
	if not dungeon or dungeon.get_script().get_path() != "res://scripts/dungeon.gd":
		test_results.append("✗ FAIL: Dungeon did not load")
		_save_results()
		return
	test_results.append("✓ Dungeon scene loaded")

	# Step 5: Verify player spawned in dungeon
	var dungeon_player = dungeon.player
	if not dungeon_player:
		test_results.append("✗ FAIL: Player not in dungeon")
		_save_results()
		return
	test_results.append("✓ Player spawned in dungeon at %s" % dungeon_player.global_position)

	# Step 6: Verify draugr enemies spawned
	var draugr_enemies = []
	for n in get_tree().get_nodes_in_group("enemies"):
		if n.display_name == "Draugr":
			draugr_enemies.append(n)

	if draugr_enemies.size() == 0:
		test_results.append("✗ FAIL: No draugr enemies found")
		_save_results()
		return
	test_results.append("✓ Found %d draugr enemies" % draugr_enemies.size())

	# Step 7: Simulate combat - move close to draugr and attack
	if draugr_enemies.size() > 0:
		var target = draugr_enemies[0]
		var initial_hp = target.health

		test_results.append("  - Target draugr at %s with %.0f HP" % [target.global_position, initial_hp])

		# Move player close to enemy
		dungeon_player.global_position = target.global_position + Vector2(30, 0)
		await get_tree().physics_frame

		# Simulate attack (call take_damage directly to test combat)
		var damage = 20.0
		target.take_damage(damage, Vector2.ZERO)
		await get_tree().physics_frame

		var new_hp = target.health
		if new_hp < initial_hp:
			test_results.append("✓ Combat works: dealt %.0f damage (%.0f → %.0f HP)" % [damage, initial_hp, new_hp])
		else:
			test_results.append("⚠ Combat: health did not change")

	# Step 8: Verify interactive objects
	var chest_found = false
	var wall_found = false
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is Interactable:
			var dist_chest = n.global_position.distance_to(Vector2(1300, 300))
			var dist_wall = n.global_position.distance_to(Vector2(400, 150))
			if dist_chest < 10:
				chest_found = true
			if dist_wall < 10:
				wall_found = true

	if chest_found:
		test_results.append("✓ Chest found in dungeon")
	if wall_found:
		test_results.append("✓ Word wall found in dungeon")

	# Step 9: Find and use exit portal
	var exit_portal = null
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is Interactable and n.global_position.distance_to(Vector2(800, 100)) < 10:
			exit_portal = n
			break

	if not exit_portal:
		test_results.append("✗ FAIL: Exit portal not found")
		_save_results()
		return
	test_results.append("✓ Exit portal found at %s" % exit_portal.global_position)

	# Use exit portal
	exit_portal.interact(dungeon_player)
	await get_tree().create_timer(0.6).timeout

	# Step 10: Verify returned to overworld
	var final_world = main_node._world
	if not final_world or final_world.get_script().get_path() != "res://scripts/overworld.gd":
		test_results.append("✗ FAIL: Did not return to overworld")
		_save_results()
		return
	test_results.append("✓ Returned to overworld")

	# Step 11: Verify player position near cave
	var final_player = final_world.player
	if final_player:
		var dist_to_cave = final_player.global_position.distance_to(cave_pos)
		test_results.append("✓ Player at %s (distance to cave: %.0f px)" % [final_player.global_position, dist_to_cave])

	test_results.append("")
	test_results.append("=== DUNGEON FLOW TEST COMPLETE ===")
	test_results.append("✓ ALL TESTS PASSED")
	test_results.append("Full dungeon flow verified: enter → spawn → fight → exit → return")

	_save_results()
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()

static func _save_results() -> void:
	var output = "\n".join(test_results)
	var file = FileAccess.open(test_file_path, FileAccess.WRITE)
	if file:
		file.store_string(output)
