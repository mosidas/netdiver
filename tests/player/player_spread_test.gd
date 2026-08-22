extends GdUnitTestSuite

const PLAYER_SCENE: PackedScene = preload("res://src/player/player.tscn")

# 2 進で厳密に表せる値を使う: 累積の丸め誤差でフレームの境界が揺れると、発射のフレームを
# フレーム数で数えられない
const FRAME_DELTA: float = 0.0625

# 4 フレーム。既定の 0.12 と別に取る: 既定のままだと、間隔を直書きした実装でも緑になる
const PRIMARY_INTERVAL: float = 0.25
const PRIMARY_INTERVAL_FRAMES: int = 4

## 1 回の呼び出しで必ず発射できる delta。間隔ちょうどであり、呼び出しごとに 1 発に収まる
const FIRE_DELTA: float = PRIMARY_INTERVAL

# 既定の 10 と別に取り、副武器の既定 50 とも重ねない: 重なると、別の項目を渡す変異が落ちない
const PRIMARY_DAMAGE: int = 7

# 既定の 400.0 と別に取り、副武器の既定 300.0・射程に渡す値とも重ねない
const PRIMARY_BULLET_SPEED: float = 220.0

# 待ちの間に射程で解放されない長さ。既定の 400.0 と別に取る。既定では
# `primary_bullet_speed` と `bullet_max_distance` が同値であり、両者を取り違える変異は
# 既定のままだと素通りする
const BULLET_MAX_DISTANCE: float = 1024.0

# 待ちの間に必ず超える短さ。射程が `stats` から流れていることを解放で示す
const SHORT_MAX_DISTANCE: float = 8.0

# 12 フレーム。既定の 0.8 と別に取る
const SECONDARY_CHARGE_TIME: float = 0.75
const SECONDARY_CHARGE_FRAMES: int = 12

# 既定の 2.0 と別に取る
const SECONDARY_COOLDOWN: float = 1.0

# 充電が満ちる 12 フレームに 1 フレームの余裕を足す: ちょうど 12 だと、1 フレーム分の
# 割り算を 12 回足した値が満充電に届かないことがあり、発射のフレームが揺れる
const SECONDARY_HOLD_FRAMES: int = 13

# 既定の 100 と別に取る
const MAX_HEALTH: int = 48
const LETHAL_DAMAGE: int = MAX_HEALTH

# 拡散の発数。仕様の値であり、実装から読まない
const SPREAD_SIZE: int = 3

# 実装の定数を参照しない: 参照するとアサーションが自明になり、文言の退行を検出できない
const MISSING_PROJECTILE_SCENE_ERROR: String = (
	"Player: projectile_scene が設定されていない。弾を生成せずに返る"
)

const RIGHT: Vector2i = Vector2i(1, 0)
const UP_RIGHT: Vector2i = Vector2i(1, -1)

# 射撃方向として妥当な向きの集合。実装の定数を参照せず自前で持つ
const EIGHT_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(1, 1),
	Vector2i(0, 1),
	Vector2i(-1, 1),
	Vector2i(-1, 0),
	Vector2i(-1, -1),
	Vector2i(0, -1),
	Vector2i(1, -1),
]

# レイヤ 3・マスクは 1 と 4。生の 4 と 9 を書かない: どのレイヤを意味するのかがテストから
# 読めなくなる
const SPREAD_COLLISION_LAYER: int = 1 << 2
const SPREAD_COLLISION_MASK: int = (1 << 0) | (1 << 3)

const FIRED_EVENT: String = "fired"
const SPREAD_EVENT: String = "spread_fired"

# [move_x, aim_y, is_on_floor]。8 方向すべてを通す: 1 方向だけだと、向きを取り違える実装や
# 中央だけを撃つ実装が素通りする
const AIM_CASES: Array = [
	[0.0, 0.0, true],
	[1.0, -1.0, true],
	[0.0, -1.0, true],
	[-1.0, 0.0, true],
	[-1.0, -1.0, true],
	[0.0, 1.0, false],
	[1.0, 1.0, false],
	[-1.0, 1.0, false],
]

