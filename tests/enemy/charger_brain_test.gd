extends GdUnitTestSuite

# 2 進で厳密に表せる値を使う: 累積の誤差で「telegraph_time ちょうど」の判定が揺れると、
# 境界を含むか含まないかを検証できない。既定値(0.4 / 0.6 / 0.8 / 150.0 / 128.0)とは
# 別の値にする: 値を直書きした実装がテスト用の stats でも同じに振る舞うことを避ける
const TELEGRAPH_TIME: float = 0.25
const ATTACK_DURATION: float = 0.5
const RECOVER_TIME: float = 0.75
const ATTACK_SPEED: float = 8.0
const DETECT_RANGE: float = 16.0

# 突進の到達距離 = ATTACK_SPEED * ATTACK_DURATION
const ATTACK_REACH: float = 4.0

const FRAME_DELTA: float = 0.125
const SMALL_DELTA: float = 0.03125

# 境界のすぐ内側。絶対値ではなく比(1 - 2^-20)で近づける: しきい値を 0.999 倍まで緩める
# 変異は、絶対値で近づけた値では素通りする
const NEAR_RATIO: float = 1.0 - 1.0 / 1048576.0
const OVER_RATIO: float = 1.0 + 1.0 / 1048576.0
const NEARLY_TELEGRAPH_TIME: float = TELEGRAPH_TIME * NEAR_RATIO
const NEARLY_ATTACK_DURATION: float = ATTACK_DURATION * NEAR_RATIO
const NEARLY_RECOVER_TIME: float = RECOVER_TIME * NEAR_RATIO
const JUST_OUTSIDE_ATTACK_REACH: float = ATTACK_REACH * OVER_RATIO

# 到達距離の内側 / 外側。外側の値は索敵範囲(DETECT_RANGE)の内側に取る: 遷移の条件を
# detect_range へ差し替える変異は、両方を跨ぐこの距離でだけ落ちる
const NEAR_DISTANCE: float = 2.0
const FAR_DISTANCE: float = 6.0

# 長い側の stats。_init() の引数が実際に使われていることを長短の比較で示す
const LONG_TELEGRAPH_TIME: float = 1.0
const LONG_ATTACK_DURATION: float = 1.0
const LONG_RECOVER_TIME: float = 2.0
const LONG_ATTACK_SPEED: float = 16.0

# 事前条件の外にある値。境界(delta = 0・距離 = 0)を両方含める
const ZERO_DELTA: float = 0.0
const NEGATIVE_DELTA: float = -0.125
const ZERO_DISTANCE: float = 0.0
const NEGATIVE_DISTANCE: float = -1.0

# 有限だが桁が大きい距離。標的の不在(INF)の判定を巨大な有限値のしきい値へ置き換える実装は、
# この距離で突進へ入らず落ちる
const HUGE_FINITE_DISTANCE: float = 1.0e30

# 実装の文言を参照しない: 参照するとアサーションが自明になり、文言の退行を検出できない
const INVALID_DELTA_ERROR_FORMAT: String = (
	"ChargerBrain.update(): delta は正でなければならない(現在値: %s)。状態を変えずに返る"
)
const NEGATIVE_DISTANCE_ERROR_FORMAT: String = (
	"ChargerBrain.update(): distance_to_target は 0 以上でなければならない(現在値: %s)。"
	+ "状態を変えずに返る"
)

# 到達できる状態の名前。_brain_in_state() が組み立てる
const IDLE: String = "idle"
const TELEGRAPH: String = "telegraph"
const CHARGE: String = "charge"
const RECOVER: String = "recover"

const REACHABLE_STATES: Array[String] = [IDLE, TELEGRAPH, CHARGE, RECOVER]

# 満了より前に与える距離。到達距離の内外・境界の 0・標的の不在(INF)を跨ぐ。
# 合計の delta(SMALL_DELTA × 4 = 0.125)はどの滞在時間より短い
const SWING_DISTANCES: Array[float] = [FAR_DISTANCE, NEAR_DISTANCE, INF, ZERO_DISTANCE]

