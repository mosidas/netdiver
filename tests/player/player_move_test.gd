extends GdUnitTestSuite

const DELTA: float = 1.0 / 60.0

# 既定値(100.0 / 600.0 / 240.0)と別の値を使う: 既定のままだと、`stats` を読まず値を直書きした実装でも緑になる
const MOVE_SPEED: float = 250.0
const GRAVITY: float = 500.0
const JUMP_SPEED: float = 300.0

const EPSILON: float = 0.0001


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