# 数フレーム(60 Hz で 1 フレーム約 17 ms)に対して余裕を取る: 遅いランナーでも物理フレームを
# 消化させる。消化した数はアサーションで確かめるため待ち時間に依存しない
const WAIT_MILLIS: int = 500

# 変位から向きと速さを戻すときの許容差。float32 の累積誤差(実測 1e-4 程度)に対して
# 余裕を取りつつ、20 度のずれ(半径 110px で 38px 相当)とは桁が離れている
const TOLERANCE: Vector2 = Vector2(0.01, 0.01)
const DIRECTION_TOLERANCE: Vector2 = Vector2(0.001, 0.001)

# ツリーへ載せた `Player` の入力をテスト側から動かす。lambda は使わない
const HELD_INPUT_SOURCE: String = """
extends RefCounted

var primary_held: bool = false


func read() -> PlayerCommand:
	var command: PlayerCommand = PlayerCommand.new()
	command.primary_held = primary_held
	return command
"""


# 検証で使う値が既定と一致しないことを固定する番人。一致すると、`stats` を読まず値を
# 直書きした実装が素通りする
func test_the_values_used_here_differ_from_the_defaults() -> void:
	var defaults: PlayerStats = auto_free(PlayerStats.new())

	assert_float(PRIMARY_INTERVAL).is_not_equal(defaults.primary_interval)
	assert_int(PRIMARY_DAMAGE).is_not_equal(defaults.primary_damage)
	assert_float(PRIMARY_BULLET_SPEED).is_not_equal(defaults.primary_bullet_speed)
	assert_float(BULLET_MAX_DISTANCE).is_not_equal(defaults.bullet_max_distance)
	assert_float(SECONDARY_CHARGE_TIME).is_not_equal(defaults.secondary_charge_time)
	assert_float(SECONDARY_COOLDOWN).is_not_equal(defaults.secondary_cooldown)
	assert_int(MAX_HEALTH).is_not_equal(defaults.max_health)

	# 主武器の値が他の枠の値と重ならないこと: 重なると、別の項目を渡す変異が落ちない
	var other_damages: Array[int] = [defaults.secondary_damage, MAX_HEALTH]
	assert_array(other_damages).not_contains([PRIMARY_DAMAGE])

	var other_speeds: Array[float] = [defaults.secondary_bullet_speed, BULLET_MAX_DISTANCE]
	assert_array(other_speeds).not_contains([PRIMARY_BULLET_SPEED])


# フレーム数で境界を数える前提を固定する: 崩れると、境界のケースが実装ではなく
# 丸め誤差を観測する
func test_the_periods_used_here_are_whole_numbers_of_frames() -> void:
	assert_float(PRIMARY_INTERVAL).is_equal(PRIMARY_INTERVAL_FRAMES * FRAME_DELTA)
	assert_float(SECONDARY_CHARGE_TIME).is_equal(SECONDARY_CHARGE_FRAMES * FRAME_DELTA)
	assert_float(FIRE_DELTA).is_equal(PRIMARY_INTERVAL)


# 撃ったフレームでだけ 3 発。間隔の内側のフレームでは 0 発であり、間隔が明ければ再び 3 発
func test_the_upgraded_primary_spawns_three_projectiles_on_the_frames_it_fires() -> void:
	var player: Player = _create_player()
	var container: Node = player.get_parent()
	player.grant_upgrade()
	var children_before: int = container.get_child_count()

	var spawns: Array[int] = _spawns_per_frame(player, container, _repeat_frames(true, 5))

	assert_array(spawns).is_equal([SPREAD_SIZE, 0, 0, 0, SPREAD_SIZE])
	assert_int(container.get_child_count()).is_equal(children_before + SPREAD_SIZE * 2)


