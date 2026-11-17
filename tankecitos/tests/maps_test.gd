extends Node
## Prueba de mapas sin red: cada categoría tiene 4 mapas, cada mapa declara un tamaño
## coherente con su categoría y ningún punto de aparición cae dentro de un muro.
## Ejecutar:  godot --headless --path . res://tests/maps_test.tscn

const GameMapScript := preload("res://maps/game_map.gd")

var _failures := 0


func _ready() -> void:
	await _run()
	print("RESULT: ", "OK" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _run() -> void:
	# Categoría según cantidad de jugadores
	var expected := {0: 0, 1: 0, 4: 0, 5: 1, 8: 1, 9: 2, 12: 2, 13: 3, 16: 3}
	for count: int in expected:
		_check(GameMapScript.size_for_players(count) == expected[count], "%d players -> category %d" % [count, expected[count]])

	var world := Node2D.new()
	add_child(world)
	var per_category := [0, 0, 0, 0]

	# De a un mapa por vez: si no, los muros de unos taparían los spawns de otros
	for scene in GameConfig.MAPS:
		var map := scene.instantiate() as GameMapScript
		world.add_child(map)
		await get_tree().physics_frame
		await get_tree().physics_frame

		var label := map.display_name
		per_category[map.size_category] += 1
		_check(label != "", "%s has a name" % label)
		_check(map.spawn_points.size() >= map.capacity(), "%s has >= %d spawn points (has %d)" % [label, map.capacity(), map.spawn_points.size()])

		# La arena original mide 2000 de largo: el lado largo debe andar cerca del tamaño de su categoría
		var nominal := 1000.0 * (map.size_category + 1)
		var long_side := maxf(map.play_size.x, map.play_size.y)
		_check(long_side >= nominal * 0.9 and long_side <= nominal * 1.2, "%s long side %d fits its category" % [label, long_side])

		var space := world.get_world_2d().direct_space_state
		var blocked := 0
		for point in map.spawn_points:
			var query := PhysicsShapeQueryParameters2D.new()
			var circle := CircleShape2D.new()
			circle.radius = GameConfig.TANK_RADIUS
			query.shape = circle
			query.transform = Transform2D(0.0, point)
			query.collision_mask = GameConfig.LAYER_WALLS
			if not space.intersect_shape(query, 1).is_empty():
				blocked += 1
		_check(blocked == 0, "%s: no spawn point inside a wall (%d blocked)" % [label, blocked])

		world.remove_child(map)
		map.queue_free()
		await get_tree().physics_frame

	for size in per_category.size():
		_check(per_category[size] == 4, "category %d has 4 maps (has %d)" % [size, per_category[size]])


func _check(condition: bool, label: String) -> void:
	print(("  ok    " if condition else "  FAIL  "), label)
	if not condition:
		_failures += 1
