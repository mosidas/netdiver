extends GdUnitTestSuite

const DELTA: float = 1.0 / 60.0

# 既定値(100.0 / 600.0 / 240.0)と別の値を使う: 既定のままだと、`stats` を読まず値を直書きした実装でも緑になる
const MOVE_SPEED: float = 250.0
const GRAVITY: float = 500.0
const JUMP_SPEED: float = 300.0

const EPSILON: float = 0.0001

const NEGATIVE_DELTA: float = -DELTA

# 実装の文言を固定する: 文言が変わると、利用者がログから原因を辿る手順が変わる
const MISSING_STATS_ERROR: String = "Player: stats が設定されていない。既定値の PlayerStats を使う"
const INVALID_DELTA_ERROR: String = "Player.apply_command(): delta は正でなければならない。速度を変えずに返る"
const INVALID_STAT_ERROR_FORMAT: String = "Player: stats.%s は正でなければならない(現在値: %s)"

# 実装が導出する項目名をテスト側で導出しない: 同じ導出を使うと、導出そのものの誤りを検出できない
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


func _create_player() -> Player:
	var player: Player = auto_free(Player.new())
	var stats: PlayerStats = auto_free(PlayerStats.new())
	stats.move_speed = MOVE_SPEED
	stats.gravity = GRAVITY
	stats.jump_speed = JUMP_SPEED
	player.stats = stats
	return player


func _command(move_x: float, jump_pressed: bool = false) -> PlayerCommand:
	var command: PlayerCommand = auto_free(PlayerCommand.new())
	command.move_x = move_x
	command.jump_pressed = jump_pressed
	return command


func test_apply_command_stops_the_horizontal_speed_when_move_x_is_zero() -> void:
	var player: Player = _create_player()

	player.apply_command(_command(1.0), DELTA, true)
	assert_float(player.velocity.x).is_equal(MOVE_SPEED)

	player.apply_command(_command(0.0), DELTA, true)

	assert_float(player.velocity.x).is_equal(0.0)


func test_facing_starts_to_the_right() -> void:
	var player: Player = _create_player()

	assert_int(player.facing).is_equal(1)


func test_apply_command_updates_facing_to_the_left() -> void:
	var player: Player = _create_player()

	player.apply_command(_command(-1.0), DELTA, true)

	assert_int(player.facing).is_equal(-1)


func test_apply_command_updates_facing_to_the_right() -> void:
	var player: Player = _create_player()

	player.apply_command(_command(-1.0), DELTA, true)
	player.apply_command(_command(1.0), DELTA, true)

	assert_int(player.facing).is_equal(1)


func test_apply_command_keeps_facing_when_move_x_is_zero() -> void:
	var player: Player = _create_player()

	player.apply_command(_command(-1.0), DELTA, true)
	player.apply_command(_command(0.0), DELTA, true)

	assert_int(player.facing).is_equal(-1)


func test_apply_command_accumulates_gravity_while_airborne() -> void:
	var player: Player = _create_player()

	player.apply_command(_command(0.0), DELTA, false)
	assert_float(player.velocity.y).is_equal_approx(GRAVITY * DELTA, EPSILON)

	player.apply_command(_command(0.0), DELTA, false)
	player.apply_command(_command(0.0), DELTA, false)

	assert_float(player.velocity.y).is_equal_approx(GRAVITY * DELTA * 3.0, EPSILON)


func test_apply_command_jumps_when_on_floor() -> void:
	var player: Player = _create_player()

	player.apply_command(_command(0.0, true), DELTA, true)

	assert_float(player.velocity.y).is_equal(-JUMP_SPEED)


func test_apply_command_ignores_jump_while_airborne() -> void:
	var player: Player = _create_player()

	player.apply_command(_command(0.0, true), DELTA, false)
	assert_float(player.velocity.y).is_equal_approx(GRAVITY * DELTA, EPSILON)

	player.apply_command(_command(0.0, true), DELTA, false)

	assert_float(player.velocity.y).is_equal_approx(GRAVITY * DELTA * 2.0, EPSILON)


func test_apply_command_clears_the_vertical_speed_while_on_floor() -> void:
	var player: Player = _create_player()

	player.apply_command(_command(0.0), DELTA, false)
	player.apply_command(_command(0.0), DELTA, false)

	player.apply_command(_command(0.0), DELTA, true)

	assert_float(player.velocity.y).is_equal(0.0)


func test_apply_command_keeps_the_speed_when_delta_is_zero() -> void:
	var player: Player = _create_player()
	player.apply_command(_command(-1.0), DELTA, false)
	var velocity_before: Vector2 = player.velocity

	# 水平・垂直・facing のすべてを動かすコマンドを渡す: 一つでも反映されたら失敗させる
	player.apply_command(_command(1.0, true), 0.0, true)

	assert_vector(player.velocity).is_equal(velocity_before)
	assert_int(player.facing).is_equal(-1)


func test_apply_command_keeps_the_speed_when_delta_is_negative() -> void:
	var player: Player = _create_player()
	player.apply_command(_command(-1.0), DELTA, false)
	var velocity_before: Vector2 = player.velocity

	player.apply_command(_command(1.0, true), NEGATIVE_DELTA, true)

	assert_vector(player.velocity).is_equal(velocity_before)
	assert_int(player.facing).is_equal(-1)


func test_apply_command_pushes_an_error_when_delta_is_zero() -> void:
	var player: Player = _create_player()

	await assert_error(func() -> void: player.apply_command(_command(1.0), 0.0, true)).is_push_error(INVALID_DELTA_ERROR)


func test_apply_command_pushes_an_error_when_delta_is_negative() -> void:
	var player: Player = _create_player()

	await assert_error(func() -> void: player.apply_command(_command(1.0), NEGATIVE_DELTA, true)).is_push_error(INVALID_DELTA_ERROR)


func test_ready_pushes_an_error_when_stats_is_missing() -> void:
	var player: Player = auto_free(Player.new())

	await assert_error(func() -> void: add_child(player)).is_push_error(MISSING_STATS_ERROR)

	assert_object(player.stats).is_not_null()
	assert_object(player.stats).is_instanceof(PlayerStats)


func test_ready_pushes_an_error_for_every_stat_set_to_zero() -> void:
	for stat_name: String in STAT_NAMES:
		var player: Player = _create_player()
		player.stats.set(stat_name, 0)
		var expected: String = INVALID_STAT_ERROR_FORMAT % [stat_name, player.stats.get(stat_name)]

		await assert_error(func() -> void: add_child(player)).is_push_error(expected)


func test_ready_pushes_an_error_for_a_negative_stat() -> void:
	var player: Player = _create_player()
	player.stats.move_speed = -MOVE_SPEED
	var expected: String = INVALID_STAT_ERROR_FORMAT % ["move_speed", player.stats.move_speed]

	await assert_error(func() -> void: add_child(player)).is_push_error(expected)


func test_ready_does_not_push_an_error_when_every_stat_is_positive() -> void:
	var player: Player = _create_player()

	await assert_error(func() -> void: add_child(player)).is_success()
