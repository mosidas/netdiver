extends GdUnitTestSuite

const FLOAT_TOLERANCE: float = 0.001
const VECTOR_TOLERANCE: Vector2 = Vector2(0.001, 0.001)

# 実装の定数を期待値に使わない: SPREAD_DEGREES を参照すると、値を書き換える変異が
# 期待値も一緒に動かして素通りする。20 度はテスト側の自前の値として持つ
const SPREAD_DEGREES: float = 20.0
const BETWEEN_DEGREES: float = 40.0

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

# 斜めを正規化した成分。sqrt(0.5)
const DIAGONAL: float = 0.7071068

# 期待値を Vector2(direction).normalized() で導かない: 導くと、実装と同じ式が
# 実装を自分で通す。8 方向すべてを表に載せる: 1 方向だけでは、回す向きを
# 取り違えた実装が素通りする
const DIRECTION_TO_CENTER: Dictionary = {
	Vector2i(1, 0): Vector2(1.0, 0.0),
	Vector2i(1, 1): Vector2(DIAGONAL, DIAGONAL),
	Vector2i(0, 1): Vector2(0.0, 1.0),
	Vector2i(-1, 1): Vector2(-DIAGONAL, DIAGONAL),
	Vector2i(-1, 0): Vector2(-1.0, 0.0),
	Vector2i(-1, -1): Vector2(-DIAGONAL, -DIAGONAL),
	Vector2i(0, -1): Vector2(0.0, -1.0),
	Vector2i(1, -1): Vector2(DIAGONAL, -DIAGONAL),
}

# Vector2i.ZERO に加えて「8 方向のすぐ外」を置く。x だけ・y だけが範囲の外の値も入れる:
# 片方の成分しか検査しない実装と、境界を緩める実装を失敗させる
const INVALID_DIRECTIONS: Array[Vector2i] = [
	Vector2i.ZERO,
	Vector2i(2, 0),
	Vector2i(0, -2),
	Vector2i(1, 2),
	Vector2i(-2, -1),
]

# 実装の文言を参照せず複製する: 参照すると、文言を書き換える変異が期待値も
# 一緒に動かして自己成就する
const INVALID_DIRECTION_ERROR_FORMAT: String = (
	"SpreadResolver.resolve(): direction は 8 方向のいずれかでなければならない(現在値: %s)。"
	+ "空の配列を返す"
)

const PLAYER_SOURCE_PATH: String = "res://src/player/player.gd"
const PLAYER_STATS_SOURCE_PATH: String = "res://src/player/player_stats.gd"

# 拡散の角度を組み立てる字面を走査する。数値の 20 そのものを走査しない:
# PlayerStats の regen_per_second が既に 20.0 であり、拡散の角度と区別できない
const SPREAD_ANGLE_MARKERS: Array[String] = [
	"SPREAD_DEGREES",
	"spread_degrees",
	"deg_to_rad",
	"rotated(",
]

const SPREAD_PROPERTY_MARKERS: Array[String] = ["spread", "degree", "angle", "rotat"]

const AIM_RESOLVER_SOURCE_PATH: String = "res://src/player/aim_resolver.gd"

# 01c1d0e 時点の src/player/aim_resolver.gd の内容。参照先の中身まで見る:
# 存在だけを見る検査は、中身を書き換える変異を通す
const AIM_RESOLVER_SOURCE_SHA256: String = (
	"fdc1323f0c696e46898f9241bee351feebd3d5dd54978203faf43c1d3048cea9"
)


func _editor_visible_property_names(object: Object) -> Array[String]:
	var names: Array[String] = []
	for property: Dictionary in object.get_property_list():
		var usage: int = property["usage"]
		if usage & PROPERTY_USAGE_EDITOR != 0 and usage & PROPERTY_USAGE_SCRIPT_VARIABLE != 0:
			names.append(property["name"])
	return names


