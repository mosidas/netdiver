extends GdUnitTestSuite

const CHARGER_SCENE: PackedScene = preload("res://src/enemy/charger_enemy.tscn")

# 埋め込みサブリソースの `resource_path` は
# `res://src/enemy/charger_enemy.tscn::Resource_xxxx` になり、この比較で落ちる
const CHARGER_STATS_PATH: String = "res://src/enemy/charger_stats.tres"

const PLACEHOLDER_SIZE: Vector2 = Vector2(16.0, 16.0)

const ENEMY_LAYER: int = 1 << 3
const TERRAIN_MASK: int = 1 << 0
const PLAYER_LAYER: int = 1 << 1
# 攻撃判定は layer を持たない: レイヤ 5 は「敵の弾」であり、近接の判定をそこへ載せると
# レイヤの表の意味が崩れる
const NO_LAYER: int = 0

const DELTA: float = 1.0 / 60.0

# 既定値(40.0 / 128.0 / 150.0 / 0.6 / 0.4 / 0.8 / 600.0 / 15)とは別の値にする: 既定のままだと、
# `stats` を読まず値を直書きした実装でも緑になる。時間は 2 進で厳密に表せる値を使う
const MOVE_SPEED: float = 50.0
const DETECT_RANGE: float = 90.0
const ATTACK_SPEED: float = 100.0
const ATTACK_DURATION: float = 0.5
const TELEGRAPH_TIME: float = 0.25
const RECOVER_TIME: float = 0.75
const GRAVITY: float = 500.0
const ATTACK_DAMAGE: int = 23

# 突進の到達距離。索敵範囲(DETECT_RANGE)より内側に取る: 2 つの値が同じだと、遷移の条件と
# 移動の条件を取り違える実装が素通りする
const ATTACK_REACH: float = ATTACK_SPEED * ATTACK_DURATION

# `IDLE` のまま水平に動く帯(到達距離より外・索敵範囲より内)の中央。到達距離の内側だと
# 即座に `TELEGRAPH` へ入って水平の速度が 0 になり、索敵範囲の外だと停止する
const APPROACH_GAP: float = (ATTACK_REACH + DETECT_RANGE) * 0.5
const OUT_OF_RANGE_GAP: float = DETECT_RANGE * 2.0
const CHARGE_GAP: float = ATTACK_REACH * 0.5

const SPAWN_POSITION: Vector2 = Vector2.ZERO

# 同期で進めるフレーム数の上限。遷移しない実装でテストが止まり続けないようにする
const MAX_DRIVEN_FRAMES: int = 600

const MOVING_FRAMES: int = 3
# 3 物理フレーム(60 Hz で 50 ms)に対して余裕を取る: CI のランナーが遅い場合でも消化させる
const WAIT_MILLIS: int = 500

# 突進の途中で初めて触れる距離。到達距離(50)の内側で `TELEGRAPH` へ入り、矩形が重なる
# までに 24px(突進の 0.24 秒ぶん)を残す
const CONTACT_GAP: float = 40.0
# 弾道の高さを保つ重力: 既定の 500 px/s² だと、突進が届く前に敵が矩形の高さを超えて落ち、
# 当たらないことが原因の緑になる
const FLOATING_GRAVITY: float = 1.0
# 硬直を長く取る: 待ち時間が揺れても 2 回目の突進が始まらず、ダメージの回数が 1 に定まる
const LONG_RECOVER_TIME: float = 4.0
# 予備動作 0.25 秒 + 突進 0.5 秒(約 0.79 秒)を過ぎ、硬直 4.0 秒の内側に収まる待ち時間
const CHARGE_WAIT_MILLIS: int = 1500


## 位置を制御できる標的。規定のフレーム数だけ索敵範囲の内側に留まり、その後は外へ退いて
## 敵の移動を打ち切る。消化したフレーム数と変位を対応付けるために使う
class MovingTarget:
	extends Node2D

	var frames: int = 0
	var frames_in_range: int = 0
	var position_out_of_range: Vector2

	func _physics_process(_delta: float) -> void:
		frames += 1
		if frames >= frames_in_range:
			position = position_out_of_range


