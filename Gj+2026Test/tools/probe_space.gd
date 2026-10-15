extends Node2D
## Headless free-space probe: tests the player's own collision shape against the
## world collision layer at a grid of positions, so we can pick placements the
## player can actually stand in.
## Run: godot --headless --path <project> res://tools/probe_space.tscn

const LevelScene := preload("res://scenes/level/test/test_level.tscn")
const STEP := 16


func _ready() -> void:
	await _run()


func _run() -> void:
	var level := LevelScene.instantiate()
	add_child(level)
	await _frames(5)

	var player: CharacterBody2D = level.get_node("Player")
	var col: CollisionShape2D = player.get_node("CollisionShape2D")
	var shape: Shape2D = col.shape
	print("PROBE: player pos=%s layer=%d mask=%d shape=%s" % [
		player.global_position, player.collision_layer, player.collision_mask, shape])

	var world := player.get_world_2d()
	var space := world.direct_space_state

	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.collision_mask = 1
	params.collide_with_areas = false
	params.collide_with_bodies = true
	params.exclude = [player.get_rid()]

	# Probe region around spawn.
	var origin := player.global_position
	var x0 := int(origin.x) - 16 * 16
	var x1 := int(origin.x) + 16 * 16
	var y0 := int(origin.y) - 8 * 16
	var y1 := int(origin.y) + 14 * 16

	var ex := {}
	for e in ["Enemy1", "Enemy2", "Enemy3"]:
		var n: Node2D = level.get_node(e)
		ex[n.global_position] = e.substr(5, 1)
	var epos := []
	for p in ex:
		epos.append(p)

	var lines: Array[String] = []
	var y := y0
	while y <= y1:
		var row := ""
		var x := x0
		while x <= x1:
			var p := Vector2(x, y)
			var mark := ""
			if p.distance_to(origin) < 8:
				mark = "@"
			else:
				for ep in epos:
					if Vector2(ep).distance_to(p) < 12:
						mark = ex[ep]
						break
			if mark == "":
				params.transform = Transform2D(0, p)
				var hits := space.intersect_shape(params, 1)
				mark = "X" if hits.size() > 0 else "."
			row += mark
			x += STEP
		lines.append("y=%4d %s" % [y, row])
		y += STEP

	print("PROBE: cols x=%d..%d step=%d" % [x0, x1, STEP])
	print("PROBE:\n" + "\n".join(lines))

	get_tree().quit(0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
