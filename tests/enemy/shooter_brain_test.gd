extends GdUnitTestSuite

# 2 進で厳密に表せる値を使う: 累積の誤差で「telegraph_time ちょうど」の判定が揺れると、
# 境界を含むか含まないかを検証できない。既定値(0.4 / 0.8 / 128.0 / 150.0 / 0.6)とは
# 別の値にする: 値を直書きした実装がテスト用の stats でも同じに振る舞うことを避ける
const TELEGRAPH_TIME: float = 0.25
const RECOVER_TIME: float = 0.75
const DETECT_RANGE: float = 4.0

# 索敵範囲と、突進型が遷移の条件に使う到達距離(attack_speed * attack_duration = 8.0)を
# 別の値に取る: 条件を到達距離へ差し替える変異は、両方を跨ぐ距離でだけ落ちる
const ATTACK_SPEED: float = 16.0
const ATTACK_DURATION: float = 0.5
# 積から導く: 値を手で複製すると、どちらかの因子を動かしたとき「両方を跨ぐ」性質が黙って崩れる
const ATTACK_REACH: float = ATTACK_SPEED * ATTACK_DURATION

const FRAME_DELTA: float = 0.125
const SMALL_DELTA: float = 0.03125

# 境界のすぐ内側 / 外側。絶対値ではなく比(1 ± 2^-20)で近づける: しきい値を 0.999 倍まで
# 緩める変異は、絶対値で近づけた値では素通りする
const NEAR_RATIO: float = 1.0 - 1.0 / 1048576.0
const OVER_RATIO: float = 1.0 + 1.0 / 1048576.0
const NEARLY_TELEGRAPH_TIME: float = TELEGRAPH_TIME * NEAR_RATIO
const NEARLY_RECOVER_TIME: float = RECOVER_TIME * NEAR_RATIO
const JUST_OUTSIDE_DETECT_RANGE: float = DETECT_RANGE * OVER_RATIO

# 索敵範囲の内側 / 外側。外側の値は到達距離(ATTACK_REACH)の内側に取る: 遷移の条件を
# 到達距離へ差し替える変異は、両方を跨ぐこの距離でだけ落ちる。
# 内側の値は他の stats(telegraph_time 0.25・recover_time 0.75・attack_duration 0.5)より
# 大きく取る: 条件をそれらへ差し替える変異はこの距離で落ちる
const NEAR_DISTANCE: float = 2.0
const FAR_DISTANCE: float = 6.0

# 長い側の stats。_init() の引数が実際に使われていることを長短の比較で示す。
# LONG_DETECT_RANGE は FAR_DISTANCE より大きく、到達距離(8.0)とは別の値に取る
const LONG_TELEGRAPH_TIME: float = 1.0
const LONG_RECOVER_TIME: float = 2.0
const LONG_DETECT_RANGE: float = 12.0

# 事前条件を破る引数。0 と負値の両方を置く
const ZERO_DELTA: float = 0.0
const NEGATIVE_DELTA: float = -FRAME_DELTA
const NEGATIVE_DISTANCE: float = -1.0
# 0 のすぐ外側(-2^-20)。負値が -1.0 の 1 つだけだと、距離の検査を
# `< -0.0001` のようなしきい値へ緩める実装と、報告する値を定数 -1.0 に固定する実装が
# どちらも素通りする
const SMALLEST_NEGATIVE_DISTANCE: float = -1.0 / 1048576.0
# 事前条件を満たす最小の delta。ガードが正の側へ広がる実装はここで落ちる
const SMALLEST_DELTA: float = 1.0 / 1048576.0

# 実装の定数を参照しない: 参照するとアサーションが自明になり、文言の退行を検出できない
const INVALID_DELTA_ERROR_FORMAT: String = (
	"ShooterBrain.update(): delta は正でなければならない(現在値: %s)。状態を変えずに偽を返す"
)
const NEGATIVE_DISTANCE_ERROR_FORMAT: String = (
	"ShooterBrain.update(): distance_to_target は 0 以上でなければならない(現在値: %s)。"
	+ "状態を変えずに偽を返す"
)

