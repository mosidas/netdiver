extends GdUnitTestSuite

const PLAYER_SCENE: PackedScene = preload("res://src/player/player.tscn")

# 既定値と別の値を使う: 既定のままだと、`stats` を読まず値を直書きした実装でも緑になる
const PRIMARY_INTERVAL: float = 0.25
const PRIMARY_DAMAGE: int = 7
const PRIMARY_BULLET_SPEED: float = 220.0
const SECONDARY_CHARGE_TIME: float = 0.5
const SECONDARY_COOLDOWN: float = 1.0
const SECONDARY_DAMAGE: int = 33
const SECONDARY_BULLET_SPEED: float = 140.0
# 待ちの間に射程で解放されない長さにする: 弾が消えると方向と速さを読めない
const BULLET_MAX_DISTANCE: float = 1024.0
# 待ちの間に必ず超える短さ。射程の値が `stats` から流れていることを解放で示す
const SHORT_MAX_DISTANCE: float = 8.0
# 発射位置から測ると待ちの間は射程内、原点から測ると即座に射程外になる組み合わせ。
# 射程の基準が発射位置からずれる変異を捕らえる。待ちの間に進むのは 110px 前後であり、
# 射程には 7 倍の余裕を取る: 余裕が薄いとランナーの遅延で実装が正しくても落ちる
const FAR_POSITION: Vector2 = Vector2(900.0, 0.0)
const LONG_MAX_DISTANCE: float = 800.0

# 2 進で厳密に表せる値を使う: 累積の丸め誤差で発射の境界が揺れると、間隔の検証がフレークする
const FIRE_DELTA: float = 0.25
const SHORT_DELTA: float = 0.0625
# 間隔の未満側。既定値の 0.12 より大きく PRIMARY_INTERVAL より小さい値にする:
# 両方より小さい値では、間隔を既定値で直書きした実装と区別できない
const BELOW_INTERVAL_DELTA: float = 0.1875

# 数フレーム(60 Hz で 1 フレーム約 17 ms)に対して余裕を取る: CI のランナーが遅い場合でも
# 物理フレームを消化させる。消化した数はアサーションで確かめるため待ち時間に依存しない
const WAIT_MILLIS: int = 500
# 発火しないことの確認は同期の呼び出しの後に行うため、待ちを長く取る必要がない
const NOT_EMITTED_MILLIS: int = 100
const TOLERANCE: Vector2 = Vector2(0.001, 0.001)

# 実装の定数を参照しない: 参照するとアサーションが自明になり、文言の退行を検出できない
const MISSING_PROJECTILE_SCENE_ERROR: String = (
	"Player: projectile_scene が設定されていない。弾を生成せずに返る"
)

const RIGHT: Vector2i = Vector2i(1, 0)
const LEFT: Vector2i = Vector2i(-1, 0)

# `player.tscn` が持つ子(placeholder と衝突形状)の数
const PLAYER_SCENE_CHILDREN: int = 2

# [move_x, aim_y, facing, is_on_floor]。斜めを必ず含める: 軸方向だけだと、向きを
# 正規化せずに速さが √2 倍になる変異が素通りする
const AIM_CASES: Array = [
	[0.0, 0.0, 1, true],
	[0.0, 0.0, -1, true],
	[0.0, -1.0, 1, true],
	[1.0, -1.0, 1, true],
	[-1.0, -1.0, -1, true],
	[-1.0, 1.0, -1, false],
]

# ツリーへ載せた `Player` が自前の入力で撃たないようにする。lambda は使わない
const NEUTRAL_INPUT_SOURCE: String = """
extends RefCounted


func read() -> PlayerCommand:
	return PlayerCommand.new()
"""


func test_primary_spawns_one_projectile_and_emits_fired() -> void:
	var player: Player = _create_player()
	var container: Node2D = _create_container(player)
	var children_before: int = container.get_child_count()
	monitor_signals(player, false)

	player.apply_command(_command(true), FIRE_DELTA, true)

	assert_int(container.get_child_count()).is_equal(children_before + 1)
	await assert_signal(player).is_emitted("fired", RIGHT, false)


