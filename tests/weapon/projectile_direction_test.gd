extends GdUnitTestSuite

# 凍結済みの `tests/weapon/projectile_test.gd` を変えずに新しい契約を固定するため、
# 同じディレクトリへ別のスイートを足す

const PROJECTILE_SCENE: PackedScene = preload("res://src/weapon/projectile.tscn")

const LAUNCH_PARAMETERS: Array = ["direction", "speed", "damage", "max_distance"]

# 呼び出し側の既定値(`PlayerStats` の弾速・威力・射程)と別の値を渡す: 既定のままだと、
# 実装がその値を直書きしても緑になる。既定と一致しないことは番人のケースが固定する
const SPEED: float = 260.0
const DAMAGE: int = 11
const MAX_DISTANCE: float = 600.0
# 拒否される呼び出しには成功する呼び出しと別の値を渡す: 同じ値だと「状態を変えない」ことを
# 観測できない
const REJECTED_SPEED: float = 310.0
const REJECTED_DAMAGE: int = 23
const REJECTED_MAX_DISTANCE: float = 700.0

# 実装の定数を参照しない: 参照するとアサーションが自明になり、文言の退行を検出できない
const ZERO_DIRECTION_ERROR: String = (
	"Projectile.launch(): direction は Vector2i.ZERO であってはならない。弾を進めずに返る"
)

const PROJECTILE_LAYER: int = 1 << 2
const TERRAIN_AND_ENEMY_MASK: int = (1 << 0) | (1 << 3)

const EIGHT_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(1, -1),
	Vector2i(0, -1),
	Vector2i(-1, -1),
	Vector2i(-1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1),
	Vector2i(1, 1),
]
# 水平から 20 度と、8 方向の中間に当たる向き。8 方向だけを見ると、内部で 8 方向へ丸める
# 実装が素通りする
const OFF_AXIS_DEGREES: float = 20.0
const OFF_AXIS_DEGREES_LIST: Array[float] = [
	OFF_AXIS_DEGREES, -OFF_AXIS_DEGREES, 65.0, 112.5, 200.0
]
# 拒否の境界(長さ 0)のすぐ外にある向き。`Vector2.ZERO` と等しくないが、近似の比較では
# ゼロと見なされる短さである。この 1 件が無いと、ガードを近似の比較へ緩める変更が
# 素通りする(残る 2 件はどちらも近似の許容差より十分大きい)
const JUST_OUTSIDE_ZERO_DIRECTION: Vector2 = Vector2(0.000001, 0.0)

# 長さが 1 でない向き。短さも 8 方向からのずれも拒否の理由にしない
const UNNORMALIZED_DIRECTIONS: Array[Vector2] = [
	Vector2(0.3, 0.0), Vector2(3.0, 1.0), JUST_OUTSIDE_ZERO_DIRECTION
]

# 数フレーム(60 Hz で 1 フレーム約 17 ms)に対して余裕を取る: CI のランナーが遅い場合でも
# 物理フレームを消化させる。消化した数はアサーションで確かめるため待ち時間に依存しない
const WAIT_MILLIS: int = 500
const TOLERANCE: Vector2 = Vector2(0.001, 0.001)
# 変位を実測してから速さへ戻すため、位置の許容差より広く取る
const SPEED_TOLERANCE: float = 0.01


func test_launch_declares_the_direction_as_a_float_vector() -> void:
	var projectile: Projectile = _create_projectile()

	var arguments: Array = _launch_arguments(projectile)

	assert_array(arguments).is_not_empty()
	var direction_argument: Dictionary = arguments[0]
	assert_str(direction_argument["name"]).is_equal("direction")
	assert_int(direction_argument["type"]).is_equal(TYPE_VECTOR2)
	# 型が広がったことを、狭い側でないことでも見る: 整数の格子に載らない向きを渡せない型へ
	# 戻す変更を、名前と並びの検査だけでは捕らえられない
	assert_int(direction_argument["type"]).is_not_equal(TYPE_VECTOR2I)


func test_launch_keeps_the_parameter_names_and_order() -> void:
	var projectile: Projectile = _create_projectile()

	var names: Array = []
	for argument: Dictionary in _launch_arguments(projectile):
		names.append(argument["name"])

	assert_array(names).is_equal(LAUNCH_PARAMETERS)


