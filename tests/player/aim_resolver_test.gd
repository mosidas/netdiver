extends GdUnitTestSuite

const MOVE_X_VALUES: Array[float] = [-1.0, 0.0, 1.0]
const AIM_Y_VALUES: Array[float] = [-1.0, 0.0, 1.0]
const FACING_VALUES: Array[int] = [-1, 1]
const ON_FLOOR_VALUES: Array[bool] = [false, true]

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

# 非接地の入力で 8 方向を網羅する: 接地では下の成分が落ち、下向きの 3 方向へ届かない
const AIRBORNE_INPUT_TO_DIRECTION: Dictionary = {
	Vector2(1.0, 0.0): Vector2i(1, 0),
	Vector2(1.0, -1.0): Vector2i(1, -1),
	Vector2(0.0, -1.0): Vector2i(0, -1),
	Vector2(-1.0, -1.0): Vector2i(-1, -1),
	Vector2(-1.0, 0.0): Vector2i(-1, 0),
	Vector2(-1.0, 1.0): Vector2i(-1, 1),
	Vector2(0.0, 1.0): Vector2i(0, 1),
	Vector2(1.0, 1.0): Vector2i(1, 1),
}

# 接地で到達できる 5 方向。下の成分を落とす条件が「下だけ」に効くことを、上と水平の側から縛る
const ON_FLOOR_INPUT_TO_DIRECTION: Dictionary = {
	Vector2(1.0, 0.0): Vector2i(1, 0),
	Vector2(1.0, -1.0): Vector2i(1, -1),
	Vector2(0.0, -1.0): Vector2i(0, -1),
	Vector2(-1.0, -1.0): Vector2i(-1, -1),
	Vector2(-1.0, 0.0): Vector2i(-1, 0),
}

# 入力と逆向きの facing を渡す: 入力から決まるはずの方向を facing で埋めた実装を失敗させる
const OPPOSING_FACING: int = -1


func test_resolve_returns_one_of_the_eight_directions_for_every_input() -> void:
	for move_x: float in MOVE_X_VALUES:
		for aim_y: float in AIM_Y_VALUES:
			for facing: int in FACING_VALUES:
				for is_on_floor: bool in ON_FLOOR_VALUES:
					var direction: Vector2i = AimResolver.resolve(move_x, aim_y, facing, is_on_floor)
					var context: String = (
						"move_x=%s aim_y=%s facing=%s is_on_floor=%s"
						% [move_x, aim_y, facing, is_on_floor]
					)

					assert_array(EIGHT_DIRECTIONS).append_failure_message(context).contains([direction])


func test_resolve_covers_the_eight_directions_while_airborne() -> void:
	for input: Vector2 in AIRBORNE_INPUT_TO_DIRECTION:
		var expected: Vector2i = AIRBORNE_INPUT_TO_DIRECTION[input]

		var direction: Vector2i = AimResolver.resolve(input.x, input.y, 1, false)

		assert_vector(direction).append_failure_message("input=%s" % input).is_equal(expected)


func test_resolve_covers_the_reachable_directions_while_on_floor() -> void:
	for input: Vector2 in ON_FLOOR_INPUT_TO_DIRECTION:
		var expected: Vector2i = ON_FLOOR_INPUT_TO_DIRECTION[input]

		var direction: Vector2i = AimResolver.resolve(input.x, input.y, OPPOSING_FACING, true)

		assert_vector(direction).append_failure_message("input=%s" % input).is_equal(expected)


func test_resolve_returns_the_facing_direction_without_input_while_facing_right() -> void:
	var direction: Vector2i = AimResolver.resolve(0.0, 0.0, 1, false)

	assert_vector(direction).is_equal(Vector2i(1, 0))


func test_resolve_returns_the_facing_direction_without_input_while_facing_left() -> void:
	var direction: Vector2i = AimResolver.resolve(0.0, 0.0, -1, false)

	assert_vector(direction).is_equal(Vector2i(-1, 0))


func test_resolve_combines_the_right_and_the_up_input() -> void:
	var direction: Vector2i = AimResolver.resolve(1.0, -1.0, 1, false)

	assert_vector(direction).is_equal(Vector2i(1, -1))


func test_resolve_drops_the_down_component_while_on_floor() -> void:
	var direction: Vector2i = AimResolver.resolve(1.0, 1.0, OPPOSING_FACING, true)

	assert_vector(direction).is_equal(Vector2i(1, 0))


func test_resolve_keeps_the_down_component_while_airborne() -> void:
	var direction: Vector2i = AimResolver.resolve(1.0, 1.0, 1, false)

	assert_vector(direction).is_equal(Vector2i(1, 1))


func test_resolve_falls_back_to_facing_when_the_down_component_is_dropped() -> void:
	var direction: Vector2i = AimResolver.resolve(0.0, 1.0, -1, true)

	assert_vector(direction).is_equal(Vector2i(-1, 0))


func test_resolve_falls_back_to_the_opposite_facing_when_the_down_component_is_dropped() -> void:
	var direction: Vector2i = AimResolver.resolve(0.0, 1.0, 1, true)

	assert_vector(direction).is_equal(Vector2i(1, 0))