func test_primary_does_not_fire_before_the_interval_elapses() -> void:
	var player: Player = _create_player()
	var container: Node2D = _create_container(player)
	# 生成直後の武器は 1 発目を待たせない。2 発目が間隔に縛られることを見る
	player.apply_command(_command(true), SHORT_DELTA, true)
	var children_after_first: int = container.get_child_count()
	var records: Array = _record_fired(player)
	monitor_signals(player, false)

	player.apply_command(_command(true), BELOW_INTERVAL_DELTA, true)

	assert_int(container.get_child_count()).is_equal(children_after_first)
	assert_array(records).is_empty()
	await assert_signal(player).wait_until(NOT_EMITTED_MILLIS).is_not_emitted("fired", RIGHT, false)


# 間隔を両側から固定する: 未満では撃たず、足りない分を足して間隔ちょうどに達したら撃つ
func test_primary_fires_again_once_the_interval_elapses() -> void:
	var player: Player = _create_player()
	var container: Node2D = _create_container(player)
	player.apply_command(_command(true), SHORT_DELTA, true)
	var children_after_first: int = container.get_child_count()
	var records: Array = _record_fired(player)

	player.apply_command(_command(true), BELOW_INTERVAL_DELTA, true)
	assert_int(container.get_child_count()).is_equal(children_after_first)

	# BELOW_INTERVAL_DELTA + SHORT_DELTA = PRIMARY_INTERVAL
	player.apply_command(_command(true), SHORT_DELTA, true)

	assert_int(container.get_child_count()).is_equal(children_after_first + 1)
	assert_array(records).is_equal([[RIGHT, false]])


func test_primary_does_not_fire_while_the_button_is_released() -> void:
	var player: Player = _create_player()
	var container: Node2D = _create_container(player)
	var children_before: int = container.get_child_count()
	var records: Array = _record_fired(player)
	monitor_signals(player, false)

	# 間隔は十分に経過している。撃たない理由がボタンだけであることを示す
	player.apply_command(_command(false), FIRE_DELTA, true)
	player.apply_command(_command(false), FIRE_DELTA, true)

	assert_int(container.get_child_count()).is_equal(children_before)
	assert_array(records).is_empty()
	await assert_signal(player).wait_until(NOT_EMITTED_MILLIS).is_not_emitted("fired", RIGHT, false)


# 押していない間に間隔の計測をやり直す実装は、離した直後の 1 発が遅れる
func test_primary_fires_immediately_after_the_button_is_pressed_again() -> void:
	var player: Player = _create_player()
	var container: Node2D = _create_container(player)
	player.apply_command(_command(true), FIRE_DELTA, true)
	player.apply_command(_command(false), SHORT_DELTA, true)
	player.apply_command(_command(false), SHORT_DELTA, true)
	player.apply_command(_command(false), SHORT_DELTA, true)
	player.apply_command(_command(false), SHORT_DELTA, true)
	var children_before: int = container.get_child_count()

	player.apply_command(_command(true), SHORT_DELTA, true)

	assert_int(container.get_child_count()).is_equal(children_before + 1)


func test_primary_projectile_carries_the_damage_from_stats() -> void:
	var player: Player = _create_player()
	var container: Node2D = _create_container(player)

	player.apply_command(_command(true), FIRE_DELTA, true)

	assert_int(_last_projectile(container).damage).is_equal(PRIMARY_DAMAGE)


