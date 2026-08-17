extends GdUnitTestSuite

const PLAYER_SCENE: PackedScene = preload("res://src/player/player.tscn")

# 2 進で厳密に表せる値を使う: 累積の丸め誤差でフレームの境界が揺れると、1 フレーム単位の
# 契約をフレーム数で数えられない
const FRAME_DELTA: float = 0.0625

# 充電を 1 フレームちょうどに取る: 副武器へ何を渡したかは非公開であり、発射の出る
# フレームでしか読めない。1 フレームで満ちる充電にすると「そのフレームに真を渡したか」が
# 次のフレームの発射の有無へそのまま現れる
const SECONDARY_CHARGE_TIME: float = FRAME_DELTA

const SECONDARY_COOLDOWN: float = 0.125
const SECONDARY_COOLDOWN_FRAMES: int = 2

const ABILITY_COOLDOWN: float = 0.25
const ABILITY_COOLDOWN_FRAMES: int = 4

# 既定の 3 を使わない。2 回撃てば空になる長さに取る: 「空 → 占有 → 空」を 1 本の列で通せる
const ABILITY_USES: int = 2

const RIGHT: Vector2i = Vector2i(1, 0)

# 数フレーム(60 Hz で 1 フレーム約 17 ms)に対して余裕を取る: 遅いランナーでも物理フレームを
# 消化させる
const WAIT_MILLIS: int = 500

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
	# 実装も緑になる(要件 8.6)
	var stats: PlayerStats = auto_free(PlayerStats.new())

	assert_float(SECONDARY_CHARGE_TIME).is_not_equal(stats.secondary_charge_time)
	assert_float(SECONDARY_COOLDOWN).is_not_equal(stats.secondary_cooldown)
	assert_float(ABILITY_COOLDOWN).is_not_equal(stats.ability_cooldown)
	assert_int(ABILITY_USES).is_not_equal(stats.ability_uses)

	# 副武器の周期と第 3 の枠の周期を別に取る: 一致していると、片方へもう片方を渡す変異が
	# 落ちない
	var secondary_periods: Array[float] = [SECONDARY_CHARGE_TIME, SECONDARY_COOLDOWN]
	assert_array(secondary_periods).not_contains([ABILITY_COOLDOWN])


func test_the_periods_used_here_are_whole_numbers_of_frames() -> void:
	# フレーム数で境界を数える前提を固定する: 崩れると、境界のケースが実装ではなく
	# 丸め誤差を観測する
	assert_float(ABILITY_COOLDOWN).is_equal(ABILITY_COOLDOWN_FRAMES * FRAME_DELTA)
	assert_float(SECONDARY_COOLDOWN).is_equal(SECONDARY_COOLDOWN_FRAMES * FRAME_DELTA)
	# 充電が 1 フレームちょうどであること: 要件 5.11 の観測手順の前提そのもの
	assert_float(SECONDARY_CHARGE_TIME).is_equal(FRAME_DELTA)


func test_the_empty_slot_passes_the_secondary_held_through() -> void:
	# 空のフレームでは `cmd.secondary_held` がそのまま副武器へ渡ること(要件 5.1)。
	# 占有中のフレームのケース(5.2)と対で見る
	var player: Player = _create_player()
	var records: Array = _record_fired(player)

	var shots: Array[int] = _shots_per_frame(player, records, [true, true, true, false])

	assert_array(shots).is_equal([0, 0, 0, 1])
	assert_bool(player.ability_slot.is_empty).is_true()
	assert_array(records).is_equal([[RIGHT, true]])


func test_the_occupied_slot_gives_the_secondary_weapon_false() -> void:
	# 空のケースと同じ入力の列を占有中に与えて、副武器の弾が出ないこと(要件 5.2・5.8)。
	# 充電は占有の開始の時点で 0 であり、5.5 の代償の 1 発は絡まない
	var player: Player = _create_player()
	player.grant_ability()
	var records: Array = _record_fired(player)

	var shots: Array[int] = _shots_per_frame(player, records, [true, true, true, false])

	assert_array(shots).is_equal([0, 0, 0, 0])
	assert_bool(player.ability_slot.is_empty).is_false()
	assert_array(records).is_empty()


