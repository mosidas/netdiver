extends GdUnitTestSuite

const PLAYER_SCENE: PackedScene = preload("res://src/player/player.tscn")

# 2 進で厳密に表せる値を使う: 累積の丸め誤差でフレームの境界が揺れると、発射のフレームを
# フレーム数で数えられない
const FRAME_DELTA: float = 0.0625

# 8 フレーム。既定の 1.5 と離し、押しっぱなしの列がクールダウンの内側に収まる長さに取る
const ABILITY_COOLDOWN: float = 0.5
const ABILITY_COOLDOWN_FRAMES: int = 8

# 既定の 3 を使わない: 既定のままだと、回数を直書きした実装でも緑になる
const ABILITY_USES: int = 5

# 主武器の 10・副武器の 50・既定の 20 のいずれとも別に取る: 一致していると、別の項目を
# 渡す変異が落ちない
const ABILITY_DAMAGE: int = 27

# 既定の 300.0 は `secondary_bullet_speed` の既定と同値であり、そのままでは副武器の値を
# 渡す変異が素通りする。主武器の 400.0 とも別に取る
const ABILITY_BULLET_SPEED: float = 180.0

# 待ちの間に射程で解放されない長さ。既定の 400.0 と別に取る
const BULLET_MAX_DISTANCE: float = 1024.0

# 待ちの間に必ず超える短さ。射程が `stats` から流れていることを解放で示す
const SHORT_MAX_DISTANCE: float = 8.0

# 12 フレーム。既定の 0.8 と別に取り、押しっぱなしで駆動するフレーム数より長くする:
# 短いと空の枠のケースへ副武器の弾が混ざり、拡散弾の不在を観測できない
const SECONDARY_CHARGE_TIME: float = 0.75

# 拡散の発数。仕様の定数であり、実装から読まない
const SPREAD_SIZE: int = 3

# 実装の定数を参照しない: 参照するとアサーションが自明になり、文言の退行を検出できない
const MISSING_PROJECTILE_SCENE_ERROR: String = (
	"Player: projectile_scene が設定されていない。弾を生成せずに返る"
)

# 充電が満ちる 12 フレームに 1 フレームの余裕を足す: ちょうど 12 だと、1 フレーム分の
# 割り算を 12 回足した値が満充電に届かないことがあり、発射のフレームが揺れる
const SECONDARY_HOLD_FRAMES: int = 13

# 移動も上下の狙いも与えないときの射撃方向。`fired` の引数を厳密に比較するために持つ
const RIGHT: Vector2i = Vector2i(1, 0)

# レイヤ 3・マスクは 1 と 4。生の 4 と 9 を書かない: どのレイヤを意味するのかがテストから
# 読めなくなる
const SPREAD_COLLISION_LAYER: int = 1 << 2
const SPREAD_COLLISION_MASK: int = (1 << 0) | (1 << 3)

# [move_x, aim_y]。環の折り返しをまたぐ方向を含める: 折り返さない方向だけだと、環を
# 成分の計算で組み立て直す実装が素通りする。(1, 0) は手前が、(1, -1) は先が折り返す
const AIM_CASES: Array = [
	[0.0, 0.0],
	[1.0, -1.0],
	[0.0, -1.0],
	[-1.0, 0.0],
]

# 空の枠へ与える押下の列。縁を何度も立て、押しっぱなしのフレームも混ぜる
const EMPTY_SLOT_FRAMES: Array[bool] = [true, false, true, true, false, true]

# 数フレーム(60 Hz で 1 フレーム約 17 ms)に対して余裕を取る: 遅いランナーでも物理フレームを
# 消化させる
const WAIT_MILLIS: int = 500

const TOLERANCE: Vector2 = Vector2(0.001, 0.001)

# ツリーへ載せた `Player` の入力をテスト側から動かす。lambda は使わない
const HELD_INPUT_SOURCE: String = """
extends RefCounted

var secondary_held: bool = false


func read() -> PlayerCommand:
	var command: PlayerCommand = PlayerCommand.new()
	command.secondary_held = secondary_held
	return command
"""