# 到達できる状態すべてに与える異常な引数の表。各行は [delta, 距離, 期待する文言]
const INVALID_ARGUMENT_TABLE: Array = [
	[ZERO_DELTA, NEAR_DISTANCE, INVALID_DELTA_ERROR_FORMAT % ZERO_DELTA],
	[NEGATIVE_DELTA, NEAR_DISTANCE, INVALID_DELTA_ERROR_FORMAT % NEGATIVE_DELTA],
	[FRAME_DELTA, NEGATIVE_DISTANCE, NEGATIVE_DISTANCE_ERROR_FORMAT % NEGATIVE_DISTANCE],
	[
		FRAME_DELTA,
		SMALLEST_NEGATIVE_DISTANCE,
		NEGATIVE_DISTANCE_ERROR_FORMAT % SMALLEST_NEGATIVE_DISTANCE,
	],
]

# 到達できる状態の名前。_brain_in_state() が組み立てる
const IDLE: String = "idle"
const TELEGRAPH: String = "telegraph"
const COOLDOWN: String = "cooldown"

const REACHABLE_STATES: Array[String] = [IDLE, TELEGRAPH, COOLDOWN]

# 満了より前に与える距離。索敵範囲の内外・境界の 0・標的の不在(INF)を跨ぐ。
# 合計の delta(SMALL_DELTA × 4 = 0.125)はどの滞在時間より短い
const SWING_DISTANCES: Array[float] = [FAR_DISTANCE, NEAR_DISTANCE, INF, 0.0]

# 滞在中に距離を振っても満了まで遷移しないことを見る表。
# 各行は [状態, その状態の enum, 滞在時間, 満了後の状態, 満了のフレームの戻り値]
const SWING_TABLE: Array = [
	[TELEGRAPH, EnemyState.State.TELEGRAPH, TELEGRAPH_TIME, EnemyState.State.COOLDOWN, true],
	[COOLDOWN, EnemyState.State.COOLDOWN, RECOVER_TIME, EnemyState.State.IDLE, false],
]

# 到達できる状態 × 距離の総当たり。条件を広げる変異・分岐を入れ替える変異が片側だけの
# 検証では素通りするため、出力を厳密比較の表で押さえる。
# 各行は [状態, 距離, [update() の戻り値, update() 後の state]]
const UPDATE_TABLE: Array = [
	[IDLE, NEAR_DISTANCE, [false, EnemyState.State.TELEGRAPH]],
	[IDLE, FAR_DISTANCE, [false, EnemyState.State.IDLE]],
	[TELEGRAPH, NEAR_DISTANCE, [false, EnemyState.State.TELEGRAPH]],
	[TELEGRAPH, FAR_DISTANCE, [false, EnemyState.State.TELEGRAPH]],
	[COOLDOWN, NEAR_DISTANCE, [false, EnemyState.State.COOLDOWN]],
	[COOLDOWN, FAR_DISTANCE, [false, EnemyState.State.COOLDOWN]],
]

# FRAME_DELTA(0.125)で距離を索敵範囲の内側に保ったまま回したときの state の並び。
# 予備動作 3 フレーム・4 フレーム目に発射・待機 7 フレーム・11 フレーム目に IDLE へ戻り、
# 15 フレーム目に 2 回目の発射が来る
const CYCLE_FRAME_COUNT: int = 15
const EXPECTED_CYCLE: Array = [
	EnemyState.State.TELEGRAPH,
	EnemyState.State.TELEGRAPH,
	EnemyState.State.TELEGRAPH,
	EnemyState.State.COOLDOWN,
	EnemyState.State.COOLDOWN,
	EnemyState.State.COOLDOWN,
	EnemyState.State.COOLDOWN,
	EnemyState.State.COOLDOWN,
	EnemyState.State.COOLDOWN,
	EnemyState.State.COOLDOWN,
	EnemyState.State.IDLE,
	EnemyState.State.TELEGRAPH,
	EnemyState.State.TELEGRAPH,
	EnemyState.State.TELEGRAPH,
	EnemyState.State.COOLDOWN,
]

