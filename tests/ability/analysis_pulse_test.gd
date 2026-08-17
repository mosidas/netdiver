extends GdUnitTestSuite

const PULSE_SOURCE_PATH: String = "res://src/ability/analysis_pulse.gd"

# 既定値をテストの側に複製する: 実装の定数を参照するとアサーションが自明になる
const DEFAULT_FLIGHT_TIME: float = 0.4

# 飛行時間を 1 物理フレームの delta の整数倍に取る: 到達のフレームが算術で決まり、
# 境界の両側(手前のフレームと到達のフレーム)を数えられる
const FLIGHT_FRAMES: int = 8
# もう 1 つの演出に別の飛行時間を与えるためのフレーム数。同じ値だと、
# 状態を共有する実装と独立に進める実装を区別できない
const SHORT_FLIGHT_FRAMES: int = 4
# 到達の後にも進めるフレーム数。`arrived` が 1 回だけであることを見る
const FRAMES_AFTER_ARRIVAL: int = 2

# 到達のフレームごとの発火回数の列。手前まで 0、到達のフレームで 1、その後も 1 のまま
const EXPECTED_ARRIVAL_COUNTS: Array[int] = [0, 0, 0, 0, 0, 0, 0, 1, 1, 1]
# 2 つの演出の [遅い側の回数, 速い側の回数] の列。速い側は 4 フレーム目、遅い側は 8 フレーム目
const EXPECTED_INDEPENDENT_COUNTS: Array[Array] = [
	[0, 0],
	[0, 0],
	[0, 0],
	[0, 1],
	[0, 1],
	[0, 1],
	[0, 1],
	[1, 1],
]

# 発射位置を原点にしない: 原点だと、`launch()` が位置を置いたのか生成時のままなのかを区別できない
const FROM: Vector2 = Vector2(-40.0, 24.0)
const SECOND_FROM: Vector2 = Vector2(18.0, -52.0)
const TARGET_POSITION: Vector2 = Vector2(60.0, -12.0)
const SECOND_TARGET_POSITION: Vector2 = Vector2(-24.0, 36.0)
# 標的を毎フレーム動かす幅。動かすと、発射時の位置を目標に固定する実装が落ちる
const TARGET_STEP: Vector2 = Vector2(3.0, -2.0)

const KINDS: Array[int] = [EnemyKind.Kind.CHARGER, EnemyKind.Kind.SHOOTER]

# 数フレーム(60 Hz で 1 フレーム約 17 ms)に対して余裕を取る: CI のランナーが遅い場合でも
# 到達まで物理フレームを消化させる
const WAIT_MILLIS: int = 500
const TOLERANCE: Vector2 = Vector2(0.001, 0.001)


func _frame_delta() -> float:
	return 1.0 / float(Engine.physics_ticks_per_second)


func _flight_time(frames: int) -> float:
	return _frame_delta() * frames


func _create_pulse(frames: int) -> AnalysisPulse:
	var pulse: AnalysisPulse = auto_free(AnalysisPulse.new())
	# 既定値を渡さない: 既定のままだと、`flight_time` を読まずに 0.4 を直書きする実装も緑になる
	pulse.flight_time = _flight_time(frames)
	return pulse


# エンジンの物理フレームと手で回すフレームを混ぜない: 混ざると到達のフレームを数えられない
func _add_hand_driven(pulse: AnalysisPulse) -> void:
	add_child(pulse)
	pulse.set_physics_process(false)


func _create_target(at: Vector2) -> Node2D:
	var target: Node2D = auto_free(Node2D.new())
	add_child(target)
	target.global_position = at
	return target


func _advance(pulse: AnalysisPulse, frames: int) -> void:
	for _frame: int in frames:
		pulse._physics_process(_frame_delta())


func _record_kinds(pulse: AnalysisPulse, kinds: Array[int]) -> void:
	pulse.arrived.connect(func(kind: int) -> void: kinds.append(kind))


func _exported_property_names(object: Object) -> Array[String]:
	var names: Array[String] = []
	for property: Dictionary in object.get_property_list():
		var usage: int = property["usage"]
		if usage & PROPERTY_USAGE_EDITOR != 0 and usage & PROPERTY_USAGE_SCRIPT_VARIABLE != 0:
			names.append(property["name"])
	return names