# 分岐のもう片側。強化していない間は同じ列で 1 発ずつになる
func test_the_plain_primary_spawns_one_projectile_on_the_frames_it_fires() -> void:
	var player: Player = _create_player()
	var container: Node = player.get_parent()
	var children_before: int = container.get_child_count()

	var spawns: Array[int] = _spawns_per_frame(player, container, _repeat_frames(true, 5))

	assert_array(spawns).is_equal([1, 0, 0, 0, 1])
	assert_int(container.get_child_count()).is_equal(children_before + 2)


# 発射のフレームが強化の有無で一致すること。押し直しを混ぜた列を与える: 押しっぱなしだけだと、
# 押下の縁で間隔を測り直す変異が両側で同じずれ方をする
func test_the_firing_frames_do_not_change_with_the_upgrade() -> void:
	var held_frames: Array[bool] = [true, true, false, true, true, true, true, true, true]
	var upgraded: Player = _create_player()
	upgraded.grant_upgrade()
	var plain: Player = _create_player()

	var upgraded_spawns: Array[int] = _spawns_per_frame(
		upgraded, upgraded.get_parent(), held_frames
	)
	var plain_spawns: Array[int] = _spawns_per_frame(plain, plain.get_parent(), held_frames)

	var upgraded_mask: Array[bool] = _firing_mask(upgraded_spawns)
	var plain_mask: Array[bool] = _firing_mask(plain_spawns)
	assert_array(upgraded_mask).is_equal(plain_mask)
	# 観測が空振りしていないこと: 発射が 1 度も起きない列だと、どんな実装でも一致する
	assert_int(upgraded_mask.count(true)).is_greater_equal(2)
	for index: int in upgraded_spawns.size():
		var context: String = "index=%d" % index
		var expected: int = SPREAD_SIZE if upgraded_mask[index] else 0
		assert_int(upgraded_spawns[index]).append_failure_message(context).is_equal(expected)
		assert_int(plain_spawns[index]).append_failure_message(context).is_equal(
			1 if plain_mask[index] else 0
		)


# 3 発の進む向きが `SpreadResolver.resolve()` の 3 要素と同じ順で一致し、速さが
# `primary_bullet_speed` であること。向きは弾の変位でしか読めないため、発射をすべて
# 終えてからツリーへ載せて実フレームで飛ばす
func test_the_spread_flies_in_the_resolver_directions_at_the_stats_speed() -> void:
	var player: Player = _create_player()
	var container: Node = player.get_parent()
	player.grant_upgrade()
	var projectiles: Array[Projectile] = []
	var expected_directions: Array[Vector2] = []

	for aim_case: Array in AIM_CASES:
		var move_x: float = aim_case[0]
		var aim_y: float = aim_case[1]
		var is_on_floor: bool = aim_case[2]
		var context: String = "case=%s" % [aim_case]
		var spawned: Array[Projectile] = _fire_primary(
			player, container, move_x, aim_y, is_on_floor
		)

		assert_int(spawned.size()).append_failure_message(context).is_equal(SPREAD_SIZE)
		projectiles.append_array(spawned)
		# 期待する 3 方向を `SpreadResolver` から取る: テスト側で角度を組み立て直すと、
		# `Player` が独自に回転を計算していても一致してしまう
		var direction: Vector2i = AimResolver.resolve(move_x, aim_y, player.facing, is_on_floor)
		expected_directions.append_array(SpreadResolver.resolve(direction))

	add_child(container)
	await await_millis(WAIT_MILLIS)

	assert_int(expected_directions.size()).is_equal(AIM_CASES.size() * SPREAD_SIZE)
	for index: int in projectiles.size():
		var projectile: Projectile = projectiles[index]
		var context: String = "index=%d expected=%s" % [index, expected_directions[index]]
		var frames: int = projectile.frames_moved
		# 待ちが足りずフレームを消化しなかった場合と、動かなかった場合を区別する
		assert_int(frames).append_failure_message(context).is_greater(0)
		# 期待値を実数で直接書かない: physics_ticks_per_second を変えると変位も変わる
		var travelled: float = PRIMARY_BULLET_SPEED / float(Engine.physics_ticks_per_second) * frames
		var expected: Vector2 = expected_directions[index] * travelled
		assert_vector(projectile.position).append_failure_message(context).is_equal_approx(
			expected, TOLERANCE
		)


