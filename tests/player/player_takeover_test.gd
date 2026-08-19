extends GdUnitTestSuite

const PLAYER_SCENE: PackedScene = preload("res://src/player/player.tscn")

const PLAYER_SOURCE_PATH: String = "res://src/player/player.gd"

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

# 充電が複数フレームかかる別の設定。1 フレームの充電では「満ちていない充電」を作れない:
# 押した最初のフレームで 1.0 に達してしまう
const PARTIAL_CHARGE_TIME: float = 0.1875
const PARTIAL_CHARGE_FRAMES: int = 3

# 占有が最短で終わるまでの長さ(5 フレーム)より長く取る: 短いと「クールダウンを超えない
# 占有」を作れず、要件 5.7 の片側しか観測できない
const LONG_SECONDARY_COOLDOWN: float = 0.625
const LONG_SECONDARY_COOLDOWN_FRAMES: int = 10

const PRIMARY_INTERVAL: float = 0.375
const PRIMARY_INTERVAL_FRAMES: int = 6

# 主武器の間隔を 2 周期またぐ長さ: 1 周期だけだと、発火が 1 回に畳まれてフレームのずれが
# 見えない
const PRIMARY_OBSERVED_FRAMES: int = 13

# 占有の長い側と短い側へ同じ列を与えるために切り出す。副武器のクールダウンが明けるのを
# 待ってから 1 フレームの充電で撃つところまでを含む
const FRAMES_AFTER_TAKEOVER: Array[bool] = [true, false, false, false, true, true, false]

# 占有を長く保つために離しておくフレーム数。第 3 の枠のクールダウン(4 フレーム)より長く、
# かつ占有の長さが `LONG_SECONDARY_COOLDOWN` を超える値
const LONG_TAKEOVER_RELEASED_FRAMES: int = 13

# `charge_ratio` / `is_cooling_down` への代入を捕らえる。比較(`==`・`!=`)は捕らえない
const SECONDARY_STATE_ASSIGNMENT_PATTERN: String = (
	"(charge_ratio|is_cooling_down)\\s*[-+*/]?=[^=]"
)

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


func test_the_added_periods_differ_from_the_defaults_and_from_each_other() -> void:
	# 別の周期を持つ `Player` を足したぶんの前提を固定する: 既定のままだと値を直書きした
	# 実装も緑になり、周期どうしが重なると片方へもう片方を渡す変異が落ちない(要件 8.6)
	var stats: PlayerStats = auto_free(PlayerStats.new())

	assert_float(PARTIAL_CHARGE_TIME).is_not_equal(stats.secondary_charge_time)
	assert_float(LONG_SECONDARY_COOLDOWN).is_not_equal(stats.secondary_cooldown)
	assert_float(PRIMARY_INTERVAL).is_not_equal(stats.primary_interval)

	assert_float(PARTIAL_CHARGE_TIME).is_equal(PARTIAL_CHARGE_FRAMES * FRAME_DELTA)
	assert_float(LONG_SECONDARY_COOLDOWN).is_equal(LONG_SECONDARY_COOLDOWN_FRAMES * FRAME_DELTA)
	assert_float(PRIMARY_INTERVAL).is_equal(PRIMARY_INTERVAL_FRAMES * FRAME_DELTA)

	var periods: Array[float] = [
		SECONDARY_CHARGE_TIME,
		SECONDARY_COOLDOWN,
		ABILITY_COOLDOWN,
		PARTIAL_CHARGE_TIME,
		LONG_SECONDARY_COOLDOWN,
		PRIMARY_INTERVAL,
	]
	var distinct: Dictionary = {}
	for period: float in periods:
		distinct[period] = true
	assert_int(distinct.size()).is_equal(periods.size())


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


func test_the_full_charge_fires_on_the_frame_the_slot_becomes_occupied() -> void:
	# 充電が 1.0 に達した状態で占有が始まったフレームに、副武器の弾が 1 発出ること
	# (要件 5.5)。切り替えを「ボタンを離した」として扱うことの帰結であり、占有中に
	# 副武器を凍結する実装ではこの 1 発が出ない。満ちていない側と対で見る
	var player: Player = _create_player()
	var records: Array = _record_fired(player)

	var while_empty: Array[int] = _shots_per_frame(player, records, [true])
	player.grant_ability()
	var on_takeover: Array[int] = _shots_per_frame(player, records, [true])

	assert_array(while_empty).is_equal([0])
	assert_array(on_takeover).is_equal([1])
	assert_array(records).is_equal([[RIGHT, true]])
	# 押しっぱなしの入力が縁として数えられていないこと: この 1 発が枠の消費の副産物でない
	assert_int(player.ability_slot.remaining_uses).is_equal(ABILITY_USES)