# 同じフレーム列の戻り値。満了のフレームの前後を含めて厳密に比較する: 真を返すフレームが
# 1 つでも増える・ずれる変異はこの並びで落ちる
const EXPECTED_FIRES: Array[bool] = [
	false,
	false,
	false,
	true,
	false,
	false,
	false,
	false,
	false,
	false,
	false,
	false,
	false,
	false,
	true,
]


func _new_stats(
	telegraph_time: float = TELEGRAPH_TIME,
	recover_time: float = RECOVER_TIME,
	detect_range: float = DETECT_RANGE
) -> EnemyStats:
	var stats: EnemyStats = auto_free(EnemyStats.new())
	stats.telegraph_time = telegraph_time
	stats.recover_time = recover_time
	stats.detect_range = detect_range
	stats.attack_speed = ATTACK_SPEED
	stats.attack_duration = ATTACK_DURATION
	return stats


func _new_brain(stats: EnemyStats = _new_stats()) -> ShooterBrain:
	return auto_free(ShooterBrain.new(stats))


## 表の各行が指す状態の Brain を組み立てる。到達経路は update() の呼び出しだけで作る。
## 進入のフレームの delta は滞在時間へ数えないため、返る Brain の滞在時間は 0 である
func _brain_in_state(state: String, brain: ShooterBrain = _new_brain()) -> ShooterBrain:
	match state:
		IDLE:
			pass
		TELEGRAPH:
			brain.update(SMALL_DELTA, NEAR_DISTANCE)
		COOLDOWN:
			_brain_in_state(TELEGRAPH, brain)
			brain.update(TELEGRAPH_TIME, NEAR_DISTANCE)
			brain.update(SMALL_DELTA, NEAR_DISTANCE)
	return brain


## 予備動作の満了に達した(次の update() が真を返す)Brain を組み立てる。
## 異常系をこの状態で見る理由は、拒否のフレームで滞在時間を巻き戻す実装を捕らえるため
## である(滞在時間が 0 の状態から始めると、巻き戻しが no-op になって観測できない)。
## 戻り値と state の不変は到達可能な状態を総当たりする表の側でも担保している
func _brain_primed_to_fire() -> ShooterBrain:
	var brain: ShooterBrain = _brain_in_state(TELEGRAPH)
	brain.update(TELEGRAPH_TIME, NEAR_DISTANCE)
	return brain


func _state_name(state: int) -> String:
	return String(EnemyState.State.keys()[state])


func test_a_new_brain_is_idle() -> void:
	var brain: ShooterBrain = _new_brain()

	assert_int(brain.state).is_equal(EnemyState.State.IDLE)


func test_the_brain_stays_idle_while_the_target_is_out_of_the_detect_range() -> void:
	# 到達距離(突進型が使う条件)の内側だが索敵範囲の外側。条件を到達距離へ差し替える
	# 変異はここで落ちる
	var brain: ShooterBrain = _new_brain()
	var observed: Array = []
	var expected: Array = []

	# この距離が両方を跨いでいることを機械で確かめる: コメントの主張だけだと、定数を動かした
	# ときに「跨いでいない」ことに気付けないまま緑になる
	assert_float(FAR_DISTANCE).is_greater(DETECT_RANGE)
	assert_float(FAR_DISTANCE).is_less(ATTACK_REACH)

	for _frame: int in CYCLE_FRAME_COUNT:
		observed.append([brain.update(FRAME_DELTA, FAR_DISTANCE), brain.state])
		expected.append([false, EnemyState.State.IDLE])

	assert_array(observed).is_equal(expected)


# 標的の不在(呼び出し側は距離に INF を渡す)は出荷時の常用の経路である。遷移そのものは
# 1 フレームでも捕らえられるが、不在が続く間ずっと偽を返すこと(1 周期を通して発射の
# フレームが 1 度も現れないこと)まで見るため 1 周期ぶん回す
func test_the_brain_stays_idle_while_the_target_is_absent() -> void:
	var brain: ShooterBrain = _new_brain()
	var observed: Array = []
	var expected: Array = []

	for _frame: int in CYCLE_FRAME_COUNT:
		observed.append([brain.update(FRAME_DELTA, INF), brain.state])
		expected.append([false, EnemyState.State.IDLE])

	assert_array(observed).is_equal(expected)


