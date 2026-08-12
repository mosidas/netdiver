extends GdUnitTestSuite

# 2 進で厳密に表せる値を使う: 累積の誤差で「charge_time ちょうど」「cooldown ちょうど」の判定が
# 揺れると、境界を含むか含まないかを検証できない
const CHARGE_TIME: float = 0.25
const COOLDOWN: float = 0.5
const FRAME_DELTA: float = 0.0625
const HALF_CHARGE_TIME: float = 0.125
# 境界のすぐ内側。充電の完了とクールダウンの明けが早まる変異を捕らえる
const NEARLY_CHARGE_TIME: float = 0.2490234375
const NEARLY_COOLDOWN: float = 0.4990234375
# さらに内側(比は 1 - 2^-18)。NEARLY_CHARGE_TIME の比は 0.996 であり、完了のしきい値を
# 0.999 まで緩める変異を素通りさせる。2 進で厳密なまま 1.0 との差を詰める
const BARELY_UNDER_CHARGE_TIME: float = 0.24999904632568359375
const LONG_CHARGE_TIME: float = 1.0
const LONG_COOLDOWN: float = 1.0

# FRAME_DELTA で充電しきるまでのフレーム数と、その間の charge_ratio
const FRAMES_TO_FULL_CHARGE: int = 4
const CHARGE_RATIO_PER_FRAME: Array[float] = [0.25, 0.5, 0.75, 1.0]

# 到達できる状態の名前。_weapon_in_state() が組み立てる
const FRESH: String = "fresh"
const HALF_CHARGED: String = "half_charged"
const FULLY_CHARGED: String = "fully_charged"
const COOLING_DOWN: String = "cooling_down"

# 到達できる状態 × 押している/離した の総当たり。条件を広げる変異・分岐を入れ替える変異が
# 片側だけの検証では素通りするため、出力を厳密比較の表で押さえる。
# 各行は [状態, held, [update() の戻り値, charge_ratio, is_cooling_down]]
const UPDATE_TABLE: Array = [
	[FRESH, true, [false, 0.25, false]],
	[FRESH, false, [false, 0.0, false]],
	[HALF_CHARGED, true, [false, 0.75, false]],
	[HALF_CHARGED, false, [false, 0.0, false]],
	[FULLY_CHARGED, true, [false, 1.0, false]],
	[FULLY_CHARGED, false, [true, 0.0, true]],
	[COOLING_DOWN, true, [false, 0.0, true]],
	[COOLING_DOWN, false, [false, 0.0, true]],
]

# 「4 フレーム押して 1 フレーム離す」を繰り返したときに真を返すフレーム(1 始まり)。
# 発射 → クールダウン 8 フレーム → 充電し直し、で 15 フレーム周期になる
const CYCLE_LENGTH: int = 5
const FRAME_COUNT: int = 35
const EXPECTED_FIRE_FRAMES: Array[int] = [5, 20, 35]


func _new_weapon(charge_time: float = CHARGE_TIME, cooldown: float = COOLDOWN) -> SecondaryWeapon:
	return auto_free(SecondaryWeapon.new(charge_time, cooldown))


## 表の各行が指す状態の武器を組み立てる。到達経路は update() の呼び出しだけで作る
func _weapon_in_state(state: String) -> SecondaryWeapon:
	var weapon: SecondaryWeapon = _new_weapon()
	match state:
		FRESH:
			pass
		HALF_CHARGED:
			weapon.update(true, HALF_CHARGE_TIME)
		FULLY_CHARGED:
			weapon.update(true, CHARGE_TIME)
		COOLING_DOWN:
			weapon.update(true, CHARGE_TIME)
			weapon.update(false, FRAME_DELTA)
	return weapon


## 発射して、クールダウンが明けた直後の状態にする
func _fire_and_finish_cooldown(weapon: SecondaryWeapon) -> void:
	weapon.update(true, CHARGE_TIME)
	weapon.update(false, FRAME_DELTA)
	weapon.update(false, COOLDOWN)


func test_a_new_weapon_is_idle() -> void:
	var weapon: SecondaryWeapon = _new_weapon()

	assert_float(weapon.charge_ratio).is_equal(0.0)
	assert_bool(weapon.is_cooling_down).is_false()