## 消化した物理フレーム数を数えるだけのノード。待ち時間が足りずフレームを消化しなかった場合と、
## 動かないことが正しい場合を区別する
class PhysicsFrameCounter:
	extends Node

	var frames: int = 0

	func _physics_process(_delta: float) -> void:
		frames += 1


## `take_damage()` を持つ body。プレイヤーの代わりに置く: 相手を型ではなくメソッドの有無で
## 見分ける契約を、`Player` を持ち込まずに試す
class RecordingBody:
	extends CharacterBody2D

	var amounts: Array[int] = []

	func take_damage(amount: int) -> void:
		amounts.append(amount)


# スイートのメンバに抱える: ローカル変数だけで持つと、毎フレーム参照するスタブへの参照が
# 切れる事故を招く
var _moving_target: MovingTarget


## テスト用の数値。シーンが指す `charger_stats.tres` は書き換えない: 1 個を全個体で共有する
## ため、書き換えると他のテストへ波及する
func _create_stats() -> EnemyStats:
	var stats: EnemyStats = auto_free(EnemyStats.new())
	stats.gravity = GRAVITY
	stats.move_speed = MOVE_SPEED
	stats.detect_range = DETECT_RANGE
	stats.telegraph_time = TELEGRAPH_TIME
	stats.attack_damage = ATTACK_DAMAGE
	stats.attack_speed = ATTACK_SPEED
	stats.attack_duration = ATTACK_DURATION
	stats.recover_time = RECOVER_TIME
	return stats


## プレイヤーの代わりに置く body。攻撃判定の mask に載るレイヤを持たせ、こちらからは何も
## 見ない(mask 0)
func _create_player_body() -> RecordingBody:
	var body: RecordingBody = auto_free(RecordingBody.new())
	body.collision_layer = PLAYER_LAYER
	body.collision_mask = 0
	# 親を auto_free するため子は登録しない: 親の解放で一緒に解放される
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = PLACEHOLDER_SIZE
	collision_shape.shape = rectangle
	body.add_child(collision_shape)
	return body


## 自動の物理フレームを止めた突進型。速度への写像は `_update_velocity()` を同期で呼んで
## 観測する: `move_and_slide()` は衝突で速度を書き換えるため、フレームの終わりの値では
## 写像を固定できない。自動のフレームを止めるのは、同期で進めたフレーム数と `brain` の
## 滞在時間の対応が崩れるのを避けるためである
func _create_driven_charger() -> ChargerEnemy:
	var enemy: ChargerEnemy = auto_free(CHARGER_SCENE.instantiate())
	enemy.stats = _create_stats()
	enemy.position = SPAWN_POSITION
	add_child(enemy)
	enemy.set_physics_process(false)
	return enemy


func _place_target(enemy: ChargerEnemy, offset: Vector2) -> Node2D:
	var target: Node2D = auto_free(Node2D.new())
	target.position = enemy.position + offset
	add_child(target)
	enemy.target = target
	return target


func _attackbox_of(enemy: ChargerEnemy) -> Attackbox:
	return enemy.get_node("Attackbox")


## 1 物理フレームぶんの写像を同期で起こす(`move_and_slide()` は含めない)。速度の決定と
## 攻撃判定の切り替えは別の関数であり、どちらも `_physics_process` から駆動される
func _step(enemy: ChargerEnemy) -> void:
	enemy._update_velocity(DELTA)
	enemy._sync_attackbox()


func _advance(enemy: ChargerEnemy, frames: int) -> void:
	for frame: int in frames:
		_step(enemy)


## 指定の状態から出るまで進める。「指定の状態へ入るまで」にしない: 遷移先を取り違える実装が、
## 別の状態を経由して同じ状態へ達し、素通りする
func _advance_out_of_state(enemy: ChargerEnemy, state: int) -> void:
	var frames: int = 0
	while enemy.brain.state == state and frames < MAX_DRIVEN_FRAMES:
		_step(enemy)
		frames += 1