# 3 発すべてが `primary_damage` を持つこと。副武器の値を渡す変異は、値を既定と別に
# 取ってあるためここで落ちる
func test_the_spread_projectiles_carry_the_primary_damage_from_stats() -> void:
	var player: Player = _create_player()
	player.grant_upgrade()

	var spawned: Array[Projectile] = _fire_primary(player, player.get_parent(), 0.0, 0.0, true)

	assert_int(spawned.size()).is_equal(SPREAD_SIZE)
	var damages: Array[int] = []
	for projectile: Projectile in spawned:
		damages.append(projectile.damage)
	assert_array(damages).is_equal([PRIMARY_DAMAGE, PRIMARY_DAMAGE, PRIMARY_DAMAGE])


# 射程に `bullet_max_distance` が渡ること。短い射程で解放される側と、長い射程で同じ待ちの
# 間は解放されない側を対で見る: 片側だけだと、射程に別の値を渡す変異がどちらかのケースで緑になる
func test_the_spread_projectiles_are_released_after_the_bullet_max_distance_from_stats() -> void:
	var near_player: Player = _create_player()
	near_player.stats.bullet_max_distance = SHORT_MAX_DISTANCE
	near_player.grant_upgrade()
	var near_container: Node = near_player.get_parent()
	var near_spawned: Array[Projectile] = _fire_primary(
		near_player, near_container, 0.0, 0.0, true
	)

	var far_player: Player = _create_player()
	far_player.grant_upgrade()
	var far_container: Node = far_player.get_parent()
	var far_spawned: Array[Projectile] = _fire_primary(far_player, far_container, 0.0, 0.0, true)

	assert_int(near_spawned.size()).is_equal(SPREAD_SIZE)
	assert_int(far_spawned.size()).is_equal(SPREAD_SIZE)

	add_child(near_container)
	add_child(far_container)
	await await_millis(WAIT_MILLIS)

	for index: int in near_spawned.size():
		var context: String = "index=%d" % index
		assert_bool(is_instance_valid(near_spawned[index])).append_failure_message(
			context
		).is_false()
	for index: int in far_spawned.size():
		var context: String = "index=%d" % index
		assert_bool(is_instance_valid(far_spawned[index])).append_failure_message(context).is_true()


# 発火の回数と順序。受け手を 1 つにまとめて控える: 別々の受け手だと、どちらが先かを読めない
func test_the_upgraded_shot_emits_fired_then_spread_fired_once() -> void:
	var player: Player = _create_player()
	var container: Node = player.get_parent()
	player.grant_upgrade()
	var events: Array = _record_events(player)

	var spawned: Array[Projectile] = _fire_primary(player, container, 1.0, -1.0, true)

	assert_int(spawned.size()).is_equal(SPREAD_SIZE)
	assert_int(events.size()).is_equal(2)
	assert_array(events[0]).is_equal([FIRED_EVENT, UP_RIGHT, false])
	assert_str(events[1][0]).is_equal(SPREAD_EVENT)
	assert_int((events[1][1] as Array).size()).is_equal(SPREAD_SIZE)


# `fired` の `direction` は 8 方向の `Vector2i` のままであること。拡散の 20 度の向きを
# `fired` に載せる変異は、型と 8 方向の集合の両方で落ちる
func test_the_fired_direction_stays_an_eight_way_vector2i_while_upgraded() -> void:
	var player: Player = _create_player()
	var container: Node = player.get_parent()
	player.grant_upgrade()
	var records: Array = _record_fired_untyped(player)
	var expected: Array = []

	for aim_case: Array in AIM_CASES:
		var move_x: float = aim_case[0]
		var aim_y: float = aim_case[1]
		var is_on_floor: bool = aim_case[2]
		_fire_primary(player, container, move_x, aim_y, is_on_floor)
		expected.append(AimResolver.resolve(move_x, aim_y, player.facing, is_on_floor))

	assert_int(records.size()).is_equal(AIM_CASES.size())
	var directions: Array = []
	for index: int in records.size():
		var context: String = "index=%d" % index
		var direction: Variant = records[index][0]
		assert_int(typeof(direction)).append_failure_message(context).is_equal(TYPE_VECTOR2I)
		assert_bool(EIGHT_DIRECTIONS.has(direction)).append_failure_message(context).is_true()
		assert_bool(records[index][1]).append_failure_message(context).is_false()
		directions.append(direction)
	assert_array(directions).is_equal(expected)