func test_charge_ratio_grows_by_the_delta_ratio_each_frame() -> void:
	var weapon: SecondaryWeapon = _new_weapon()
	var ratios: Array[float] = []

	for _frame: int in FRAMES_TO_FULL_CHARGE:
		weapon.update(true, FRAME_DELTA)
		ratios.append(weapon.charge_ratio)

	assert_array(ratios).is_equal(CHARGE_RATIO_PER_FRAME)


func test_charge_ratio_stops_at_one() -> void:
	var weapon: SecondaryWeapon = _new_weapon()
	weapon.update(true, CHARGE_TIME)

	weapon.update(true, CHARGE_TIME)

	assert_float(weapon.charge_ratio).is_equal(1.0)


func test_charging_does_not_fire_while_the_button_is_held() -> void:
	var weapon: SecondaryWeapon = _new_weapon()

	var results: Array[bool] = [
		weapon.update(true, CHARGE_TIME),
		weapon.update(true, CHARGE_TIME),
	]

	assert_array(results).is_equal([false, false])


func test_releasing_a_complete_charge_fires() -> void:
	var weapon: SecondaryWeapon = _new_weapon()
	weapon.update(true, CHARGE_TIME)

	assert_bool(weapon.update(false, FRAME_DELTA)).is_true()


# 事後条件: 真を返した直後は充電が空でクールダウン中である
func test_firing_clears_the_charge_and_starts_the_cooldown() -> void:
	var weapon: SecondaryWeapon = _new_weapon()
	weapon.update(true, CHARGE_TIME)

	weapon.update(false, FRAME_DELTA)

	assert_float(weapon.charge_ratio).is_equal(0.0)
	assert_bool(weapon.is_cooling_down).is_true()


func test_releasing_an_incomplete_charge_does_not_fire() -> void:
	var weapon: SecondaryWeapon = _new_weapon()
	weapon.update(true, HALF_CHARGE_TIME)

	var fired: bool = weapon.update(false, FRAME_DELTA)

	assert_bool(fired).is_false()
	assert_float(weapon.charge_ratio).is_equal(0.0)
	# 未完了で離した場合はクールダウンに入らない。すぐに充電をやり直せる
	assert_bool(weapon.is_cooling_down).is_false()


# 境界のすぐ内側。完了の判定が緩む変異を捕らえる
func test_releasing_a_nearly_complete_charge_does_not_fire() -> void:
	var weapon: SecondaryWeapon = _new_weapon()
	weapon.update(true, NEARLY_CHARGE_TIME)

	var fired: bool = weapon.update(false, FRAME_DELTA)

	assert_bool(fired).is_false()
	assert_bool(weapon.is_cooling_down).is_false()


# 完了のしきい値が 1.0 未満のどこかへ緩んでいないことを見る
func test_releasing_a_charge_a_hair_under_full_does_not_fire() -> void:
	var weapon: SecondaryWeapon = _new_weapon()
	weapon.update(true, BARELY_UNDER_CHARGE_TIME)

	var fired: bool = weapon.update(false, FRAME_DELTA)

	assert_bool(fired).is_false()
	assert_bool(weapon.is_cooling_down).is_false()


# 中断した充電が残ると、次の充電が短くなって完了までの時間が縮む
func test_an_incomplete_charge_does_not_carry_over() -> void:
	var weapon: SecondaryWeapon = _new_weapon()
	weapon.update(true, HALF_CHARGE_TIME)
	weapon.update(false, FRAME_DELTA)

	weapon.update(true, HALF_CHARGE_TIME)

	assert_float(weapon.charge_ratio).is_equal(0.5)
	assert_bool(weapon.update(false, FRAME_DELTA)).is_false()


func test_charge_does_not_grow_during_the_cooldown() -> void:
	var weapon: SecondaryWeapon = _new_weapon()
	weapon.update(true, CHARGE_TIME)
	weapon.update(false, FRAME_DELTA)
	var ratios: Array[float] = []

	for _frame: int in FRAMES_TO_FULL_CHARGE:
		weapon.update(true, FRAME_DELTA)
		ratios.append(weapon.charge_ratio)

	assert_array(ratios).is_equal([0.0, 0.0, 0.0, 0.0])
	assert_bool(weapon.is_cooling_down).is_true()


func test_the_cooldown_persists_just_below_its_duration() -> void:
	var weapon: SecondaryWeapon = _new_weapon()
	weapon.update(true, CHARGE_TIME)
	weapon.update(false, FRAME_DELTA)

	weapon.update(false, NEARLY_COOLDOWN)

	assert_bool(weapon.is_cooling_down).is_true()