func test_launch_moves_along_every_direction_given_as_vector2i() -> void:
	var projectiles: Array[Projectile] = []
	var expected_directions: Array[Vector2] = []

	for direction: Vector2i in EIGHT_DIRECTIONS:
		var projectile: Projectile = _create_projectile()
		add_child(projectile)
		projectiles.append(projectile)
		expected_directions.append(Vector2(direction))
		# `Vector2i` の実引数を暗黙変換で渡す: 呼び出し側を書き換えないことが型を広げる前提
		projectile.launch(direction, SPEED, DAMAGE, MAX_DISTANCE)

	await await_millis(WAIT_MILLIS)

	_assert_travelled_along(projectiles, expected_directions)


func test_launch_moves_along_directions_off_the_eight_axes() -> void:
	var projectiles: Array[Projectile] = []
	var expected_directions: Array[Vector2] = []

	for degrees: float in OFF_AXIS_DEGREES_LIST:
		var direction: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(degrees))
		var projectile: Projectile = _create_projectile()
		add_child(projectile)
		projectiles.append(projectile)
		expected_directions.append(direction)
		projectile.launch(direction, SPEED, DAMAGE, MAX_DISTANCE)

	await await_millis(WAIT_MILLIS)

	_assert_travelled_along(projectiles, expected_directions)


func test_launch_keeps_the_speed_on_a_diagonal_and_an_off_axis_direction() -> void:
	var diagonal: Projectile = _create_projectile()
	var off_axis: Projectile = _create_projectile()
	add_child(diagonal)
	add_child(off_axis)

	diagonal.launch(Vector2i(1, 1), SPEED, DAMAGE, MAX_DISTANCE)
	off_axis.launch(
		Vector2.RIGHT.rotated(deg_to_rad(OFF_AXIS_DEGREES)), SPEED, DAMAGE, MAX_DISTANCE
	)
	await await_millis(WAIT_MILLIS)

	var projectiles: Array[Projectile] = [diagonal, off_axis]
	for index: int in projectiles.size():
		var projectile: Projectile = projectiles[index]
		var context: String = "index=%s" % index
		var frames: int = projectile.frames_moved
		assert_int(frames).append_failure_message(context).is_greater(0)
		# 期待値を実数で直接書かない: physics/common/physics_ticks_per_second を変えると
		# 変位も変わる
		var measured_speed: float = (
			projectile.position.length() * float(Engine.physics_ticks_per_second) / float(frames)
		)
		assert_float(measured_speed).append_failure_message(context).is_equal_approx(
			SPEED, SPEED_TOLERANCE
		)


func test_launch_accepts_directions_that_are_not_unit_length() -> void:
	var projectiles: Array[Projectile] = []

	for direction: Vector2 in UNNORMALIZED_DIRECTIONS:
		var projectile: Projectile = _create_projectile()
		add_child(projectile)
		projectiles.append(projectile)
		projectile.launch(direction, SPEED, DAMAGE, MAX_DISTANCE)

	await await_millis(WAIT_MILLIS)

	# 進んだことだけでなく、進んだ向きが正規化された向きであることまで見る
	_assert_travelled_along(projectiles, UNNORMALIZED_DIRECTIONS)


# 番人。上の 1 件が「境界のすぐ外」であり続けることを固定する。値を大きく書き換えると、
# 近似の比較へ緩めた実装を落とせなくなる
func test_the_suite_drives_a_direction_that_the_approximate_comparison_calls_zero() -> void:
	assert_bool(JUST_OUTSIDE_ZERO_DIRECTION.is_zero_approx()).is_true()
	assert_bool(JUST_OUTSIDE_ZERO_DIRECTION == Vector2.ZERO).is_false()
	assert_array(UNNORMALIZED_DIRECTIONS).contains([JUST_OUTSIDE_ZERO_DIRECTION])


func test_launch_rejects_a_zero_vector2_direction() -> void:
	var projectile: Projectile = _create_projectile()
	add_child(projectile)

	await assert_error(
		func() -> void: projectile.launch(
			Vector2.ZERO, REJECTED_SPEED, REJECTED_DAMAGE, REJECTED_MAX_DISTANCE
		)
	).is_push_error(ZERO_DIRECTION_ERROR)

	await _assert_stays_in_place(projectile)