# `spread_fired` の `directions` が、生成した 3 発の進む向きと同じ順であること。
# 並びを入れ替える変異はここでしか落ちない
func test_the_spread_fired_directions_match_the_spawned_projectiles_in_order() -> void:
	var player: Player = _create_player()
	var container: Node = player.get_parent()
	player.grant_upgrade()
	var records: Array = _record_spread_fired(player)

	var spawned: Array[Projectile] = _fire_primary(player, container, 1.0, -1.0, true)

	assert_int(spawned.size()).is_equal(SPREAD_SIZE)
	assert_int(records.size()).is_equal(1)
	var emitted: Array = records[0]
	assert_int(emitted.size()).is_equal(SPREAD_SIZE)

	add_child(container)
	await await_millis(WAIT_MILLIS)

	for index: int in spawned.size():
		var projectile: Projectile = spawned[index]
		var context: String = "index=%d emitted=%s" % [index, emitted[index]]
		assert_int(projectile.frames_moved).append_failure_message(context).is_greater(0)
		var travelled: float = projectile.position.length()
		assert_float(travelled).append_failure_message(context).is_greater(0.0)
		var flight: Vector2 = projectile.position / travelled
		assert_vector(flight).append_failure_message(context).is_equal_approx(
			emitted[index], DIRECTION_TOLERANCE
		)


# 分岐のもう片側。強化していない間は `fired` だけが出て `spread_fired` は出ない
func test_the_plain_primary_emits_fired_without_spread_fired() -> void:
	var player: Player = _create_player()
	var container: Node = player.get_parent()
	var events: Array = _record_events(player)

	var spawned: Array[Projectile] = _fire_primary(player, container, 1.0, -1.0, true)

	assert_int(spawned.size()).is_equal(1)
	assert_array(events).is_equal([[FIRED_EVENT, UP_RIGHT, false]])


# 強化中でも副武器の発射では `spread_fired` が出ないこと
func test_the_secondary_weapon_does_not_emit_spread_fired() -> void:
	var player: Player = _create_player()
	var container: Node = player.get_parent()
	player.grant_upgrade()
	var events: Array = _record_events(player)
	var children_before: int = container.get_child_count()

	_charge_and_release_secondary(player)

	assert_int(container.get_child_count()).is_equal(children_before + 1)
	assert_array(events).is_equal([[FIRED_EVENT, RIGHT, true]])


# 弾を生成できないケース。報告が出ること・弾が 0 発・どちらのシグナルも出ないことを同じ
# ケースで見る。`push_error` の回数は仕様が定めていないためアサーションしない
func test_the_upgraded_shot_without_a_projectile_scene_reports_and_emits_nothing() -> void:
	var player: Player = _create_player()
	var container: Node = player.get_parent()
	player.projectile_scene = null
	player.grant_upgrade()
	var events: Array = _record_events(player)
	var children_before: int = container.get_child_count()
	var fire: Callable = func() -> void: (
		player.apply_command(_primary_command(true, 0.0, 0.0), FIRE_DELTA, true)
	)

	await assert_error(fire).is_push_error(MISSING_PROJECTILE_SCENE_ERROR)

	assert_int(container.get_child_count()).is_equal(children_before)
	assert_array(events).is_empty()


