extends GdUnitTestSuite

# 2 進で厳密に表せる値を使う: 累積の誤差で「regen_delay ちょうど」の判定が揺れると、
# 境界を含むか含まないかを検証できない。回復量も端数の切り捨てを厳密に書けなくなる
const MAX_VALUE: int = 40
const REGEN_DELAY: float = 0.5
const REGEN_PER_SECOND: float = 8.0
# 1 フレームで 0.5 回復する delta。端数の蓄積と切り捨てが 2 フレーム周期で観測できる
const FRAME_DELTA: float = 0.0625
# 1 フレームで 2 回復する delta
const BIG_DELTA: float = 0.25
# 上限に達するまで回復させる delta
const HUGE_DELTA: float = 10.0
# 待機時間のすぐ内側(比は 1 - 2^-19)。開始のしきい値を緩める変異を捕らえる
const NEARLY_REGEN_DELAY: float = 0.49999904632568359375
# 待機時間のうちに消化しても届かないフレーム数(7 × 0.0625 = 0.4375)
const FRAMES_UNDER_DELAY: int = 7

const DAMAGE: int = 20
const DAMAGED_CURRENT: int = 20
# 被弾を拒む値。0 だけだと「引いた結果が同じ」で素通りするため負値を混ぜる
const INVALID_AMOUNTS: Array[int] = [0, -1, -DAMAGE]
# 実装の定数は参照しない: 参照するとアサーションが自明化し、文言の退行を検出できない
const INVALID_AMOUNT_ERROR_FORMAT: String = (
	"Health.take_damage(): amount は正でなければならない(現在値: %s)。状態を変えずに返る"
)

# _init() の引数が使われていることを見るための対の値。既定の PlayerStats とも異なる
const LONG_REGEN_DELAY: float = 1.0
const FAST_REGEN_PER_SECOND: float = 16.0
const LARGE_MAX_VALUE: int = 48

# 待機が明けた後に FRAME_DELTA で 8 フレーム回復させたときの current。
# 1 フレームあたり 0.5 であり、端数を切り捨てるため 2 フレームに 1 だけ増える
const REGEN_STEPS: int = 8
const CURRENT_PER_REGEN_STEP: Array[int] = [20, 21, 21, 22, 22, 23, 23, 24]

# 到達できる状態の名前。_health_in_state() が組み立てる
const FULL: String = "full"
const WAITING: String = "waiting"
const REGENERATING: String = "regenerating"
const NEAR_MAX: String = "near_max"
const DEPLETED: String = "depleted"

# 到達できる状態 × delta の総当たり。待機と回復の分岐を広げる変異・上限の強制を外す変異が
# 片側だけの検証では素通りするため、出力を厳密比較の表で押さえる。
# 各行は [状態, delta, [current, is_depleted]]
const TICK_TABLE: Array = [
	[FULL, FRAME_DELTA, [40, false]],
	[FULL, BIG_DELTA, [40, false]],
	[FULL, REGEN_DELAY, [40, false]],
	[WAITING, FRAME_DELTA, [20, false]],
	[WAITING, BIG_DELTA, [20, false]],
	[WAITING, REGEN_DELAY, [20, false]],
	[REGENERATING, FRAME_DELTA, [20, false]],
	[REGENERATING, BIG_DELTA, [22, false]],
	[REGENERATING, REGEN_DELAY, [24, false]],
	[NEAR_MAX, FRAME_DELTA, [39, false]],
	[NEAR_MAX, BIG_DELTA, [40, false]],
	[NEAR_MAX, REGEN_DELAY, [40, false]],
	[DEPLETED, FRAME_DELTA, [0, true]],
	[DEPLETED, BIG_DELTA, [0, true]],
	[DEPLETED, REGEN_DELAY, [0, true]],
]


func _new_health(
	max_value: int = MAX_VALUE,
	regen_delay: float = REGEN_DELAY,
	regen_per_second: float = REGEN_PER_SECOND
) -> Health:
	return auto_free(Health.new(max_value, regen_delay, regen_per_second))


## 表の各行が指す状態の体力を組み立てる。到達経路は take_damage() と tick() だけで作る
func _health_in_state(state: String) -> Health:
	var health: Health = _new_health()
	match state:
		FULL:
			pass
		WAITING:
			health.take_damage(DAMAGE)
		REGENERATING:
			health.take_damage(DAMAGE)
			health.tick(REGEN_DELAY)
		NEAR_MAX:
			health.take_damage(1)
			health.tick(REGEN_DELAY)
		DEPLETED:
			health.take_damage(MAX_VALUE)
	return health


## `depleted` の発火を控える配列を返す。Array は参照として捕捉されるため、
## 値コピーで捕捉される lambda のローカル変数と違い外側から回数を読める
func _record_depleted(health: Health) -> Array[bool]:
	var emissions: Array[bool] = []
	health.depleted.connect(func() -> void: emissions.append(true))
	return emissions


