extends GdUnitTestSuite

# `Enemy` 単体のシーンは無い。衝突形状を持つノードでしか接地を確かめられないため、基底の
# 物理の器として突進型のシーンを使う
const CHARGER_SCENE: PackedScene = preload("res://src/enemy/charger_enemy.tscn")
const ENEMY_SOURCE_PATH: String = "res://src/enemy/enemy.gd"

const DELTA: float = 1.0 / 60.0

# 既定値(30)と別の値を使う: 既定のままだと、`stats` を読まず値を直書きした実装でも緑になる
const MAX_HP: int = 24
const DAMAGE: int = 10
const OVERKILL: int = MAX_HP + DAMAGE

# 既定値(128.0)と別の値を使う: 既定のままだと、`stats` を読まない実装でも緑になる
const NEGATIVE_DETECT_RANGE: float = -96.0

# 既定値(600.0)と別の値を使う: 既定のままだと、`stats` を読まず値を直書きした実装でも緑になる
const GRAVITY: float = 500.0

const MIN_PHYSICS_FRAMES: int = 3
# 3 物理フレーム(60 Hz で 50 ms)に対して余裕を取る: CI のランナーが遅い場合でも消化させる
const WAIT_MILLIS: int = 500
# 落下 22px に要する sqrt(2 * 22 / 500) ≒ 0.30 秒に対して余裕を取る
const LANDING_WAIT_MILLIS: int = 800

const TERRAIN_LAYER: int = 1 << 0
const FLOOR_SIZE: Vector2 = Vector2(320.0, 20.0)
# 床の上面は y = -10。敵の半分の高さ 8 を足した y = -18 で静止する
const FLOOR_POSITION: Vector2 = Vector2.ZERO
const SPAWN_POSITION: Vector2 = Vector2(0.0, -40.0)

# 3-4-5 の直角三角形。距離が丸め誤差なしの 50.0 になる
const TARGET_OFFSET: Vector2 = Vector2(30.0, 40.0)
const TARGET_DISTANCE: float = 50.0

# 実装の文言を参照しない: 参照するとアサーションが自明になり、文言の退行を検出できない
const INVALID_AMOUNT_ERROR_FORMAT: String = (
	"Enemy.take_damage(): amount は正でなければならない(現在値: %s)。状態を変えずに返る"
)
const MISSING_STATS_ERROR: String = "Enemy: stats が設定されていない。既定値の EnemyStats を使う"
const NON_POSITIVE_STAT_ERROR_FORMAT: String = "Enemy: stats.%s は正でなければならない(現在値: %s)"
const NEGATIVE_STAT_ERROR_FORMAT: String = "Enemy: stats.%s は 0 以上でなければならない(現在値: %s)"

# 実装が導出する項目名をテスト側で導出しない: 同じ導出を使うと、導出そのものの誤りを検出できない
const POSITIVE_STAT_NAMES: Array[String] = [
	"max_hp",
	"gravity",
	"detect_range",
	"telegraph_time",
	"attack_damage",
	"attack_speed",
	"recover_time",
]
const ZERO_ALLOWED_STAT_NAMES: Array[String] = [
	"move_speed",
	"attack_duration",
	"bullet_max_distance",
]

# 実装が知りようのない項目名。`EnemyStats` へ項目を足した状況をテストの中だけで作る
const UNKNOWN_STAT_NAME: String = "unknown_stat"


## `EnemyStats` に項目が増えた状態。実装が項目名を固定で並べていると、この派生型の項目は
## 検査から漏れる
class ExtendedStats:
	extends EnemyStats

	@export var unknown_stat: float = 1.0

	## `@export` を付けない内部用の項目。手触りの数値ではないので検査の対象外であり、
	## 0 のままでも `push_error` は出ない
	var internal_stat: float = 0.0


## 消化した物理フレーム数を数えるだけのノード。検証する敵の子として載せる。待ち時間が足りず
## フレームを消化しなかった場合と、速度が変わらないことが正しい場合を区別する
class PhysicsFrameCounter:
	extends Node

	var frames: int = 0

	func _physics_process(_delta: float) -> void:
		frames += 1


func _create_stats() -> EnemyStats:
	var stats: EnemyStats = auto_free(EnemyStats.new())
	stats.max_hp = MAX_HP
	return stats


## ツリーへ載せていない `Enemy`。体力・撃破の契約はこの形で成立する
func _create_enemy() -> Enemy:
	var enemy: Enemy = auto_free(Enemy.new())
	enemy.stats = _create_stats()
	return enemy