func test_the_pulse_exports_the_flight_time() -> void:
	var pulse: AnalysisPulse = auto_free(AnalysisPulse.new())

	assert_array(_exported_property_names(pulse)).contains(["flight_time"])


func test_the_player_stats_does_not_hold_the_flight_time() -> void:
	# 演出の数値はプレイヤーの手触りではなく解析の見え方を決めるため、`PlayerStats` に置かない。
	# 演出の側だけを見ると、両方に置く実装が素通りする
	var stats: PlayerStats = auto_free(PlayerStats.new())

	for name: String in _exported_property_names(stats):
		assert_str(name).append_failure_message("property=%s" % name).not_contains("flight")


func test_the_pulse_does_not_read_the_player_stats() -> void:
	var source: String = FileAccess.get_file_as_string(PULSE_SOURCE_PATH)

	assert_str(source).is_not_empty()
	assert_str(source).not_contains("PlayerStats")


func test_the_default_flight_time_is_the_specified_value() -> void:
	var pulse: AnalysisPulse = auto_free(AnalysisPulse.new())

	assert_float(pulse.flight_time).is_equal(DEFAULT_FLIGHT_TIME)


func test_the_flight_times_used_here_differ_from_the_default() -> void:
	# 既定値と一致する値を渡していないことを先に固定する: 一致していると、
	# `flight_time` を無視して既定値を直書きする実装も緑になる
	assert_float(_flight_time(FLIGHT_FRAMES)).is_not_equal(DEFAULT_FLIGHT_TIME)
	assert_float(_flight_time(SHORT_FLIGHT_FRAMES)).is_not_equal(DEFAULT_FLIGHT_TIME)


func test_the_flight_times_are_reached_by_accumulating_the_frame_delta() -> void:
	# 到達のフレームを数える前提を明示する: 1 フレームぶんの delta を積むと
	# `flight_time` にちょうど届くことが、境界のケースの土台になる
	for frames: int in [SHORT_FLIGHT_FRAMES, FLIGHT_FRAMES]:
		var elapsed: float = 0.0
		for _frame: int in frames:
			elapsed += _frame_delta()
		var context: String = "frames=%s" % frames
		assert_bool(elapsed >= _flight_time(frames)).append_failure_message(context).is_true()


func test_launch_places_the_pulse_at_the_start_position() -> void:
	var target: Node2D = _create_target(TARGET_POSITION)
	var pulse: AnalysisPulse = _create_pulse(FLIGHT_FRAMES)
	_add_hand_driven(pulse)

	pulse.launch(EnemyKind.Kind.SHOOTER, FROM, target)

	# 物理フレームを 1 つも進めていない時点で見る
	assert_vector(pulse.global_position).is_equal(FROM)
	# 発射位置と標的の位置が別であることを固定する: 同じだと「標的へ置く」実装も緑になる
	assert_vector(target.global_position).is_not_equal(FROM)


func test_the_pulse_interpolates_toward_a_still_target_each_frame() -> void:
	var target: Node2D = _create_target(TARGET_POSITION)
	var pulse: AnalysisPulse = _create_pulse(FLIGHT_FRAMES)
	_add_hand_driven(pulse)

	pulse.launch(EnemyKind.Kind.CHARGER, FROM, target)

	var positions: Array[Vector2] = []
	for _frame: int in FLIGHT_FRAMES:
		pulse._physics_process(_frame_delta())
		positions.append(pulse.global_position)

	for index: int in positions.size():
		var progress: float = float(index + 1) / float(FLIGHT_FRAMES)
		var expected: Vector2 = FROM.lerp(TARGET_POSITION, progress)
		var context: String = "frame=%s" % (index + 1)
		assert_vector(positions[index]).append_failure_message(context).is_equal_approx(
			expected, TOLERANCE
		)


