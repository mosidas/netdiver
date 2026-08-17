extends GdUnitTestSuite

const EIGHT_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(1, 1),
	Vector2i(0, 1),
	Vector2i(-1, 1),
	Vector2i(-1, 0),
	Vector2i(-1, -1),
	Vector2i(0, -1),
	Vector2i(1, -1),
]

# 期待値を実装の環から導かない: 導くと、環を逆順に並べた実装が自分の並びで自分を通す。
# 8 方向すべてを表に載せる: 1 方向だけでは、環の回り方を取り違えた実装が素通りする
const DIRECTION_TO_SPREAD: Dictionary = {
	Vector2i(1, 0): [Vector2i(1, 0), Vector2i(1, -1), Vector2i(1, 1)],
	Vector2i(1, 1): [Vector2i(1, 1), Vector2i(1, 0), Vector2i(0, 1)],
	Vector2i(0, 1): [Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1)],
	Vector2i(-1, 1): [Vector2i(-1, 1), Vector2i(0, 1), Vector2i(-1, 0)],
	Vector2i(-1, 0): [Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(-1, -1)],
	Vector2i(-1, -1): [Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(0, -1)],
	Vector2i(0, -1): [Vector2i(0, -1), Vector2i(-1, -1), Vector2i(1, -1)],
	Vector2i(1, -1): [Vector2i(1, -1), Vector2i(0, -1), Vector2i(1, 0)],
}

# 環の折り返しをまたぐ 2 方向。表の中に埋もれると、折り返しだけを落とす実装の失敗が
# 他の 6 方向の成功に紛れる
const RIGHT: Vector2i = Vector2i(1, 0)
const RIGHT_SPREAD: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, -1), Vector2i(1, 1)]
const UP_RIGHT: Vector2i = Vector2i(1, -1)
const UP_RIGHT_SPREAD: Array[Vector2i] = [Vector2i(1, -1), Vector2i(0, -1), Vector2i(1, 0)]

# Vector2i.ZERO に加えて「8 方向のすぐ外」を置く。x だけ・y だけが範囲の外の値も入れる:
# 片方の成分しか検査しない実装を失敗させる
const INVALID_DIRECTIONS: Array[Vector2i] = [
	Vector2i.ZERO,
	Vector2i(2, 0),
	Vector2i(0, -2),
	Vector2i(1, 2),
	Vector2i(-2, -1),
]

# 実装の文言を固定する: 文言が変わると、利用者がログから原因を辿る手順が変わる
const INVALID_DIRECTION_ERROR_FORMAT: String = (
	"SpreadResolver.resolve(): direction は 8 方向のいずれかでなければならない(現在値: %s)。"
	+ "空の配列を返す"
)


func test_resolve_returns_three_elements_for_every_direction() -> void:
	for direction: Vector2i in EIGHT_DIRECTIONS:
		var spread: Array[Vector2i] = SpreadResolver.resolve(direction)

		assert_array(spread).append_failure_message("direction=%s" % direction).has_size(3)


func test_resolve_returns_the_argument_first_for_every_direction() -> void:
	for direction: Vector2i in EIGHT_DIRECTIONS:
		var spread: Array[Vector2i] = SpreadResolver.resolve(direction)

		assert_vector(spread[0]).append_failure_message("direction=%s" % direction).is_equal(
			direction
		)


func test_resolve_returns_the_ring_neighbours_for_every_direction() -> void:
	for direction: Vector2i in DIRECTION_TO_SPREAD:
		var expected: Array = DIRECTION_TO_SPREAD[direction]

		var spread: Array[Vector2i] = SpreadResolver.resolve(direction)

		# 手前と先を同じケースで対にして比較する: 片方だけを見ると、環を逆順に並べた実装が
		# 半分のケースで緑になる
		assert_vector(spread[1]).append_failure_message("direction=%s" % direction).is_equal(
			expected[1]
		)
		assert_vector(spread[2]).append_failure_message("direction=%s" % direction).is_equal(
			expected[2]
		)


func test_resolve_wraps_the_ring_at_the_right_direction() -> void:
	var spread: Array[Vector2i] = SpreadResolver.resolve(RIGHT)

	assert_array(spread).is_equal(RIGHT_SPREAD)


func test_resolve_wraps_the_ring_at_the_up_right_direction() -> void:
	var spread: Array[Vector2i] = SpreadResolver.resolve(UP_RIGHT)

	assert_array(spread).is_equal(UP_RIGHT_SPREAD)


func test_resolve_returns_distinct_directions_for_every_direction() -> void:
	for direction: Vector2i in EIGHT_DIRECTIONS:
		var spread: Array[Vector2i] = SpreadResolver.resolve(direction)

		for index: int in spread.size():
			for other: int in spread.size():
				if index == other:
					continue

				assert_vector(spread[index]).append_failure_message(
					"direction=%s index=%s other=%s" % [direction, index, other]
				).is_not_equal(spread[other])


func test_resolve_returns_only_eight_directions_for_every_direction() -> void:
	for direction: Vector2i in EIGHT_DIRECTIONS:
		var spread: Array[Vector2i] = SpreadResolver.resolve(direction)

		assert_array(EIGHT_DIRECTIONS).append_failure_message("direction=%s" % direction).contains(
			spread
		)


func test_resolve_never_returns_the_zero_direction() -> void:
	for direction: Vector2i in EIGHT_DIRECTIONS:
		var spread: Array[Vector2i] = SpreadResolver.resolve(direction)

		for element: Vector2i in spread:
			assert_vector(element).append_failure_message("direction=%s" % direction).is_not_equal(
				Vector2i.ZERO
			)


func test_resolve_returns_an_empty_array_for_an_invalid_direction() -> void:
	for direction: Vector2i in INVALID_DIRECTIONS:
		var spread: Array[Vector2i] = SpreadResolver.resolve(direction)

		assert_array(spread).append_failure_message("direction=%s" % direction).is_empty()


func test_resolve_pushes_an_error_for_an_invalid_direction() -> void:
	for direction: Vector2i in INVALID_DIRECTIONS:
		var expected: String = INVALID_DIRECTION_ERROR_FORMAT % direction

		await assert_error(
			func() -> void: SpreadResolver.resolve(direction)
		).is_push_error(expected)


func test_resolve_does_not_push_an_error_for_the_eight_directions() -> void:
	for direction: Vector2i in EIGHT_DIRECTIONS:
		await assert_error(func() -> void: SpreadResolver.resolve(direction)).is_success()


func test_resolve_returns_an_equal_array_for_the_same_argument() -> void:
	for direction: Vector2i in EIGHT_DIRECTIONS:
		var first: Array[Vector2i] = SpreadResolver.resolve(direction)
		var second: Array[Vector2i] = SpreadResolver.resolve(direction)

		assert_array(second).append_failure_message("direction=%s" % direction).is_equal(first)


func test_resolve_returns_a_separate_array_on_each_call() -> void:
	var first: Array[Vector2i] = SpreadResolver.resolve(RIGHT)
	var second: Array[Vector2i] = SpreadResolver.resolve(RIGHT)

	# 戻り値を書き換える: 内部の配列をそのまま返す実装なら、以降の呼び出しに汚染が残る
	first[0] = Vector2i.ZERO

	assert_array(second).is_equal(RIGHT_SPREAD)
	assert_array(SpreadResolver.resolve(RIGHT)).is_equal(RIGHT_SPREAD)