# 滞在中に距離を振っても満了まで遷移しないことを見る表。
# 各行は [状態, その状態の enum, 滞在時間, 満了後の状態]
const SWING_TABLE: Array = [
	[TELEGRAPH, EnemyState.State.TELEGRAPH, TELEGRAPH_TIME, EnemyState.State.CHARGE],
	[CHARGE, EnemyState.State.CHARGE, ATTACK_DURATION, EnemyState.State.RECOVER],
	[RECOVER, EnemyState.State.RECOVER, RECOVER_TIME, EnemyState.State.IDLE],
]

# 事前条件に反する引数と、そのとき出る文言。
# 各行は [delta, distance_to_target, 期待する文言]
const INVALID_ARGUMENT_TABLE: Array = [
	[ZERO_DELTA, NEAR_DISTANCE, INVALID_DELTA_ERROR_FORMAT % ZERO_DELTA],
	[NEGATIVE_DELTA, NEAR_DISTANCE, INVALID_DELTA_ERROR_FORMAT % NEGATIVE_DELTA],
	[FRAME_DELTA, NEGATIVE_DISTANCE, NEGATIVE_DISTANCE_ERROR_FORMAT % NEGATIVE_DISTANCE],
]

# 到達できる状態 × 距離の総当たり。条件を広げる変異・分岐を入れ替える変異が片側だけの
# 検証では素通りするため、出力を厳密比較の表で押さえる。
# 各行は [状態, 距離, [update() 後の state, is_attack_active]]
const UPDATE_TABLE: Array = [
	[IDLE, NEAR_DISTANCE, [EnemyState.State.TELEGRAPH, false]],
	[IDLE, FAR_DISTANCE, [EnemyState.State.IDLE, false]],
	[TELEGRAPH, NEAR_DISTANCE, [EnemyState.State.TELEGRAPH, false]],
	[TELEGRAPH, FAR_DISTANCE, [EnemyState.State.TELEGRAPH, false]],
	[CHARGE, NEAR_DISTANCE, [EnemyState.State.CHARGE, true]],
	[CHARGE, FAR_DISTANCE, [EnemyState.State.CHARGE, true]],
	[RECOVER, NEAR_DISTANCE, [EnemyState.State.RECOVER, false]],
	[RECOVER, FAR_DISTANCE, [EnemyState.State.RECOVER, false]],
]

# FRAME_DELTA(0.125)で距離を到達距離の内側に保ったまま回したときの state の並び。
# 予備動作 3 フレーム・突進 5 フレーム・硬直 7 フレームで 1 周し、16 フレーム目に IDLE へ戻る
const CYCLE_FRAME_COUNT: int = 17
const EXPECTED_CYCLE: Array = [
	EnemyState.State.TELEGRAPH,
	EnemyState.State.TELEGRAPH,
	EnemyState.State.TELEGRAPH,
	EnemyState.State.CHARGE,
	EnemyState.State.CHARGE,
	EnemyState.State.CHARGE,
	EnemyState.State.CHARGE,
	EnemyState.State.CHARGE,
	EnemyState.State.RECOVER,
	EnemyState.State.RECOVER,
	EnemyState.State.RECOVER,
	EnemyState.State.RECOVER,
	EnemyState.State.RECOVER,
	EnemyState.State.RECOVER,
	EnemyState.State.RECOVER,
	EnemyState.State.IDLE,
	EnemyState.State.TELEGRAPH,
]
const EXPECTED_ATTACK_ACTIVE_FRAMES: Array[int] = [4, 5, 6, 7, 8]


func _new_stats(
	telegraph_time: float = TELEGRAPH_TIME,
	attack_duration: float = ATTACK_DURATION,
	recover_time: float = RECOVER_TIME,
	attack_speed: float = ATTACK_SPEED
) -> EnemyStats:
	var stats: EnemyStats = auto_free(EnemyStats.new())
	stats.telegraph_time = telegraph_time
	stats.attack_duration = attack_duration
	stats.recover_time = recover_time
	stats.attack_speed = attack_speed
	stats.detect_range = DETECT_RANGE
	return stats


func _new_brain(stats: EnemyStats = _new_stats()) -> ChargerBrain:
	return auto_free(ChargerBrain.new(stats))