func test_a_new_health_is_full() -> void:
	var health: Health = _new_health()

	assert_int(health.current).is_equal(MAX_VALUE)
	assert_bool(health.is_depleted).is_false()


func test_take_damage_subtracts_the_amount() -> void:
	var health: Health = _new_health()

	health.take_damage(DAMAGE)

	assert_int(health.current).is_equal(DAMAGED_CURRENT)


func test_take_damage_stops_at_zero() -> void:
	var health: Health = _new_health()

	health.take_damage(MAX_VALUE + DAMAGE)

	assert_int(health.current).is_equal(0)


# 拒んだときに「体力が変わらない」だけでなく「待機の計測が振り出しに戻らない」ことも見る。
# 0 は引いても体力が変わらないため、計測を見ないとガードを外す変異が素通りする
func test_take_damage_rejects_an_amount_that_is_not_positive() -> void:
	for amount: int in INVALID_AMOUNTS:
		var health: Health = _new_health()
		health.take_damage(DAMAGE)
		health.tick(NEARLY_REGEN_DELAY)
		var expected: String = INVALID_AMOUNT_ERROR_FORMAT % amount

		await assert_error(func() -> void: health.take_damage(amount)).is_push_error(expected)

		var after_error: int = health.current
		# 待機が残り 1 フレーム分であること: 拒否が計測を戻していれば回復に届かない
		health.tick(FRAME_DELTA)
		health.tick(BIG_DELTA)
		var context: String = "amount=%d" % amount
		assert_array([after_error, health.current]).append_failure_message(context).is_equal(
			[DAMAGED_CURRENT, DAMAGED_CURRENT + 2]
		)


# 正常系を境界のすぐ内側で通す: 拒否の範囲が 0 より広がる変異を、異常系のケースでは検出できない
func test_take_damage_accepts_the_smallest_positive_amount() -> void:
	var health: Health = _new_health()

	await assert_error(func() -> void: health.take_damage(1)).is_success()

	assert_int(health.current).is_equal(MAX_VALUE - 1)


func test_depleted_is_emitted_once_when_the_current_reaches_zero() -> void:
	var health: Health = _new_health()
	var emissions: Array[bool] = _record_depleted(health)

	health.take_damage(MAX_VALUE)
	health.take_damage(DAMAGE)
	health.take_damage(DAMAGE)

	assert_array(emissions).is_equal([true])
	assert_int(health.current).is_equal(0)
	assert_bool(health.is_depleted).is_true()


func test_depleted_is_not_emitted_while_the_current_stays_above_zero() -> void:
	var health: Health = _new_health()
	var emissions: Array[bool] = _record_depleted(health)

	health.take_damage(MAX_VALUE - 1)
	health.tick(REGEN_DELAY)
	health.tick(BIG_DELTA)

	assert_array(emissions).is_equal([])
	assert_int(health.current).is_equal(3)
	assert_bool(health.is_depleted).is_false()


# 枯渇の後は追加の被弾でも自動回復でも状態が動かない。
# tick を 2 回踏むのは、1 回目で待機が明けて 2 回目から回復が始まる形だから
func test_a_depleted_health_does_not_change_state() -> void:
	var health: Health = _new_health()
	health.take_damage(MAX_VALUE)
	var states: Array = []

	health.take_damage(DAMAGE)
	states.append([health.current, health.is_depleted])
	health.tick(HUGE_DELTA)
	states.append([health.current, health.is_depleted])
	health.tick(HUGE_DELTA)
	states.append([health.current, health.is_depleted])

	assert_array(states).is_equal([[0, true], [0, true], [0, true]])


func test_no_regen_while_the_delay_has_not_elapsed() -> void:
	var health: Health = _new_health()
	health.take_damage(DAMAGE)
	var currents: Array[int] = []

	for _frame: int in FRAMES_UNDER_DELAY:
		health.tick(FRAME_DELTA)
		currents.append(health.current)

	assert_array(currents).is_equal([20, 20, 20, 20, 20, 20, 20])


# 待機時間のすぐ内側。開始のしきい値が緩む変異を捕らえる。
# 経過の判定は delta を足す前に行われるため、内側の値に届いた次のフレームまで見る
func test_no_regen_just_below_the_delay() -> void:
	var health: Health = _new_health()
	health.take_damage(DAMAGE)
	var currents: Array[int] = []

	health.tick(NEARLY_REGEN_DELAY)
	currents.append(health.current)
	health.tick(BIG_DELTA)
	currents.append(health.current)

	assert_array(currents).is_equal([20, 20])


# 待機を消化したフレームは回復に使わない。同じ delta を待機と回復の両方へ数えると、
# 被弾から回復の開始までが regen_delay より短くなる
func test_the_frame_that_elapses_the_delay_does_not_regen() -> void:
	var health: Health = _new_health()
	health.take_damage(DAMAGE)
	var currents: Array[int] = []

	health.tick(REGEN_DELAY)
	currents.append(health.current)
	health.tick(BIG_DELTA)
	currents.append(health.current)

	assert_array(currents).is_equal([20, 22])