# 距離 0.0 は「以下」を満たす正当な入力(標的と完全に重なる局面)であり、下端を除く実装が
# ここで落ちる
func test_the_brain_telegraphs_at_a_zero_distance() -> void:
	var brain: ShooterBrain = _new_brain()

	var fired: bool = brain.update(FRAME_DELTA, 0.0)

	assert_array([fired, brain.state]).is_equal([false, EnemyState.State.TELEGRAPH])


func test_the_brain_stays_idle_just_outside_the_detect_range() -> void:
	var brain: ShooterBrain = _new_brain()

	var fired: bool = brain.update(FRAME_DELTA, JUST_OUTSIDE_DETECT_RANGE)

	assert_array([fired, brain.state]).is_equal([false, EnemyState.State.IDLE])


func test_the_brain_telegraphs_when_the_target_is_within_the_detect_range() -> void:
	var brain: ShooterBrain = _new_brain()

	var fired: bool = brain.update(FRAME_DELTA, NEAR_DISTANCE)

	assert_array([fired, brain.state]).is_equal([false, EnemyState.State.TELEGRAPH])


func test_the_brain_telegraphs_exactly_at_the_detect_range() -> void:
	var brain: ShooterBrain = _new_brain()

	brain.update(FRAME_DELTA, DETECT_RANGE)

	assert_int(brain.state).is_equal(EnemyState.State.TELEGRAPH)


func test_the_telegraph_persists_just_below_its_duration() -> void:
	var brain: ShooterBrain = _brain_in_state(TELEGRAPH)
	brain.update(NEARLY_TELEGRAPH_TIME, NEAR_DISTANCE)

	var fired: bool = brain.update(SMALL_DELTA, NEAR_DISTANCE)

	assert_array([fired, brain.state]).is_equal([false, EnemyState.State.TELEGRAPH])


func test_the_telegraph_ends_exactly_when_it_elapses() -> void:
	var brain: ShooterBrain = _brain_in_state(TELEGRAPH)
	brain.update(TELEGRAPH_TIME, NEAR_DISTANCE)

	var fired: bool = brain.update(SMALL_DELTA, NEAR_DISTANCE)

	assert_array([fired, brain.state]).is_equal([true, EnemyState.State.COOLDOWN])


func test_the_telegraph_ends_even_when_the_target_is_absent() -> void:
	# 満了時に距離で分岐しない(突進型は分岐する)。標的を失っても待機へ移り、そのフレームは
	# 真を返す。弾を作らない判断は ShooterEnemy が持つ
	var brain: ShooterBrain = _brain_in_state(TELEGRAPH)
	brain.update(TELEGRAPH_TIME, INF)

	var fired: bool = brain.update(SMALL_DELTA, INF)

	assert_array([fired, brain.state]).is_equal([true, EnemyState.State.COOLDOWN])


func test_the_cooldown_persists_just_below_its_duration() -> void:
	var brain: ShooterBrain = _brain_in_state(COOLDOWN)
	brain.update(NEARLY_RECOVER_TIME, NEAR_DISTANCE)

	var fired: bool = brain.update(SMALL_DELTA, NEAR_DISTANCE)

	assert_array([fired, brain.state]).is_equal([false, EnemyState.State.COOLDOWN])


func test_the_cooldown_ends_exactly_when_it_elapses() -> void:
	# 距離が索敵範囲の内側でも、待機の満了で入るのは IDLE である(次の予備動作はその次の
	# フレームから始まる)
	var brain: ShooterBrain = _brain_in_state(COOLDOWN)
	brain.update(RECOVER_TIME, NEAR_DISTANCE)

	var fired: bool = brain.update(SMALL_DELTA, NEAR_DISTANCE)

	assert_array([fired, brain.state]).is_equal([false, EnemyState.State.IDLE])