func _resolve_argument_types(resolver: SpreadResolver) -> Array[int]:
	var types: Array[int] = []
	for method: Dictionary in resolver.get_method_list():
		if method["name"] != "resolve":
			continue
		for argument: Dictionary in method["args"]:
			types.append(argument["type"])
	return types


func test_the_direction_table_covers_the_eight_directions() -> void:
	# 表が 8 方向を網羅していることを固定する: 表から 1 方向が抜けると、
	# 表を回るケースがその方向を 1 度も見ないまま緑になる
	assert_array(EIGHT_DIRECTIONS).has_size(8)
	assert_int(DIRECTION_TO_CENTER.size()).is_equal(8)
	for direction: Vector2i in EIGHT_DIRECTIONS:
		assert_bool(DIRECTION_TO_CENTER.has(direction)).append_failure_message(
			"direction=%s" % direction
		).is_true()


func test_resolve_returns_three_elements_for_every_direction() -> void:
	for direction: Vector2i in EIGHT_DIRECTIONS:
		var spread: Array[Vector2] = SpreadResolver.resolve(direction)

		assert_array(spread).append_failure_message("direction=%s" % direction).has_size(3)


func test_resolve_returns_a_vector2_typed_array_for_every_direction() -> void:
	for direction: Vector2i in EIGHT_DIRECTIONS:
		var spread: Array[Vector2] = SpreadResolver.resolve(direction)

		assert_int(spread.get_typed_builtin()).append_failure_message(
			"direction=%s" % direction
		).is_equal(TYPE_VECTOR2)


func test_resolve_returns_the_normalized_argument_first_for_every_direction() -> void:
	for direction: Vector2i in DIRECTION_TO_CENTER:
		var expected: Vector2 = DIRECTION_TO_CENTER[direction]

		var spread: Array[Vector2] = SpreadResolver.resolve(direction)

		assert_vector(spread[0]).append_failure_message("direction=%s" % direction).is_equal_approx(
			expected, VECTOR_TOLERANCE
		)


func test_resolve_turns_the_second_and_third_to_opposite_sides_for_every_direction() -> void:
	for direction: Vector2i in EIGHT_DIRECTIONS:
		var spread: Array[Vector2] = SpreadResolver.resolve(direction)

		# 手前と先を同じケースで対にし、符号込みで比べる: 片側だけ・絶対値だけを見ると、
		# 回す符号を反転する変異が半分のケースで緑になる。画面座標(y は下向き)では
		# 反時計回りが負の角に当たる
		assert_float(spread[0].angle_to(spread[1])).append_failure_message(
			"direction=%s" % direction
		).is_equal_approx(-deg_to_rad(SPREAD_DEGREES), FLOAT_TOLERANCE)
		assert_float(spread[0].angle_to(spread[2])).append_failure_message(
			"direction=%s" % direction
		).is_equal_approx(deg_to_rad(SPREAD_DEGREES), FLOAT_TOLERANCE)


func test_resolve_separates_the_second_and_third_by_forty_degrees() -> void:
	# 1 番目との角とは独立に測る: 両方を 0 度回す変異は 1 番目との比較では落ちても
	# 互いの間隔を見ないと残る組み合わせがある
	for direction: Vector2i in EIGHT_DIRECTIONS:
		var spread: Array[Vector2] = SpreadResolver.resolve(direction)

		assert_float(spread[1].angle_to(spread[2])).append_failure_message(
			"direction=%s" % direction
		).is_equal_approx(deg_to_rad(BETWEEN_DEGREES), FLOAT_TOLERANCE)


func test_resolve_returns_unit_vectors_for_every_direction() -> void:
	for direction: Vector2i in EIGHT_DIRECTIONS:
		var spread: Array[Vector2] = SpreadResolver.resolve(direction)

		for index: int in spread.size():
			assert_float(spread[index].length()).append_failure_message(
				"direction=%s index=%s" % [direction, index]
			).is_equal_approx(1.0, FLOAT_TOLERANCE)


