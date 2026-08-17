extends GdUnitTestSuite

const CHARGER_STATS_PATH: String = "res://src/enemy/charger_stats.tres"
const SHOOTER_STATS_PATH: String = "res://src/enemy/shooter_stats.tres"

const STAT_NAMES: Array[String] = [
	"max_hp",
	"gravity",
	"move_speed",
	"detect_range",
	"telegraph_time",
	"attack_damage",
	"attack_speed",
	"attack_duration",
	"recover_time",
	"bullet_max_distance",
]


func _load_stats(path: String) -> EnemyStats:
	# 共有される 1 個を読むため auto_free に渡さない。渡すとキャッシュ上の実体を解放してしまう
	return ResourceLoader.load(path) as EnemyStats


func _editor_visible_property_names(object: Object) -> Array[String]:
	var names: Array[String] = []
	for property: Dictionary in object.get_property_list():
		var usage: int = property["usage"]
		if usage & PROPERTY_USAGE_EDITOR != 0 and usage & PROPERTY_USAGE_SCRIPT_VARIABLE != 0:
			names.append(property["name"])
	return names


func test_enemy_stats_is_a_resource() -> void:
	var stats: EnemyStats = auto_free(EnemyStats.new())

	assert_object(stats).is_instanceof(Resource)


func test_enemy_stats_exposes_exactly_the_ten_stats_to_the_inspector() -> void:
	var stats: EnemyStats = auto_free(EnemyStats.new())

	assert_array(_editor_visible_property_names(stats)).contains_exactly_in_any_order(STAT_NAMES)


func test_enemy_stats_script_defaults() -> void:
	var stats: EnemyStats = auto_free(EnemyStats.new())

	assert_int(stats.max_hp).is_equal(30)
	assert_float(stats.gravity).is_equal(600.0)
	assert_float(stats.move_speed).is_equal(40.0)
	assert_float(stats.detect_range).is_equal(128.0)
	assert_float(stats.telegraph_time).is_equal(0.4)
	assert_int(stats.attack_damage).is_equal(15)
	assert_float(stats.attack_speed).is_equal(150.0)
	assert_float(stats.attack_duration).is_equal(0.6)
	assert_float(stats.recover_time).is_equal(0.8)
	assert_float(stats.bullet_max_distance).is_equal(0.0)


func test_the_charger_stats_values_are_fixed() -> void:
	# 期待値はテスト側に持ち、実装・.tres から参照しない。参照するとアサーションが自明化し、
	# 値の退行を検出できない(tests/weapon/combat_limits_test.gd と同じ形)
	var stats: EnemyStats = _load_stats(CHARGER_STATS_PATH)

	assert_int(stats.max_hp).is_equal(30)
	assert_float(stats.gravity).is_equal(600.0)
	assert_float(stats.move_speed).is_equal(40.0)
	assert_float(stats.detect_range).is_equal(128.0)
	assert_float(stats.telegraph_time).is_equal(0.4)
	assert_int(stats.attack_damage).is_equal(15)
	assert_float(stats.attack_speed).is_equal(150.0)
	assert_float(stats.attack_duration).is_equal(0.6)
	assert_float(stats.recover_time).is_equal(0.8)
	assert_float(stats.bullet_max_distance).is_equal(0.0)


func test_the_shooter_stats_values_are_fixed() -> void:
	var stats: EnemyStats = _load_stats(SHOOTER_STATS_PATH)

	assert_int(stats.max_hp).is_equal(20)
	assert_float(stats.gravity).is_equal(600.0)
	assert_float(stats.move_speed).is_equal(0.0)
	assert_float(stats.detect_range).is_equal(160.0)
	assert_float(stats.telegraph_time).is_equal(0.4)
	assert_int(stats.attack_damage).is_equal(10)
	assert_float(stats.attack_speed).is_equal(120.0)
	assert_float(stats.attack_duration).is_equal(0.0)
	assert_float(stats.recover_time).is_equal(1.5)
	assert_float(stats.bullet_max_distance).is_equal(216.0)