## 表の各行が指す状態の Brain を組み立てる。到達経路は update() の呼び出しだけで作る。
## 進入のフレームの delta は滞在時間へ数えないため、返る Brain の滞在時間は 0 である
func _brain_in_state(state: String, brain: ChargerBrain = _new_brain()) -> ChargerBrain:
	match state:
		IDLE:
			pass
		TELEGRAPH:
			brain.update(SMALL_DELTA, NEAR_DISTANCE)
		CHARGE:
			_brain_in_state(TELEGRAPH, brain)
			brain.update(TELEGRAPH_TIME, NEAR_DISTANCE)
			brain.update(SMALL_DELTA, NEAR_DISTANCE)
		RECOVER:
			_brain_in_state(CHARGE, brain)
			brain.update(ATTACK_DURATION, NEAR_DISTANCE)
			brain.update(SMALL_DELTA, NEAR_DISTANCE)
	return brain


func _state_name(state: int) -> String:
	return String(EnemyState.State.keys()[state])


func test_a_new_brain_is_idle() -> void:
	var brain: ChargerBrain = _new_brain()

	assert_int(brain.state).is_equal(EnemyState.State.IDLE)
	assert_bool(brain.is_attack_active).is_false()


func test_the_brain_stays_idle_while_the_target_is_out_of_the_attack_reach() -> void:
	# 索敵範囲の内側だが到達距離の外側。条件を detect_range へ差し替える変異はここで落ちる
	var brain: ChargerBrain = _new_brain()

	for _frame: int in CYCLE_FRAME_COUNT:
		brain.update(FRAME_DELTA, FAR_DISTANCE)

	assert_int(brain.state).is_equal(EnemyState.State.IDLE)
	assert_bool(brain.is_attack_active).is_false()


func test_the_brain_stays_idle_just_outside_the_attack_reach() -> void:
	var brain: ChargerBrain = _new_brain()

	brain.update(FRAME_DELTA, JUST_OUTSIDE_ATTACK_REACH)

	assert_int(brain.state).is_equal(EnemyState.State.IDLE)
	assert_bool(brain.is_attack_active).is_false()


func test_the_brain_telegraphs_when_the_target_is_within_the_attack_reach() -> void:
	var brain: ChargerBrain = _new_brain()

	brain.update(FRAME_DELTA, NEAR_DISTANCE)

	assert_int(brain.state).is_equal(EnemyState.State.TELEGRAPH)
	assert_bool(brain.is_attack_active).is_false()


func test_the_brain_telegraphs_exactly_at_the_attack_reach() -> void:
	var brain: ChargerBrain = _new_brain()

	brain.update(FRAME_DELTA, ATTACK_REACH)

	assert_int(brain.state).is_equal(EnemyState.State.TELEGRAPH)


func test_the_telegraph_persists_just_below_its_duration() -> void:
	var brain: ChargerBrain = _brain_in_state(TELEGRAPH)
	brain.update(NEARLY_TELEGRAPH_TIME, NEAR_DISTANCE)

	brain.update(SMALL_DELTA, NEAR_DISTANCE)

	assert_int(brain.state).is_equal(EnemyState.State.TELEGRAPH)


func test_the_telegraph_ends_exactly_when_it_elapses() -> void:
	var brain: ChargerBrain = _brain_in_state(TELEGRAPH)
	brain.update(TELEGRAPH_TIME, NEAR_DISTANCE)

	brain.update(SMALL_DELTA, NEAR_DISTANCE)

	assert_int(brain.state).is_equal(EnemyState.State.CHARGE)
	assert_bool(brain.is_attack_active).is_true()


func test_the_charge_persists_just_below_its_duration() -> void:
	var brain: ChargerBrain = _brain_in_state(CHARGE)
	brain.update(NEARLY_ATTACK_DURATION, NEAR_DISTANCE)

	brain.update(SMALL_DELTA, NEAR_DISTANCE)

	assert_int(brain.state).is_equal(EnemyState.State.CHARGE)


func test_the_charge_ends_exactly_when_it_elapses() -> void:
	var brain: ChargerBrain = _brain_in_state(CHARGE)
	brain.update(ATTACK_DURATION, NEAR_DISTANCE)

	brain.update(SMALL_DELTA, NEAR_DISTANCE)

	assert_int(brain.state).is_equal(EnemyState.State.RECOVER)
	assert_bool(brain.is_attack_active).is_false()