func test_the_partial_charge_is_dropped_when_the_slot_becomes_occupied() -> void:
	# 充電が 1.0 未満のまま占有が始まったフレームには弾が出ず、充電が捨てられること
	# (要件 5.6)。捨てずに持ち越す実装(占有中に副武器を凍結する形を含む)は、占有が
	# 終わったあと 3 フレームに足りない充電で撃ててしまう
	var player: Player = _create_player(PARTIAL_CHARGE_TIME)
	var records: Array = _record_fired(player)

	var while_empty: Array[int] = _shots_per_frame(player, records, [true, true])
	player.grant_ability()
	var on_takeover: Array[int] = _shots_per_frame(player, records, [true])
	# 離す → 押す → 3 フレーム離す → 押す。第 3 の枠のクールダウンを跨いで 2 回撃ち、
	# 占有を終わらせる
	var while_occupied: Array[int] = _shots_per_frame(
		player, records, [false, true, false, false, false, true]
	)
	var after_takeover: Array[int] = _shots_per_frame(player, records, [true, false])

	assert_array(while_empty).is_equal([0, 0])
	assert_array(on_takeover).is_equal([0])
	assert_array(while_occupied).is_equal([0, 0, 0, 0, 0, 0])
	assert_array(after_takeover).is_equal([0, 0])
	assert_bool(player.ability_slot.is_empty).is_true()
	assert_array(records).is_empty()

	# 観測が空振りしていないこと: 0 から数え直して 3 フレーム充電すれば撃てる
	var refilled: Array[int] = _shots_per_frame(player, records, [true, true, true, false])

	assert_array(refilled).is_equal([0, 0, 0, 1])


func test_the_secondary_cooldown_runs_out_while_the_slot_is_occupied() -> void:
	# 占有が副武器のクールダウンより長く続いたとき、占有が終わった直後の充電で撃てること
	# (要件 5.7)。占有中に副武器を凍結する実装はクールダウンが実時間で進まず、ここで
	# 撃てない。クールダウンを超えない占有の側と対で見る
	var player: Player = _create_player(SECONDARY_CHARGE_TIME, LONG_SECONDARY_COOLDOWN)
	var records: Array = _record_fired(player)

	var while_empty: Array[int] = _shots_per_frame(player, records, [true, false])
	player.grant_ability()
	var occupied_frames: int = _end_the_takeover(player, LONG_TAKEOVER_RELEASED_FRAMES)
	var shots_after_grant: int = records.size()
	var after_takeover: Array[int] = _shots_per_frame(player, records, FRAMES_AFTER_TAKEOVER)

	assert_array(while_empty).is_equal([0, 1])
	# 占有が副武器のクールダウンより長いこと: 短いと裏側のケースと区別できない
	assert_int(occupied_frames).is_greater(LONG_SECONDARY_COOLDOWN_FRAMES)
	assert_int(shots_after_grant).is_equal(1)
	assert_array(after_takeover).is_equal([0, 1, 0, 0, 0, 0, 0])
	assert_bool(player.ability_slot.is_empty).is_true()


func test_the_secondary_cooldown_outlasts_a_short_occupation() -> void:
	# 占有が副武器のクールダウンより短いとき、占有が終わった直後の充電では撃てないこと
	# (要件 5.7 の裏側)。占有の開始や終了でクールダウンを捨てる実装はここで撃ててしまう
	var player: Player = _create_player(SECONDARY_CHARGE_TIME, LONG_SECONDARY_COOLDOWN)
	var records: Array = _record_fired(player)

	var while_empty: Array[int] = _shots_per_frame(player, records, [true, false])
	player.grant_ability()
	var occupied_frames: int = _end_the_takeover(player, ABILITY_COOLDOWN_FRAMES - 1)
	var shots_after_grant: int = records.size()
	var after_takeover: Array[int] = _shots_per_frame(player, records, FRAMES_AFTER_TAKEOVER)

	assert_array(while_empty).is_equal([0, 1])
	assert_int(occupied_frames).is_less(LONG_SECONDARY_COOLDOWN_FRAMES)
	assert_int(shots_after_grant).is_equal(1)
	# 残りのクールダウンが明けるまで撃てず、明けてから 1 フレームの充電で撃てる
	assert_array(after_takeover).is_equal([0, 0, 0, 0, 0, 0, 1])
	assert_bool(player.ability_slot.is_empty).is_true()


