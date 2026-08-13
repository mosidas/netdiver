extends GdUnitTestSuite

const DEV_STAGE_SCENE: PackedScene = preload("res://src/stage/dev_stage.tscn")

const TERRAIN_LAYER: int = 1 << 0
const PLAYER_LAYER: int = 1 << 1

# 段差の高さの上限。プレイヤーの最高到達点(48px)より低く取り、頂点で乗ることを要求しない
const MAX_STEP_HEIGHT: float = 32.0

const FLOOR_NAME: String = "Floor"
const STEP_NAMES: Array[String] = ["Step1", "Step2", "Step3"]
const WALL_NAMES: Array[String] = ["WallLeft", "WallRight"]
const PLAYER_NAME: String = "Player"

# 実装の定数を参照せずテスト側に持つ(main.tscn の差し替えを検出するため)
const EXPECTED_MAIN_SCENE: String = "res://main.tscn"


func _instantiate_stage() -> Node2D:
	var stage: Node2D = auto_free(DEV_STAGE_SCENE.instantiate())
	assert_object(stage).is_not_null()
	return stage


func _collect_class_names(node: Node, into: Array[String]) -> void:
	into.append(node.get_class())
	for child: Node in node.get_children():
		_collect_class_names(child, into)


func test_the_stage_has_a_floor_three_steps_and_two_walls() -> void:
	var stage := _instantiate_stage()
	var expected_bodies: Array[String] = [FLOOR_NAME]
	expected_bodies.append_array(STEP_NAMES)
	expected_bodies.append_array(WALL_NAMES)

	for body_name: String in expected_bodies:
		var body: Node = stage.get_node_or_null(NodePath(body_name))
		assert_object(body).append_failure_message(body_name).is_not_null()
		assert_bool(body is StaticBody2D).append_failure_message(body_name).is_true()

	# 床・段差 3 段・壁 2 の 6 つだけであること(数え漏らし・重複を固定する)
	var static_bodies: Array[Node] = []
	for child: Node in stage.get_children():
		if child is StaticBody2D:
			static_bodies.append(child)
	assert_int(static_bodies.size()).is_equal(expected_bodies.size())


func test_every_static_body_carries_a_rectangle_collision_shape() -> void:
	var stage := _instantiate_stage()

	for child: Node in stage.get_children():
		if not (child is StaticBody2D):
			continue
		var shape_node: CollisionShape2D = child.get_node_or_null(^"CollisionShape2D")
		assert_object(shape_node).append_failure_message(child.name).is_not_null()
		assert_object(shape_node.shape).append_failure_message(child.name).is_not_null()
		assert_bool(shape_node.shape is RectangleShape2D).append_failure_message(
			child.name
		).is_true()
		var size: Vector2 = (shape_node.shape as RectangleShape2D).size
		assert_bool(size.x > 0.0 and size.y > 0.0).append_failure_message(
			"%s size=%s" % [child.name, size]
		).is_true()


func test_each_step_rises_no_more_than_the_reachable_height() -> void:
	var stage := _instantiate_stage()
	var previous: Node2D = stage.get_node(NodePath(FLOOR_NAME))

	for step_name: String in STEP_NAMES:
		var step: Node2D = stage.get_node(NodePath(step_name))
		var rise: float = absf(previous.global_position.y - step.global_position.y)
		assert_float(rise).append_failure_message(
			"%s -> %s: %f" % [previous.name, step_name, rise]
		).is_less_equal(MAX_STEP_HEIGHT)
		# 段差が「上がっている」ことも見る。すべて同じ高さに並べる退行を弾く
		assert_float(step.global_position.y).append_failure_message(step_name).is_less(
			previous.global_position.y
		)
		previous = step


func test_the_stage_uses_no_tile_map_layer() -> void:
	var stage := _instantiate_stage()
	var class_names: Array[String] = []
	_collect_class_names(stage, class_names)

	assert_array(class_names).append_failure_message(str(class_names)).not_contains(
		["TileMapLayer"]
	)


func test_terrain_sits_on_the_terrain_layer_and_the_player_on_its_own() -> void:
	var stage := _instantiate_stage()

	for child: Node in stage.get_children():
		if child is StaticBody2D:
			assert_int((child as StaticBody2D).collision_layer).append_failure_message(
				child.name
			).is_equal(TERRAIN_LAYER)

	var player: CharacterBody2D = stage.get_node(NodePath(PLAYER_NAME))
	assert_int(player.collision_layer).is_equal(PLAYER_LAYER)


func test_the_player_starts_above_the_floor_and_inside_the_walls() -> void:
	var stage := _instantiate_stage()
	var player: Node2D = stage.get_node(NodePath(PLAYER_NAME))
	var floor_body: Node2D = stage.get_node(NodePath(FLOOR_NAME))
	var left_wall: Node2D = stage.get_node(NodePath(WALL_NAMES[0]))
	var right_wall: Node2D = stage.get_node(NodePath(WALL_NAMES[1]))

	assert_float(player.global_position.y).is_less(floor_body.global_position.y)
	assert_float(player.global_position.x).is_greater(left_wall.global_position.x)
	assert_float(player.global_position.x).is_less(right_wall.global_position.x)


func test_the_main_scene_setting_is_left_untouched() -> void:
	var main_scene: String = str(ProjectSettings.get_setting("application/run/main_scene"))

	assert_str(main_scene).is_equal(EXPECTED_MAIN_SCENE)