func test_the_pulse_follows_a_target_that_moves_every_frame() -> void:
	var target: Node2D = _create_target(TARGET_POSITION)
	var pulse: AnalysisPulse = _create_pulse(FLIGHT_FRAMES)
	_add_hand_driven(pulse)
	# 解放された後は位置を読めないため、発火の時点の位置を控える
	var arrival_positions: Array[Vector2] = []
	pulse.arrived.connect(func(_kind: int) -> void: arrival_positions.append(pulse.global_position))

	pulse.launch(EnemyKind.Kind.SHOOTER, FROM, target)

	var positions: Array[Vector2] = []
	var expected_positions: Array[Vector2] = []
	for frame: int in FLIGHT_FRAMES:
		target.global_position += TARGET_STEP
		pulse._physics_process(_frame_delta())
		positions.append(pulse.global_position)
		var progress: float = float(frame + 1) / float(FLIGHT_FRAMES)
		expected_positions.append(FROM.lerp(target.global_position, progress))

	for index: int in positions.size():
		var context: String = "frame=%s" % (index + 1)
		assert_vector(positions[index]).append_failure_message(context).is_equal_approx(
			expected_positions[index], TOLERANCE
		)
	# 到達点は「到達時点の標的の位置」であり、発射時の標的の位置ではない
	assert_vector(positions[FLIGHT_FRAMES - 1]).is_equal_approx(target.global_position, TOLERANCE)
	assert_vector(positions[FLIGHT_FRAMES - 1]).is_not_equal(TARGET_POSITION)
	assert_array(arrival_positions).has_size(1)
	assert_vector(arrival_positions[0]).is_equal_approx(target.global_position, TOLERANCE)


func test_the_pulse_emits_arrived_once_when_the_flight_time_elapses() -> void:
	var target: Node2D = _create_target(TARGET_POSITION)
	var pulse: AnalysisPulse = _create_pulse(FLIGHT_FRAMES)
	_add_hand_driven(pulse)
	var kinds: Array[int] = []
	_record_kinds(pulse, kinds)

	pulse.launch(EnemyKind.Kind.SHOOTER, FROM, target)

	# 発火回数をフレームごとに並べる: 1 本のアサーションに畳むと、境界がずれる変異と
	# 繰り返し発火する変異のどちらかが素通りする
	var counts: Array[int] = []
	for _frame: int in FLIGHT_FRAMES + FRAMES_AFTER_ARRIVAL:
		pulse._physics_process(_frame_delta())
		counts.append(kinds.size())

	assert_array(counts).is_equal(EXPECTED_ARRIVAL_COUNTS)


func test_the_pulse_does_not_emit_arrived_one_frame_before_the_flight_time() -> void:
	var target: Node2D = _create_target(TARGET_POSITION)
	var pulse: AnalysisPulse = _create_pulse(FLIGHT_FRAMES)
	_add_hand_driven(pulse)
	var kinds: Array[int] = []
	_record_kinds(pulse, kinds)

	pulse.launch(EnemyKind.Kind.SHOOTER, FROM, target)
	_advance(pulse, FLIGHT_FRAMES - 1)

	assert_array(kinds).is_empty()
	assert_vector(pulse.global_position).is_not_equal(TARGET_POSITION)


func test_arrived_carries_the_kind_passed_to_launch() -> void:
	var kinds: Array[int] = []
	for kind: int in KINDS:
		var target: Node2D = _create_target(TARGET_POSITION)
		var pulse: AnalysisPulse = _create_pulse(FLIGHT_FRAMES)
		_add_hand_driven(pulse)
		_record_kinds(pulse, kinds)

		pulse.launch(kind, FROM, target)
		_advance(pulse, FLIGHT_FRAMES)

	# 両方の種別を通す: 片方だけだと、定数を返す実装が素通りする
	assert_array(kinds).is_equal(KINDS)


func test_the_pulse_releases_itself_after_emitting_arrived() -> void:
	var target: Node2D = _create_target(TARGET_POSITION)
	var pulse: AnalysisPulse = _create_pulse(FLIGHT_FRAMES)
	_add_hand_driven(pulse)
	# 発火が解放より先であることを、受け手の中の観測で固定する
	var queued_at_arrival: Array[bool] = []
	pulse.arrived.connect(
		func(_kind: int) -> void: queued_at_arrival.append(pulse.is_queued_for_deletion())
	)

	pulse.launch(EnemyKind.Kind.CHARGER, FROM, target)
	_advance(pulse, FLIGHT_FRAMES - 1)

	assert_bool(pulse.is_queued_for_deletion()).is_false()

	pulse._physics_process(_frame_delta())

	assert_array(queued_at_arrival).is_equal([false])
	assert_bool(pulse.is_queued_for_deletion()).is_true()
	assert_bool(is_instance_valid(pulse)).is_true()

	await await_idle_frame()

	assert_bool(is_instance_valid(pulse)).is_false()