func test_the_update_table_holds_for_every_reachable_state() -> void:
	for row: Array in UPDATE_TABLE:
		var state: String = row[0]
		var distance: float = row[1]
		var expected: Array = row[2]
		var brain: ShooterBrain = _brain_in_state(state)

		var fired: bool = brain.update(SMALL_DELTA, distance)

		var actual: Array = [fired, brain.state]
		var context: String = "state=%s distance=%s" % [state, distance]
		assert_array(actual).append_failure_message(context).is_equal(expected)


# 4.3・4.4・4.6 をこの 1 本で押さえる: 満了のフレームの前後を含む連続した列を厳密に比較する
func test_the_brain_fires_on_exactly_one_frame_of_each_cycle() -> void:
	var brain: ShooterBrain = _new_brain()
	var states: Array = []
	var fires: Array[bool] = []

	for _frame: int in CYCLE_FRAME_COUNT:
		fires.append(brain.update(FRAME_DELTA, NEAR_DISTANCE))
		states.append(brain.state)

	assert_array(states).is_equal(EXPECTED_CYCLE)
	assert_array(fires).is_equal(EXPECTED_FIRES)


# 遷移したフレームの delta を遷移先へ数えると、予備動作から発射までが telegraph_time より
# 短くなる。遷移のフレームに満了ぶんの delta を与えて、満了が 1 フレーム遅れることを見る
func test_the_frame_that_enters_the_telegraph_does_not_count_toward_it() -> void:
	var brain: ShooterBrain = _new_brain()
	brain.update(TELEGRAPH_TIME, NEAR_DISTANCE)

	var fired: bool = brain.update(SMALL_DELTA, NEAR_DISTANCE)

	assert_array([fired, brain.state]).is_equal([false, EnemyState.State.TELEGRAPH])


func test_the_frame_that_enters_the_cooldown_does_not_count_toward_it() -> void:
	var brain: ShooterBrain = _brain_in_state(TELEGRAPH)
	brain.update(TELEGRAPH_TIME, NEAR_DISTANCE)
	brain.update(RECOVER_TIME, NEAR_DISTANCE)

	var fired: bool = brain.update(SMALL_DELTA, NEAR_DISTANCE)

	assert_array([fired, brain.state]).is_equal([false, EnemyState.State.COOLDOWN])


# 滞在時間と索敵範囲が _init() の引数から来ることを見る: 値を直書きした実装は長短の両方で
# 同じに振る舞う
func test_a_longer_telegraph_time_delays_the_shot() -> void:
	var short_brain: ShooterBrain = _brain_in_state(TELEGRAPH)
	var long_brain: ShooterBrain = _brain_in_state(
		TELEGRAPH, _new_brain(_new_stats(LONG_TELEGRAPH_TIME))
	)
	var fires: Array[bool] = []

	for brain: ShooterBrain in [short_brain, long_brain]:
		brain.update(TELEGRAPH_TIME, NEAR_DISTANCE)
		fires.append(brain.update(SMALL_DELTA, NEAR_DISTANCE))

	assert_array(fires).is_equal([true, false])
	assert_array([short_brain.state, long_brain.state]).is_equal(
		[EnemyState.State.COOLDOWN, EnemyState.State.TELEGRAPH]
	)


func test_a_longer_telegraph_time_fires_once_it_elapses() -> void:
	var brain: ShooterBrain = _brain_in_state(
		TELEGRAPH, _new_brain(_new_stats(LONG_TELEGRAPH_TIME))
	)

	brain.update(LONG_TELEGRAPH_TIME, NEAR_DISTANCE)
	var fired: bool = brain.update(SMALL_DELTA, NEAR_DISTANCE)

	assert_array([fired, brain.state]).is_equal([true, EnemyState.State.COOLDOWN])


func test_a_longer_recover_time_delays_the_idle() -> void:
	var short_brain: ShooterBrain = _brain_in_state(COOLDOWN)
	var long_brain: ShooterBrain = _brain_in_state(
		COOLDOWN, _new_brain(_new_stats(TELEGRAPH_TIME, LONG_RECOVER_TIME))
	)

	for brain: ShooterBrain in [short_brain, long_brain]:
		brain.update(RECOVER_TIME, NEAR_DISTANCE)
		brain.update(SMALL_DELTA, NEAR_DISTANCE)

	assert_array([short_brain.state, long_brain.state]).is_equal(
		[EnemyState.State.IDLE, EnemyState.State.COOLDOWN]
	)


