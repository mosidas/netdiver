extends GdUnitTestSuite

const PLAYER_SCENE: PackedScene = preload("res://src/player/player.tscn")

const PLAYER_SCENE_PATH: String = "res://src/player/player.tscn"
const PROJECTILE_SCENE_PATH: String = "res://src/weapon/projectile.tscn"
const FRAGMENT_SCENE_PATH: String = "res://src/ability/analysis_fragment.tscn"
const PROJECT_SETTINGS_PATH: String = "res://project.godot"

# 凍結時点(作業ブランチの分岐元)の `player.tscn` の sha256。語の不在だけを見ると、
# 別のシーンの項目として同じ値を書き込む変更を通す
const FROZEN_PLAYER_SCENE_SHA256: String = (
	"c1ff5528021fd94707275d72618d64bf9d614501b0b14b6e0905b49be42fcabd"
)

const TINT_PROPERTY_NAME: String = "upgraded_secondary_tint"

# 既定(スクリプト側の値)と別に取る: 既定のまま渡すと、色を直書きした実装でも緑になる。
# `Color.WHITE` とも別に取る
const TINT: Color = Color(0.9, 0.2, 0.4, 1)

# 2 進で厳密に表せる値を使う: 累積の丸め誤差でフレームの境界が揺れると、発射のフレームを
# フレーム数で数えられない
const FRAME_DELTA: float = 0.0625

# 4 フレーム。既定の 0.8 と別に取る
const SECONDARY_CHARGE_TIME: float = 0.25
const SECONDARY_CHARGE_FRAMES: int = 4

# 充電が満ちる 4 フレームに 1 フレームの余裕を足す: ちょうど 4 だと、1 フレーム分の
# 割り算を 4 回足した値が満充電に届かないことがあり、発射のフレームが揺れる
const SECONDARY_HOLD_FRAMES: int = 5

# 8 フレーム。既定の 2.0 と別に取る
const SECONDARY_COOLDOWN: float = 0.5
const SECONDARY_COOLDOWN_FRAMES: int = 8

# 既定の 50 と別に取り、主武器の既定 10 とも重ねない: 重なると、別の項目を渡す変異が落ちない
const SECONDARY_DAMAGE: int = 23

# 既定の 300.0 と別に取り、主武器の既定 400.0・射程の既定 400.0 とも重ねない
const SECONDARY_BULLET_SPEED: float = 180.0

# 6 フレーム。既定の 0.12 と別に取り、副武器の充電時間・クールダウンとも重ねない
const PRIMARY_INTERVAL: float = 0.375

# 拡散の発数。仕様の値であり、実装から読まない
const SPREAD_SIZE: int = 3

const RIGHT: Vector2i = Vector2i(1, 0)

# 数フレーム(60 Hz で 1 フレーム約 17 ms)に対して余裕を取る: 遅いランナーでも物理フレームを
# 消化させる。撃ったことはアサーションで確かめるため、待ち時間そのものには依存しない
const CHARGE_WAIT_MILLIS: int = 500
const RELEASE_WAIT_MILLIS: int = 300
const FLIGHT_WAIT_MILLIS: int = 500

# 変位から速さを戻すときの許容差。float32 の累積誤差(実測 1e-3 程度)に対して余裕を取る
const TOLERANCE: Vector2 = Vector2(0.01, 0.01)

# ツリーへ載せた `Player` の入力をテスト側から動かす。lambda は使わない
const HELD_INPUT_SOURCE: String = """
extends RefCounted

var secondary_held: bool = false


func read() -> PlayerCommand:
	var command: PlayerCommand = PlayerCommand.new()
	command.secondary_held = secondary_held
	return command
"""