func test_the_recover_persists_just_below_its_duration() -> void:
	var brain: ChargerBrain = _brain_in_state(RECOVER)
	brain.update(NEARLY_RECOVER_TIME, NEAR_DISTANCE)

	brain.update(SMALL_DELTA, NEAR_DISTANCE)

	assert_int(brain.state).is_equal(EnemyState.State.RECOVER)


func test_the_recover_ends_exactly_when_it_elapses() -> void:
	# 距離が到達距離の内側でも、硬直の満了で入るのは IDLE である(次の予備動作はその次の
	# フレームから始まる)
	var brain: ChargerBrain = _brain_in_state(RECOVER)
	brain.update(RECOVER_TIME, NEAR_DISTANCE)

	brain.update(SMALL_DELTA, NEAR_DISTANCE)

	assert_int(brain.state).is_equal(EnemyState.State.IDLE)


func test_the_update_table_holds_for_every_reachable_state() -> void:
	for row: Array in UPDATE_TABLE:
		var state: String = row[0]
		var distance: float = row[1]
		var expected: Array = row[2]
		var brain: ChargerBrain = _brain_in_state(state)

		brain.update(SMALL_DELTA, distance)

		var actual: Array = [brain.state, brain.is_attack_active]
		var context: String = "state=%s distance=%s" % [state, distance]
		assert_array(actual).append_failure_message(context).is_equal(expected)


func test_the_brain_runs_through_the_cycle_on_the_expected_frames() -> void:
	var brain: ChargerBrain = _new_brain()
	var states: Array = []
	var attack_active_frames: Array[int] = []

	for frame: int in range(1, CYCLE_FRAME_COUNT + 1):
		brain.update(FRAME_DELTA, NEAR_DISTANCE)
		states.append(brain.state)
		if brain.is_attack_active:
			attack_active_frames.append(frame)

	assert_array(states).is_equal(EXPECTED_CYCLE)
	assert_array(attack_active_frames).is_equal(EXPECTED_ATTACK_ACTIVE_FRAMES)


# 遷移したフレームの delta を遷移先へ数えると、予備動作から突進までが telegraph_time より
# 短くなる。遷移のフレームに満了ぶんの delta を与えて、満了が 1 フレーム遅れることを見る
func test_the_frame_that_enters_the_telegraph_does_not_count_toward_it() -> void:
	var brain: ChargerBrain = _new_brain()
	brain.update(TELEGRAPH_TIME, NEAR_DISTANCE)

	brain.update(SMALL_DELTA, NEAR_DISTANCE)

	assert_int(brain.state).is_equal(EnemyState.State.TELEGRAPH)


func test_the_frame_that_enters_the_charge_does_not_count_toward_it() -> void:
	var brain: ChargerBrain = _brain_in_state(TELEGRAPH)
	brain.update(TELEGRAPH_TIME, NEAR_DISTANCE)
	brain.update(ATTACK_DURATION, NEAR_DISTANCE)

	brain.update(SMALL_DELTA, NEAR_DISTANCE)

	assert_int(brain.state).is_equal(EnemyState.State.CHARGE)


func test_the_frame_that_enters_the_recover_does_not_count_toward_it() -> void:
	var brain: ChargerBrain = _brain_in_state(CHARGE)
	brain.update(ATTACK_DURATION, NEAR_DISTANCE)
	brain.update(RECOVER_TIME, NEAR_DISTANCE)

	brain.update(SMALL_DELTA, NEAR_DISTANCE)

	assert_int(brain.state).is_equal(EnemyState.State.RECOVER)


# 滞在時間と到達距離が _init() の引数から来ることを見る: 値を直書きした実装は長短の両方で
# 同じに振る舞う
func test_a_longer_telegraph_time_delays_the_charge() -> void:
	var short_brain: ChargerBrain = _brain_in_state(TELEGRAPH)
	var long_brain: ChargerBrain = _brain_in_state(
		TELEGRAPH, _new_brain(_new_stats(LONG_TELEGRAPH_TIME))
	)

	for brain: ChargerBrain in [short_brain, long_brain]:
		brain.update(TELEGRAPH_TIME, NEAR_DISTANCE)
		brain.update(SMALL_DELTA, NEAR_DISTANCE)

	assert_int(short_brain.state).is_equal(EnemyState.State.CHARGE)
	assert_int(long_brain.state).is_equal(EnemyState.State.TELEGRAPH)