func test_the_cooldown_ends_exactly_when_it_elapses() -> void:
	var weapon: SecondaryWeapon = _new_weapon()
	weapon.update(true, CHARGE_TIME)
	weapon.update(false, FRAME_DELTA)

	weapon.update(false, COOLDOWN)

	assert_bool(weapon.is_cooling_down).is_false()


# クールダウンを消化したフレームは充電に使わない。同じ delta を両方へ数えると、
# 発射から次の発射までが cooldown + charge_time より短くなる
func test_the_frame_that_ends_the_cooldown_does_not_charge() -> void:
	var weapon: SecondaryWeapon = _new_weapon()
	weapon.update(true, CHARGE_TIME)
	weapon.update(false, FRAME_DELTA)

	weapon.update(true, COOLDOWN)

	assert_bool(weapon.is_cooling_down).is_false()
	assert_float(weapon.charge_ratio).is_equal(0.0)


func test_charging_resumes_after_the_cooldown() -> void:
	var weapon: SecondaryWeapon = _new_weapon()
	_fire_and_finish_cooldown(weapon)

	weapon.update(true, CHARGE_TIME)

	assert_float(weapon.charge_ratio).is_equal(1.0)
	assert_bool(weapon.update(false, FRAME_DELTA)).is_true()


func test_the_update_table_holds_for_every_reachable_state() -> void:
	for row: Array in UPDATE_TABLE:
		var state: String = row[0]
		var held: bool = row[1]
		var expected: Array = row[2]
		var weapon: SecondaryWeapon = _weapon_in_state(state)

		var fired: bool = weapon.update(held, FRAME_DELTA)

		var actual: Array = [fired, weapon.charge_ratio, weapon.is_cooling_down]
		var context: String = "state=%s held=%s" % [state, held]
		assert_array(actual).append_failure_message(context).is_equal(expected)


func test_the_weapon_fires_on_the_expected_frames() -> void:
	var weapon: SecondaryWeapon = _new_weapon()
	var fire_frames: Array[int] = []

	for frame: int in range(1, FRAME_COUNT + 1):
		# 周期の最後のフレームだけ離す
		var held: bool = frame % CYCLE_LENGTH != 0
		if weapon.update(held, FRAME_DELTA):
			fire_frames.append(frame)

	assert_array(fire_frames).is_equal(EXPECTED_FIRE_FRAMES)


# 充電の長さが _init() の引数から来ることを見る: 値を直書きした実装は両方で同じに振る舞う
func test_a_longer_charge_time_delays_the_completion() -> void:
	var short_weapon: SecondaryWeapon = _new_weapon()
	var long_weapon: SecondaryWeapon = _new_weapon(LONG_CHARGE_TIME, COOLDOWN)

	short_weapon.update(true, CHARGE_TIME)
	long_weapon.update(true, CHARGE_TIME)

	assert_bool(short_weapon.update(false, FRAME_DELTA)).is_true()
	assert_bool(long_weapon.update(false, FRAME_DELTA)).is_false()


func test_a_longer_charge_time_completes_once_it_elapses() -> void:
	var weapon: SecondaryWeapon = _new_weapon(LONG_CHARGE_TIME, COOLDOWN)

	weapon.update(true, LONG_CHARGE_TIME)

	assert_bool(weapon.update(false, FRAME_DELTA)).is_true()


# クールダウンの長さが _init() の引数から来ることを見る
func test_a_longer_cooldown_delays_the_recovery() -> void:
	var short_weapon: SecondaryWeapon = _new_weapon()
	var long_weapon: SecondaryWeapon = _new_weapon(CHARGE_TIME, LONG_COOLDOWN)
	for weapon: SecondaryWeapon in [short_weapon, long_weapon]:
		weapon.update(true, CHARGE_TIME)
		weapon.update(false, FRAME_DELTA)

	short_weapon.update(false, COOLDOWN)
	long_weapon.update(false, COOLDOWN)

	assert_bool(short_weapon.is_cooling_down).is_false()
	assert_bool(long_weapon.is_cooling_down).is_true()


func test_a_longer_cooldown_ends_once_it_elapses() -> void:
	var weapon: SecondaryWeapon = _new_weapon(CHARGE_TIME, LONG_COOLDOWN)
	weapon.update(true, CHARGE_TIME)
	weapon.update(false, FRAME_DELTA)

	weapon.update(false, LONG_COOLDOWN)

	assert_bool(weapon.is_cooling_down).is_false()