func test_regen_moves_only_the_whole_part_of_the_accumulated_amount() -> void:
	var health: Health = _new_health()
	health.take_damage(DAMAGE)
	health.tick(REGEN_DELAY)
	var currents: Array[int] = []

	for _frame: int in REGEN_STEPS:
		health.tick(FRAME_DELTA)
		currents.append(health.current)

	assert_array(currents).is_equal(CURRENT_PER_REGEN_STEP)


func test_regen_stops_at_the_maximum() -> void:
	var health: Health = _new_health()
	health.take_damage(DAMAGE)
	health.tick(REGEN_DELAY)
	var currents: Array[int] = []

	health.tick(HUGE_DELTA)
	currents.append(health.current)
	health.tick(HUGE_DELTA)
	currents.append(health.current)

	assert_array(currents).is_equal([MAX_VALUE, MAX_VALUE])


func test_take_damage_restarts_the_delay() -> void:
	var health: Health = _new_health()
	health.take_damage(DAMAGE)
	health.tick(REGEN_DELAY)
	health.tick(BIG_DELTA)
	var currents: Array[int] = []

	health.take_damage(DAMAGE)
	currents.append(health.current)
	health.tick(NEARLY_REGEN_DELAY)
	currents.append(health.current)
	health.tick(BIG_DELTA)
	currents.append(health.current)
	health.tick(BIG_DELTA)
	currents.append(health.current)

	assert_array(currents).is_equal([2, 2, 2, 4])


# 端数を持ち越すと、被弾のたびに回復の最初の 1 点が早まる
func test_the_regen_remainder_does_not_survive_a_hit() -> void:
	var health: Health = _new_health()
	health.take_damage(DAMAGE)
	health.tick(REGEN_DELAY)
	health.tick(FRAME_DELTA)
	var currents: Array[int] = []

	health.take_damage(1)
	health.tick(REGEN_DELAY)
	currents.append(health.current)
	health.tick(FRAME_DELTA)
	currents.append(health.current)
	health.tick(FRAME_DELTA)
	currents.append(health.current)

	assert_array(currents).is_equal([19, 19, 20])


func test_the_tick_table_holds_for_every_reachable_state() -> void:
	for row: Array in TICK_TABLE:
		var state: String = row[0]
		var delta: float = row[1]
		var expected: Array = row[2]
		var health: Health = _health_in_state(state)

		health.tick(delta)

		var actual: Array = [health.current, health.is_depleted]
		var context: String = "state=%s delta=%s" % [state, delta]
		assert_array(actual).append_failure_message(context).is_equal(expected)


# 待機時間が _init() の引数から来ることを見る: 値を直書きした実装は両方で同じに振る舞う
func test_a_longer_delay_postpones_the_regen() -> void:
	var short_health: Health = _new_health()
	var long_health: Health = _new_health(MAX_VALUE, LONG_REGEN_DELAY)
	for health: Health in [short_health, long_health]:
		health.take_damage(DAMAGE)
		health.tick(REGEN_DELAY)
		health.tick(BIG_DELTA)

	assert_int(short_health.current).is_equal(22)
	assert_int(long_health.current).is_equal(20)


func test_a_longer_delay_regens_once_it_elapses() -> void:
	var health: Health = _new_health(MAX_VALUE, LONG_REGEN_DELAY)
	health.take_damage(DAMAGE)

	health.tick(LONG_REGEN_DELAY)
	health.tick(BIG_DELTA)

	assert_int(health.current).is_equal(22)


# 回復の速さが _init() の引数から来ることを見る
func test_a_faster_rate_regens_more_per_frame() -> void:
	var slow_health: Health = _new_health()
	var fast_health: Health = _new_health(MAX_VALUE, REGEN_DELAY, FAST_REGEN_PER_SECOND)
	for health: Health in [slow_health, fast_health]:
		health.take_damage(DAMAGE)
		health.tick(REGEN_DELAY)
		health.tick(BIG_DELTA)

	assert_int(slow_health.current).is_equal(22)
	assert_int(fast_health.current).is_equal(24)


# 上限が _init() の引数から来ることを見る
func test_a_larger_maximum_starts_and_caps_higher() -> void:
	var small_health: Health = _new_health()
	var large_health: Health = _new_health(LARGE_MAX_VALUE)
	var starts: Array[int] = [small_health.current, large_health.current]
	for health: Health in [small_health, large_health]:
		health.take_damage(4)
		health.tick(REGEN_DELAY)
		health.tick(HUGE_DELTA)

	assert_array(starts).is_equal([MAX_VALUE, LARGE_MAX_VALUE])
	assert_array([small_health.current, large_health.current]).is_equal(
		[MAX_VALUE, LARGE_MAX_VALUE]
	)