## 標的を到達距離の内側に置き、突進へ入るまで進める
func _advance_into_the_charge(enemy: ChargerEnemy) -> void:
	_place_target(enemy, Vector2(CHARGE_GAP, 0.0))
	_step(enemy)
	_advance_out_of_state(enemy, EnemyState.State.TELEGRAPH)


## 次の突進へ入るまで進める(硬直 → 待機 → 予備動作を消化する)
func _advance_into_the_next_charge(enemy: ChargerEnemy) -> void:
	_advance_out_of_state(enemy, EnemyState.State.CHARGE)
	_advance_out_of_state(enemy, EnemyState.State.RECOVER)
	_advance_out_of_state(enemy, EnemyState.State.IDLE)
	_advance_out_of_state(enemy, EnemyState.State.TELEGRAPH)


func test_charger_scene_centers_a_16x16_placeholder_on_the_origin() -> void:
	var enemy: ChargerEnemy = auto_free(CHARGER_SCENE.instantiate())
	var placeholder: ColorRect = enemy.get_node("Placeholder")
	var collision_shape: CollisionShape2D = enemy.get_node("CollisionShape2D")
	var shape: RectangleShape2D = collision_shape.shape

	assert_vector(placeholder.size).is_equal(PLACEHOLDER_SIZE)
	assert_vector(placeholder.position).is_equal(-PLACEHOLDER_SIZE * 0.5)
	assert_vector(shape.size).is_equal(PLACEHOLDER_SIZE)
	assert_vector(collision_shape.position).is_equal(Vector2.ZERO)


func test_charger_scene_is_on_the_enemy_layer_and_collides_with_terrain() -> void:
	var enemy: ChargerEnemy = auto_free(CHARGER_SCENE.instantiate())

	assert_int(enemy.collision_layer).is_equal(ENEMY_LAYER)
	assert_int(enemy.collision_mask).is_equal(TERRAIN_MASK)


func test_charger_scene_reads_the_stats_from_the_shared_file() -> void:
	var enemy: ChargerEnemy = auto_free(CHARGER_SCENE.instantiate())

	assert_object(enemy.stats).is_instanceof(EnemyStats)
	assert_str(enemy.stats.resource_path).is_equal(CHARGER_STATS_PATH)


func test_charger_scene_does_not_copy_the_stats_per_instance() -> void:
	var enemy: ChargerEnemy = auto_free(CHARGER_SCENE.instantiate())

	assert_bool(enemy.stats.resource_local_to_scene).is_false()


func test_charger_returns_the_charger_kind() -> void:
	var enemy: ChargerEnemy = auto_free(CHARGER_SCENE.instantiate())

	assert_int(enemy.kind()).is_equal(EnemyKind.Kind.CHARGER)


func test_charger_starts_without_a_target() -> void:
	var enemy: ChargerEnemy = auto_free(CHARGER_SCENE.instantiate())

	assert_object(enemy.target).is_null()
	assert_float(enemy.target_distance()).is_equal(INF)


func test_the_charger_exposes_its_brain() -> void:
	var enemy: ChargerEnemy = _create_driven_charger()

	assert_object(enemy.brain).is_instanceof(ChargerBrain)
	assert_int(enemy.brain.state).is_equal(EnemyState.State.IDLE)


func test_the_charger_approaches_a_target_on_its_right_inside_the_detect_range() -> void:
	var enemy: ChargerEnemy = _create_driven_charger()
	_place_target(enemy, Vector2(APPROACH_GAP, 0.0))

	enemy._update_velocity(DELTA)

	assert_int(enemy.brain.state).is_equal(EnemyState.State.IDLE)
	assert_float(enemy.velocity.x).is_equal(MOVE_SPEED)


func test_the_charger_approaches_a_target_on_its_left_inside_the_detect_range() -> void:
	var enemy: ChargerEnemy = _create_driven_charger()
	_place_target(enemy, Vector2(-APPROACH_GAP, 0.0))

	enemy._update_velocity(DELTA)

	assert_int(enemy.brain.state).is_equal(EnemyState.State.IDLE)
	assert_float(enemy.velocity.x).is_equal(-MOVE_SPEED)


