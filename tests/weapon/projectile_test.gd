extends GdUnitTestSuite

const PROJECTILE_SCENE: PackedScene = preload("res://src/weapon/projectile.tscn")
const PROJECTILE_SOURCE_PATH: String = "res://src/weapon/projectile.gd"

const PLACEHOLDER_SIZE: Vector2 = Vector2(4.0, 4.0)
const PROJECTILE_LAYER: int = 1 << 2
const TERRAIN_AND_ENEMY_MASK: int = (1 << 0) | (1 << 3)

const LAUNCH_PARAMETERS: Array = ["direction", "speed", "damage", "max_distance"]

const SPEED: float = 180.0
const DAMAGE: int = 7
const MAX_DISTANCE: float = 400.0
# 数フレーム(60 Hz で 1 フレーム約 17 ms)に対して余裕を取る: CI のランナーが遅い場合でも
# 物理フレームを消化させる。消化した数はアサーションで確かめるため待ち時間に依存しない
const WAIT_MILLIS: int = 500
const TOLERANCE: Vector2 = Vector2(0.001, 0.001)


func test_launch_moves_the_projectile_along_the_direction() -> void:
	var projectile: Projectile = _create_projectile()
	add_child(projectile)

	projectile.launch(Vector2i(1, 0), SPEED, DAMAGE, MAX_DISTANCE)
	await await_millis(WAIT_MILLIS)

	# 待ちが足りずフレームを消化しなかった場合と、動かなかった場合を区別する
	var frames: int = projectile.frames_moved
	assert_int(frames).is_greater(0)
	# 期待値を実数で直接書かない: physics/common/physics_ticks_per_second を変えると変位も変わる
	var expected_x: float = SPEED / float(Engine.physics_ticks_per_second) * frames
	assert_vector(projectile.position).is_equal_approx(Vector2(expected_x, 0.0), TOLERANCE)


func test_launch_normalizes_a_diagonal_direction() -> void:
	var projectile: Projectile = _create_projectile()
	add_child(projectile)

	projectile.launch(Vector2i(1, -1), SPEED, DAMAGE, MAX_DISTANCE)
	await await_millis(WAIT_MILLIS)

	var frames: int = projectile.frames_moved
	assert_int(frames).is_greater(0)
	var expected_distance: float = SPEED / float(Engine.physics_ticks_per_second) * frames
	var expected_position: Vector2 = Vector2(1.0, -1.0).normalized() * expected_distance
	assert_float(projectile.position.length()).is_equal_approx(expected_distance, 0.001)
	assert_vector(projectile.position).is_equal_approx(expected_position, TOLERANCE)


func test_projectile_stays_in_place_until_launched() -> void:
	var projectile: Projectile = _create_projectile()
	var witness: Projectile = _create_projectile()
	add_child(projectile)
	add_child(witness)

	witness.launch(Vector2i(1, 0), SPEED, DAMAGE, MAX_DISTANCE)
	await await_millis(WAIT_MILLIS)

	# 待ちの間に物理フレームが進んだことを、発射済みの弾で示す
	assert_int(witness.frames_moved).is_greater(0)
	assert_int(projectile.frames_moved).is_zero()
	assert_vector(projectile.position).is_equal(Vector2.ZERO)


func test_damage_comes_from_launch_and_stays_constant() -> void:
	var projectile: Projectile = _create_projectile()
	add_child(projectile)

	projectile.launch(Vector2i(1, 0), SPEED, DAMAGE, MAX_DISTANCE)
	assert_int(projectile.damage).is_equal(DAMAGE)

	await await_millis(WAIT_MILLIS)

	assert_int(projectile.frames_moved).is_greater(0)
	assert_int(projectile.damage).is_equal(DAMAGE)


func test_launch_takes_max_distance_as_a_parameter() -> void:
	var projectile: Projectile = _create_projectile()

	assert_array(_launch_parameter_names(projectile)).is_equal(LAUNCH_PARAMETERS)


func test_projectile_does_not_read_player_stats() -> void:
	var source: String = FileAccess.get_file_as_string(PROJECTILE_SOURCE_PATH)

	assert_str(source).is_not_empty()
	assert_str(source).not_contains("PlayerStats")


func test_projectile_scene_is_on_the_player_projectile_layer() -> void:
	var projectile: Projectile = _create_projectile()

	assert_int(projectile.collision_layer).is_equal(PROJECTILE_LAYER)
	assert_int(projectile.collision_mask).is_equal(TERRAIN_AND_ENEMY_MASK)


func test_projectile_scene_centers_a_4x4_placeholder_on_the_origin() -> void:
	var projectile: Projectile = _create_projectile()
	var placeholder: ColorRect = projectile.get_node("Placeholder")
	var collision_shape: CollisionShape2D = projectile.get_node("CollisionShape2D")
	var shape: RectangleShape2D = collision_shape.shape

	assert_vector(placeholder.size).is_equal(PLACEHOLDER_SIZE)
	assert_vector(placeholder.position).is_equal(-PLACEHOLDER_SIZE * 0.5)
	assert_vector(shape.size).is_equal(PLACEHOLDER_SIZE)
	assert_vector(collision_shape.position).is_equal(Vector2.ZERO)


func _create_projectile() -> Projectile:
	return auto_free(PROJECTILE_SCENE.instantiate())


func _launch_parameter_names(projectile: Projectile) -> Array:
	var names: Array = []
	for method: Dictionary in projectile.get_method_list():
		if method["name"] != "launch":
			continue
		for argument: Dictionary in method["args"]:
			names.append(argument["name"])
	return names
