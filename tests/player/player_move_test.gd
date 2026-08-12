extends GdUnitTestSuite

const DELTA: float = 1.0 / 60.0

# 既定値(100.0)と別の値を使う: 既定のままだと、`stats` を読まず速度を直書きした実装でも緑になる
const MOVE_SPEED: float = 250.0


func _create_player() -> Player:
	var player: Player = auto_free(Player.new())
	var stats: PlayerStats = auto_free(PlayerStats.new())
	stats.move_speed = MOVE_SPEED
	player.stats = stats
	return player


func _command(move_x: float) -> PlayerCommand:
	var command: PlayerCommand = auto_free(PlayerCommand.new())
	command.move_x = move_x
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
