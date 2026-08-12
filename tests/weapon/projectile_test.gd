extends GdUnitTestSuite

const PROJECTILE_SCENE: PackedScene = preload("res://src/weapon/projectile.tscn")
const PROJECTILE_SOURCE_PATH: String = "res://src/weapon/projectile.gd"

const PLACEHOLDER_SIZE: Vector2 = Vector2(4.0, 4.0)
const PROJECTILE_LAYER: int = 1 << 2
const TERRAIN_AND_ENEMY_MASK: int = (1 << 0) | (1 << 3)
const TERRAIN_LAYER: int = 1 << 0
const PLAYER_LAYER: int = 1 << 1

const LAUNCH_PARAMETERS: Array = ["direction", "speed", "damage", "max_distance"]

const SPEED: float = 180.0
const DAMAGE: int = 7
const MAX_DISTANCE: float = 400.0
# 弾が数フレームで届く位置に置く: 待ちの間に必ず接触させ、通り抜けの検証でも余裕を残す
const TERRAIN_POSITION: Vector2 = Vector2(20.0, 0.0)
const TERRAIN_SIZE: Vector2 = Vector2(16.0, 16.0)
# 待ちの間に必ず超える短さにする。射程で解放されることの検証を待ち時間に頼らない
const SHORT_MAX_DISTANCE: float = 30.0
# 原点からの距離が MAX_DISTANCE を超える発射位置。距離の基準が原点だと即座に解放される
const FAR_LAUNCH_POSITION: Vector2 = Vector2(500.0, 0.0)
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
	var expected_x: float = _frame_step() * frames
	assert_vector(projectile.position).is_equal_approx(Vector2(expected_x, 0.0), TOLERANCE)


func test_launch_normalizes_a_diagonal_direction() -> void:
	var projectile: Projectile = _create_projectile()
	add_child(projectile)

	projectile.launch(Vector2i(1, -1), SPEED, DAMAGE, MAX_DISTANCE)
	await await_millis(WAIT_MILLIS)

	var frames: int = projectile.frames_moved
	assert_int(frames).is_greater(0)
	var expected_distance: float = _frame_step() * frames
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


func test_projectile_frees_itself_when_it_touches_terrain() -> void:
	var terrain: StaticBody2D = _create_terrain(TERRAIN_LAYER)
	var projectile: Projectile = _create_projectile()
	var exit_positions: Array[Vector2] = []
	add_child(terrain)
	add_child(projectile)
	_record_position_on_exit(projectile, exit_positions)

	projectile.launch(Vector2i(1, 0), SPEED, DAMAGE, MAX_DISTANCE)
	await await_millis(WAIT_MILLIS)

	assert_bool(is_instance_valid(projectile)).is_false()
	assert_array(exit_positions).has_size(1)
	# 縁が重なる位置より手前で解放されていたら、地形との接触以外が原因である
	var contact_x: float = TERRAIN_POSITION.x - (TERRAIN_SIZE.x + PLACEHOLDER_SIZE.x) * 0.5
	var step: float = _frame_step()
	assert_float(exit_positions[0].x).is_greater(contact_x)
	# 上限は 2 フレーム分。重なりに届くまでに最大 1 フレーム、`Area2D` の重なりの通知が
	# 1 物理フレーム遅れるためさらに 1 フレーム(実測: 接触 10.0 に対し解放は 15.0 = 5 フレーム目、
	# 最初に重なるのは 4 フレーム目)。これを超えて進んでいたら判定が遅れている
	assert_float(exit_positions[0].x).is_less_equal(contact_x + 2.0 * step)


func test_projectile_flies_through_a_body_outside_its_collision_mask() -> void:
	var terrain: StaticBody2D = _create_terrain(PLAYER_LAYER)
	var projectile: Projectile = _create_projectile()
	add_child(terrain)
	add_child(projectile)

	projectile.launch(Vector2i(1, 0), SPEED, DAMAGE, MAX_DISTANCE)
	await await_millis(WAIT_MILLIS)

	assert_bool(is_instance_valid(projectile)).is_true()
	var frames: int = projectile.frames_moved
	assert_int(frames).is_greater(0)
	# 矩形の中心を越えたことで、重なりが起きたうえで解放されなかったことを示す
	assert_float(projectile.position.x).is_greater(TERRAIN_POSITION.x)