func test_the_values_used_here_differ_from_the_defaults() -> void:
	# 既定値と一致する値を渡していないことを先に固定する: 既定のままだと、値を直書きした
	# 実装も緑になる(要件 8.6 の担保)
	var stats: PlayerStats = auto_free(PlayerStats.new())

	assert_int(ABILITY_USES).is_not_equal(stats.ability_uses)
	assert_float(ABILITY_COOLDOWN).is_not_equal(stats.ability_cooldown)
	assert_int(ABILITY_DAMAGE).is_not_equal(stats.ability_damage)
	assert_float(ABILITY_BULLET_SPEED).is_not_equal(stats.ability_bullet_speed)
	assert_float(BULLET_MAX_DISTANCE).is_not_equal(stats.bullet_max_distance)
	assert_float(SECONDARY_CHARGE_TIME).is_not_equal(stats.secondary_charge_time)

	# 能力の値が他の枠の値と重ならないこと: 重なると、別の項目を渡す変異が落ちない
	var other_damages: Array[int] = [stats.primary_damage, stats.secondary_damage]
	assert_array(other_damages).not_contains([ABILITY_DAMAGE])

	var other_speeds: Array[float] = [stats.primary_bullet_speed, stats.secondary_bullet_speed]
	assert_array(other_speeds).not_contains([ABILITY_BULLET_SPEED])

	var distances: Array[float] = [BULLET_MAX_DISTANCE, SHORT_MAX_DISTANCE]
	assert_array(distances).not_contains([ABILITY_BULLET_SPEED])


func test_the_periods_used_here_are_whole_numbers_of_frames() -> void:
	# フレーム数で境界を数える前提を固定する: 崩れると、境界のケースが実装ではなく
	# 丸め誤差を観測する
	assert_float(ABILITY_COOLDOWN).is_equal(ABILITY_COOLDOWN_FRAMES * FRAME_DELTA)


func test_the_third_slot_spawns_three_projectiles_on_the_frame_it_fires() -> void:
	# 縁の立つフレームでだけ 3 発を生成すること。押しっぱなしのフレームとクールダウン中の
	# 縁では 0 発であり、クールダウンが明ければ再び 3 発になる(分岐の両側)
	var player: Player = _create_player()
	var container: Node = player.get_parent()
	player.grant_ability()

	var spawned: Array[int] = _spawns_per_frame(player, container, [true, true, false, true])
	var released: Array[bool] = _repeat_frames(false, ABILITY_COOLDOWN_FRAMES)
	released.append(true)
	var after_cooldown: Array[int] = _spawns_per_frame(player, container, released)

	assert_array(spawned).is_equal([SPREAD_SIZE, 0, 0, 0])
	assert_array(after_cooldown).is_equal(_repeat_spawns(0, ABILITY_COOLDOWN_FRAMES, SPREAD_SIZE))
	assert_int(player.ability_slot.remaining_uses).is_equal(ABILITY_USES - 2)


func test_the_spread_flies_in_the_resolver_directions_at_the_ability_speed() -> void:
	# 3 発の方向が `SpreadResolver.resolve()` の 3 要素と同じ順で一致し、速さが
	# `ability_bullet_speed` であること。方向は弾の変位でしか読めないため、発射を
	# すべて終えてからツリーへ載せて実フレームで飛ばす
	var player: Player = _create_player()
	var container: Node = player.get_parent()
	var projectiles: Array[Projectile] = []
	var expected_directions: Array[Vector2i] = []

	for aim_case: Array in AIM_CASES:
		var move_x: float = aim_case[0]
		var aim_y: float = aim_case[1]
		var context: String = "case=%s" % [aim_case]
		var spawned: Array[Projectile] = _fire_spread(player, container, move_x, aim_y)

		assert_int(spawned.size()).append_failure_message(context).is_equal(SPREAD_SIZE)
		projectiles.append_array(spawned)
		# 期待する 3 方向を `SpreadResolver` から取る: テスト側で隣を並べ直すと、`Player` が
		# 独自に環を組み立てていても一致してしまう
		var direction: Vector2i = AimResolver.resolve(move_x, aim_y, player.facing, true)
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
		var travelled: float = ABILITY_BULLET_SPEED / float(Engine.physics_ticks_per_second) * frames
		var expected: Vector2 = Vector2(expected_directions[index]).normalized() * travelled
		assert_vector(projectile.position).append_failure_message(context).is_equal_approx(
			expected, TOLERANCE
		)