func test_the_frame_of_the_last_use_gives_the_secondary_weapon_false() -> void:
	# 最後の 1 回を撃つフレーム N で押したままにし、N+1 で離す(要件 5.11)。占有の判定を
	# `ability_slot.update()` の後の `is_empty` で行う実装は、N で副武器へ真を渡して充電を
	# 満たし、N+1 の解放で 1 発を出す。1 つの押下が第 3 の枠と副武器の両方を動かす欠陥は
	# このケースだけが落とす
	var player: Player = _create_player()
	player.grant_ability()
	var records: Array = _record_fired(player)
	_spend_uses(player, ABILITY_USES - 1)
	assert_int(player.ability_slot.remaining_uses).is_equal(1)

	var shots: Array[int] = _shots_per_frame(player, records, [true, false])

	# 最後の 1 回がフレーム N で出たこと。出ていなければ観測が空振りする
	assert_int(player.ability_slot.remaining_uses).is_equal(0)
	assert_array(shots).is_equal([0, 0])


func test_the_slot_is_updated_on_the_frames_where_it_is_empty() -> void:
	# 空のフレームで `ability_slot.update()` を呼ばない実装は、押しっぱなしのボタンが取得の
	# 直後に縁と誤認され、残り回数が 1 つ減る(要件 5.3・1.11)。拡散弾の生成はまだ入って
	# いないため、観測は `ability_slot.remaining_uses` を直接読む形で行う
	var player: Player = _create_player()
	_advance(player, [true, true, true])

	player.grant_ability()
	_advance(player, [true, true, true])

	assert_int(player.ability_slot.remaining_uses).is_equal(ABILITY_USES)

	# 番人が空振りしていないこと: いったん離してから押せば縁として数えられる
	_advance(player, [false, true])
	assert_int(player.ability_slot.remaining_uses).is_equal(ABILITY_USES - 1)


func test_the_secondary_returns_after_the_slot_becomes_empty_again() -> void:
	# 1 本の列で「空 → 占有 → 空」を通す(要件 5.4)。占有が終わった次のフレーム以降で
	# 5.1 のケースが再び成立すること
	var player: Player = _create_player()
	var records: Array = _record_fired(player)

	var while_empty: Array[int] = _shots_per_frame(player, records, [true, false, false, false])
	player.grant_ability()
	# 押す → 3 フレーム離す → 押す。`AbilitySlot` のクールダウン(4 フレーム)を跨いで
	# 2 回撃ち、占有を終わらせる
	var while_occupied: Array[int] = _shots_per_frame(
		player, records, [true, false, false, false, true]
	)
	var after_empty: Array[int] = _shots_per_frame(player, records, [true, false])

	assert_array(while_empty).is_equal([0, 1, 0, 0])
	assert_array(while_occupied).is_equal([0, 0, 0, 0, 0])
	assert_array(after_empty).is_equal([0, 1])
	assert_bool(player.ability_slot.is_empty).is_true()
	assert_array(records).is_equal([[RIGHT, true], [RIGHT, true]])


func test_the_takeover_holds_while_real_physics_frames_drive_the_player() -> void:
	# 同期で駆動するヘルパだけに頼らない: エンジンの物理フレームで `_physics_process` を
	# 通しても、空の枠では副武器が撃て、占有中は撃てないこと
	var player: Player = _create_player()
	var input_stub: RefCounted = _create_input_stub()
	player.input_source = Callable(input_stub, "read")
	add_child(player.get_parent())
	var records: Array = _record_fired(player)

	input_stub.secondary_held = true
	await await_millis(WAIT_MILLIS)
	input_stub.secondary_held = false
	await await_millis(WAIT_MILLIS)

	assert_int(_count_secondary(records, 0)).is_equal(1)

	var shots_before_grant: int = records.size()
	player.grant_ability()
	input_stub.secondary_held = true
	await await_millis(WAIT_MILLIS)
	input_stub.secondary_held = false
	await await_millis(WAIT_MILLIS)

	assert_int(_count_secondary(records, shots_before_grant)).is_equal(0)
	# 枠が実フレームの入力で 1 回だけ減っていること: 減っていなければ占有の観測が空振りする
	assert_int(player.ability_slot.remaining_uses).is_equal(ABILITY_USES - 1)