# 自身の子にすると、弾がプレイヤーと一緒に動いてしまう。親の子が 3 つ増えることと、
# 自身の子が増えないことを対で見る
func test_the_spread_projectiles_are_added_to_the_parent_of_the_player() -> void:
	var player: Player = _create_player()
	var container: Node = player.get_parent()
	player.grant_upgrade()
	var player_children_before: int = player.get_child_count()
	var container_children_before: int = container.get_child_count()

	var spawned: Array[Projectile] = _fire_primary(player, container, 0.0, 0.0, true)

	assert_int(spawned.size()).is_equal(SPREAD_SIZE)
	assert_int(player.get_child_count()).is_equal(player_children_before)
	assert_int(container.get_child_count()).is_equal(container_children_before + SPREAD_SIZE)
	for index: int in spawned.size():
		var context: String = "index=%d" % index
		assert_object(spawned[index].get_parent()).append_failure_message(context).is_same(container)


# 親が無いときだけ自身へ載せる(既存の 1 発の生成と同じ扱い)
func test_the_spread_projectiles_are_added_to_the_player_when_it_has_no_parent() -> void:
	var player: Player = _create_orphan_player()
	player.grant_upgrade()
	var children_before: int = player.get_child_count()

	var spawned: Array[Projectile] = _fire_primary(player, player, 0.0, 0.0, true)

	assert_int(spawned.size()).is_equal(SPREAD_SIZE)
	assert_int(player.get_child_count()).is_equal(children_before + SPREAD_SIZE)


# 当たり判定は `projectile.tscn` の流用によって満たす。生成の経路で書き換える実装は
# ここで落ちる
func test_the_spread_projectiles_keep_the_collision_layers_of_the_projectile() -> void:
	var player: Player = _create_player()
	player.grant_upgrade()

	var spawned: Array[Projectile] = _fire_primary(player, player.get_parent(), 0.0, 0.0, true)

	assert_int(spawned.size()).is_equal(SPREAD_SIZE)
	for index: int in spawned.size():
		var projectile: Projectile = spawned[index]
		var context: String = "index=%d" % index
		assert_int(projectile.collision_layer).append_failure_message(context).is_equal(
			SPREAD_COLLISION_LAYER
		)
		assert_int(projectile.collision_mask).append_failure_message(context).is_equal(
			SPREAD_COLLISION_MASK
		)


# 強化の解除が状態だけでなく発射にも及ぶこと。死ぬ前に 3 発だったことを同じケースで見る:
# 見ないと、最初から 1 発の実装でも緑になる
func test_the_primary_returns_to_one_projectile_after_the_health_reaches_zero() -> void:
	var player: Player = _create_player()
	var container: Node = player.get_parent()
	player.grant_upgrade()
	var before_death: Array[Projectile] = _fire_primary(player, container, 0.0, 0.0, true)

	player.take_damage(LETHAL_DAMAGE)
	var events: Array = _record_events(player)
	var after_death: Array[Projectile] = _fire_primary(player, container, 0.0, 0.0, true)

	assert_int(before_death.size()).is_equal(SPREAD_SIZE)
	assert_int(player.health.current).is_equal(0)
	assert_bool(player.is_primary_upgraded).is_false()
	assert_int(after_death.size()).is_equal(1)
	assert_array(events).is_equal([[FIRED_EVENT, RIGHT, false]])


# 同期で駆動するヘルパだけに頼らない: エンジンの物理フレームで `_physics_process` を通しても
# 1 回の発射につき 3 発が出ること。発射の回数は待ちの長さで変わるため、シグナルの回数から導く
func test_the_spread_is_fired_while_real_physics_frames_drive_the_player() -> void:
	var player: Player = _create_player()
	var container: Node = player.get_parent()
	var stub: RefCounted = _create_input_stub()
	player.input_source = Callable(stub, "read")
	player.grant_upgrade()
	var fired_records: Array = _record_fired(player)
	var spread_records: Array = _record_spread_fired(player)
	var children_before: int = container.get_child_count()
	stub.primary_held = true

	add_child(container)
	await await_millis(WAIT_MILLIS)
	stub.primary_held = false

	# 待ちが足りずフレームを消化しなかった場合と、撃たなかった場合を区別する
	assert_int(spread_records.size()).is_greater_equal(1)
	assert_int(fired_records.size()).is_equal(spread_records.size())
	assert_int(container.get_child_count()).is_equal(
		children_before + SPREAD_SIZE * spread_records.size()
	)
	for index: int in range(children_before, container.get_child_count()):
		var projectile: Projectile = container.get_child(index)
		var context: String = "index=%d" % index
		# 弾が実フレームで進んでいること: 進んでいなければツリーの外での駆動と区別できない
		assert_int(projectile.frames_moved).append_failure_message(context).is_greater(0)