func test_a_longer_recover_time_ends_once_it_elapses() -> void:
	var brain: ShooterBrain = _brain_in_state(
		COOLDOWN, _new_brain(_new_stats(TELEGRAPH_TIME, LONG_RECOVER_TIME))
	)

	brain.update(LONG_RECOVER_TIME, NEAR_DISTANCE)
	brain.update(SMALL_DELTA, NEAR_DISTANCE)

	assert_int(brain.state).is_equal(EnemyState.State.IDLE)


func test_a_wider_detect_range_starts_the_telegraph_farther_away() -> void:
	var short_brain: ShooterBrain = _new_brain()
	var long_brain: ShooterBrain = _new_brain(
		_new_stats(TELEGRAPH_TIME, RECOVER_TIME, LONG_DETECT_RANGE)
	)

	short_brain.update(FRAME_DELTA, FAR_DISTANCE)
	long_brain.update(FRAME_DELTA, FAR_DISTANCE)

	assert_array([short_brain.state, long_brain.state]).is_equal(
		[EnemyState.State.IDLE, EnemyState.State.TELEGRAPH]
	)


func test_the_distance_does_not_cut_a_state_short() -> void:
	for row: Array in SWING_TABLE:
		var state: String = row[0]
		var state_value: int = row[1]
		var duration: float = row[2]
		var next_state: int = row[3]
		var fires_on_expiry: bool = row[4]
		var brain: ShooterBrain = _brain_in_state(state)
		var observed: Array = []
		var expected: Array = []

		for distance: float in SWING_DISTANCES:
			observed.append([brain.update(SMALL_DELTA, distance), brain.state])
			expected.append([false, state_value])

		# 満了させる。満了のフレームの距離は索敵範囲の内側に取る
		brain.update(duration, NEAR_DISTANCE)
		observed.append([brain.update(SMALL_DELTA, NEAR_DISTANCE), brain.state])
		expected.append([fires_on_expiry, next_state])

		assert_array(observed).append_failure_message("state=%s" % state).is_equal(expected)


func test_every_reachable_state_is_one_of_the_shared_enum_values() -> void:
	var names: Array[String] = []

	for state: String in REACHABLE_STATES:
		names.append(_state_name(_brain_in_state(state).state))

	assert_array(names).is_equal(["IDLE", "TELEGRAPH", "COOLDOWN"])


func test_a_zero_delta_is_rejected() -> void:
	var brain: ShooterBrain = _brain_primed_to_fire()
	var fired: Array = []
	var call: Callable = func() -> void: fired.append(brain.update(ZERO_DELTA, NEAR_DISTANCE))

	await assert_error(call).is_push_error(INVALID_DELTA_ERROR_FORMAT % ZERO_DELTA)

	assert_array([fired[0], brain.state]).is_equal([false, EnemyState.State.TELEGRAPH])


func test_a_negative_delta_is_rejected() -> void:
	var brain: ShooterBrain = _brain_primed_to_fire()
	var fired: Array = []
	var call: Callable = func() -> void: fired.append(brain.update(NEGATIVE_DELTA, NEAR_DISTANCE))

	await assert_error(call).is_push_error(INVALID_DELTA_ERROR_FORMAT % NEGATIVE_DELTA)

	assert_array([fired[0], brain.state]).is_equal([false, EnemyState.State.TELEGRAPH])


func test_a_negative_distance_is_rejected() -> void:
	var brain: ShooterBrain = _brain_primed_to_fire()
	var fired: Array = []
	var call: Callable = func() -> void: fired.append(brain.update(FRAME_DELTA, NEGATIVE_DISTANCE))

	await assert_error(call).is_push_error(NEGATIVE_DISTANCE_ERROR_FORMAT % NEGATIVE_DISTANCE)

	assert_array([fired[0], brain.state]).is_equal([false, EnemyState.State.TELEGRAPH])
	# 滞在時間も巻き戻していないこと: 拒否のときに _elapsed を 0 へ戻す実装はここで落ちる。
	# 満了に達した Brain で見るため、巻き戻せば次の 1 フレームで真が返らなくなる
	var after: bool = brain.update(SMALL_DELTA, NEAR_DISTANCE)
	assert_array([after, brain.state]).is_equal([true, EnemyState.State.COOLDOWN])