func test_the_charger_approaches_a_target_exactly_at_the_detect_range() -> void:
	# 索敵範囲は「以下」である。条件を「未満」へ変える実装はこの距離でだけ落ちる
	var enemy: ChargerEnemy = _create_driven_charger()
	_place_target(enemy, Vector2(DETECT_RANGE, 0.0))

	enemy._update_velocity(DELTA)

	assert_float(enemy.velocity.x).is_equal(MOVE_SPEED)


func test_the_charger_stands_still_for_a_target_beyond_the_detect_range() -> void:
	var enemy: ChargerEnemy = _create_driven_charger()
	_place_target(enemy, Vector2(OUT_OF_RANGE_GAP, 0.0))

	enemy._update_velocity(DELTA)

	assert_int(enemy.brain.state).is_equal(EnemyState.State.IDLE)
	assert_float(enemy.velocity.x).is_equal(0.0)


func test_the_charger_stands_still_while_it_telegraphs() -> void:
	# 接近して水平の速度を持たせてから予備動作へ入れる: 速度 0 から始めると、`TELEGRAPH` で
	# 速度を戻さない実装が素通りする
	var enemy: ChargerEnemy = _create_driven_charger()
	var target: Node2D = _place_target(enemy, Vector2(APPROACH_GAP, 0.0))
	enemy._update_velocity(DELTA)
	target.position = enemy.position + Vector2(CHARGE_GAP, 0.0)

	enemy._update_velocity(DELTA)

	assert_int(enemy.brain.state).is_equal(EnemyState.State.TELEGRAPH)
	assert_float(enemy.velocity.x).is_equal(0.0)


func test_the_charger_stands_still_while_it_recovers() -> void:
	var enemy: ChargerEnemy = _create_driven_charger()
	_place_target(enemy, Vector2(CHARGE_GAP, 0.0))
	enemy._update_velocity(DELTA)
	_advance_out_of_state(enemy, EnemyState.State.TELEGRAPH)

	_advance_out_of_state(enemy, EnemyState.State.CHARGE)

	assert_int(enemy.brain.state).is_equal(EnemyState.State.RECOVER)
	assert_float(enemy.velocity.x).is_equal(0.0)


func test_the_charger_charges_toward_a_target_on_its_right() -> void:
	var enemy: ChargerEnemy = _create_driven_charger()
	_place_target(enemy, Vector2(CHARGE_GAP, 0.0))
	enemy._update_velocity(DELTA)

	_advance_out_of_state(enemy, EnemyState.State.TELEGRAPH)

	assert_int(enemy.brain.state).is_equal(EnemyState.State.CHARGE)
	assert_float(enemy.velocity.x).is_equal(ATTACK_SPEED)


func test_the_charger_charges_toward_a_target_on_its_left() -> void:
	var enemy: ChargerEnemy = _create_driven_charger()
	_place_target(enemy, Vector2(-CHARGE_GAP, 0.0))
	enemy._update_velocity(DELTA)

	_advance_out_of_state(enemy, EnemyState.State.TELEGRAPH)

	assert_int(enemy.brain.state).is_equal(EnemyState.State.CHARGE)
	assert_float(enemy.velocity.x).is_equal(-ATTACK_SPEED)


func test_the_charge_keeps_the_direction_it_started_with() -> void:
	var enemy: ChargerEnemy = _create_driven_charger()
	var target: Node2D = _place_target(enemy, Vector2(CHARGE_GAP, 0.0))
	enemy._update_velocity(DELTA)
	_advance_out_of_state(enemy, EnemyState.State.TELEGRAPH)

	target.position = enemy.position + Vector2(-CHARGE_GAP, 0.0)
	enemy._update_velocity(DELTA)

	assert_int(enemy.brain.state).is_equal(EnemyState.State.CHARGE)
	assert_float(enemy.velocity.x).is_equal(ATTACK_SPEED)