func test_primary_projectiles_fly_in_the_resolved_direction_at_the_stats_speed() -> void:
	var player: Player = _create_player()
	var container: Node2D = _create_container(player)
	var projectiles: Array[Projectile] = []
	var expected_directions: Array[Vector2i] = []

	for aim_case: Array in AIM_CASES:
		var move_x: float = aim_case[0]
		var aim_y: float = aim_case[1]
		var facing: int = aim_case[2]
		var is_on_floor: bool = aim_case[3]
		player.facing = facing
		var command: PlayerCommand = _command(true)
		command.move_x = move_x
		command.aim_y = aim_y

		player.apply_command(command, FIRE_DELTA, is_on_floor)

		projectiles.append(_last_projectile(container))
		# 期待する向きを `AimResolver` から取る: テスト側で組み立てると、`Player` が
		# 方向を独自に計算していても一致してしまう
		expected_directions.append(AimResolver.resolve(move_x, aim_y, facing, is_on_floor))

	# 発射をすべて終えてからツリーへ載せる: 弾はツリーの上でしか進まず、発射位置は原点に揃う
	add_child(container)
	await await_millis(WAIT_MILLIS)

	for index: int in projectiles.size():
		var projectile: Projectile = projectiles[index]
		var context: String = "case=%s" % [AIM_CASES[index]]
		var frames: int = projectile.frames_moved
		# 待ちが足りずフレームを消化しなかった場合と、動かなかった場合を区別する
		assert_int(frames).append_failure_message(context).is_greater(0)
		# 期待値を実数で直接書かない: physics_ticks_per_second を変えると変位も変わる
		var travelled: float = PRIMARY_BULLET_SPEED / float(Engine.physics_ticks_per_second) * frames
		var expected: Vector2 = Vector2(expected_directions[index]).normalized() * travelled
		assert_vector(projectile.position).append_failure_message(context).is_equal_approx(
			expected, TOLERANCE
		)


func test_secondary_spawns_one_projectile_and_emits_fired() -> void:
	var player: Player = _create_player()
	var container: Node2D = _create_container(player)
	var children_before: int = container.get_child_count()
	monitor_signals(player, false)

	_charge_and_release(player)

	assert_int(container.get_child_count()).is_equal(children_before + 1)
	await assert_signal(player).is_emitted("fired", RIGHT, true)


func test_secondary_does_not_fire_before_the_charge_completes() -> void:
	var player: Player = _create_player()
	var container: Node2D = _create_container(player)
	var children_before: int = container.get_child_count()
	var records: Array = _record_fired(player)
	monitor_signals(player, false)

	player.apply_command(_secondary_command(true), SHORT_DELTA, true)
	player.apply_command(_secondary_command(false), SHORT_DELTA, true)

	assert_int(container.get_child_count()).is_equal(children_before)
	assert_array(records).is_empty()
	await assert_signal(player).wait_until(NOT_EMITTED_MILLIS).is_not_emitted("fired", RIGHT, true)


func test_secondary_does_not_fire_again_until_the_cooldown_elapses() -> void:
	var player: Player = _create_player()
	var container: Node2D = _create_container(player)
	_charge_and_release(player)
	var children_after_first: int = container.get_child_count()
	var records: Array = _record_fired(player)

	# クールダウン中は充電が進まないため、充電と解放を繰り返しても 2 発目は出ない
	_charge_and_release(player)

	assert_int(container.get_child_count()).is_equal(children_after_first)
	assert_array(records).is_empty()


# クールダウンの長さが `stats` から流れていることを見る
func test_secondary_fires_again_after_the_cooldown_from_stats_elapses() -> void:
	var player: Player = _create_player()
	var container: Node2D = _create_container(player)
	_charge_and_release(player)
	var children_after_first: int = container.get_child_count()
	var records: Array = _record_fired(player)

	# クールダウンの経過だけを進める。明けたフレームでは充電が始まらない
	player.apply_command(_secondary_command(false), SECONDARY_COOLDOWN, true)
	_charge_and_release(player)

	assert_int(container.get_child_count()).is_equal(children_after_first + 1)
	assert_array(records).is_equal([[RIGHT, true]])


func test_secondary_projectile_carries_the_damage_from_stats() -> void:
	var player: Player = _create_player()
	var container: Node2D = _create_container(player)

	_charge_and_release(player)

	assert_int(_last_projectile(container).damage).is_equal(SECONDARY_DAMAGE)