func test_two_pulses_with_different_flight_times_arrive_independently() -> void:
	var slow_target: Node2D = _create_target(TARGET_POSITION)
	var fast_target: Node2D = _create_target(SECOND_TARGET_POSITION)
	var slow: AnalysisPulse = _create_pulse(FLIGHT_FRAMES)
	var fast: AnalysisPulse = _create_pulse(SHORT_FLIGHT_FRAMES)
	_add_hand_driven(slow)
	_add_hand_driven(fast)
	var slow_kinds: Array[int] = []
	var fast_kinds: Array[int] = []
	var order: Array[int] = []
	_record_kinds(slow, slow_kinds)
	_record_kinds(fast, fast_kinds)
	_record_kinds(slow, order)
	_record_kinds(fast, order)

	slow.launch(EnemyKind.Kind.CHARGER, FROM, slow_target)
	fast.launch(EnemyKind.Kind.SHOOTER, SECOND_FROM, fast_target)

	var counts: Array[Array] = []
	for _frame: int in FLIGHT_FRAMES:
		slow._physics_process(_frame_delta())
		fast._physics_process(_frame_delta())
		counts.append([slow_kinds.size(), fast_kinds.size()])

	assert_array(counts).is_equal(EXPECTED_INDEPENDENT_COUNTS)
	# 飛行時間の短い側が先に到達する
	assert_array(order).is_equal([EnemyKind.Kind.SHOOTER, EnemyKind.Kind.CHARGER])


func test_the_pulse_does_not_advance_while_physics_processing_is_off() -> void:
	# 位置の更新を `_process` へ移す実装はここで落ちる
	var target: Node2D = _create_target(TARGET_POSITION)
	var still: AnalysisPulse = _create_pulse(FLIGHT_FRAMES)
	var witness: AnalysisPulse = _create_pulse(FLIGHT_FRAMES)
	add_child(still)
	add_child(witness)
	var still_kinds: Array[int] = []
	var witness_kinds: Array[int] = []
	_record_kinds(still, still_kinds)
	_record_kinds(witness, witness_kinds)

	still.launch(EnemyKind.Kind.SHOOTER, FROM, target)
	still.set_physics_process(false)
	witness.launch(EnemyKind.Kind.CHARGER, SECOND_FROM, target)
	await await_millis(WAIT_MILLIS)

	# 待ちの間に物理フレームが進んだことを、処理を止めていない演出で示す
	assert_array(witness_kinds).is_equal([EnemyKind.Kind.CHARGER])
	assert_array(still_kinds).is_empty()
	assert_bool(is_instance_valid(still)).is_true()
	assert_vector(still.global_position).is_equal(FROM)


func test_the_engine_drives_the_pulse_over_real_physics_frames() -> void:
	# 手で回すヘルパが `_physics_process` を代行していないことを担保する
	var target: Node2D = _create_target(TARGET_POSITION)
	var pulse: AnalysisPulse = _create_pulse(FLIGHT_FRAMES)
	add_child(pulse)
	var arrival_positions: Array[Vector2] = []
	var kinds: Array[int] = []
	_record_kinds(pulse, kinds)
	pulse.arrived.connect(func(_kind: int) -> void: arrival_positions.append(pulse.global_position))

	pulse.launch(EnemyKind.Kind.SHOOTER, FROM, target)
	await await_millis(WAIT_MILLIS)

	assert_array(kinds).is_equal([EnemyKind.Kind.SHOOTER])
	assert_array(arrival_positions).has_size(1)
	assert_vector(arrival_positions[0]).is_equal_approx(TARGET_POSITION, TOLERANCE)
	assert_bool(is_instance_valid(pulse)).is_false()