func test_the_primary_weapon_fires_on_the_same_frames_while_the_slot_is_occupied() -> void:
	# 主武器の発火のフレームが占有の有無で変わらないこと(要件 5.9)。占有の判定を主武器
	# にも及ぼす実装は、占有中の列がずれる
	var input_frames: Array[bool] = _repeat_frames(true, PRIMARY_OBSERVED_FRAMES)
	var empty_player: Player = _create_player()
	var empty_records: Array = _record_fired(empty_player)
	var occupied_player: Player = _create_player()
	occupied_player.grant_ability()
	var occupied_records: Array = _record_fired(occupied_player)

	var while_empty: Array[int] = _primary_shots_per_frame(
		empty_player, empty_records, input_frames
	)
	var while_occupied: Array[int] = _primary_shots_per_frame(
		occupied_player, occupied_records, input_frames
	)

	assert_array(while_occupied).is_equal(while_empty)
	# 観測が空振りしていないこと: 主武器が間隔どおりに 3 回出ていること
	assert_array(while_empty).is_equal([1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1])
	assert_bool(empty_player.ability_slot.is_empty).is_true()
	assert_bool(occupied_player.ability_slot.is_empty).is_false()


func test_the_player_source_does_not_assign_to_the_secondary_weapon_state() -> void:
	# 充電とクールダウンを動かすのは `SecondaryWeapon.update()` だけであること(要件 5.10)。
	# 静的な検査は等価な別解を素通りさせるため、振る舞い側の対を
	# `test_the_partial_charge_is_dropped_when_the_slot_becomes_occupied`(充電が捨てられる)
	# と `test_the_secondary_cooldown_runs_out_while_the_slot_is_occupied`(クールダウンが
	# 実時間で進む)が担う
	var regex: RegEx = auto_free(RegEx.create_from_string(SECONDARY_STATE_ASSIGNMENT_PATTERN))
	var source: String = FileAccess.get_file_as_string(PLAYER_SOURCE_PATH)

	assert_object(regex.search(source)).is_null()

	# 検査が空振りしていないこと: 代入の形は捕らえ、比較の形は捕らえない
	assert_object(regex.search("	_secondary_weapon.charge_ratio = 0.0")).is_not_null()
	assert_object(regex.search("	_secondary_weapon.is_cooling_down = false")).is_not_null()
	assert_object(regex.search("	if _secondary_weapon.is_cooling_down == true:")).is_null()


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


## 主武器を押しっぱなしにして 1 フレームずつ進め、そのフレームに出た主武器の発射の回数を
## 並べて返す。副武器の発射は数えない
func _primary_shots_per_frame(
	player: Player, records: Array, held_frames: Array[bool]
) -> Array[int]:
	var shots: Array[int] = []
	for held: bool in held_frames:
		var before: int = records.size()
		player.apply_command(_command(true, held), FRAME_DELTA, true)
		shots.append(_count_primary(records, before))
	return shots


## 押す → `released` フレーム離す → 押す、で第 3 の枠を 2 回撃ち切って占有を終わらせる。
## 駆動した占有中のフレーム数を返す
func _end_the_takeover(player: Player, released: int) -> int:
	var frames: Array[bool] = [true]
	frames.append_array(_repeat_frames(false, released))
	frames.append(true)
	_advance(player, frames)
	return frames.size()


## `held` を `count` フレーム分並べて返す
func _repeat_frames(held: bool, count: int) -> Array[bool]:
	var frames: Array[bool] = []
	for frame: int in count:
		frames.append(held)
	return frames


## 副武器の発射を観測せずにフレームだけ進める。回数をフレームごとに数えるのは
## `_shots_per_frame()` の役目であり、ここでは発火の有無を固定しない
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


## `from` 番目以降に控えた発火のうち、主武器のものを数える
func _count_primary(records: Array, from: int) -> int:
	var shots: int = 0
	for index: int in range(from, records.size()):
		if not records[index][1]:
			shots += 1
	return shots


## 発火した順に `[direction, is_secondary]` を控える
func _record_fired(player: Player) -> Array:
	var records: Array = []
	var record: Callable = func(direction: Vector2i, is_secondary: bool) -> void:
		records.append([direction, is_secondary])
	player.fired.connect(record)
	return records


## 周期を引数で受け取る: 1 フレームの充電では「満ちていない充電」を、2 フレームの
## クールダウンでは「占有がクールダウンを超えない列」をそれぞれ作れない
func _create_player(
	charge_time: float = SECONDARY_CHARGE_TIME, cooldown: float = SECONDARY_COOLDOWN
) -> Player:
	var player: Player = auto_free(PLAYER_SCENE.instantiate())
	var stats: PlayerStats = auto_free(PlayerStats.new())
	stats.primary_interval = PRIMARY_INTERVAL
	stats.secondary_charge_time = charge_time
	stats.secondary_cooldown = cooldown
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
	return _command(false, secondary_held)


func _command(primary_held: bool, secondary_held: bool) -> PlayerCommand:
	var command: PlayerCommand = auto_free(PlayerCommand.new())
	command.primary_held = primary_held
	command.secondary_held = secondary_held
	return command