func test_secondary_projectile_flies_in_the_resolved_direction_at_the_stats_speed() -> void:
	var player: Player = _create_player()
	var container: Node2D = _create_container(player)
	# 斜めで撃つ: 軸方向だけだと、向きを正規化せずに速さが √2 倍になる変異が素通りする
	var expected_direction: Vector2i = AimResolver.resolve(1.0, -1.0, 1, true)

	_charge_and_release(player, 1.0, -1.0)

	var projectile: Projectile = _last_projectile(container)
	add_child(container)
	await await_millis(WAIT_MILLIS)

	var frames: int = projectile.frames_moved
	assert_int(frames).is_greater(0)
	var travelled: float = SECONDARY_BULLET_SPEED / float(Engine.physics_ticks_per_second) * frames
	var expected: Vector2 = Vector2(expected_direction).normalized() * travelled
	assert_vector(projectile.position).is_equal_approx(expected, TOLERANCE)


# 両武器が同じ 1 発を数え合わないことを見る
func test_both_weapons_fire_on_the_same_frame() -> void:
	var player: Player = _create_player()
	var container: Node2D = _create_container(player)
	var children_before: int = container.get_child_count()
	var records: Array = _record_fired(player)

	player.apply_command(_both_command(true), SECONDARY_CHARGE_TIME, true)
	player.apply_command(_both_command(false, true), FIRE_DELTA, true)

	assert_int(container.get_child_count()).is_equal(children_before + 3)
	assert_array(records).is_equal([[RIGHT, false], [RIGHT, false], [RIGHT, true]])


func test_the_fired_direction_follows_the_facing() -> void:
	var player: Player = _create_player()
	var container: Node2D = _create_container(player)
	var children_before: int = container.get_child_count()
	var records: Array = _record_fired(player)
	var command: PlayerCommand = _command(true)
	command.move_x = -1.0

	player.apply_command(command, FIRE_DELTA, true)

	assert_int(container.get_child_count()).is_equal(children_before + 1)
	assert_array(records).is_equal([[LEFT, false]])


# 自身の子にすると、弾がプレイヤーと一緒に動いてしまう
func test_the_projectile_is_added_to_the_parent_of_the_player() -> void:
	var player: Player = _create_player()
	var container: Node2D = _create_container(player)

	player.apply_command(_command(true), FIRE_DELTA, true)

	assert_int(player.get_child_count()).is_equal(PLAYER_SCENE_CHILDREN)
	assert_object(_last_projectile(container).get_parent()).is_same(container)


func test_the_projectile_is_added_to_the_player_when_it_has_no_parent() -> void:
	var player: Player = _create_player()
	var children_before: int = player.get_child_count()

	player.apply_command(_command(true), FIRE_DELTA, true)

	assert_int(player.get_child_count()).is_equal(children_before + 1)


func test_the_projectile_starts_at_the_position_of_the_player() -> void:
	var player: Player = _create_player()
	var container: Node2D = _create_container(player)
	player.position = Vector2(48.0, -32.0)

	player.apply_command(_command(true), FIRE_DELTA, true)

	assert_vector(_last_projectile(container).position).is_equal(player.position)


# 射程が `stats` から流れていることを、待ちの間に解放されることで示す
func test_the_projectile_is_released_after_the_max_distance_from_stats() -> void:
	var player: Player = _create_player()
	player.stats.bullet_max_distance = SHORT_MAX_DISTANCE
	var container: Node2D = _create_container(player)

	player.apply_command(_command(true), FIRE_DELTA, true)

	var projectile: Projectile = _last_projectile(container)
	add_child(container)
	await await_millis(WAIT_MILLIS)

	assert_bool(is_instance_valid(projectile)).is_false()


func test_firing_without_a_projectile_scene_pushes_an_error() -> void:
	var player: Player = _create_player()
	var container: Node2D = _create_container(player)
	player.projectile_scene = null
	var children_before: int = container.get_child_count()
	var records: Array = _record_fired(player)
	var command: PlayerCommand = _command(true)

	await assert_error(
		func() -> void: player.apply_command(command, FIRE_DELTA, true)
	).is_push_error(MISSING_PROJECTILE_SCENE_ERROR)

	assert_int(container.get_child_count()).is_equal(children_before)
	assert_array(records).is_empty()