## 衝突形状を持つ `Enemy`。基底の物理はツリーの上でしか成立しない
func _create_embodied_enemy() -> Enemy:
	var enemy: Enemy = auto_free(CHARGER_SCENE.instantiate())
	# シーンが指す `charger_stats.tres` を書き換えない: 1 個を全個体で共有するため、
	# 書き換えると他のテストへ波及する
	var stats: EnemyStats = auto_free(EnemyStats.new())
	stats.gravity = GRAVITY
	enemy.stats = stats
	enemy.position = SPAWN_POSITION
	return enemy


func _count_physics_frames(node: Node) -> PhysicsFrameCounter:
	var counter: PhysicsFrameCounter = auto_free(PhysicsFrameCounter.new())
	node.add_child(counter)
	return counter


func _add_floor() -> StaticBody2D:
	var body: StaticBody2D = auto_free(StaticBody2D.new())
	body.collision_layer = TERRAIN_LAYER
	body.position = FLOOR_POSITION
	var collision_shape: CollisionShape2D = auto_free(CollisionShape2D.new())
	var shape: RectangleShape2D = auto_free(RectangleShape2D.new())
	shape.size = FLOOR_SIZE
	collision_shape.shape = shape
	body.add_child(collision_shape)
	add_child(body)
	return body


func _add_target(enemy: Enemy) -> Node2D:
	var target: Node2D = auto_free(Node2D.new())
	target.position = SPAWN_POSITION + TARGET_OFFSET
	add_child(target)
	enemy.target = target
	return target


func _property_usage(object: Object, property_name: String) -> int:
	for property: Dictionary in object.get_property_list():
		if property["name"] == property_name:
			return property["usage"]
	return 0


func _function_body(source: String, function_name: String) -> String:
	var body: PackedStringArray = PackedStringArray()
	var is_inside: bool = false
	for line: String in source.split("\n"):
		if line.begins_with("func "):
			is_inside = line.begins_with("func %s(" % function_name)
			continue
		# 関数の外に置かれた行を本体に混ぜない: 次の関数へ付けた説明コメントは列 0 から始まり、
		# 混ぜるとコメントの語が順序のアサーションを揺らす
		if is_inside and line.begins_with("\t"):
			body.append(line)
	return "\n".join(body)


func test_hp_starts_at_the_max_hp_of_the_stats() -> void:
	var enemy: Enemy = _create_enemy()

	assert_int(enemy.hp).is_equal(MAX_HP)


func test_take_damage_reduces_the_hp_by_the_amount() -> void:
	var enemy: Enemy = _create_enemy()

	enemy.take_damage(DAMAGE)

	assert_int(enemy.hp).is_equal(MAX_HP - DAMAGE)
	assert_bool(enemy.is_defeated).is_false()


func test_take_damage_does_not_take_the_hp_below_zero() -> void:
	var enemy: Enemy = _create_enemy()

	enemy.take_damage(OVERKILL)

	assert_int(enemy.hp).is_equal(0)


func test_defeated_is_emitted_once_with_the_kind_when_the_hp_reaches_zero() -> void:
	var enemy: Enemy = _create_enemy()
	# 発火を Array へ控える: lambda はローカル変数を値コピーで捕捉するが、Array は参照として
	# 捕捉されるため外側から読める
	var emissions: Array = []
	enemy.defeated.connect(func(kind: int) -> void: emissions.append(kind))

	enemy.take_damage(MAX_HP)

	assert_array(emissions).is_equal([EnemyKind.Kind.CHARGER])


func test_defeated_is_not_emitted_while_the_hp_remains() -> void:
	var enemy: Enemy = _create_enemy()
	var emissions: Array = []
	enemy.defeated.connect(func(kind: int) -> void: emissions.append(kind))

	enemy.take_damage(MAX_HP - 1)

	assert_array(emissions).is_empty()
	assert_int(enemy.hp).is_equal(1)


func test_is_defeated_stays_false_while_the_hp_remains() -> void:
	var enemy: Enemy = _create_enemy()

	enemy.take_damage(MAX_HP - 1)

	assert_bool(enemy.is_defeated).is_false()


func test_is_defeated_becomes_true_when_the_hp_reaches_zero() -> void:
	var enemy: Enemy = _create_enemy()

	enemy.take_damage(MAX_HP)

	assert_bool(enemy.is_defeated).is_true()