# 検証で使う値が既定と一致しないことを固定する番人。一致すると、`stats` と
# `upgraded_secondary_tint` を読まずに値を直書きした実装が素通りする
func test_the_values_used_here_differ_from_the_defaults() -> void:
	var defaults: PlayerStats = auto_free(PlayerStats.new())
	var player: Player = auto_free(Player.new())

	assert_bool(TINT == player.upgraded_secondary_tint).append_failure_message(
		"差し替えの色が既定と同じ: %s" % TINT
	).is_false()
	assert_bool(TINT == Color.WHITE).is_false()

	assert_float(SECONDARY_CHARGE_TIME).is_not_equal(defaults.secondary_charge_time)
	assert_float(SECONDARY_COOLDOWN).is_not_equal(defaults.secondary_cooldown)
	assert_int(SECONDARY_DAMAGE).is_not_equal(defaults.secondary_damage)
	assert_float(SECONDARY_BULLET_SPEED).is_not_equal(defaults.secondary_bullet_speed)
	assert_float(PRIMARY_INTERVAL).is_not_equal(defaults.primary_interval)

	# 副武器の値が他の枠の値と重ならないこと: 重なると、別の項目を渡す変異が落ちない
	var other_damages: Array[int] = [defaults.primary_damage, defaults.max_health]
	assert_array(other_damages).not_contains([SECONDARY_DAMAGE])

	var other_speeds: Array[float] = [defaults.primary_bullet_speed, defaults.bullet_max_distance]
	assert_array(other_speeds).not_contains([SECONDARY_BULLET_SPEED])

	var other_periods: Array[float] = [PRIMARY_INTERVAL, SECONDARY_COOLDOWN]
	assert_array(other_periods).not_contains([SECONDARY_CHARGE_TIME])


# フレーム数で境界を数える前提を固定する: 崩れると、発射のフレームを数えるケースが実装ではなく
# 丸め誤差を観測する
func test_the_periods_used_here_are_whole_numbers_of_frames() -> void:
	assert_float(SECONDARY_CHARGE_TIME).is_equal(SECONDARY_CHARGE_FRAMES * FRAME_DELTA)
	assert_float(SECONDARY_COOLDOWN).is_equal(SECONDARY_COOLDOWN_FRAMES * FRAME_DELTA)
	assert_int(SECONDARY_HOLD_FRAMES).is_greater(SECONDARY_CHARGE_FRAMES)


func test_the_upgraded_secondary_projectile_carries_the_tint() -> void:
	var player: Player = _create_player()
	player.grant_upgrade()

	var spawned: Array[Projectile] = _fire_secondary(player, player.get_parent())

	assert_int(spawned.size()).is_equal(1)
	_assert_color_equals(spawned[0].modulate, TINT, "modulate")


# 分岐のもう片側。色は差し替えたまま渡してあるため、常に掛ける変異はここで落ちる
func test_the_plain_secondary_projectile_stays_white() -> void:
	var player: Player = _create_player()

	var spawned: Array[Projectile] = _fire_secondary(player, player.get_parent())

	assert_int(spawned.size()).is_equal(1)
	_assert_color_equals(spawned[0].modulate, Color.WHITE, "modulate")


# 既定値そのものが検査の対象であり、ここでは差し替えない。等しいと「見た目が変わる」という
# 契約が成立しない
func test_the_default_tint_differs_from_white() -> void:
	var from_script: Player = auto_free(Player.new())

	assert_bool(from_script.upgraded_secondary_tint == Color.WHITE).append_failure_message(
		"既定の色が白: %s" % from_script.upgraded_secondary_tint
	).is_false()


# 描画色の比較。弾の色をテスト側に書き写さず `.tscn` から解決する: 書き写すと、弾の色を
# 変えたときに検査が古い前提のまま緑になる
func test_the_tinted_secondary_projectile_renders_in_another_color() -> void:
	var placeholder: Color = _placeholder_color(PROJECTILE_SCENE_PATH)

	var rendered: Color = _tinted_projectile_color()

	assert_bool(rendered.is_equal_approx(placeholder)).append_failure_message(
		"掛けても描画色が変わらない: %s" % rendered
	).is_false()


# 断片の色と強化中の副武器の弾の描画色を見分けられること。どちらも `.tscn` から解決する
func test_the_fragment_color_differs_from_the_tinted_secondary_projectile() -> void:
	var fragment_color: Color = _placeholder_color(FRAGMENT_SCENE_PATH)

	var rendered: Color = _tinted_projectile_color()

	assert_bool(rendered.is_equal_approx(fragment_color)).append_failure_message(
		"断片と強化中の弾の描画色が同じ: %s" % rendered
	).is_false()


# 主武器の弾は強化の有無によらず白のまま。両側を見る: 強化中だけを見ると、主武器にも掛ける
# 変異が半分のケースで緑になる
func test_the_primary_projectiles_stay_white_with_and_without_the_upgrade() -> void:
	var upgraded: Player = _create_player()
	upgraded.grant_upgrade()
	var plain: Player = _create_player()

	var spread: Array[Projectile] = _fire_primary(upgraded, upgraded.get_parent())
	var single: Array[Projectile] = _fire_primary(plain, plain.get_parent())

	assert_int(spread.size()).is_equal(SPREAD_SIZE)
	assert_int(single.size()).is_equal(1)
	for index: int in spread.size():
		_assert_color_equals(spread[index].modulate, Color.WHITE, "spread index=%d" % index)
	_assert_color_equals(single[0].modulate, Color.WHITE, "plain")