func test_the_spread_projectiles_carry_the_ability_damage() -> void:
	# 3 発すべてが `ability_damage` を持つこと。主武器・副武器の値を渡す変異は、値を
	# 既定と別に取ってあるためここで落ちる
	var player: Player = _create_player()
	var spawned: Array[Projectile] = _fire_spread(player, player.get_parent(), 0.0, 0.0)

	assert_int(spawned.size()).is_equal(SPREAD_SIZE)
	var damages: Array[int] = []
	for projectile: Projectile in spawned:
		damages.append(projectile.damage)
	assert_array(damages).is_equal([ABILITY_DAMAGE, ABILITY_DAMAGE, ABILITY_DAMAGE])


func test_the_spread_projectiles_are_released_after_the_bullet_max_distance() -> void:
	# 射程に `bullet_max_distance` が渡ること。短い射程で解放される側と、長い射程で
	# 同じ待ちの間は解放されない側を対で見る: 片側だけだと、射程に別の値を渡す変異が
	# どちらかのケースで緑になる
	var near_player: Player = _create_player()
	near_player.stats.bullet_max_distance = SHORT_MAX_DISTANCE
	var near_container: Node = near_player.get_parent()
	var near_spawned: Array[Projectile] = _fire_spread(near_player, near_container, 0.0, 0.0)

	var far_player: Player = _create_player()
	var far_container: Node = far_player.get_parent()
	var far_spawned: Array[Projectile] = _fire_spread(far_player, far_container, 0.0, 0.0)

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


func test_the_spread_projectiles_are_added_to_the_parent_of_the_player() -> void:
	# 自身の子にすると、弾がプレイヤーと一緒に動いてしまう。親の子が 3 つ増えることと、
	# 自身の子が増えないことを対で見る
	var player: Player = _create_player()
	var container: Node = player.get_parent()
	var player_children_before: int = player.get_child_count()
	var container_children_before: int = container.get_child_count()

	var spawned: Array[Projectile] = _fire_spread(player, container, 0.0, 0.0)

	assert_int(spawned.size()).is_equal(SPREAD_SIZE)
	assert_int(player.get_child_count()).is_equal(player_children_before)
	assert_int(container.get_child_count()).is_equal(container_children_before + SPREAD_SIZE)
	for index: int in spawned.size():
		var context: String = "index=%d" % index
		assert_object(spawned[index].get_parent()).append_failure_message(context).is_same(container)


func test_the_spread_projectiles_are_added_to_the_player_when_it_has_no_parent() -> void:
	# 親が無いときだけ自身へ載せる(既存の 1 発の生成と同じ扱い)
	var player: Player = _create_orphan_player()
	var children_before: int = player.get_child_count()

	var spawned: Array[Projectile] = _fire_spread(player, player, 0.0, 0.0)

	assert_int(spawned.size()).is_equal(SPREAD_SIZE)
	assert_int(player.get_child_count()).is_equal(children_before + SPREAD_SIZE)


func test_the_spread_projectiles_keep_the_collision_layers_of_the_projectile() -> void:
	# 当たり判定は `projectile.tscn` の流用によって満たす。生成の経路で書き換える実装は
	# ここで落ちる
	var player: Player = _create_player()

	var spawned: Array[Projectile] = _fire_spread(player, player.get_parent(), 0.0, 0.0)

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


