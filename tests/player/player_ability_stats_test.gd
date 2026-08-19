extends GdUnitTestSuite

# 実装の文言を参照しない: 参照するとアサーションが自明になり、文言の退行を検出できない
const INVALID_STAT_ERROR_FORMAT: String = "Player: stats.%s は正でなければならない(現在値: %s)"

const ABILITY_PREFIX: String = "ability_"

const ABILITY_USES: String = "ability_uses"
const ABILITY_COOLDOWN: String = "ability_cooldown"
const ABILITY_DAMAGE: String = "ability_damage"
const ABILITY_BULLET_SPEED: String = "ability_bullet_speed"

const ABILITY_STAT_NAMES: Array[String] = [
	ABILITY_USES,
	ABILITY_COOLDOWN,
	ABILITY_DAMAGE,
	ABILITY_BULLET_SPEED,
]

const ABILITY_STAT_COUNT: int = 4

# 実装が知りようのない項目名。`PlayerStats` へ項目を足した状況をテストの中だけで作る
const UNKNOWN_STAT_NAME: String = "unknown_stat"


## `PlayerStats` に項目が増えた状態。実装が項目名を固定で並べていると、この派生型の項目は
## 検査から漏れる
class ExtendedStats:
	extends PlayerStats

	@export var unknown_stat: float = 1.0


func _exported_properties(object: Object) -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	for property: Dictionary in object.get_property_list():
		var usage: int = property["usage"]
		if usage & PROPERTY_USAGE_EDITOR != 0 and usage & PROPERTY_USAGE_SCRIPT_VARIABLE != 0:
			properties.append(property)
	return properties


func _exported_property_names(object: Object) -> Array[String]:
	var names: Array[String] = []
	for property: Dictionary in _exported_properties(object):
		names.append(property["name"])
	return names


func _exported_property_type(object: Object, stat_name: String) -> int:
	for property: Dictionary in _exported_properties(object):
		if property["name"] == stat_name:
			return property["type"]
	return TYPE_NIL


func _player_with(stats: PlayerStats) -> Player:
	var player: Player = auto_free(Player.new())
	player.stats = stats
	return player


func test_player_stats_exports_the_four_ability_stats() -> void:
	var stats: PlayerStats = auto_free(PlayerStats.new())

	assert_array(_exported_property_names(stats)).contains(ABILITY_STAT_NAMES)


func test_player_stats_keeps_the_ability_counts_whole_and_the_rest_fractional() -> void:
	var stats: PlayerStats = auto_free(PlayerStats.new())

	assert_int(_exported_property_type(stats, ABILITY_USES)).is_equal(TYPE_INT)
	assert_int(_exported_property_type(stats, ABILITY_DAMAGE)).is_equal(TYPE_INT)
	assert_int(_exported_property_type(stats, ABILITY_COOLDOWN)).is_equal(TYPE_FLOAT)
	assert_int(_exported_property_type(stats, ABILITY_BULLET_SPEED)).is_equal(TYPE_FLOAT)


func test_player_stats_ability_defaults() -> void:
	var stats: PlayerStats = auto_free(PlayerStats.new())

	assert_int(stats.ability_uses).is_equal(3)
	assert_float(stats.ability_cooldown).is_equal(1.5)
	assert_int(stats.ability_damage).is_equal(20)
	assert_float(stats.ability_bullet_speed).is_equal(300.0)


func test_player_stats_ability_defaults_are_all_positive() -> void:
	var stats: PlayerStats = auto_free(PlayerStats.new())

	for stat_name: String in ABILITY_STAT_NAMES:
		assert_float(float(stats.get(stat_name))).override_failure_message(
			"%s の既定値は正でなければならない" % stat_name
		).is_greater(0.0)


func test_ready_pushes_an_error_for_every_ability_stat_set_to_zero() -> void:
	# 0 に「その振る舞いを持たない」意味を持たせていないことを、振る舞いで示す。`Enemy` の
	# 除外の仕組みに相当するものがこの 4 項目に無ければ、どの項目でも `push_error` が出る
	for stat_name: String in ABILITY_STAT_NAMES:
		var player: Player = _player_with(auto_free(PlayerStats.new()))
		player.stats.set(stat_name, 0)
		var expected: String = INVALID_STAT_ERROR_FORMAT % [stat_name, player.stats.get(stat_name)]

		await assert_error(func() -> void: add_child(player)).is_push_error(expected)


func test_ready_pushes_an_error_for_a_negative_ability_stat() -> void:
	var player: Player = _player_with(auto_free(PlayerStats.new()))
	player.stats.ability_damage = -20

	var expected: String = INVALID_STAT_ERROR_FORMAT % [ABILITY_DAMAGE, player.stats.ability_damage]

	await assert_error(func() -> void: add_child(player)).is_push_error(expected)


func test_ready_checks_an_ability_stat_the_implementation_cannot_know_by_name() -> void:
	# 検査の対象を `get_property_list()` から導いていることを、実装が名前で持ちようのない項目で
	# 示す。4 項目を名前で並べただけの検査はこのケースだけが落ちる
	var stats: ExtendedStats = auto_free(ExtendedStats.new())
	stats.unknown_stat = 0.0
	var player: Player = _player_with(stats)
	var expected: String = INVALID_STAT_ERROR_FORMAT % [UNKNOWN_STAT_NAME, stats.unknown_stat]

	await assert_error(func() -> void: add_child(player)).is_push_error(expected)


func test_ready_accepts_the_ability_defaults() -> void:
	var player: Player = _player_with(auto_free(PlayerStats.new()))

	await assert_error(func() -> void: add_child(player)).is_success()


func test_player_stats_holds_no_ability_stat_beyond_the_four() -> void:
	# 名前を並べて確かめない: 並べると 5 つ目の能力専用の項目(専用の射程など)を足しても緑になる
	var stats: PlayerStats = auto_free(PlayerStats.new())

	var count: int = 0
	for stat_name: String in _exported_property_names(stats):
		if stat_name.begins_with(ABILITY_PREFIX):
			count += 1

	assert_int(count).is_equal(ABILITY_STAT_COUNT)
