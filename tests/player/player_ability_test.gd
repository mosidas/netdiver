extends GdUnitTestSuite

const PLAYER_SCENE: PackedScene = preload("res://src/player/player.tscn")

# 2 進で厳密に表せる値を使い、クールダウンを 1 フレームの整数倍に取る:
# 累積の誤差で境界の判定が揺れると、経過をフレーム数で数えられない
const FRAME_DELTA: float = 0.0625
const ABILITY_COOLDOWN: float = 0.25
const ABILITY_COOLDOWN_FRAMES: int = 4

# 能力の 4 項目をすべて既定(3・1.5・20・300.0)と別の値へ差し替える: 既定のままだと、
# `stats` を読まずに値を直書きした実装でも緑になる(要件 8.6)
const ABILITY_USES: int = 4
const ABILITY_DAMAGE: int = 27
const ABILITY_BULLET_SPEED: float = 180.0

# 2 回目の取得で `stats` を読み直していることを示す回数。1 回目とも既定とも別の値を取る
const REGRANT_USES: int = 6

# 能力のクールダウンと別の値を取る: 同じ値だと、`AbilitySlot` へ別の項目を渡す変異が
# 素通りする(要件 7.10)
const PRIMARY_INTERVAL: float = 0.5
const SECONDARY_CHARGE_TIME: float = 0.75
const SECONDARY_COOLDOWN: float = 1.0

# 数フレーム(60 Hz で 1 フレーム約 17 ms)に対して余裕を取る: 遅いランナーでも物理フレームを
# 消化させる
const WAIT_MILLIS: int = 500

# ツリーへ載せた `Player` が自前の入力で撃たないようにする。lambda は使わない
const NEUTRAL_INPUT_SOURCE: String = """
extends RefCounted


func read() -> PlayerCommand:
	return PlayerCommand.new()
"""


func test_the_values_used_here_differ_from_the_defaults() -> void:
	# 既定値と一致する値を渡していないことを先に固定する: 既定のままだと、値を直書きした
	# 実装も緑になる(要件 8.6)
	var stats: PlayerStats = auto_free(PlayerStats.new())

	assert_array([ABILITY_USES, REGRANT_USES]).not_contains([stats.ability_uses])
	assert_float(ABILITY_COOLDOWN).is_not_equal(stats.ability_cooldown)
	assert_int(ABILITY_DAMAGE).is_not_equal(stats.ability_damage)
	assert_float(ABILITY_BULLET_SPEED).is_not_equal(stats.ability_bullet_speed)

	# 他の周期とも別の値であること: 一致していると、`secondary_cooldown` や
	# `primary_interval` を `AbilitySlot` へ渡す変異が落ちない(要件 7.10)
	var other_periods: Array[float] = [
		PRIMARY_INTERVAL,
		SECONDARY_CHARGE_TIME,
		SECONDARY_COOLDOWN,
		stats.primary_interval,
		stats.secondary_charge_time,
		stats.secondary_cooldown,
	]
	assert_array(other_periods).not_contains([ABILITY_COOLDOWN])


func test_the_cooldown_used_here_is_a_whole_number_of_frames() -> void:
	# フレーム数で境界を数える前提を固定する: 崩れると、境界のケースが実装ではなく
	# 丸め誤差を観測する
	assert_float(ABILITY_COOLDOWN).is_equal(ABILITY_COOLDOWN_FRAMES * FRAME_DELTA)


func test_the_slot_exists_and_is_empty_before_any_grant() -> void:
	# 取得の前から観測点として読めること。7.5 が比較する「初期状態」はこの状態である
	var player: Player = _create_player()

	player.apply_command(_neutral_command(), FRAME_DELTA, true)

	assert_object(player.ability_slot).is_not_null()
	assert_int(player.ability_slot.remaining_uses).is_equal(0)
	assert_bool(player.ability_slot.is_empty).is_true()