# 生成された弾がすべて主武器・副武器のどちらかの 1 回の発射に帰属すること。両方の武器を
# 同じ列で駆動し、フレームごとに増えた弾の数が `3 × 主武器の発射 + 1 × 副武器の発射` と
# 一致することを見る。第 3 の発射経路が残っていれば、その差としてここに現れる
func test_every_spawned_projectile_belongs_to_the_primary_or_the_secondary_weapon() -> void:
	var player: Player = _create_player()
	var container: Node = player.get_parent()
	player.grant_upgrade()
	var fired_records: Array = _record_fired(player)
	var held_frames: Array[bool] = _repeat_frames(true, SECONDARY_HOLD_FRAMES)
	held_frames.append(false)
	var observed: Array = []

	for secondary_held: bool in held_frames:
		var children_before: int = container.get_child_count()
		var records_before: int = fired_records.size()
		var command: PlayerCommand = _primary_command(true, 0.0, 0.0)
		command.secondary_held = secondary_held
		player.apply_command(command, FRAME_DELTA, true)
		observed.append(
			[
				container.get_child_count() - children_before,
				_count_shots(fired_records, records_before, false),
				_count_shots(fired_records, records_before, true),
			]
		)

	var total_primary: int = 0
	var total_secondary: int = 0
	for index: int in observed.size():
		var entry: Array = observed[index]
		var context: String = "index=%d entry=%s" % [index, entry]
		assert_int(entry[0]).append_failure_message(context).is_equal(
			SPREAD_SIZE * int(entry[1]) + int(entry[2])
		)
		total_primary += int(entry[1])
		total_secondary += int(entry[2])

	# 観測が空振りしていないこと: どちらの武器も実際に撃っている
	assert_int(total_primary).is_greater_equal(2)
	assert_int(total_secondary).is_equal(1)


## 1 回分の発射を行い、そのフレームに増えた弾を返す。
##
## `FIRE_DELTA` は間隔ちょうどであり、呼び出しごとに必ず 1 回発射する
func _fire_primary(
	player: Player, container: Node, move_x: float, aim_y: float, is_on_floor: bool
) -> Array[Projectile]:
	var children_before: int = container.get_child_count()
	player.apply_command(_primary_command(true, move_x, aim_y), FIRE_DELTA, is_on_floor)

	var spawned: Array[Projectile] = []
	for index: int in range(children_before, container.get_child_count()):
		spawned.append(container.get_child(index))
	return spawned


## 1 フレームずつ進め、そのフレームに増えた子の数を並べて返す。
##
## 1 本のアサーションに畳まない: 畳むと、発射のフレームが 1 つずれる変異が落ちない
func _spawns_per_frame(player: Player, container: Node, held_frames: Array[bool]) -> Array[int]:
	var spawns: Array[int] = []
	for held: bool in held_frames:
		var before: int = container.get_child_count()
		player.apply_command(_primary_command(held, 0.0, 0.0), FRAME_DELTA, true)
		spawns.append(container.get_child_count() - before)
	return spawns


## 弾が増えたフレームを真にした列。発数の違いを落として発射のフレームだけを比べる
func _firing_mask(spawns: Array[int]) -> Array[bool]:
	var mask: Array[bool] = []
	for count: int in spawns:
		mask.append(count > 0)
	return mask