# 射程は発射位置から測る。発射位置を決める前に発射すると、原点からの距離で測られる
func test_the_range_is_measured_from_the_position_of_the_player() -> void:
	var player: Player = _create_player()
	player.stats.bullet_max_distance = LONG_MAX_DISTANCE
	var container: Node2D = _create_container(player)
	player.position = FAR_POSITION

	player.apply_command(_command(true), FIRE_DELTA, true)

	var projectile: Projectile = _last_projectile(container)
	add_child(container)
	await await_millis(WAIT_MILLIS)

	assert_bool(is_instance_valid(projectile)).is_true()
	var frames: int = projectile.frames_moved
	assert_int(frames).is_greater(0)
	# 待ちの間に射程へ届いていないことを確かめる。届いていれば解放が正しく、検証が空振りする
	var travelled: float = PRIMARY_BULLET_SPEED / float(Engine.physics_ticks_per_second) * frames
	assert_float(travelled).is_less(LONG_MAX_DISTANCE)


func _create_player() -> Player:
	var player: Player = auto_free(PLAYER_SCENE.instantiate())
	var stats: PlayerStats = auto_free(PlayerStats.new())
	stats.primary_interval = PRIMARY_INTERVAL
	stats.primary_damage = PRIMARY_DAMAGE
	stats.primary_bullet_speed = PRIMARY_BULLET_SPEED
	stats.secondary_charge_time = SECONDARY_CHARGE_TIME
	stats.secondary_cooldown = SECONDARY_COOLDOWN
	stats.secondary_damage = SECONDARY_DAMAGE
	stats.secondary_bullet_speed = SECONDARY_BULLET_SPEED
	stats.bullet_max_distance = BULLET_MAX_DISTANCE
	player.stats = stats
	player.input_source = Callable(_create_neutral_input_stub(), "read")
	return player


## 弾の親になる容器。生成された弾は容器の子であり、容器の解放で一緒に解放される
func _create_container(player: Player) -> Node2D:
	var container: Node2D = auto_free(Node2D.new())
	container.add_child(player)
	return container


func _create_neutral_input_stub() -> RefCounted:
	var stub_script: GDScript = GDScript.new()
	stub_script.source_code = NEUTRAL_INPUT_SOURCE
	stub_script.reload()
	return auto_free(stub_script.new())


func _command(primary_held: bool) -> PlayerCommand:
	var command: PlayerCommand = auto_free(PlayerCommand.new())
	command.primary_held = primary_held
	return command


func _secondary_command(secondary_held: bool) -> PlayerCommand:
	var command: PlayerCommand = auto_free(PlayerCommand.new())
	command.secondary_held = secondary_held
	return command


func _both_command(secondary_held: bool, primary_held: bool = true) -> PlayerCommand:
	var command: PlayerCommand = auto_free(PlayerCommand.new())
	command.primary_held = primary_held
	command.secondary_held = secondary_held
	return command


func _charge_and_release(player: Player, move_x: float = 0.0, aim_y: float = 0.0) -> void:
	var holding: PlayerCommand = _secondary_command(true)
	holding.move_x = move_x
	holding.aim_y = aim_y
	player.apply_command(holding, SECONDARY_CHARGE_TIME, true)

	var releasing: PlayerCommand = _secondary_command(false)
	releasing.move_x = move_x
	releasing.aim_y = aim_y
	player.apply_command(releasing, SHORT_DELTA, true)


## 発火した順に `[direction, is_secondary]` を控える。発火の回数と引数を厳密に比較できる
func _record_fired(player: Player) -> Array:
	var records: Array = []
	var record: Callable = func(direction: Vector2i, is_secondary: bool) -> void:
		records.append([direction, is_secondary])
	player.fired.connect(record)
	return records


func _last_projectile(container: Node2D) -> Projectile:
	return container.get_child(container.get_child_count() - 1)