func test_the_empty_slot_spawns_nothing_and_reports_no_error() -> void:
	# 枠が空の間は、副武器のボタンを何度押しても拡散弾が出ず、報告も出ないこと(要件 7.4)。
	# 空の枠での押下は異常ではない
	var player: Player = _create_player()
	var container: Node = player.get_parent()
	var children_before: int = container.get_child_count()
	var press_frames: Callable = func() -> void: _advance(player, EMPTY_SLOT_FRAMES)

	await assert_error(press_frames).is_success()

	assert_int(container.get_child_count()).is_equal(children_before)
	assert_bool(player.ability_slot.is_empty).is_true()

	# 観測が空振りしていないこと: 能力を得れば同じ押下の列で弾が出る
	player.grant_ability()
	_advance(player, [false, true])

	assert_int(container.get_child_count()).is_equal(children_before + SPREAD_SIZE)


func test_the_spread_is_fired_while_real_physics_frames_drive_the_player() -> void:
	# 同期で駆動するヘルパだけに頼らない: エンジンの物理フレームで `_physics_process` を
	# 通しても 3 発が出ること。押しっぱなしのままなので縁は 1 度きりであり、待ちの長さに
	# 関わらず発射は 1 回に収まる
	var player: Player = _create_player()
	var container: Node = player.get_parent()
	var input_stub: RefCounted = _create_input_stub()
	player.input_source = Callable(input_stub, "read")
	player.grant_ability()
	var children_before: int = container.get_child_count()
	input_stub.secondary_held = true

	add_child(container)
	await await_millis(WAIT_MILLIS)

	assert_int(container.get_child_count()).is_equal(children_before + SPREAD_SIZE)
	assert_int(player.ability_slot.remaining_uses).is_equal(ABILITY_USES - 1)
	for index: int in range(children_before, container.get_child_count()):
		var projectile: Projectile = container.get_child(index)
		var context: String = "index=%d" % index
		# 弾が実フレームで進んでいること: 進んでいなければツリーの外での駆動と区別できない
		assert_int(projectile.frames_moved).append_failure_message(context).is_greater(0)


func test_the_third_slot_emits_ability_fired_once_and_never_fired() -> void:
	# 撃ったフレームでだけ `ability_fired` が 1 回発火し、そのフレームで `fired` が 0 回で
	# あること。押しっぱなしのフレームとクールダウン中の縁では 0 回であり、クールダウンが
	# 明ければ再び 1 回になる(1 度きりしか発火しない変異は後半の列で落ちる)
	var player: Player = _create_player()
	player.grant_ability()
	var ability_records: Array = _record_ability_fired(player)
	var fired_records: Array = _record_fired(player)

	var counts: Array = _emits_per_frame(
		player, ability_records, fired_records, _spread_commands([true, true, false, true])
	)
	var released: Array[bool] = _repeat_frames(false, ABILITY_COOLDOWN_FRAMES)
	released.append(true)
	var after_cooldown: Array = _emits_per_frame(
		player, ability_records, fired_records, _spread_commands(released)
	)

	assert_array(counts).is_equal([[1, 0], [0, 0], [0, 0], [0, 0]])
	assert_array(after_cooldown).is_equal(_repeat_emits(ABILITY_COOLDOWN_FRAMES, [1, 0]))


func test_the_primary_weapon_emits_fired_and_not_ability_fired() -> void:
	# 分岐のもう片側。主武器で撃ったフレームで `fired` が 1 回・`ability_fired` が 0 回で
	# あること。枠を占有させたまま撃つ: 占有中の発射をすべて第 3 の枠として扱う変異が落ちる
	var player: Player = _create_player()
	player.grant_ability()
	var ability_records: Array = _record_ability_fired(player)
	var fired_records: Array = _record_fired(player)

	var counts: Array = _emits_per_frame(
		player, ability_records, fired_records, [_primary_command()]
	)

	assert_array(counts).is_equal([[0, 1]])
	assert_array(fired_records).is_equal([[RIGHT, false]])