func test_take_damage_after_the_defeat_changes_neither_the_hp_nor_the_signal() -> void:
	var enemy: Enemy = _create_enemy()
	var emissions: Array = []
	enemy.defeated.connect(func(kind: int) -> void: emissions.append(kind))
	enemy.take_damage(MAX_HP)

	enemy.take_damage(DAMAGE)

	assert_int(enemy.hp).is_equal(0)
	assert_bool(enemy.is_defeated).is_true()
	assert_array(emissions).is_equal([EnemyKind.Kind.CHARGER])


func test_defeated_is_emitted_before_the_enemy_is_released() -> void:
	var enemy: Enemy = _create_enemy()
	# 受け手の中から解放の有無と is_defeated を読む: 発火の時点で敵が生きており、撃破の状態が
	# 済んでいることを、順序の要求として固定する。
	# is_instance_valid() だけでは足りない: queue_free() は実際の解放をフレームの終わりまで
	# 遅らせるため、解放を先に呼ぶ実装でも受け手の中では true のままになる
	var observed: Array = []
	var record: Callable = func(_kind: int) -> void: observed.append(
		[is_instance_valid(enemy), enemy.is_defeated, enemy.is_queued_for_deletion()]
	)
	enemy.defeated.connect(record)

	enemy.take_damage(MAX_HP)

	assert_array(observed).is_equal([[true, true, false]])


func test_the_enemy_is_released_after_the_defeat() -> void:
	var enemy: Enemy = _create_enemy()

	enemy.take_damage(MAX_HP)
	# 実時間で待たない: 解放は現在のフレームの終わりに行われるので、フレーム境界を 1 つ跨げば
	# 足りる。ミリ秒で待つと遅いランナーで揺れる
	await await_idle_frame()

	assert_bool(is_instance_valid(enemy)).is_false()


func test_take_damage_rejects_a_non_positive_amount() -> void:
	var enemy: Enemy = _create_enemy()

	await (
		assert_error(func() -> void: enemy.take_damage(0))
		. is_push_error(INVALID_AMOUNT_ERROR_FORMAT % 0)
	)
	await (
		assert_error(func() -> void: enemy.take_damage(-DAMAGE))
		. is_push_error(INVALID_AMOUNT_ERROR_FORMAT % -DAMAGE)
	)
	assert_int(enemy.hp).is_equal(MAX_HP)
	assert_bool(enemy.is_defeated).is_false()


func test_a_bare_enemy_returns_the_charger_kind() -> void:
	var enemy: Enemy = _create_enemy()

	assert_int(enemy.kind()).is_equal(EnemyKind.Kind.CHARGER)


func test_ready_falls_back_to_the_default_stats_when_stats_is_missing() -> void:
	# ツリーへ載せる: 検査は `_ready()` に置かれており、`add_child()` は同期で `_ready()` まで走る
	var enemy: Enemy = auto_free(Enemy.new())

	await assert_error(func() -> void: add_child(enemy)).is_push_error(MISSING_STATS_ERROR)

	assert_object(enemy.stats).is_instanceof(EnemyStats)
	assert_int(enemy.hp).is_equal(enemy.stats.max_hp)


func test_ready_pushes_an_error_for_every_stat_that_must_be_positive_when_it_is_zero() -> void:
	for stat_name: String in POSITIVE_STAT_NAMES:
		var enemy: Enemy = _create_enemy()
		enemy.stats.set(stat_name, 0)
		var expected: String = (
			NON_POSITIVE_STAT_ERROR_FORMAT % [stat_name, enemy.stats.get(stat_name)]
		)

		await assert_error(func() -> void: add_child(enemy)).is_push_error(expected)


func test_ready_pushes_an_error_for_every_stat_set_to_a_negative_value() -> void:
	for stat_name: String in POSITIVE_STAT_NAMES:
		var enemy: Enemy = _create_enemy()
		enemy.stats.set(stat_name, -1)
		var expected: String = (
			NON_POSITIVE_STAT_ERROR_FORMAT % [stat_name, enemy.stats.get(stat_name)]
		)

		await assert_error(func() -> void: add_child(enemy)).is_push_error(expected)

	for stat_name: String in ZERO_ALLOWED_STAT_NAMES:
		var enemy: Enemy = _create_enemy()
		enemy.stats.set(stat_name, -1)
		var expected: String = NEGATIVE_STAT_ERROR_FORMAT % [stat_name, enemy.stats.get(stat_name)]

		await assert_error(func() -> void: add_child(enemy)).is_push_error(expected)