func test_resolve_returns_distinct_directions_for_every_direction() -> void:
	for direction: Vector2i in EIGHT_DIRECTIONS:
		var spread: Array[Vector2] = SpreadResolver.resolve(direction)

		for index: int in spread.size():
			for other: int in spread.size():
				if index == other:
					continue

				# 角の大きさが 0 より確実に離れていることを見る: 完全一致だけを見ると、
				# 浮動小数の丸めで辛うじて違う値が「異なる」として通る
				assert_float(absf(spread[index].angle_to(spread[other]))).append_failure_message(
					"direction=%s index=%s other=%s" % [direction, index, other]
				).is_greater(FLOAT_TOLERANCE)


func test_resolve_never_returns_the_zero_vector() -> void:
	for direction: Vector2i in EIGHT_DIRECTIONS:
		var spread: Array[Vector2] = SpreadResolver.resolve(direction)

		for index: int in spread.size():
			assert_vector(spread[index]).append_failure_message(
				"direction=%s index=%s" % [direction, index]
			).is_not_equal(Vector2.ZERO)


func test_spread_degrees_is_twenty() -> void:
	# 値そのものを検査の対象として読む唯一のケース(spec.md §7 の「検証の形式」)
	assert_float(SpreadResolver.SPREAD_DEGREES).is_equal(20.0)


func test_the_spread_angle_is_not_built_outside_the_resolver() -> void:
	for path: String in [PLAYER_SOURCE_PATH, PLAYER_STATS_SOURCE_PATH]:
		var source: String = FileAccess.get_file_as_string(path)

		assert_str(source).append_failure_message("path=%s" % path).is_not_empty()
		for marker: String in SPREAD_ANGLE_MARKERS:
			assert_bool(source.contains(marker)).append_failure_message(
				"path=%s marker=%s" % [path, marker]
			).is_false()


func test_player_stats_has_no_spread_angle_property() -> void:
	var stats: PlayerStats = auto_free(PlayerStats.new())

	var names: Array[String] = _editor_visible_property_names(stats)

	assert_array(names).is_not_empty()
	for name: String in names:
		for marker: String in SPREAD_PROPERTY_MARKERS:
			assert_bool(name.to_lower().contains(marker)).append_failure_message(
				"name=%s marker=%s" % [name, marker]
			).is_false()


func test_resolve_returns_an_empty_array_for_an_invalid_direction() -> void:
	for direction: Vector2i in INVALID_DIRECTIONS:
		var spread: Array[Vector2] = SpreadResolver.resolve(direction)

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
		var first: Array[Vector2] = SpreadResolver.resolve(direction)
		var second: Array[Vector2] = SpreadResolver.resolve(direction)

		assert_array(second).append_failure_message("direction=%s" % direction).is_equal(first)


func test_resolve_returns_a_separate_array_on_each_call() -> void:
	for direction: Vector2i in EIGHT_DIRECTIONS:
		var first: Array[Vector2] = SpreadResolver.resolve(direction)
		var second: Array[Vector2] = SpreadResolver.resolve(direction)

		assert_bool(is_same(first, second)).append_failure_message(
			"direction=%s" % direction
		).is_false()

		# 戻り値を書き換える: 内部の配列をそのまま返す実装なら、以降の呼び出しに汚染が残る
		first[0] = Vector2.ZERO

		assert_vector(SpreadResolver.resolve(direction)[0]).append_failure_message(
			"direction=%s" % direction
		).is_equal_approx(DIRECTION_TO_CENTER[direction], VECTOR_TOLERANCE)


func test_resolve_takes_a_vector2i_argument() -> void:
	var resolver: SpreadResolver = auto_free(SpreadResolver.new())

	assert_array(_resolve_argument_types(resolver)).is_equal([TYPE_VECTOR2I])


func test_the_aim_resolver_source_is_unchanged() -> void:
	assert_str(FileAccess.get_sha256(AIM_RESOLVER_SOURCE_PATH)).is_equal(AIM_RESOLVER_SOURCE_SHA256)