func test_a_second_charge_takes_up_the_direction_of_that_moment() -> void:
	# 向きを 1 度だけ決める実装を落とす: 保つのは 1 回の突進の間だけであり、次の突進は
	# その時点の標的の側から取り直す
	var enemy: ChargerEnemy = _create_driven_charger()
	var target: Node2D = _place_target(enemy, Vector2(CHARGE_GAP, 0.0))
	enemy._update_velocity(DELTA)
	_advance_out_of_state(enemy, EnemyState.State.TELEGRAPH)
	assert_float(enemy.velocity.x).is_equal(ATTACK_SPEED)

	target.position = enemy.position + Vector2(-CHARGE_GAP, 0.0)
	_advance_out_of_state(enemy, EnemyState.State.CHARGE)
	_advance_out_of_state(enemy, EnemyState.State.RECOVER)
	_advance_out_of_state(enemy, EnemyState.State.IDLE)
	_advance_out_of_state(enemy, EnemyState.State.TELEGRAPH)

	assert_int(enemy.brain.state).is_equal(EnemyState.State.CHARGE)
	assert_float(enemy.velocity.x).is_equal(-ATTACK_SPEED)


func test_the_charger_stays_idle_and_still_once_the_target_becomes_null() -> void:
	var enemy: ChargerEnemy = _create_driven_charger()
	_place_target(enemy, Vector2(APPROACH_GAP, 0.0))
	enemy._update_velocity(DELTA)

	enemy.target = null
	_advance(enemy, MOVING_FRAMES)

	assert_int(enemy.brain.state).is_equal(EnemyState.State.IDLE)
	assert_float(enemy.velocity.x).is_equal(0.0)


func test_a_null_target_during_the_telegraph_cancels_the_charge() -> void:
	# 標的までの距離を `INF` として渡していることの観測点。巨大な有限値(例 1e9)へ
	# 置き換える実装は、満了で `CHARGE` へ進んでこのケースが落ちる
	var enemy: ChargerEnemy = _create_driven_charger()
	_place_target(enemy, Vector2(CHARGE_GAP, 0.0))
	enemy._update_velocity(DELTA)

	enemy.target = null
	_advance_out_of_state(enemy, EnemyState.State.TELEGRAPH)

	assert_int(enemy.brain.state).is_equal(EnemyState.State.RECOVER)
	assert_float(enemy.velocity.x).is_equal(0.0)


func test_a_released_target_during_the_telegraph_cancels_the_charge() -> void:
	var enemy: ChargerEnemy = _create_driven_charger()
	var target: Node2D = _place_target(enemy, Vector2(CHARGE_GAP, 0.0))
	enemy._update_velocity(DELTA)

	target.queue_free()
	# 解放の反映を待ってから満了させる: 待たずに進めると `null` にする経路と区別がつかない
	await await_idle_frame()
	assert_bool(is_instance_valid(target)).is_false()
	_advance_out_of_state(enemy, EnemyState.State.TELEGRAPH)

	assert_int(enemy.brain.state).is_equal(EnemyState.State.RECOVER)
	assert_float(enemy.velocity.x).is_equal(0.0)


func test_the_charger_covers_the_ground_its_move_speed_defines() -> void:
	var enemy: ChargerEnemy = auto_free(CHARGER_SCENE.instantiate())
	enemy.stats = _create_stats()
	enemy.position = SPAWN_POSITION
	var counter: PhysicsFrameCounter = auto_free(PhysicsFrameCounter.new())
	enemy.add_child(counter)
	add_child(enemy)
	# 標的を敵より後に載せる: 物理フレームは木の順に走るため、敵が距離を読み終えてから
	# 標的が退く。先に載せると打ち切りが 1 フレーム早まる
	_moving_target = auto_free(MovingTarget.new())
	_moving_target.position = SPAWN_POSITION + Vector2(APPROACH_GAP, 0.0)
	_moving_target.position_out_of_range = SPAWN_POSITION + Vector2(OUT_OF_RANGE_GAP, 0.0)
	_moving_target.frames_in_range = MOVING_FRAMES
	add_child(_moving_target)
	enemy.target = _moving_target

	await await_millis(WAIT_MILLIS)

	# 打ち切りの後のフレームまで消化していることを見る: 等しいだけだと、待ち時間が足りずに
	# 止まった場合と区別できない
	assert_int(counter.frames).is_greater(MOVING_FRAMES)
	# 期待値を実数で直接書かない: physics_ticks_per_second を変えると変位も変わる
	var expected: float = MOVE_SPEED / float(Engine.physics_ticks_per_second) * MOVING_FRAMES
	assert_float(enemy.position.x).is_equal_approx(expected, 0.001)