func test_grant_ability_fills_the_slot_with_the_uses_from_stats() -> void:
	var player: Player = _create_player()

	player.grant_ability()

	assert_int(player.ability_slot.remaining_uses).is_equal(ABILITY_USES)
	assert_bool(player.ability_slot.is_empty).is_false()


func test_grant_ability_works_on_a_player_that_is_not_in_the_tree() -> void:
	# `_ready()` を通らない経路で `ability_slot` が null にならないこと(要件 7.9)。
	# 生成を `_ready()` に置く変異はこのケースだけが落とす
	var player: Player = _create_player()
	assert_bool(player.is_inside_tree()).is_false()

	player.grant_ability()

	assert_object(player.ability_slot).is_not_null()
	assert_int(player.ability_slot.remaining_uses).is_equal(ABILITY_USES)
	assert_bool(player.ability_slot.is_empty).is_false()


func test_the_granted_slot_survives_the_frames_that_follow_the_grant() -> void:
	# 取得を先に済ませてからフレームを進める: フレームの側で枠を作り直す実装は、取得した
	# 残り回数をここで捨てる
	var player: Player = _create_player()
	player.grant_ability()

	player.apply_command(_neutral_command(), FRAME_DELTA, true)
	player.apply_command(_neutral_command(), FRAME_DELTA, true)

	assert_int(player.ability_slot.remaining_uses).is_equal(ABILITY_USES)
	assert_bool(player.ability_slot.is_empty).is_false()


func test_grant_ability_replaces_the_remaining_uses_rather_than_adding() -> void:
	# 1 回撃って残り回数を減らしてから 2 回目を呼ぶ: 減らさずに 2 回呼ぶと、加算する実装でも
	# 値が一致しうる
	var player: Player = _create_player()
	player.grant_ability()
	assert_bool(_fire(player)).is_true()
	assert_int(player.ability_slot.remaining_uses).is_equal(ABILITY_USES - 1)

	player.grant_ability()

	assert_int(player.ability_slot.remaining_uses).is_equal(ABILITY_USES)


func test_grant_ability_reads_the_uses_from_stats_on_every_call() -> void:
	# 取得のたびに `stats` を読み直すこと: 生成の時点で回数を控える実装はここで落ちる
	var player: Player = _create_player()
	player.grant_ability()
	assert_bool(_fire(player)).is_true()
	player.stats.ability_uses = REGRANT_USES

	player.grant_ability()

	assert_int(player.ability_slot.remaining_uses).is_equal(REGRANT_USES)


func test_grant_ability_leaves_the_cooldown_ready() -> void:
	# クールダウン中に取得したケースと、取得しないケースの両側を見る: 空の状態からの取得
	# だけだと、クールダウンを明けない変異が「初期値が明けている」ために素通りする
	var granting: Player = _spent_one_shot_player()
	granting.ability_slot.update(false, FRAME_DELTA)
	granting.grant_ability()

	var waiting: Player = _spent_one_shot_player()
	waiting.ability_slot.update(false, FRAME_DELTA)

	assert_array(
		[
			granting.ability_slot.update(true, FRAME_DELTA),
			waiting.ability_slot.update(true, FRAME_DELTA),
		]
	).is_equal([true, false])


func test_the_slot_takes_the_cooldown_from_the_ability_stat() -> void:
	# 境界の両側を見る: 片側だけだと、比較を緩める変異も別の項目を渡す変異も落ちない
	var early: Player = _spent_one_shot_player()
	var early_fired: bool = _press_after_frames(early, ABILITY_COOLDOWN_FRAMES - 1)

	var exact: Player = _spent_one_shot_player()
	var exact_fired: bool = _press_after_frames(exact, ABILITY_COOLDOWN_FRAMES)

	assert_array([early_fired, exact_fired]).is_equal([false, true])