func test_a_longer_telegraph_time_ends_once_it_elapses() -> void:
	var brain: ChargerBrain = _brain_in_state(
		TELEGRAPH, _new_brain(_new_stats(LONG_TELEGRAPH_TIME))
	)

	brain.update(LONG_TELEGRAPH_TIME, NEAR_DISTANCE)
	brain.update(SMALL_DELTA, NEAR_DISTANCE)

	assert_int(brain.state).is_equal(EnemyState.State.CHARGE)


func test_a_longer_attack_duration_delays_the_recover() -> void:
	var short_brain: ChargerBrain = _brain_in_state(CHARGE)
	var long_brain: ChargerBrain = _brain_in_state(
		CHARGE, _new_brain(_new_stats(TELEGRAPH_TIME, LONG_ATTACK_DURATION))
	)

	for brain: ChargerBrain in [short_brain, long_brain]:
		brain.update(ATTACK_DURATION, NEAR_DISTANCE)
		brain.update(SMALL_DELTA, NEAR_DISTANCE)

	assert_int(short_brain.state).is_equal(EnemyState.State.RECOVER)
	assert_int(long_brain.state).is_equal(EnemyState.State.CHARGE)


func test_a_longer_recover_time_delays_the_idle() -> void:
	var short_brain: ChargerBrain = _brain_in_state(RECOVER)
	var long_brain: ChargerBrain = _brain_in_state(
		RECOVER, _new_brain(_new_stats(TELEGRAPH_TIME, ATTACK_DURATION, LONG_RECOVER_TIME))
	)

	for brain: ChargerBrain in [short_brain, long_brain]:
		brain.update(RECOVER_TIME, NEAR_DISTANCE)
		brain.update(SMALL_DELTA, NEAR_DISTANCE)

	assert_int(short_brain.state).is_equal(EnemyState.State.IDLE)
	assert_int(long_brain.state).is_equal(EnemyState.State.RECOVER)


# 到達距離は attack_speed と attack_duration の積である。片方だけを見る実装は
# 次の 2 つのうち一方で落ちる
func test_a_faster_attack_speed_widens_the_attack_reach() -> void:
	var short_brain: ChargerBrain = _new_brain()
	var long_brain: ChargerBrain = _new_brain(
		_new_stats(TELEGRAPH_TIME, ATTACK_DURATION, RECOVER_TIME, LONG_ATTACK_SPEED)
	)

	short_brain.update(FRAME_DELTA, FAR_DISTANCE)
	long_brain.update(FRAME_DELTA, FAR_DISTANCE)

	assert_int(short_brain.state).is_equal(EnemyState.State.IDLE)
	assert_int(long_brain.state).is_equal(EnemyState.State.TELEGRAPH)


func test_a_longer_attack_duration_widens_the_attack_reach() -> void:
	var short_brain: ChargerBrain = _new_brain()
	var long_brain: ChargerBrain = _new_brain(
		_new_stats(TELEGRAPH_TIME, LONG_ATTACK_DURATION)
	)

	short_brain.update(FRAME_DELTA, FAR_DISTANCE)
	long_brain.update(FRAME_DELTA, FAR_DISTANCE)

	assert_int(short_brain.state).is_equal(EnemyState.State.IDLE)
	assert_int(long_brain.state).is_equal(EnemyState.State.TELEGRAPH)


func test_a_zero_delta_is_rejected() -> void:
	# is_attack_active が真の状態で見る: 偽の状態だけでは、拒否のときに偽へ倒す実装が素通りする
	var brain: ChargerBrain = _brain_in_state(CHARGE)
	var expected: String = INVALID_DELTA_ERROR_FORMAT % ZERO_DELTA

	await assert_error(
		func() -> void: brain.update(ZERO_DELTA, NEAR_DISTANCE)
	).is_push_error(expected)

	var actual: Array = [brain.state, brain.is_attack_active]
	assert_array(actual).is_equal([EnemyState.State.CHARGE, true])