func test_the_charger_does_not_have_a_bullet() -> void:
	# 0 は「その振る舞いを持たない」ことを表す。突進型が弾を持たないことをこの 1 項目で示す
	var stats: EnemyStats = _load_stats(CHARGER_STATS_PATH)

	assert_float(stats.bullet_max_distance).is_equal(0.0)


func test_the_shooter_neither_moves_nor_charges() -> void:
	var stats: EnemyStats = _load_stats(SHOOTER_STATS_PATH)

	assert_float(stats.move_speed).is_equal(0.0)
	assert_float(stats.attack_duration).is_equal(0.0)


func test_both_stats_are_external_files() -> void:
	assert_bool(ResourceLoader.exists(CHARGER_STATS_PATH)).is_true()
	assert_bool(ResourceLoader.exists(SHOOTER_STATS_PATH)).is_true()


func test_the_loaded_stats_keep_the_path_of_their_file() -> void:
	assert_str(_load_stats(CHARGER_STATS_PATH).resource_path).is_equal(CHARGER_STATS_PATH)
	assert_str(_load_stats(SHOOTER_STATS_PATH).resource_path).is_equal(SHOOTER_STATS_PATH)


func test_the_charger_stats_are_one_shared_instance() -> void:
	var stats: EnemyStats = _load_stats(CHARGER_STATS_PATH)
	var other: EnemyStats = _load_stats(CHARGER_STATS_PATH)

	assert_object(stats).is_same(other)
	assert_bool(stats.resource_local_to_scene).is_false()


func test_the_shooter_stats_are_one_shared_instance() -> void:
	var stats: EnemyStats = _load_stats(SHOOTER_STATS_PATH)
	var other: EnemyStats = _load_stats(SHOOTER_STATS_PATH)

	assert_object(stats).is_same(other)
	assert_bool(stats.resource_local_to_scene).is_false()


func test_the_two_kinds_do_not_share_one_instance() -> void:
	assert_object(_load_stats(CHARGER_STATS_PATH)).is_not_same(_load_stats(SHOOTER_STATS_PATH))


func test_a_shooter_bullet_expires_before_the_next_shot() -> void:
	# 1 体の射撃型から同時に 2 発を存在させない
	var stats: EnemyStats = _load_stats(SHOOTER_STATS_PATH)
	var bullet_lifetime: float = stats.bullet_max_distance / stats.attack_speed
	var shot_interval: float = stats.telegraph_time + stats.recover_time

	assert_float(bullet_lifetime).is_less(shot_interval)


func test_both_telegraph_times_reach_the_shared_minimum() -> void:
	assert_float(_load_stats(CHARGER_STATS_PATH).telegraph_time).is_greater_equal(
		CombatLimits.ENEMY_TELEGRAPH_MIN_TIME
	)
	assert_float(_load_stats(SHOOTER_STATS_PATH).telegraph_time).is_greater_equal(
		CombatLimits.ENEMY_TELEGRAPH_MIN_TIME
	)


func test_both_attack_speeds_stay_within_the_shared_limit() -> void:
	assert_float(_load_stats(CHARGER_STATS_PATH).attack_speed).is_less_equal(
		CombatLimits.ENEMY_BULLET_MAX_SPEED
	)
	assert_float(_load_stats(SHOOTER_STATS_PATH).attack_speed).is_less_equal(
		CombatLimits.ENEMY_BULLET_MAX_SPEED
	)


func test_enemy_state_has_the_five_shared_states() -> void:
	assert_array(EnemyState.State.keys()).contains_exactly(
		["IDLE", "TELEGRAPH", "CHARGE", "COOLDOWN", "RECOVER"]
	)


func test_enemy_kind_has_the_two_kinds() -> void:
	assert_array(EnemyKind.Kind.keys()).contains_exactly(["CHARGER", "SHOOTER"])