# `Vector2i.ZERO` を別のケースにする: 暗黙変換の後にゼロのガードが働くことを見る
func test_launch_rejects_a_zero_vector2i_direction() -> void:
	var projectile: Projectile = _create_projectile()
	add_child(projectile)

	await assert_error(
		func() -> void: projectile.launch(
			Vector2i.ZERO, REJECTED_SPEED, REJECTED_DAMAGE, REJECTED_MAX_DISTANCE
		)
	).is_push_error(ZERO_DIRECTION_ERROR)

	await _assert_stays_in_place(projectile)


func test_projectile_scene_keeps_its_collision_layer_and_mask() -> void:
	var projectile: Projectile = _create_projectile()

	assert_int(projectile.collision_layer).is_equal(PROJECTILE_LAYER)
	assert_int(projectile.collision_mask).is_equal(TERRAIN_AND_ENEMY_MASK)


# 番人。このスイートが渡す値が呼び出し側の既定値と一致すると、実装が既定値を直書きしても
# 緑になる。既定値が動いたらここで気付く
func test_the_suite_passes_values_that_differ_from_the_caller_defaults() -> void:
	var stats: PlayerStats = PlayerStats.new()

	assert_float(SPEED).is_not_equal(stats.primary_bullet_speed)
	assert_float(SPEED).is_not_equal(stats.secondary_bullet_speed)
	assert_float(REJECTED_SPEED).is_not_equal(stats.primary_bullet_speed)
	assert_float(REJECTED_SPEED).is_not_equal(stats.secondary_bullet_speed)
	assert_int(DAMAGE).is_not_equal(stats.primary_damage)
	assert_int(DAMAGE).is_not_equal(stats.secondary_damage)
	assert_int(REJECTED_DAMAGE).is_not_equal(stats.primary_damage)
	assert_int(REJECTED_DAMAGE).is_not_equal(stats.secondary_damage)
	assert_float(MAX_DISTANCE).is_not_equal(stats.bullet_max_distance)
	assert_float(REJECTED_MAX_DISTANCE).is_not_equal(stats.bullet_max_distance)
	# 成功する呼び出しと拒否される呼び出しが同じ値だと、状態を変えないことを観測できない
	assert_float(REJECTED_SPEED).is_not_equal(SPEED)
	assert_int(REJECTED_DAMAGE).is_not_equal(DAMAGE)
	assert_float(REJECTED_MAX_DISTANCE).is_not_equal(MAX_DISTANCE)


func _create_projectile() -> Projectile:
	return auto_free(PROJECTILE_SCENE.instantiate())


func _assert_travelled_along(projectiles: Array[Projectile], directions: Array[Vector2]) -> void:
	for index: int in projectiles.size():
		var projectile: Projectile = projectiles[index]
		var direction: Vector2 = directions[index]
		var context: String = "index=%s direction=%s" % [index, direction]
		# 待ちが足りずフレームを消化しなかった場合と、動かなかった場合を区別する
		var frames: int = projectile.frames_moved
		assert_int(frames).append_failure_message(context).is_greater(0)
		var expected: Vector2 = direction.normalized() * _frame_step() * frames
		assert_vector(projectile.position).append_failure_message(context).is_equal_approx(
			expected, TOLERANCE
		)


# 拒否された弾が進まないことを確かめる。待ちの間に物理フレームが進んだことは、
# 同じ待ちの中で発射済みの弾が動いたことで示す
func _assert_stays_in_place(projectile: Projectile) -> void:
	var witness: Projectile = _create_projectile()
	add_child(witness)

	witness.launch(Vector2i(1, 0), SPEED, DAMAGE, MAX_DISTANCE)
	await await_millis(WAIT_MILLIS)

	assert_int(witness.frames_moved).is_greater(0)
	assert_int(projectile.frames_moved).is_zero()
	assert_vector(projectile.position).is_equal(Vector2.ZERO)
	# 引数を取り込んでいないことも見る: ガードが代入より後ろにあると damage が残る
	assert_int(projectile.damage).is_zero()


func _frame_step() -> float:
	return SPEED / float(Engine.physics_ticks_per_second)


func _launch_arguments(projectile: Projectile) -> Array:
	for method: Dictionary in projectile.get_method_list():
		if method["name"] == "launch":
			return method["args"]
	return []
