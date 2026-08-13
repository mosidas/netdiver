extends GdUnitTestSuite

const PLAYER_SCENE: PackedScene = preload("res://src/player/player.tscn")

# 既定値(100 / 3.0 / 20.0)と別の値を使う: 既定のままだと、`stats` を読まず値を直書きした
# 実装でも緑になる
const MAX_HEALTH: int = 40
const REGEN_DELAY: float = 0.5
const REGEN_PER_SECOND: float = 8.0

# 2 進で厳密に表せる値を使う: 累積の丸め誤差で待機の境界が揺れると、回復の検証がフレークする
const DELTA: float = 0.0625

# 待機を消化しきるフレーム数。`Health` は「待機を消化したフレームでは回復しない」ため、
# REGEN_DELAY / DELTA = 8 フレーム目までが待機、9 フレーム目から回復に入る
const DELAY_FRAMES: int = 8
# 回復に使うフレーム数。ここまでの経過時間は 16 * DELTA = 1.0 秒であり、設定値 0.5 と
# 既定値 3.0 の間にある: 待機を既定値で直書きした実装ではまだ 1 点も回復しない
const REGEN_FRAMES: int = 8
# 8.0 * 8 * 0.0625 = 4.0 点。既定の 20.0 なら 10 点であり、回復量の直書きと区別できる
const EXPECTED_REGEN: int = 4

const DAMAGE: int = 10

const NEGATIVE_DELTA: float = -DELTA

# 実装の文言を参照しない: 参照するとアサーションが自明になり、文言の退行を検出できない
const INVALID_AMOUNT_ERROR_FORMAT: String = (
	"Health.take_damage(): amount は正でなければならない(現在値: %s)。状態を変えずに返る"
)


func _create_stats() -> PlayerStats:
	var stats: PlayerStats = auto_free(PlayerStats.new())
	stats.max_health = MAX_HEALTH
	stats.regen_delay = REGEN_DELAY
	stats.regen_per_second = REGEN_PER_SECOND
	return stats


## ツリーへ載せていない `Player`。`apply_command()` と `take_damage()` はこの形でも呼べる
func _create_detached_player() -> Player:
	var player: Player = auto_free(Player.new())
	player.stats = _create_stats()
	return player


## `player.tscn` を読み込み、ツリーへ載せて `_ready()` を通した `Player`
func _create_ready_player() -> Player:
	var player: Player = auto_free(PLAYER_SCENE.instantiate())
	player.stats = _create_stats()
	add_child(player)
	return player


func _command() -> PlayerCommand:
	return auto_free(PlayerCommand.new())


func _advance(player: Player, frames: int) -> void:
	for _i: int in frames:
		player.apply_command(_command(), DELTA, true)


func test_ready_creates_the_health_from_the_stats() -> void:
	var player: Player = _create_ready_player()

	assert_object(player.health).is_not_null()
	assert_int(player.health.current).is_equal(MAX_HEALTH)


func test_take_damage_reduces_the_health() -> void:
	var player: Player = _create_ready_player()

	player.take_damage(DAMAGE)

	assert_int(player.health.current).is_equal(MAX_HEALTH - DAMAGE)


func test_take_damage_works_before_ready_runs() -> void:
	var player: Player = _create_detached_player()

	player.take_damage(DAMAGE)

	assert_object(player.health).is_not_null()
	assert_int(player.health.current).is_equal(MAX_HEALTH - DAMAGE)


func test_apply_command_works_before_ready_runs() -> void:
	var player: Player = _create_detached_player()

	player.apply_command(_command(), DELTA, true)

	assert_object(player.health).is_not_null()
	assert_int(player.health.current).is_equal(MAX_HEALTH)


func test_apply_command_does_not_regen_while_the_delay_is_running() -> void:
	var player: Player = _create_detached_player()
	player.take_damage(DAMAGE)

	_advance(player, DELAY_FRAMES)

	assert_int(player.health.current).is_equal(MAX_HEALTH - DAMAGE)


func test_apply_command_regens_after_the_delay() -> void:
	var player: Player = _create_detached_player()
	player.take_damage(DAMAGE)

	_advance(player, DELAY_FRAMES + REGEN_FRAMES)

	assert_int(player.health.current).is_equal(MAX_HEALTH - DAMAGE + EXPECTED_REGEN)


func test_apply_command_does_not_tick_the_health_when_the_delta_is_not_positive() -> void:
	var player: Player = _create_detached_player()
	player.take_damage(DAMAGE)
	# 待機の途中で拒否させる: 経過時間が戻ると、その後の回復の開始が遅れる
	for _i: int in REGEN_FRAMES:
		player.apply_command(_command(), NEGATIVE_DELTA, true)

	_advance(player, DELAY_FRAMES + REGEN_FRAMES)

	assert_int(player.health.current).is_equal(MAX_HEALTH - DAMAGE + EXPECTED_REGEN)


func test_a_rejected_delta_does_not_change_the_pace_of_the_regen() -> void:
	var player: Player = _create_detached_player()
	player.take_damage(DAMAGE)
	# 待機を消化しきる: 残るのは回復だけであり、拒否した delta が端数へ流れると差が出る
	_advance(player, DELAY_FRAMES + REGEN_FRAMES)
	var current_before: int = player.health.current

	for _i: int in REGEN_FRAMES:
		player.apply_command(_command(), NEGATIVE_DELTA, true)
	assert_int(player.health.current).is_equal(current_before)

	# 端数が汚れていないことを、続く正常な delta の回復量で見る
	_advance(player, REGEN_FRAMES)
	assert_int(player.health.current).is_equal(current_before + EXPECTED_REGEN)


func test_died_is_emitted_once_when_the_health_reaches_zero() -> void:
	var player: Player = _create_ready_player()
	# 発火の回数を Array へ控える: lambda はローカル変数を値コピーで捕捉するが、Array は
	# 参照として捕捉されるため外側から読める
	var emissions: Array = []
	player.died.connect(func() -> void: emissions.append(true))

	player.take_damage(MAX_HEALTH)

	assert_array(emissions).is_equal([true])
	assert_int(player.health.current).is_equal(0)


func test_died_is_not_emitted_again_after_the_health_is_depleted() -> void:
	var player: Player = _create_ready_player()
	var emissions: Array = []
	player.died.connect(func() -> void: emissions.append(true))
	player.take_damage(MAX_HEALTH)

	player.take_damage(DAMAGE)
	_advance(player, DELAY_FRAMES + REGEN_FRAMES)

	assert_array(emissions).is_equal([true])
	# 枯渇後は回復もしない
	assert_int(player.health.current).is_equal(0)


func test_died_is_not_emitted_while_the_health_remains() -> void:
	var player: Player = _create_ready_player()
	var emissions: Array = []
	player.died.connect(func() -> void: emissions.append(true))

	player.take_damage(MAX_HEALTH - 1)

	assert_array(emissions).is_empty()


func test_take_damage_rejects_a_non_positive_amount() -> void:
	var player: Player = _create_ready_player()

	await (
		assert_error(func() -> void: player.take_damage(0))
		. is_push_error(INVALID_AMOUNT_ERROR_FORMAT % 0)
	)
	await (
		assert_error(func() -> void: player.take_damage(-DAMAGE))
		. is_push_error(INVALID_AMOUNT_ERROR_FORMAT % -DAMAGE)
	)
	assert_int(player.health.current).is_equal(MAX_HEALTH)