func test_a_negative_delta_is_rejected() -> void:
	var brain: ChargerBrain = _brain_in_state(CHARGE)
	var expected: String = INVALID_DELTA_ERROR_FORMAT % NEGATIVE_DELTA

	await assert_error(
		func() -> void: brain.update(NEGATIVE_DELTA, NEAR_DISTANCE)
	).is_push_error(expected)

	var actual: Array = [brain.state, brain.is_attack_active]
	assert_array(actual).is_equal([EnemyState.State.CHARGE, true])


func test_a_negative_distance_is_rejected() -> void:
	var brain: ChargerBrain = _brain_in_state(CHARGE)
	var expected: String = NEGATIVE_DISTANCE_ERROR_FORMAT % NEGATIVE_DISTANCE

	await assert_error(
		func() -> void: brain.update(FRAME_DELTA, NEGATIVE_DISTANCE)
	).is_push_error(expected)

	var actual: Array = [brain.state, brain.is_attack_active]
	assert_array(actual).is_equal([EnemyState.State.CHARGE, true])


func test_invalid_arguments_are_rejected_in_every_reachable_state() -> void:
	for state: String in REACHABLE_STATES:
		for row: Array in INVALID_ARGUMENT_TABLE:
			var brain: ChargerBrain = _brain_in_state(state)
			var before: Array = [brain.state, brain.is_attack_active]
			var context: String = "state=%s delta=%s distance=%s" % [state, row[0], row[1]]

			await (
				assert_error(func() -> void: brain.update(row[0], row[1]))
				. append_failure_message(context)
				. is_push_error(row[2])
			)

			var actual: Array = [brain.state, brain.is_attack_active]
			assert_array(actual).append_failure_message(context).is_equal(before)


# ガードを満了の判定より後ろに置いた実装は、拒否したフレームの delta を滞在時間へ数えてしまう。
# 距離の異常と delta の異常でずれる向きが逆(足す / 引く)なので、両方に個別のケースを割り当てる
func test_a_rejected_distance_does_not_count_toward_the_telegraph() -> void:
	var brain: ChargerBrain = _brain_in_state(TELEGRAPH)
	var expected: String = NEGATIVE_DISTANCE_ERROR_FORMAT % NEGATIVE_DISTANCE

	await assert_error(
		func() -> void: brain.update(TELEGRAPH_TIME, NEGATIVE_DISTANCE)
	).is_push_error(expected)
	brain.update(SMALL_DELTA, NEAR_DISTANCE)

	assert_int(brain.state).is_equal(EnemyState.State.TELEGRAPH)


func test_a_rejected_delta_does_not_count_toward_the_telegraph() -> void:
	var brain: ChargerBrain = _brain_in_state(TELEGRAPH)
	brain.update(TELEGRAPH_TIME, NEAR_DISTANCE)
	var expected: String = INVALID_DELTA_ERROR_FORMAT % NEGATIVE_DELTA

	await assert_error(
		func() -> void: brain.update(NEGATIVE_DELTA, NEAR_DISTANCE)
	).is_push_error(expected)
	brain.update(SMALL_DELTA, NEAR_DISTANCE)

	assert_int(brain.state).is_equal(EnemyState.State.CHARGE)


func test_a_zero_distance_is_accepted_and_starts_the_telegraph() -> void:
	# 事前条件は「0 以上」であり 0 は正当な入力である。距離の検査を 0 以下へ広げる変異はここで落ちる
	var brain: ChargerBrain = _new_brain()

	await assert_error(func() -> void: brain.update(FRAME_DELTA, ZERO_DISTANCE)).is_success()

	assert_int(brain.state).is_equal(EnemyState.State.TELEGRAPH)


func test_the_distance_does_not_cut_a_state_short() -> void:
	for row: Array in SWING_TABLE:
		var state: String = row[0]
		var state_value: int = row[1]
		var duration: float = row[2]
		var next_state: int = row[3]
		var brain: ChargerBrain = _brain_in_state(state)
		var observed: Array = []
		var expected: Array = []

		for distance: float in SWING_DISTANCES:
			brain.update(SMALL_DELTA, distance)
			observed.append(brain.state)
			expected.append(state_value)

		# 満了させる。満了のフレームの距離は到達距離の内側に取る: 標的の不在の分岐と混ぜない
		brain.update(duration, NEAR_DISTANCE)
		brain.update(SMALL_DELTA, NEAR_DISTANCE)
		observed.append(brain.state)
		expected.append(next_state)

		assert_array(observed).append_failure_message("state=%s" % state).is_equal(expected)