## 1 フレームずつ進め、そのフレームに出た副武器の発射の回数を並べて返す。
##
## 副武器へ何を渡したかは非公開であり、発射の出るフレームでしか観測できない。1 本の
## アサーションに畳まず列で比較する: 畳むとフレームが 1 つずれる変異が落ちない
func _shots_per_frame(player: Player, records: Array, held_frames: Array[bool]) -> Array[int]:
	var shots: Array[int] = []
	for held: bool in held_frames:
		var before: int = records.size()
		player.apply_command(_secondary_command(held), FRAME_DELTA, true)
		shots.append(_count_secondary(records, before))
	return shots


## 副武器の発射を観測せずにフレームだけ進める。占有の開始のフレームに出る 1 発
## (要件 5.5)は本タスクの担当外であり、ここでは回数を固定しない
func _advance(player: Player, held_frames: Array[bool]) -> void:
	for held: bool in held_frames:
		player.apply_command(_secondary_command(held), FRAME_DELTA, true)


## `count` 回だけ第 3 の枠を撃たせる。戻ったときの状態は「離している・クールダウンは明け」
## であり、次の 1 フレームの押下がそのまま縁になる
func _spend_uses(player: Player, count: int) -> void:
	var released: Array[bool] = []
	for frame: int in ABILITY_COOLDOWN_FRAMES - 1:
		released.append(false)

	for use: int in count:
		var before: int = player.ability_slot.remaining_uses
		_advance(player, [true])
		var message: String = "use=%d" % use
		assert_int(player.ability_slot.remaining_uses).append_failure_message(message).is_equal(
			before - 1
		)
		_advance(player, released)


## `from` 番目以降に控えた発火のうち、副武器のものを数える
func _count_secondary(records: Array, from: int) -> int:
	var shots: int = 0
	for index: int in range(from, records.size()):
		if records[index][1]:
			shots += 1
	return shots


## 発火した順に `[direction, is_secondary]` を控える
func _record_fired(player: Player) -> Array:
	var records: Array = []
	var record: Callable = func(direction: Vector2i, is_secondary: bool) -> void:
		records.append([direction, is_secondary])
	player.fired.connect(record)
	return records


func _create_player() -> Player:
	var player: Player = auto_free(PLAYER_SCENE.instantiate())
	var stats: PlayerStats = auto_free(PlayerStats.new())
	stats.secondary_charge_time = SECONDARY_CHARGE_TIME
	stats.secondary_cooldown = SECONDARY_COOLDOWN
	stats.ability_uses = ABILITY_USES
	stats.ability_cooldown = ABILITY_COOLDOWN
	player.stats = stats
	player.input_source = Callable(_create_input_stub(), "read")

	# 弾の親になる容器を与える: 与えないと弾が `Player` 自身の子になり、木の形が変わる
	var container: Node2D = auto_free(Node2D.new())
	container.add_child(player)
	return player


## 既定では何も押していない入力源。ツリーへ載せたケースだけが `secondary_held` を動かす
func _create_input_stub() -> RefCounted:
	var stub_script: GDScript = GDScript.new()
	stub_script.source_code = HELD_INPUT_SOURCE
	stub_script.reload()
	return auto_free(stub_script.new())


func _secondary_command(secondary_held: bool) -> PlayerCommand:
	var command: PlayerCommand = auto_free(PlayerCommand.new())
	command.secondary_held = secondary_held
	return command