func test_the_attackbox_of_the_charger_has_no_layer_and_watches_the_player() -> void:
	var enemy: ChargerEnemy = auto_free(CHARGER_SCENE.instantiate())

	var attackbox: Attackbox = _attackbox_of(enemy)

	assert_int(attackbox.collision_layer).is_equal(NO_LAYER)
	assert_int(attackbox.collision_mask).is_equal(PLAYER_LAYER)


func test_the_attackbox_of_the_charger_covers_the_same_rectangle_as_its_body() -> void:
	# 本体からはみ出すと、突進の見た目と当たりが食い違う
	var enemy: ChargerEnemy = auto_free(CHARGER_SCENE.instantiate())
	var body_shape_node: CollisionShape2D = enemy.get_node("CollisionShape2D")
	var body_shape: RectangleShape2D = body_shape_node.shape
	var attackbox: Attackbox = _attackbox_of(enemy)
	var attack_shape_node: CollisionShape2D = attackbox.get_node("CollisionShape2D")
	var attack_shape: RectangleShape2D = attack_shape_node.shape

	assert_vector(attack_shape.size).is_equal(body_shape.size)
	assert_vector(attackbox.position).is_equal(Vector2.ZERO)
	assert_vector(attack_shape_node.position).is_equal(body_shape_node.position)


func test_the_attackbox_of_the_charger_starts_disabled() -> void:
	# シーンの既定が有効だと、待機の 1 フレーム目に触れている相手へダメージが入る
	var enemy: ChargerEnemy = auto_free(CHARGER_SCENE.instantiate())

	assert_bool(_attackbox_of(enemy).monitoring).is_false()


func test_the_charger_hands_its_attack_damage_to_the_attackbox() -> void:
	# シーンへ焼き込まず `stats` から代入することの観測点。既定値(15)と別の値を使う
	var enemy: ChargerEnemy = _create_driven_charger()

	assert_int(_attackbox_of(enemy).damage).is_equal(ATTACK_DAMAGE)


func test_the_attackbox_is_active_only_while_the_charger_charges() -> void:
	var enemy: ChargerEnemy = _create_driven_charger()
	var attackbox: Attackbox = _attackbox_of(enemy)
	var target: Node2D = _place_target(enemy, Vector2(OUT_OF_RANGE_GAP, 0.0))
	var observed: Array = []

	_step(enemy)
	observed.append([enemy.brain.state, attackbox.monitoring])
	target.position = enemy.position + Vector2(CHARGE_GAP, 0.0)
	_step(enemy)
	observed.append([enemy.brain.state, attackbox.monitoring])
	_advance_out_of_state(enemy, EnemyState.State.TELEGRAPH)
	observed.append([enemy.brain.state, attackbox.monitoring])
	_advance_out_of_state(enemy, EnemyState.State.CHARGE)
	observed.append([enemy.brain.state, attackbox.monitoring])

	assert_array(observed).is_equal(
		[
			[EnemyState.State.IDLE, false],
			[EnemyState.State.TELEGRAPH, false],
			[EnemyState.State.CHARGE, true],
			[EnemyState.State.RECOVER, false],
		]
	)


func test_the_attackbox_damages_the_player_it_touches_while_charging() -> void:
	var enemy: ChargerEnemy = _create_driven_charger()
	var body: RecordingBody = _create_player_body()
	_advance_into_the_charge(enemy)
	assert_int(enemy.brain.state).is_equal(EnemyState.State.CHARGE)

	_attackbox_of(enemy).body_entered.emit(body)

	assert_array(body.amounts).is_equal([ATTACK_DAMAGE])