# 副武器への入力の素通し。押したフレームと押さないフレームを混ぜた列を与える: 押しっぱなし
# だけだと、入力を主武器の強化へ移す実装(枠の占有)が両側で同じずれ方をする
func test_the_secondary_firing_frames_do_not_change_with_the_upgrade() -> void:
	var held_frames: Array[bool] = _secondary_frame_pattern()
	var upgraded: Player = _create_player()
	upgraded.grant_upgrade()
	var plain: Player = _create_player()

	var upgraded_shots: Array = _shots_per_frame(upgraded, upgraded.get_parent(), held_frames)
	var plain_shots: Array = _shots_per_frame(plain, plain.get_parent(), held_frames)

	var upgraded_frames: Array[int] = _shot_frames(upgraded_shots)
	var plain_frames: Array[int] = _shot_frames(plain_shots)
	assert_array(upgraded_frames).is_equal(plain_frames)
	# 観測が空振りしていないこと: 1 度も撃たない列だと、どんな実装でも一致する
	assert_int(upgraded_frames.size()).is_greater_equal(2)


# 強化中でも副武器の弾は 1 発であり、`fired(direction, true)` が 1 回だけ出ること。
# 拡散が副武器にも及ぶ変異はここで落ちる
func test_the_upgraded_secondary_spawns_one_projectile_and_emits_fired_once() -> void:
	var player: Player = _create_player()
	var container: Node = player.get_parent()
	player.grant_upgrade()
	var records: Array = _record_fired(player)
	var children_before: int = container.get_child_count()

	var spawned: Array[Projectile] = _fire_secondary(player, container)

	assert_int(spawned.size()).is_equal(1)
	assert_int(container.get_child_count()).is_equal(children_before + 1)
	assert_array(records).is_equal([[RIGHT, true]])


# 充電時間・クールダウン・威力・弾速が強化の有無で変わらないこと。4 項目すべてを既定と
# 別の値へ差し替えて渡してある
func test_the_secondary_numbers_do_not_change_with_the_upgrade() -> void:
	var held_frames: Array[bool] = _secondary_frame_pattern()
	var upgraded: Player = _create_player()
	upgraded.grant_upgrade()
	var plain: Player = _create_player()

	var upgraded_shots: Array = _shots_per_frame(upgraded, upgraded.get_parent(), held_frames)
	var plain_shots: Array = _shots_per_frame(plain, plain.get_parent(), held_frames)

	# 充電時間とクールダウンは発射のフレームに現れる
	assert_array(_shot_frames(upgraded_shots)).is_equal(_shot_frames(plain_shots))
	assert_int(upgraded_shots.size()).is_greater_equal(2)
	assert_int(plain_shots.size()).is_equal(upgraded_shots.size())

	var projectiles: Array[Projectile] = []
	for shot: Array in upgraded_shots + plain_shots:
		projectiles.append(shot[1])
	for index: int in projectiles.size():
		var context: String = "index=%d" % index
		assert_int(projectiles[index].damage).append_failure_message(context).is_equal(
			SECONDARY_DAMAGE
		)

	add_child(upgraded.get_parent())
	add_child(plain.get_parent())
	await await_millis(FLIGHT_WAIT_MILLIS)

	for index: int in projectiles.size():
		var projectile: Projectile = projectiles[index]
		var context: String = "index=%d" % index
		# 待ちが足りずフレームを消化しなかった場合と、動かなかった場合を区別する
		assert_int(projectile.frames_moved).append_failure_message(context).is_greater(0)
		# 期待値を実数で直接書かない: physics_ticks_per_second を変えると変位も変わる
		var travelled: float = (
			SECONDARY_BULLET_SPEED / float(Engine.physics_ticks_per_second) * projectile.frames_moved
		)
		var expected: Vector2 = Vector2(RIGHT) * travelled
		assert_vector(projectile.position).append_failure_message(context).is_equal_approx(
			expected, TOLERANCE
		)