func test_the_secondary_weapon_emits_fired_and_not_ability_fired() -> void:
	# 分岐のもう片側(副武器)。枠が空のまま充電して離したフレームで `fired` が 1 回・
	# `ability_fired` が 0 回であること
	var player: Player = _create_player()
	var ability_records: Array = _record_ability_fired(player)
	var fired_records: Array = _record_fired(player)
	var frames: Array[bool] = _repeat_frames(true, SECONDARY_HOLD_FRAMES)
	frames.append(false)

	var counts: Array = _emits_per_frame(
		player, ability_records, fired_records, _spread_commands(frames)
	)

	assert_array(counts).is_equal(_repeat_emits(SECONDARY_HOLD_FRAMES, [0, 1]))
	assert_array(fired_records).is_equal([[RIGHT, true]])


func test_the_ability_fired_directions_match_the_spread_in_order() -> void:
	# `directions` が生成した 3 発と同じ順であること。環の折り返しをまたぐ方向を含む
	# 4 通りで回す: 1 方向だけだと並びを取り違える実装が素通りする
	var player: Player = _create_player()
	var container: Node = player.get_parent()
	var records: Array = _record_ability_fired(player)
	var emitted: Array = []
	var expected: Array = []

	for aim_case: Array in AIM_CASES:
		var move_x: float = aim_case[0]
		var aim_y: float = aim_case[1]
		var context: String = "case=%s" % [aim_case]
		var records_before: int = records.size()
		var spawned: Array[Projectile] = _fire_spread(player, container, move_x, aim_y)

		# 同じフレームで 3 発が出ていること: 生成と切り離して発火する変異を落とす
		assert_int(spawned.size()).append_failure_message(context).is_equal(SPREAD_SIZE)
		assert_int(records.size() - records_before).append_failure_message(context).is_equal(1)
		emitted.append(records[records_before])
		# 期待する 3 方向を `SpreadResolver` から取る: テスト側で隣を並べ直すと、`Player` が
		# 独自に環を組み立てていても一致してしまう
		var direction: Vector2i = AimResolver.resolve(move_x, aim_y, player.facing, true)
		expected.append(SpreadResolver.resolve(direction))

	assert_int(expected.size()).is_equal(AIM_CASES.size())
	assert_array(emitted).is_equal(expected)


func test_the_third_slot_without_a_projectile_scene_reports_and_keeps_the_spent_use() -> void:
	# 弾を生成できないケース。報告が出ること・弾が 0 発・`ability_fired` が 0 回・残り回数が
	# 1 減ったままであることを同じケースで見る。減算を取り消す変異は最後の 1 つだけが落とす。
	# `push_error` の回数は仕様が定めていないためアサーションしない
	var player: Player = _create_player()
	var container: Node = player.get_parent()
	player.projectile_scene = null
	player.grant_ability()
	var records: Array = _record_ability_fired(player)
	var children_before: int = container.get_child_count()
	var fire_frames: Callable = func() -> void: _advance(player, [false, true])

	await assert_error(fire_frames).is_push_error(MISSING_PROJECTILE_SCENE_ERROR)

	assert_int(container.get_child_count()).is_equal(children_before)
	assert_array(records).is_empty()
	assert_int(player.ability_slot.remaining_uses).is_equal(ABILITY_USES - 1)


## 第 3 の枠へ能力を与え直してから 1 回撃たせ、そのフレームに増えた子を返す。
##
## 与え直すのはクールダウンを明けた状態へ戻すためであり、方向ごとの発射を独立させる
func _fire_spread(
	player: Player, container: Node, move_x: float, aim_y: float
) -> Array[Projectile]:
	player.grant_ability()
	# 離してから押す: 縁が立たないと第 3 の枠は撃たない
	player.apply_command(_spread_command(false, move_x, aim_y), FRAME_DELTA, true)

	var children_before: int = container.get_child_count()
	player.apply_command(_spread_command(true, move_x, aim_y), FRAME_DELTA, true)

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
		player.apply_command(_spread_command(held, 0.0, 0.0), FRAME_DELTA, true)
		spawns.append(container.get_child_count() - before)
	return spawns


