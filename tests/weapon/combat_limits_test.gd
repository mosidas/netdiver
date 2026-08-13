extends GdUnitTestSuite

# 期待値は実装の定数を参照せずテスト側に持つ。参照するとアサーションが自明化し、
# 値を書き換える変異を検出できない(タスク 3.1・3.2 と同じ形)
const EXPECTED_ENEMY_BULLET_MAX_SPEED: float = 150.0
const EXPECTED_ENEMY_TELEGRAPH_MIN_TIME: float = 0.4

# 上限の根拠となる回避に要する時間(反応 0.3 秒 + 1 タイル 16px の回避 0.16 秒)。
# 弾が基準解像度の半分 160px を進む時間がこれを上回ることを確かめる
const DODGE_TIME: float = 0.46
const HALF_SCREEN_WIDTH: float = 160.0


func test_enemy_bullet_max_speed_is_fixed() -> void:
	assert_float(CombatLimits.ENEMY_BULLET_MAX_SPEED).is_equal(EXPECTED_ENEMY_BULLET_MAX_SPEED)


func test_enemy_telegraph_min_time_is_fixed() -> void:
	assert_float(CombatLimits.ENEMY_TELEGRAPH_MIN_TIME).is_equal(
		EXPECTED_ENEMY_TELEGRAPH_MIN_TIME
	)


func test_a_bullet_at_the_speed_limit_crosses_half_the_screen_slower_than_a_dodge() -> void:
	# 上限そのものが「移動で回避できる」を満たしていること。値を緩める変異を捕らえる
	var travel_time: float = HALF_SCREEN_WIDTH / CombatLimits.ENEMY_BULLET_MAX_SPEED

	assert_float(travel_time).is_greater(DODGE_TIME)


func test_the_limits_are_floats() -> void:
	# int で定義すると foot-enemies 側の比較で切り捨てが挟まる
	assert_int(typeof(CombatLimits.ENEMY_BULLET_MAX_SPEED)).is_equal(TYPE_FLOAT)
	assert_int(typeof(CombatLimits.ENEMY_TELEGRAPH_MIN_TIME)).is_equal(TYPE_FLOAT)