func test_the_tint_is_an_export_of_the_player_and_not_of_the_stats() -> void:
	var player: Player = auto_free(Player.new())

	var tint_property: Dictionary = _find_property(player, TINT_PROPERTY_NAME)

	assert_dict(tint_property).append_failure_message(
		"`%s` が `Player` の宣言に無い" % TINT_PROPERTY_NAME
	).is_not_empty()
	var usage: int = int(tint_property["usage"])
	# `@export` は「スクリプト変数」かつ「インスペクタへ出る」ことで見分ける
	assert_int(usage & PROPERTY_USAGE_SCRIPT_VARIABLE).is_not_equal(0)
	assert_int(usage & PROPERTY_USAGE_EDITOR).is_not_equal(0)
	assert_int(int(tint_property["type"])).is_equal(TYPE_COLOR)

	var stats: PlayerStats = auto_free(PlayerStats.new())
	var stat_names: Array[String] = []
	for property: Dictionary in stats.get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		stat_names.append(property["name"])

	# 走査の空振りと区別する: 名前が 1 つも集まらないと `not_contains` は何も見ずに緑になる
	assert_array(stat_names).is_not_empty()
	assert_array(stat_names).not_contains([TINT_PROPERTY_NAME])
	for stat_name: String in stat_names:
		assert_bool(stat_name.contains("tint")).append_failure_message(stat_name).is_false()


# 値の出どころが 1 箇所であること。参照を解決した値どうしを比べる: シーンのテキストを
# 見るだけだと、同じ値を別の書き方で持ち込む変異が素通りする
func test_the_tint_default_is_the_same_from_the_script_and_from_the_scene() -> void:
	var from_script: Player = auto_free(Player.new())
	var from_scene: Player = auto_free(PLAYER_SCENE.instantiate())

	_assert_color_equals(
		from_scene.upgraded_secondary_tint, from_script.upgraded_secondary_tint, "既定の色"
	)

	var text: String = FileAccess.get_file_as_string(PLAYER_SCENE_PATH)
	assert_str(text).is_not_empty()
	assert_str(text).not_contains(TINT_PROPERTY_NAME)
	assert_str(FileAccess.get_sha256(PLAYER_SCENE_PATH)).is_equal(FROZEN_PLAYER_SCENE_SHA256)


# 同期で駆動するヘルパだけに頼らない: エンジンの物理フレームで `_physics_process` を通しても
# 強化中の副武器の弾に色が乗ること
func test_the_upgraded_secondary_is_tinted_while_real_physics_frames_drive_the_player() -> void:
	var player: Player = _create_player()
	var container: Node = player.get_parent()
	var stub: RefCounted = _create_input_stub()
	player.input_source = Callable(stub, "read")
	player.grant_upgrade()
	var records: Array = _record_fired(player)
	var children_before: int = container.get_child_count()

	stub.secondary_held = true
	add_child(container)
	await await_millis(CHARGE_WAIT_MILLIS)
	# 副武器はボタンを離したフレームで撃つ
	stub.secondary_held = false
	await await_millis(RELEASE_WAIT_MILLIS)

	assert_array(records).is_equal([[RIGHT, true]])
	assert_int(container.get_child_count()).is_equal(children_before + 1)
	var projectile: Projectile = container.get_child(children_before)
	_assert_color_equals(projectile.modulate, TINT, "modulate")
	# 弾が実フレームで進んでいること: 進んでいなければツリーの外での駆動と区別できない
	assert_int(projectile.frames_moved).is_greater(0)


# 強化の状態が `Player` の宣言の外へ逃げていないこと。ツリーにも親にも属さない `Player` が
# 単独で色を掛けられることと、動的に付けた状態(メタ)もオートロードも無いことを対で見る
func test_the_upgraded_secondary_needs_no_state_outside_the_player() -> void:
	var player: Player = _create_orphan_player()
	player.grant_upgrade()

	var spawned: Array[Projectile] = _fire_secondary(player, player)

	assert_int(spawned.size()).is_equal(1)
	_assert_color_equals(spawned[0].modulate, TINT, "modulate")
	assert_int(player.get_meta_list().size()).append_failure_message(
		str(player.get_meta_list())
	).is_equal(0)

	var settings: String = FileAccess.get_file_as_string(PROJECT_SETTINGS_PATH)
	assert_str(settings).is_not_empty()
	assert_str(settings).not_contains("[autoload]")


func _assert_color_equals(actual: Color, expected: Color, context: String) -> void:
	assert_bool(actual == expected).append_failure_message(
		"%s: actual=%s expected=%s" % [context, actual, expected]
	).is_true()


## 既定の色を掛けた副武器の弾の描画色。色の値をテスト側に書き写さず `.tscn` から解決する
func _tinted_projectile_color() -> Color:
	var player: Player = auto_free(Player.new())
	return _placeholder_color(PROJECTILE_SCENE_PATH) * player.upgraded_secondary_tint