func test_the_attackbox_damages_the_player_only_once_in_one_charge() -> void:
	var enemy: ChargerEnemy = _create_driven_charger()
	var body: RecordingBody = _create_player_body()
	var attackbox: Attackbox = _attackbox_of(enemy)
	_advance_into_the_charge(enemy)

	attackbox.body_entered.emit(body)
	# 同じ突進のフレームを 1 つ挟む: 与済みの記録を毎フレーム落とす実装は、離れて触れ直した
	# 相手へ 2 回目を与えてしまう。記録を落とすのは突進へ入る縁の 1 回だけである
	_step(enemy)
	attackbox.body_entered.emit(body)

	assert_int(enemy.brain.state).is_equal(EnemyState.State.CHARGE)
	assert_array(body.amounts).is_equal([ATTACK_DAMAGE])


func test_a_new_charge_lets_the_attackbox_damage_the_player_again() -> void:
	# 3.7 と分岐の両側である: 与済みの記録は 1 回の突進の間だけ持ち、次の突進では落とす
	var enemy: ChargerEnemy = _create_driven_charger()
	var body: RecordingBody = _create_player_body()
	var attackbox: Attackbox = _attackbox_of(enemy)
	_advance_into_the_charge(enemy)
	attackbox.body_entered.emit(body)

	_advance_into_the_next_charge(enemy)
	attackbox.body_entered.emit(body)

	assert_int(enemy.brain.state).is_equal(EnemyState.State.CHARGE)
	assert_array(body.amounts).is_equal([ATTACK_DAMAGE, ATTACK_DAMAGE])


func test_the_attackbox_pushes_no_error_for_a_body_without_take_damage() -> void:
	# `Hurtbox` の 6.5(親が `take_damage()` を持たなければ `push_error`)と非対称である:
	# 攻撃判定の mask 2 にはプレイヤー以外が載らず、素通りは異常ではなく想定内である
	var enemy: ChargerEnemy = _create_driven_charger()
	var attackbox: Attackbox = _attackbox_of(enemy)
	var plain_body: CharacterBody2D = auto_free(CharacterBody2D.new())
	_advance_into_the_charge(enemy)

	await assert_error(func() -> void: attackbox.body_entered.emit(plain_body)).is_success()

	# 与済みの記録を消費しないことも併せて見る: 素通りで記録を落とす実装は、同じ突進で
	# プレイヤーへ届かなくなる
	var body: RecordingBody = _create_player_body()
	attackbox.body_entered.emit(body)
	assert_array(body.amounts).is_equal([ATTACK_DAMAGE])


func test_the_charge_damages_a_player_body_it_runs_into() -> void:
	# `monitoring` の切り替えで攻撃判定を制御できること(spec.md §3 の未検証の前提)と、
	# 切り替えが物理フレームから駆動されていることの観測点。同期で駆動する他のケースは
	# 配線そのものを見ていない
	var enemy: ChargerEnemy = auto_free(CHARGER_SCENE.instantiate())
	var stats: EnemyStats = _create_stats()
	stats.gravity = FLOATING_GRAVITY
	stats.recover_time = LONG_RECOVER_TIME
	enemy.stats = stats
	enemy.position = SPAWN_POSITION
	add_child(enemy)
	var body: RecordingBody = _create_player_body()
	body.position = SPAWN_POSITION + Vector2(CONTACT_GAP, 0.0)
	add_child(body)
	enemy.target = body

	await await_millis(CHARGE_WAIT_MILLIS)

	# 硬直まで進んでいることを witness にする: 待ちが足りず突進が終わっていない場合と区別する
	assert_int(enemy.brain.state).is_equal(EnemyState.State.RECOVER)
	assert_bool(_attackbox_of(enemy).monitoring).is_false()
	assert_array(body.amounts).is_equal([ATTACK_DAMAGE])