func test_invalid_arguments_are_rejected_in_every_reachable_state() -> void:
	for state: String in REACHABLE_STATES:
		for row: Array in INVALID_ARGUMENT_TABLE:
			var brain: ShooterBrain = _brain_in_state(state)
			var before: int = brain.state
			var fired: Array = []
			var context: String = "state=%s delta=%s distance=%s" % [state, row[0], row[1]]
			var call: Callable = func() -> void: fired.append(brain.update(row[0], row[1]))

			await assert_error(call).append_failure_message(context).is_push_error(row[2])

			var actual: Array = [fired[0], brain.state]
			assert_array(actual).append_failure_message(context).is_equal([false, before])


# ガードを満了の判定より後ろに置いた実装は、拒否したフレームの delta を滞在時間へ数えてしまう。
# 距離の異常と delta の異常でずれる向きが逆(足す / 引く)なので、両方に個別のケースを割り当てる。
# なお「ガードの中で滞在時間を明示的に 0 へ戻す」実装は、滞在時間 0 から始める距離側のケース
# では no-op になって観測できない。それを担うのは満了に達した Brain で拒否させる
# test_a_negative_distance_is_rejected(距離側)と、下の delta 側のケース(こちらは
# _brain_primed_to_fire() 起点なので同じ 1 本が両方を捕らえる)である
func test_a_rejected_distance_does_not_count_toward_the_telegraph() -> void:
	var brain: ShooterBrain = _brain_in_state(TELEGRAPH)
	var call: Callable = func() -> void: brain.update(TELEGRAPH_TIME, NEGATIVE_DISTANCE)

	await assert_error(call).is_push_error(
		NEGATIVE_DISTANCE_ERROR_FORMAT % NEGATIVE_DISTANCE
	)

	# 拒否のフレームを数えていれば、この 1 フレームで予備動作が満了して真が返る
	var fired: bool = brain.update(SMALL_DELTA, NEAR_DISTANCE)
	assert_array([fired, brain.state]).is_equal([false, EnemyState.State.TELEGRAPH])


func test_a_rejected_delta_does_not_count_toward_the_telegraph() -> void:
	var brain: ShooterBrain = _brain_primed_to_fire()
	var call: Callable = func() -> void: brain.update(NEGATIVE_DELTA, NEAR_DISTANCE)

	await assert_error(call).is_push_error(INVALID_DELTA_ERROR_FORMAT % NEGATIVE_DELTA)

	# 負の delta を数えていれば滞在時間が巻き戻り、この 1 フレームでは満了しない
	var fired: bool = brain.update(SMALL_DELTA, NEAR_DISTANCE)
	assert_array([fired, brain.state]).is_equal([true, EnemyState.State.COOLDOWN])


func test_a_smallest_positive_delta_is_accepted() -> void:
	# 事前条件は「正であること」であり、0 のすぐ外側は正当な入力である。delta の検査を
	# 正の側へ広げる変異はここで落ちる
	var brain: ShooterBrain = _brain_in_state(TELEGRAPH)
	var fired: Array = []
	var call: Callable = func() -> void: fired.append(brain.update(SMALLEST_DELTA, NEAR_DISTANCE))

	await assert_error(call).is_success()

	assert_array([fired[0], brain.state]).is_equal([false, EnemyState.State.TELEGRAPH])


func test_an_infinite_distance_is_accepted_and_ends_the_telegraph() -> void:
	# 標的の不在は事前条件を満たす正当な入力である(4.13 の経路)。距離の検査を
	# 「有限であること」まで広げる変異はここで落ちる
	var brain: ShooterBrain = _brain_primed_to_fire()
	var fired: Array = []
	var call: Callable = func() -> void: fired.append(brain.update(SMALL_DELTA, INF))

	await assert_error(call).is_success()

	assert_array([fired[0], brain.state]).is_equal([true, EnemyState.State.COOLDOWN])
