extends GdUnitTestSuite

# 2 進で厳密に表せる値を使う: 累積の誤差で「interval ちょうど」の判定が揺れると、
# 境界を含むか含まないかを検証できない
const INTERVAL: float = 0.25
const FRAME_DELTA: float = 0.0625
const HALF_INTERVAL: float = 0.125
# 境界のすぐ内側。拒否の範囲が interval より短い側へ縮む変異を捕らえる
const NEARLY_INTERVAL: float = 0.2490234375
const LONG_INTERVAL: float = 1.0

const FRAME_COUNT: int = 16
# tick(FRAME_DELTA) → try_fire() を毎フレーム繰り返したときに真を返すフレーム(1 始まり)。
# 生成直後の 1 フレーム目と、そこから interval ごと(4 フレームごと)
const EXPECTED_FIRE_FRAMES: Array[int] = [1, 5, 9, 13]

# フレーム時間が揺れる状況を模す。1 周期の合計 0.3125 が interval を跨ぐ
const JITTERED_DELTAS: Array[float] = [0.0625, 0.03125, 0.09375, 0.125]
const JITTER_CYCLES: int = 6
# 揺れの最大値。発射の間隔がこれ以上に開いていたら、待ちが interval より長い
const LARGEST_DELTA: float = 0.125


func test_try_fire_succeeds_immediately_after_construction() -> void:
	var weapon: PrimaryWeapon = auto_free(PrimaryWeapon.new(INTERVAL))

	assert_bool(weapon.try_fire()).is_true()


func test_try_fire_is_rejected_right_after_firing() -> void:
	var weapon: PrimaryWeapon = auto_free(PrimaryWeapon.new(INTERVAL))

	# 経過時間を進めずに続けて呼ぶ。真を返すのは最初の 1 回だけである
	var results: Array[bool] = [weapon.try_fire(), weapon.try_fire(), weapon.try_fire()]

	assert_array(results).is_equal([true, false, false])


func test_try_fire_is_rejected_below_the_interval() -> void:
	var weapon: PrimaryWeapon = auto_free(PrimaryWeapon.new(INTERVAL))
	weapon.try_fire()

	weapon.tick(NEARLY_INTERVAL)

	assert_bool(weapon.try_fire()).is_false()


func test_try_fire_succeeds_exactly_at_the_interval() -> void:
	var weapon: PrimaryWeapon = auto_free(PrimaryWeapon.new(INTERVAL))
	weapon.try_fire()

	weapon.tick(INTERVAL)

	assert_bool(weapon.try_fire()).is_true()


func test_try_fire_succeeds_beyond_the_interval() -> void:
	var weapon: PrimaryWeapon = auto_free(PrimaryWeapon.new(INTERVAL))
	weapon.try_fire()

	weapon.tick(INTERVAL + FRAME_DELTA)

	assert_bool(weapon.try_fire()).is_true()


# 拒否が状態を変えないことを見る: 拒否のたびに経過時間を捨てる実装では、
# 残りを足しても真に届かない
func test_a_rejected_try_fire_keeps_the_elapsed_time() -> void:
	var weapon: PrimaryWeapon = auto_free(PrimaryWeapon.new(INTERVAL))
	weapon.try_fire()

	weapon.tick(HALF_INTERVAL)
	var rejected: bool = weapon.try_fire()
	weapon.tick(HALF_INTERVAL)

	assert_bool(rejected).is_false()
	assert_bool(weapon.try_fire()).is_true()


func test_the_interval_starts_over_after_each_shot() -> void:
	var weapon: PrimaryWeapon = auto_free(PrimaryWeapon.new(INTERVAL))
	weapon.try_fire()
	weapon.tick(INTERVAL)
	weapon.try_fire()

	weapon.tick(NEARLY_INTERVAL)

	assert_bool(weapon.try_fire()).is_false()


func test_try_fire_succeeds_on_the_expected_frames() -> void:
	var weapon: PrimaryWeapon = auto_free(PrimaryWeapon.new(INTERVAL))
	var fire_frames: Array[int] = []

	for frame: int in range(1, FRAME_COUNT + 1):
		weapon.tick(FRAME_DELTA)
		if weapon.try_fire():
			fire_frames.append(frame)

	assert_array(fire_frames).is_equal(EXPECTED_FIRE_FRAMES)


# 事後条件: 連続するフレームで真を返す間隔は常に interval 以上である
func test_the_gap_between_shots_is_at_least_the_interval() -> void:
	var weapon: PrimaryWeapon = auto_free(PrimaryWeapon.new(INTERVAL))
	var gaps: Array[float] = []
	# 初弾は生成直後の状態から出るため、間隔の計測は 2 発目以降を対象にする
	var has_fired: bool = false
	var since_last_shot: float = 0.0

	for cycle: int in JITTER_CYCLES:
		for delta: float in JITTERED_DELTAS:
			weapon.tick(delta)
			since_last_shot += delta
			if not weapon.try_fire():
				continue
			if has_fired:
				gaps.append(since_last_shot)
			has_fired = true
			since_last_shot = 0.0

	# 間隔が 1 つも取れないと、以降のアサーションが空振りする
	assert_int(gaps.size()).is_greater(2)
	for index: int in gaps.size():
		var context: String = "index=%s gap=%s" % [index, gaps[index]]
		assert_float(gaps[index]).append_failure_message(context).is_greater_equal(INTERVAL)
		# 上限も見る: 待ちが interval より長い実装は、押しっぱなしの連射が間延びする
		assert_float(gaps[index]).append_failure_message(context).is_less_equal(
			INTERVAL + LARGEST_DELTA
		)


# 待ちの長さが _init() の引数から来ることを見る: 値を直書きした実装は両方で同じに振る舞う
func test_a_longer_interval_delays_the_next_shot() -> void:
	var short_weapon: PrimaryWeapon = auto_free(PrimaryWeapon.new(INTERVAL))
	var long_weapon: PrimaryWeapon = auto_free(PrimaryWeapon.new(LONG_INTERVAL))
	short_weapon.try_fire()
	long_weapon.try_fire()

	short_weapon.tick(INTERVAL)
	long_weapon.tick(INTERVAL)

	assert_bool(short_weapon.try_fire()).is_true()
	assert_bool(long_weapon.try_fire()).is_false()


func test_a_longer_interval_allows_a_shot_once_it_elapses() -> void:
	var weapon: PrimaryWeapon = auto_free(PrimaryWeapon.new(LONG_INTERVAL))
	weapon.try_fire()

	weapon.tick(LONG_INTERVAL)

	assert_bool(weapon.try_fire()).is_true()