func _count_shots(records: Array, from_index: int, is_secondary: bool) -> int:
	var count: int = 0
	for index: int in range(from_index, records.size()):
		if bool(records[index][1]) == is_secondary:
			count += 1
	return count


## 充電を満たしてから離す。副武器はボタンを離したフレームで撃つ
func _charge_and_release_secondary(player: Player) -> void:
	var holding: PlayerCommand = auto_free(PlayerCommand.new())
	holding.secondary_held = true
	player.apply_command(holding, SECONDARY_CHARGE_TIME, true)

	var releasing: PlayerCommand = auto_free(PlayerCommand.new())
	player.apply_command(releasing, FRAME_DELTA, true)


## 発火した順に `[FIRED_EVENT, direction, is_secondary]` と `[SPREAD_EVENT, directions]` を
## 1 つの配列へ控える。発火の順序を読める形にする
func _record_events(player: Player) -> Array:
	var records: Array = []
	var record_fired: Callable = func(direction: Vector2i, is_secondary: bool) -> void:
		records.append([FIRED_EVENT, direction, is_secondary])
	player.fired.connect(record_fired)
	var record_spread: Callable = func(directions: Array[Vector2]) -> void:
		records.append([SPREAD_EVENT, directions])
	player.spread_fired.connect(record_spread)
	return records


## 発火した順に `[direction, is_secondary]` を控える
func _record_fired(player: Player) -> Array:
	var records: Array = []
	var record: Callable = func(direction: Vector2i, is_secondary: bool) -> void:
		records.append([direction, is_secondary])
	player.fired.connect(record)
	return records


## 型を宣言せずに控える: 型付きの受け手は値を変換して受け取るため、渡された型そのものを
## 観測できない
func _record_fired_untyped(player: Player) -> Array:
	var records: Array = []
	var record: Callable = func(direction: Variant, is_secondary: Variant) -> void:
		records.append([direction, is_secondary])
	player.fired.connect(record)
	return records


## 発火した順に `directions` を控える
func _record_spread_fired(player: Player) -> Array:
	var records: Array = []
	var record: Callable = func(directions: Array[Vector2]) -> void: records.append(directions)
	player.spread_fired.connect(record)
	return records


## `held` を `count` フレーム分並べて返す
func _repeat_frames(held: bool, count: int) -> Array[bool]:
	var frames: Array[bool] = []
	for frame: int in count:
		frames.append(held)
	return frames


func _primary_command(primary_held: bool, move_x: float, aim_y: float) -> PlayerCommand:
	var command: PlayerCommand = auto_free(PlayerCommand.new())
	command.primary_held = primary_held
	command.move_x = move_x
	command.aim_y = aim_y
	return command


## 弾の親になる容器の子として返す。容器を与えないと弾が `Player` 自身の子になり、
## 木の形が変わる
func _create_player() -> Player:
	var player: Player = _create_orphan_player()
	var container: Node2D = auto_free(Node2D.new())
	container.add_child(player)
	return player


## 容器を持たない `Player`。親が無いときの生成先を見るケースが使う
func _create_orphan_player() -> Player:
	var player: Player = auto_free(PLAYER_SCENE.instantiate())
	var stats: PlayerStats = auto_free(PlayerStats.new())
	stats.max_health = MAX_HEALTH
	stats.primary_interval = PRIMARY_INTERVAL
	stats.primary_damage = PRIMARY_DAMAGE
	stats.primary_bullet_speed = PRIMARY_BULLET_SPEED
	stats.bullet_max_distance = BULLET_MAX_DISTANCE
	stats.secondary_charge_time = SECONDARY_CHARGE_TIME
	stats.secondary_cooldown = SECONDARY_COOLDOWN
	player.stats = stats
	player.input_source = Callable(_create_input_stub(), "read")
	return player


## 既定では何も押していない入力源。ツリーへ載せるケースだけが `primary_held` を動かす
func _create_input_stub() -> RefCounted:
	var stub_script: GDScript = GDScript.new()
	stub_script.source_code = HELD_INPUT_SOURCE
	stub_script.reload()
	return auto_free(stub_script.new())