func test_the_emptied_slot_matches_the_slot_before_any_grant() -> void:
	# 使い切った枠を初期状態と区別しないこと(要件 7.5)
	var spent: Player = _create_player()
	spent.grant_ability()
	for shot: int in ABILITY_USES:
		assert_bool(_fire(spent)).append_failure_message("shot=%d" % shot).is_true()

	var fresh: Player = _create_player()
	fresh.apply_command(_neutral_command(), FRAME_DELTA, true)

	assert_array([spent.ability_slot.remaining_uses, spent.ability_slot.is_empty]).is_equal(
		[fresh.ability_slot.remaining_uses, fresh.ability_slot.is_empty]
	)
	# 両方が同じ誤った値(負の残り回数など)で一致する空振りを防ぐ
	assert_int(spent.ability_slot.remaining_uses).is_equal(0)
	assert_bool(spent.ability_slot.is_empty).is_true()


func test_the_emptied_slot_can_be_granted_again() -> void:
	# 使い切った枠に取得を締め出す状態が残っていないこと(要件 7.5 の振る舞い側)
	var player: Player = _create_player()
	player.grant_ability()
	for shot: int in ABILITY_USES:
		assert_bool(_fire(player)).append_failure_message("shot=%d" % shot).is_true()

	player.grant_ability()

	assert_int(player.ability_slot.remaining_uses).is_equal(ABILITY_USES)
	assert_bool(player.ability_slot.is_empty).is_false()


func test_the_slot_is_created_while_real_physics_frames_drive_the_player() -> void:
	# 同期で駆動するヘルパだけに頼らない: エンジンの物理フレームで `_physics_process` を
	# 通しても枠が生成され、取得が効くことを見る
	var player: Player = _create_player()
	var container: Node2D = auto_free(Node2D.new())
	container.add_child(player)
	add_child(container)
	await await_millis(WAIT_MILLIS)

	assert_object(player.ability_slot).is_not_null()
	assert_int(player.ability_slot.remaining_uses).is_equal(0)

	player.grant_ability()
	await await_millis(WAIT_MILLIS)

	assert_int(player.ability_slot.remaining_uses).is_equal(ABILITY_USES)
	assert_bool(player.ability_slot.is_empty).is_false()


## 押下の縁とクールダウンの明けの両方を満たしてから押す。戻り値はそのフレームの発射
func _fire(player: Player) -> bool:
	for frame: int in ABILITY_COOLDOWN_FRAMES:
		player.ability_slot.update(false, FRAME_DELTA)
	return player.ability_slot.update(true, FRAME_DELTA)


## 能力を取得して 1 発だけ撃った直後の `Player`。以降のフレームはクールダウンの内側から始まる
func _spent_one_shot_player() -> Player:
	var player: Player = _create_player()
	player.grant_ability()
	assert_bool(_fire(player)).is_true()
	return player


## 発射したフレームから数えて `frames` フレーム後に押す。`AbilitySlot` は `update()` の
## 先頭で `delta` を足してから比較するため、この数え方で境界がフレーム数に一致する
func _press_after_frames(player: Player, frames: int) -> bool:
	for frame: int in frames - 1:
		player.ability_slot.update(false, FRAME_DELTA)
	return player.ability_slot.update(true, FRAME_DELTA)


func _create_player() -> Player:
	var player: Player = auto_free(PLAYER_SCENE.instantiate())
	var stats: PlayerStats = auto_free(PlayerStats.new())
	stats.primary_interval = PRIMARY_INTERVAL
	stats.secondary_charge_time = SECONDARY_CHARGE_TIME
	stats.secondary_cooldown = SECONDARY_COOLDOWN
	stats.ability_uses = ABILITY_USES
	stats.ability_cooldown = ABILITY_COOLDOWN
	stats.ability_damage = ABILITY_DAMAGE
	stats.ability_bullet_speed = ABILITY_BULLET_SPEED
	player.stats = stats
	player.input_source = Callable(_create_neutral_input_stub(), "read")
	return player


func _create_neutral_input_stub() -> RefCounted:
	var stub_script: GDScript = GDScript.new()
	stub_script.source_code = NEUTRAL_INPUT_SOURCE
	stub_script.reload()
	return auto_free(stub_script.new())


func _neutral_command() -> PlayerCommand:
	return auto_free(PlayerCommand.new())
