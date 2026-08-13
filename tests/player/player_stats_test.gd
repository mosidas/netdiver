extends GdUnitTestSuite

const STAT_NAMES: Array[String] = [
	"move_speed",
	"gravity",
	"jump_speed",
	"max_health",
	"regen_delay",
	"regen_per_second",
	"primary_interval",
	"primary_damage",
	"primary_bullet_speed",
	"secondary_charge_time",
	"secondary_cooldown",
	"secondary_damage",
	"secondary_bullet_speed",
	"bullet_max_distance",
]


func _editor_visible_property_names(object: Object) -> Array[String]:
	var names: Array[String] = []
	for property: Dictionary in object.get_property_list():
		var usage: int = property["usage"]
		if usage & PROPERTY_USAGE_EDITOR != 0 and usage & PROPERTY_USAGE_SCRIPT_VARIABLE != 0:
			names.append(property["name"])
	return names


func test_player_stats_is_a_resource() -> void:
	var stats: PlayerStats = auto_free(PlayerStats.new())

	assert_object(stats).is_instanceof(Resource)


func test_player_stats_movement_defaults() -> void:
	var stats: PlayerStats = auto_free(PlayerStats.new())

	assert_float(stats.move_speed).is_equal(100.0)
	assert_float(stats.gravity).is_equal(600.0)
	assert_float(stats.jump_speed).is_equal(240.0)


func test_player_stats_health_defaults() -> void:
	var stats: PlayerStats = auto_free(PlayerStats.new())

	assert_int(stats.max_health).is_equal(100)
	assert_float(stats.regen_delay).is_equal(3.0)
	assert_float(stats.regen_per_second).is_equal(20.0)


func test_player_stats_primary_weapon_defaults() -> void:
	var stats: PlayerStats = auto_free(PlayerStats.new())

	assert_float(stats.primary_interval).is_equal(0.12)
	assert_int(stats.primary_damage).is_equal(10)
	assert_float(stats.primary_bullet_speed).is_equal(400.0)


func test_player_stats_secondary_weapon_defaults() -> void:
	var stats: PlayerStats = auto_free(PlayerStats.new())

	assert_float(stats.secondary_charge_time).is_equal(0.8)
	assert_float(stats.secondary_cooldown).is_equal(2.0)
	assert_int(stats.secondary_damage).is_equal(50)
	assert_float(stats.secondary_bullet_speed).is_equal(300.0)


func test_player_stats_bullet_max_distance_default() -> void:
	var stats: PlayerStats = auto_free(PlayerStats.new())

	assert_float(stats.bullet_max_distance).is_equal(400.0)


func test_player_stats_defaults_are_all_positive() -> void:
	var stats: PlayerStats = auto_free(PlayerStats.new())

	for stat_name: String in STAT_NAMES:
		assert_float(float(stats.get(stat_name))).override_failure_message(
			"%s の既定値は正でなければならない" % stat_name
		).is_greater(0.0)


func test_player_stats_exposes_every_stat_to_the_inspector() -> void:
	var stats: PlayerStats = auto_free(PlayerStats.new())

	assert_array(_editor_visible_property_names(stats)).contains(STAT_NAMES)


func test_player_stats_instances_do_not_share_values() -> void:
	var stats: PlayerStats = auto_free(PlayerStats.new())
	var other: PlayerStats = auto_free(PlayerStats.new())

	stats.move_speed = 42.0

	assert_float(other.move_speed).is_equal(100.0)


func test_player_command_defaults_are_neutral() -> void:
	var command: PlayerCommand = auto_free(PlayerCommand.new())

	assert_float(command.move_x).is_equal(0.0)
	assert_float(command.aim_y).is_equal(0.0)
	assert_bool(command.jump_pressed).is_false()
	assert_bool(command.primary_held).is_false()
	assert_bool(command.secondary_held).is_false()


func test_player_command_keeps_the_three_allowed_axis_values() -> void:
	var command: PlayerCommand = auto_free(PlayerCommand.new())

	command.move_x = -1.0
	command.aim_y = 1.0

	assert_float(command.move_x).is_equal(-1.0)
	assert_float(command.aim_y).is_equal(1.0)

	command.move_x = 1.0
	command.aim_y = -1.0

	assert_float(command.move_x).is_equal(1.0)
	assert_float(command.aim_y).is_equal(-1.0)


func test_player_command_holds_the_button_states() -> void:
	var command: PlayerCommand = auto_free(PlayerCommand.new())

	command.jump_pressed = true
	command.primary_held = true
	command.secondary_held = true

	assert_bool(command.jump_pressed).is_true()
	assert_bool(command.primary_held).is_true()
	assert_bool(command.secondary_held).is_true()