func test_projectile_frees_itself_when_it_exceeds_max_distance() -> void:
	var projectile: Projectile = _create_projectile()
	var exit_positions: Array[Vector2] = []
	add_child(projectile)
	_record_position_on_exit(projectile, exit_positions)

	projectile.launch(Vector2i(1, 0), SPEED, DAMAGE, SHORT_MAX_DISTANCE)
	await await_millis(WAIT_MILLIS)

	assert_bool(is_instance_valid(projectile)).is_false()
	assert_array(exit_positions).has_size(1)
	var travelled: float = exit_positions[0].length()
	assert_float(travelled).is_greater(SHORT_MAX_DISTANCE)
	# 超えた最初のフレームで解放する。まるまる 1 フレーム分の余裕までを許容する
	assert_float(travelled).is_less_equal(SHORT_MAX_DISTANCE + _frame_step())


# 斜めを軸方向と別のケースにする: 距離を x 成分だけで測る実装は軸方向のケースを素通りする
func test_max_distance_is_measured_along_a_diagonal_direction() -> void:
	var projectile: Projectile = _create_projectile()
	var exit_positions: Array[Vector2] = []
	add_child(projectile)
	_record_position_on_exit(projectile, exit_positions)

	projectile.launch(Vector2i(1, -1), SPEED, DAMAGE, SHORT_MAX_DISTANCE)
	await await_millis(WAIT_MILLIS)

	assert_bool(is_instance_valid(projectile)).is_false()
	assert_array(exit_positions).has_size(1)
	var travelled: float = exit_positions[0].length()
	assert_float(travelled).is_greater(SHORT_MAX_DISTANCE)
	assert_float(travelled).is_less_equal(SHORT_MAX_DISTANCE + _frame_step())


func test_projectile_keeps_flying_while_it_is_within_max_distance() -> void:
	var projectile: Projectile = _create_projectile()
	add_child(projectile)

	projectile.launch(Vector2i(1, 0), SPEED, DAMAGE, MAX_DISTANCE)
	await await_millis(WAIT_MILLIS)

	assert_bool(is_instance_valid(projectile)).is_true()
	var frames: int = projectile.frames_moved
	assert_int(frames).is_greater(0)
	# 射程に届かないまま待ちが終わったことを確かめる。届いていれば解放が正しく、検証が空振りする
	var travelled: float = _frame_step() * frames
	assert_float(travelled).is_less(MAX_DISTANCE)
	assert_vector(projectile.position).is_equal_approx(Vector2(travelled, 0.0), TOLERANCE)


func test_max_distance_is_measured_from_the_launch_position() -> void:
	var projectile: Projectile = _create_projectile()
	projectile.position = FAR_LAUNCH_POSITION
	add_child(projectile)

	projectile.launch(Vector2i(1, 0), SPEED, DAMAGE, MAX_DISTANCE)
	await await_millis(WAIT_MILLIS)

	assert_bool(is_instance_valid(projectile)).is_true()
	var frames: int = projectile.frames_moved
	assert_int(frames).is_greater(0)
	var travelled: float = _frame_step() * frames
	assert_float(travelled).is_less(MAX_DISTANCE)
	assert_vector(projectile.position).is_equal_approx(
		FAR_LAUNCH_POSITION + Vector2(travelled, 0.0), TOLERANCE
	)


func _create_projectile() -> Projectile:
	return auto_free(PROJECTILE_SCENE.instantiate())


func _create_terrain(layer: int) -> StaticBody2D:
	var terrain: StaticBody2D = auto_free(StaticBody2D.new())
	terrain.collision_layer = layer
	terrain.collision_mask = 0
	terrain.position = TERRAIN_POSITION
	# 親を auto_free するため子は登録しない: 親の解放で一緒に解放される
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = TERRAIN_SIZE
	collision_shape.shape = rectangle
	terrain.add_child(collision_shape)
	return terrain


# 解放後は位置を読めないため、ツリーを離れる直前の位置を控える
func _record_position_on_exit(projectile: Projectile, positions: Array[Vector2]) -> void:
	var record: Callable = func() -> void: positions.append(projectile.position)
	projectile.tree_exiting.connect(record)


func _frame_step() -> float:
	return SPEED / float(Engine.physics_ticks_per_second)


func _launch_parameter_names(projectile: Projectile) -> Array:
	var names: Array = []
	for method: Dictionary in projectile.get_method_list():
		if method["name"] != "launch":
			continue
		for argument: Dictionary in method["args"]:
			names.append(argument["name"])
	return names