func test_ready_accepts_zero_for_the_stats_that_stand_for_an_absent_behaviour() -> void:
	var enemy: Enemy = _create_enemy()
	for stat_name: String in ZERO_ALLOWED_STAT_NAMES:
		enemy.stats.set(stat_name, 0.0)

	await assert_error(func() -> void: add_child(enemy)).is_success()


func test_ready_checks_a_stat_the_implementation_cannot_know_by_name() -> void:
	# 検査の対象を `get_property_list()` から導いていることを、実装が名前で持ちようのない項目で
	# 示す。項目名を固定で並べる実装はこのケースだけが落ちる
	var enemy: Enemy = auto_free(Enemy.new())
	var stats: ExtendedStats = auto_free(ExtendedStats.new())
	stats.max_hp = MAX_HP
	stats.unknown_stat = 0.0
	enemy.stats = stats
	var expected: String = NON_POSITIVE_STAT_ERROR_FORMAT % [UNKNOWN_STAT_NAME, stats.unknown_stat]

	await assert_error(func() -> void: add_child(enemy)).is_push_error(expected)


func test_ready_leaves_a_stat_that_is_not_exported_out_of_the_check() -> void:
	# 検査が `@export` の項目だけを見ていることを示す。エディタのビットで絞らない実装は、
	# 内部用の項目に偽の `push_error` を出してこのケースだけが落ちる
	var enemy: Enemy = auto_free(Enemy.new())
	var stats: ExtendedStats = auto_free(ExtendedStats.new())
	stats.max_hp = MAX_HP
	enemy.stats = stats

	await assert_error(func() -> void: add_child(enemy)).is_success()


func test_ready_reports_a_violation_that_comes_after_an_earlier_one() -> void:
	# 宣言の順で離れた 2 項目を同時に壊し、後ろの項目の報告を見る: 最初の違反を見つけた時点で
	# 打ち切る実装は、このケースだけが落ちる
	var enemy: Enemy = _create_enemy()
	enemy.stats.detect_range = 0.0
	enemy.stats.recover_time = 0.0
	var expected: String = (
		NON_POSITIVE_STAT_ERROR_FORMAT % ["recover_time", enemy.stats.recover_time]
	)

	await assert_error(func() -> void: add_child(enemy)).is_push_error(expected)


func test_ready_does_not_correct_an_invalid_stat_value() -> void:
	var enemy: Enemy = _create_enemy()
	enemy.stats.detect_range = NEGATIVE_DETECT_RANGE
	var expected: String = (
		NON_POSITIVE_STAT_ERROR_FORMAT % ["detect_range", enemy.stats.detect_range]
	)

	await assert_error(func() -> void: add_child(enemy)).is_push_error(expected)

	assert_float(enemy.stats.detect_range).is_equal(NEGATIVE_DETECT_RANGE)


func test_the_vertical_speed_grows_by_the_stats_gravity_while_off_the_floor() -> void:
	var enemy: Enemy = _create_embodied_enemy()
	var counter: PhysicsFrameCounter = _count_physics_frames(enemy)
	add_child(enemy)

	await await_millis(WAIT_MILLIS)

	assert_int(counter.frames).is_greater_equal(MIN_PHYSICS_FRAMES)
	assert_bool(enemy.is_on_floor()).is_false()
	# 期待値を実数で直接書かない: physics_ticks_per_second を変えると増分も変わる
	var expected: float = GRAVITY / float(Engine.physics_ticks_per_second) * counter.frames
	assert_float(enemy.velocity.y).is_equal_approx(expected, 0.001)


func test_the_vertical_speed_stays_at_zero_while_on_the_floor() -> void:
	_add_floor()
	var enemy: Enemy = _create_embodied_enemy()
	var counter: PhysicsFrameCounter = _count_physics_frames(enemy)
	add_child(enemy)

	await await_millis(LANDING_WAIT_MILLIS)

	assert_int(counter.frames).is_greater_equal(MIN_PHYSICS_FRAMES)
	assert_bool(enemy.is_on_floor()).is_true()
	# 速度の決定だけを同期で呼び、フレームの終わりの値を見ない: `move_and_slide()` は接地の
	# 衝突で垂直の速度を 0 へ戻すため、接地中も重力を足し続ける実装がそのまま通ってしまう
	enemy._update_velocity(DELTA)

	assert_float(enemy.velocity.y).is_equal(0.0)