func test_the_brain_stays_idle_while_the_target_is_absent() -> void:
	var brain: ChargerBrain = _new_brain()
	# 複数行の lambda を呼び出しの引数へ直接書けない(閉じ括弧の字下げが戻せない)ため変数へ置く
	var run_frames: Callable = func() -> void:
		for _frame: int in CYCLE_FRAME_COUNT:
			brain.update(FRAME_DELTA, INF)

	await assert_error(run_frames).is_success()

	var actual: Array = [brain.state, brain.is_attack_active]
	assert_array(actual).is_equal([EnemyState.State.IDLE, false])


func test_the_telegraph_ends_in_the_recover_when_the_target_is_absent() -> void:
	var brain: ChargerBrain = _brain_in_state(TELEGRAPH)
	brain.update(TELEGRAPH_TIME, NEAR_DISTANCE)

	brain.update(SMALL_DELTA, INF)

	assert_int(brain.state).is_equal(EnemyState.State.RECOVER)
	assert_bool(brain.is_attack_active).is_false()


# 満了時の分岐の両側。片側だけでは、分岐そのものを消した実装が残る側で素通りする。
# 有限の側は桁の大きい距離でも見る: 不在の判定をしきい値(距離が巨大なら不在と見なす)へ
# 置き換えた実装は、遠いだけで標的のある局面を取りやめてしまう
func test_the_expiry_of_the_telegraph_branches_on_the_presence_of_the_target() -> void:
	var present_brain: ChargerBrain = _brain_in_state(TELEGRAPH)
	var far_present_brain: ChargerBrain = _brain_in_state(TELEGRAPH)
	var absent_brain: ChargerBrain = _brain_in_state(TELEGRAPH)
	for brain: ChargerBrain in [present_brain, far_present_brain, absent_brain]:
		brain.update(TELEGRAPH_TIME, NEAR_DISTANCE)

	present_brain.update(SMALL_DELTA, NEAR_DISTANCE)
	far_present_brain.update(SMALL_DELTA, HUGE_FINITE_DISTANCE)
	absent_brain.update(SMALL_DELTA, INF)

	var actual: Array = [
		present_brain.state,
		present_brain.is_attack_active,
		far_present_brain.state,
		far_present_brain.is_attack_active,
		absent_brain.state,
		absent_brain.is_attack_active,
	]
	var expected: Array = [
		EnemyState.State.CHARGE,
		true,
		EnemyState.State.CHARGE,
		true,
		EnemyState.State.RECOVER,
		false,
	]
	assert_array(actual).is_equal(expected)


# INF は事前条件の「0 以上」を満たす。異常な引数(push_error を出す)との非対称を固定する
func test_an_absent_target_pushes_no_error() -> void:
	var brain: ChargerBrain = _brain_in_state(TELEGRAPH)
	brain.update(TELEGRAPH_TIME, NEAR_DISTANCE)

	await assert_error(func() -> void: brain.update(SMALL_DELTA, INF)).is_success()

	assert_int(brain.state).is_equal(EnemyState.State.RECOVER)


func test_the_cancelled_charge_recovers_for_the_full_recover_time() -> void:
	var brain: ChargerBrain = _brain_in_state(TELEGRAPH)
	brain.update(TELEGRAPH_TIME, NEAR_DISTANCE)
	brain.update(SMALL_DELTA, INF)

	brain.update(NEARLY_RECOVER_TIME, INF)
	brain.update(SMALL_DELTA, INF)
	var before_expiry: int = brain.state
	brain.update(SMALL_DELTA, INF)

	assert_array([before_expiry, brain.state]).is_equal(
		[EnemyState.State.RECOVER, EnemyState.State.IDLE]
	)


func test_every_reachable_state_is_one_of_the_shared_enum_values() -> void:
	var names: Array[String] = []

	for state: String in REACHABLE_STATES:
		names.append(_state_name(_brain_in_state(state).state))

	assert_array(names).is_equal(["IDLE", "TELEGRAPH", "CHARGE", "RECOVER"])