## `.tscn` が持つ唯一の `ColorRect` の色。1 枚であることを確かめてから読む
func _placeholder_color(scene_path: String) -> Color:
	var scene: PackedScene = load(scene_path)
	var root: Node = auto_free(scene.instantiate())
	var rects: Array[ColorRect] = []
	for child: Node in root.get_children():
		if child is ColorRect:
			rects.append(child as ColorRect)

	assert_int(rects.size()).append_failure_message(scene_path).is_equal(1)
	return rects[0].color


## 充電を満たしてから離し、離したフレームに増えた弾を返す
func _fire_secondary(player: Player, container: Node) -> Array[Projectile]:
	for frame: int in SECONDARY_HOLD_FRAMES:
		player.apply_command(_secondary_command(true), FRAME_DELTA, true)

	var children_before: int = container.get_child_count()
	player.apply_command(_secondary_command(false), FRAME_DELTA, true)
	return _children_from(container, children_before)


## 1 回分の主武器の発射を行い、そのフレームに増えた弾を返す。
##
## `PRIMARY_INTERVAL` は間隔ちょうどであり、呼び出しごとに必ず 1 回発射する
func _fire_primary(player: Player, container: Node) -> Array[Projectile]:
	var children_before: int = container.get_child_count()
	var command: PlayerCommand = _secondary_command(false)
	command.primary_held = true
	player.apply_command(command, PRIMARY_INTERVAL, true)
	return _children_from(container, children_before)


## 1 フレームずつ進め、増えた弾を `[フレームの添字, 弾]` で並べて返す
func _shots_per_frame(player: Player, container: Node, held_frames: Array[bool]) -> Array:
	var shots: Array = []
	for index: int in held_frames.size():
		var children_before: int = container.get_child_count()
		player.apply_command(_secondary_command(held_frames[index]), FRAME_DELTA, true)
		for projectile: Projectile in _children_from(container, children_before):
			shots.append([index, projectile])
	return shots


func _shot_frames(shots: Array) -> Array[int]:
	var frames: Array[int] = []
	for shot: Array in shots:
		frames.append(shot[0])
	return frames


## 充電を途中で捨てるフレーム・充電・発射・クールダウンを混ぜた列。押した状態と押さない
## 状態の両方を通す
func _secondary_frame_pattern() -> Array[bool]:
	var frames: Array[bool] = [true, true, false]
	for frame: int in SECONDARY_HOLD_FRAMES:
		frames.append(true)
	frames.append(false)
	for frame: int in SECONDARY_COOLDOWN_FRAMES:
		frames.append(false)
	for frame: int in SECONDARY_HOLD_FRAMES:
		frames.append(true)
	frames.append(false)
	return frames


func _children_from(container: Node, from_index: int) -> Array[Projectile]:
	var found: Array[Projectile] = []
	for index: int in range(from_index, container.get_child_count()):
		found.append(container.get_child(index))
	return found


## 発火した順に `[direction, is_secondary]` を控える
func _record_fired(player: Player) -> Array:
	var records: Array = []
	var record: Callable = func(direction: Vector2i, is_secondary: bool) -> void:
		records.append([direction, is_secondary])
	player.fired.connect(record)
	return records


func _find_property(target: Object, property_name: String) -> Dictionary:
	for property: Dictionary in target.get_property_list():
		if property["name"] == property_name:
			return property
	return {}


func _secondary_command(secondary_held: bool) -> PlayerCommand:
	var command: PlayerCommand = auto_free(PlayerCommand.new())
	command.secondary_held = secondary_held
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
	stats.primary_interval = PRIMARY_INTERVAL
	stats.secondary_charge_time = SECONDARY_CHARGE_TIME
	stats.secondary_cooldown = SECONDARY_COOLDOWN
	stats.secondary_damage = SECONDARY_DAMAGE
	stats.secondary_bullet_speed = SECONDARY_BULLET_SPEED
	player.stats = stats
	player.upgraded_secondary_tint = TINT
	player.input_source = Callable(_create_input_stub(), "read")
	return player


## 既定では何も押していない入力源。ツリーへ載せるケースだけが `secondary_held` を動かす
func _create_input_stub() -> RefCounted:
	var stub_script: GDScript = GDScript.new()
	stub_script.source_code = HELD_INPUT_SOURCE
	stub_script.reload()
	return auto_free(stub_script.new())