## 弾の数を観測せずにフレームだけ進める
func _advance(player: Player, held_frames: Array[bool]) -> void:
	for held: bool in held_frames:
		player.apply_command(_spread_command(held, 0.0, 0.0), FRAME_DELTA, true)


## 1 フレームずつ進め、各フレームの `[ability_fired の回数, fired の回数]` を並べて返す。
##
## 1 本のアサーションに畳まない: 畳むと、発火のフレームが 1 つずれる変異が落ちない
func _emits_per_frame(
	player: Player, ability_records: Array, fired_records: Array, commands: Array
) -> Array:
	var counts: Array = []
	for command: PlayerCommand in commands:
		var ability_before: int = ability_records.size()
		var fired_before: int = fired_records.size()
		player.apply_command(command, FRAME_DELTA, true)
		counts.append(
			[ability_records.size() - ability_before, fired_records.size() - fired_before]
		)
	return counts


## 発火した順に `directions` を控える。発火の回数と方向の並びを厳密に比較できる
func _record_ability_fired(player: Player) -> Array:
	var records: Array = []
	var record: Callable = func(directions: Array[Vector2i]) -> void: records.append(directions)
	player.ability_fired.connect(record)
	return records


## 発火した順に `[direction, is_secondary]` を控える
func _record_fired(player: Player) -> Array:
	var records: Array = []
	var record: Callable = func(direction: Vector2i, is_secondary: bool) -> void:
		records.append([direction, is_secondary])
	player.fired.connect(record)
	return records


## 副武器の押下の列を `PlayerCommand` の列にする
func _spread_commands(held_frames: Array[bool]) -> Array:
	var commands: Array = []
	for held: bool in held_frames:
		commands.append(_spread_command(held, 0.0, 0.0))
	return commands


## 主武器だけを押した 1 フレーム分の入力
func _primary_command() -> PlayerCommand:
	var command: PlayerCommand = auto_free(PlayerCommand.new())
	command.primary_held = true
	return command


## `count` フレーム分の `[0, 0]` に `last` を足した列を返す
func _repeat_emits(count: int, last: Array) -> Array:
	var expected: Array = []
	for frame: int in count:
		expected.append([0, 0])
	expected.append(last)
	return expected


## `held` を `count` フレーム分並べて返す
func _repeat_frames(held: bool, count: int) -> Array[bool]:
	var frames: Array[bool] = []
	for frame: int in count:
		frames.append(held)
	return frames


## `count` フレーム分の `spawns` に `last` を足した列を返す
func _repeat_spawns(spawns: int, count: int, last: int) -> Array[int]:
	var expected: Array[int] = []
	for frame: int in count:
		expected.append(spawns)
	expected.append(last)
	return expected


func _spread_command(secondary_held: bool, move_x: float, aim_y: float) -> PlayerCommand:
	var command: PlayerCommand = auto_free(PlayerCommand.new())
	command.secondary_held = secondary_held
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
	stats.secondary_charge_time = SECONDARY_CHARGE_TIME
	stats.bullet_max_distance = BULLET_MAX_DISTANCE
	stats.ability_uses = ABILITY_USES
	stats.ability_cooldown = ABILITY_COOLDOWN
	stats.ability_damage = ABILITY_DAMAGE
	stats.ability_bullet_speed = ABILITY_BULLET_SPEED
	player.stats = stats
	player.input_source = Callable(_create_input_stub(), "read")
	return player


## 既定では何も押していない入力源。ツリーへ載せるケースだけが `secondary_held` を動かす
func _create_input_stub() -> RefCounted:
	var stub_script: GDScript = GDScript.new()
	stub_script.source_code = HELD_INPUT_SOURCE
	stub_script.reload()
	return auto_free(stub_script.new())