func test_the_enemy_falls_toward_the_floor_and_stops_on_it() -> void:
	_add_floor()
	var enemy: Enemy = _create_embodied_enemy()
	var counter: PhysicsFrameCounter = _count_physics_frames(enemy)
	add_child(enemy)

	await await_millis(LANDING_WAIT_MILLIS)

	assert_int(counter.frames).is_greater_equal(MIN_PHYSICS_FRAMES)
	# 床の上面 -10 に敵の半分の高さ 8 を足した位置。めり込みの余白のぶんだけ許容する
	assert_float(enemy.position.y).is_between(-19.0, -17.0)


func test_target_is_an_exported_property() -> void:
	var enemy: Enemy = _create_enemy()

	var usage: int = _property_usage(enemy, "target")

	assert_int(usage & PROPERTY_USAGE_EDITOR).is_not_equal(0)
	assert_int(usage & PROPERTY_USAGE_SCRIPT_VARIABLE).is_not_equal(0)


func test_the_assigned_target_survives_physics_frames() -> void:
	# 内部で標的を検索して上書きする実装は、注入した標的がフレームを跨いで別のものへ
	# 置き換わってこのケースが落ちる
	var enemy: Enemy = _create_embodied_enemy()
	var target: Node2D = _add_target(enemy)
	var counter: PhysicsFrameCounter = _count_physics_frames(enemy)
	add_child(enemy)

	await await_millis(WAIT_MILLIS)

	assert_int(counter.frames).is_greater_equal(MIN_PHYSICS_FRAMES)
	assert_object(enemy.target).is_same(target)


func test_target_distance_measures_the_gap_to_the_target() -> void:
	var enemy: Enemy = _create_embodied_enemy()
	_add_target(enemy)
	add_child(enemy)

	assert_float(enemy.target_distance()).is_equal(TARGET_DISTANCE)


func test_target_distance_is_infinite_without_a_target() -> void:
	var enemy: Enemy = _create_embodied_enemy()
	add_child(enemy)
	enemy.target = null
	# 戻り値だけを見ると足りない: 標的の扱いは `target_distance()` にあり、ここへ `push_error`
	# を足す実装が素通りする。戻り値は Array へ控えて外から読む
	var observed: Array = []

	await assert_error(func() -> void: observed.append(enemy.target_distance())).is_success()

	assert_array(observed).is_equal([INF])


func test_target_distance_is_infinite_once_the_target_is_released() -> void:
	var enemy: Enemy = _create_embodied_enemy()
	var target: Node2D = _add_target(enemy)
	add_child(enemy)
	target.queue_free()
	await await_idle_frame()
	var observed: Array = []

	await assert_error(func() -> void: observed.append(enemy.target_distance())).is_success()

	assert_array(observed).is_equal([INF])


func test_a_physics_frame_pushes_no_error_when_the_target_is_null() -> void:
	# フレームの処理を同期で呼ぶ: 実際の物理フレームの `push_error` は `assert_error` の
	# 観測窓の外で起きるため、待って観測する形では捕らえられない
	var enemy: Enemy = _create_embodied_enemy()
	add_child(enemy)
	enemy.target = null

	await assert_error(func() -> void: enemy._physics_process(DELTA)).is_success()


func test_a_physics_frame_pushes_no_error_when_the_target_is_released() -> void:
	var enemy: Enemy = _create_embodied_enemy()
	var target: Node2D = _add_target(enemy)
	add_child(enemy)
	target.queue_free()
	await await_idle_frame()

	await assert_error(func() -> void: enemy._physics_process(DELTA)).is_success()


func test_physics_process_calls_move_and_slide_after_the_velocity_is_decided() -> void:
	var source: String = FileAccess.get_file_as_string(ENEMY_SOURCE_PATH)

	var body: String = _function_body(source, "_physics_process")

	assert_str(body).contains("_update_velocity(")
	assert_str(body).contains("move_and_slide()")
	assert_int(body.find("_update_velocity(")).is_less(body.find("move_and_slide()"))


func test_the_velocity_is_decided_without_moving_the_body() -> void:
	var source: String = FileAccess.get_file_as_string(ENEMY_SOURCE_PATH)

	var body: String = _function_body(source, "_update_velocity")

	assert_str(body).not_contains("move_and_slide")
