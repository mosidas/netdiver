extends GdUnitTestSuite

const SHOOTER_SCENE: PackedScene = preload("res://src/enemy/shooter_enemy.tscn")

# 埋め込みサブリソースの `resource_path` は
# `res://src/enemy/shooter_enemy.tscn::Resource_xxxx` になり、この比較で落ちる
const SHOOTER_STATS_PATH: String = "res://src/enemy/shooter_stats.tres"
const ENEMY_PROJECTILE_SCENE_PATH: String = "res://src/weapon/enemy_projectile.tscn"

const PLACEHOLDER_SIZE: Vector2 = Vector2(16.0, 16.0)

const ENEMY_LAYER: int = 1 << 3
const TERRAIN_MASK: int = 1 << 0
const PLAYER_PROJECTILE_MASK: int = 1 << 2

# 2 進で厳密に表せる delta。攻撃の速さ(128.0)と組で 1 フレームちょうど 2.0px 進む
const DELTA: float = 1.0 / 64.0

# 射撃型の既定値(600.0 / 160.0 / 0.4 / 10 / 120.0 / 1.5 / 216.0)とは別の値にする: 既定の
# ままだと、`stats` を読まず値を直書きした実装でも緑になる。時間は 2 進で厳密に表せる値を使う
const GRAVITY: float = 512.0
const DETECT_RANGE: float = 96.0
const TELEGRAPH_TIME: float = 0.25
const RECOVER_TIME: float = 0.75
const ATTACK_DAMAGE: int = 7
const ATTACK_SPEED: float = 128.0
const BULLET_MAX_DISTANCE: float = 24.0

# 弾が 1 フレームで進む距離(ちょうど 2.0px)。射程 24.0 は 12 フレームぶんであり、
# 超えるのは 13 フレーム目である
const BULLET_STEP: float = ATTACK_SPEED * DELTA

# 敵を載せる入れ物の位置と、入れ物の中での敵の位置。どちらも原点から離す: 原点のままだと、
# 発射位置を親の座標系と取り違える実装・`_ready()` の時点で控える実装が同じ値を読めてしまう。
# 敵の位置は射程(24.0)より遠く取る: 位置を決める前に `launch()` を呼ぶ実装は、射程の基準が
# 原点のままになって弾が 1 フレーム目で解放される
const CONTAINER_POSITION: Vector2 = Vector2(64.0, -32.0)
const SPAWN_POSITION: Vector2 = Vector2(20.0, -48.0)

# 標的の配置と、そこへ向かう単位ベクトル。各行は [敵からの変位, 期待する向き]。
# 斜めは 45 度以外に取る: 45 度は `Vector2i` へ丸めても同じ角度になり、丸める実装が素通りする。
# 真上・真下は `direction.x == 0.0` になる向きであり、射撃型が実際に作る配置である
const SHOT_TABLE: Array = [
	[Vector2(30.0, 40.0), Vector2(0.6, 0.8)],
	[Vector2(-24.0, -32.0), Vector2(-0.6, -0.8)],
	[Vector2(0.0, -40.0), Vector2(0.0, -1.0)],
	[Vector2(0.0, 40.0), Vector2(0.0, 1.0)],
]

# 索敵範囲(96.0)の内側の配置。距離は 50.0
const NEAR_OFFSET: Vector2 = Vector2(30.0, 40.0)
# 索敵範囲の外側の配置。予備動作へ入らない
const FAR_OFFSET: Vector2 = Vector2(200.0, 0.0)
# 予備動作の途中で標的が退く先と、そこへ向かう単位ベクトル。索敵範囲の外(距離 200.0)であり、
# 向きは NEAR_OFFSET の (0.6, 0.8) と別の (-0.6, 0.8) になる。既定値では索敵範囲 160・予備動作
# 0.4 秒・プレイヤーの速度 100 であり、予備動作の間に範囲外へ抜けるのは日常的に起きる経路である
const ESCAPE_OFFSET: Vector2 = Vector2(-120.0, 160.0)
const ESCAPE_DIRECTION: Vector2 = Vector2(-0.6, 0.8)
# 軸方向の配置。1 フレームの変位が 2.0px ちょうどになり、射程の境界をフレーム数で押さえられる
const AXIS_OFFSET: Vector2 = Vector2(-50.0, 0.0)

# 待機の間も観測するフレーム数。待機(0.75 秒 = 50 フレーム)の内側に収める
const COOLDOWN_OBSERVED_FRAMES: int = 4

# 水平の速度を 0 にすることの観測点で、直前に与える速度。0 から始めると代入そのものを落とす
# 変異が素通りする
const STRAY_SPEED: float = 33.0

const TOLERANCE: Vector2 = Vector2(0.001, 0.001)

# 3 物理フレーム(60 Hz で 50 ms)に対して余裕を取る: CI のランナーが遅い場合でも消化させる
const WAIT_MILLIS: int = 500

# 実フレームで 1 発だけ撃たせるための数値。弾道の高さを保つ重力(既定の 512.0 だと敵が
# 落ちながら撃ち、向きが配置から決まらない)と、待ちの間に射程で消えない長さの射程を使う
const FLOATING_GRAVITY: float = 1.0
const LONG_BULLET_MAX_DISTANCE: float = 400.0
# 60 Hz での予備動作の満了(ceil(0.25 * 60) + 2 = 17 フレーム = 283ms)の 2.1 倍であり、
# 2 発目(1 周 = 予備動作 + 待機 0.75 秒。64 フレーム = 1067ms)の 0.56 倍。下限と上限の
# 両方に余裕がある
const SHOT_WAIT_MILLIS: int = 600


## 消化した物理フレーム数を数えるだけのノード。待ち時間が足りずフレームを消化しなかった場合と、
## 動かないことが正しい場合を区別する
class PhysicsFrameCounter:
	extends Node

	var frames: int = 0

	func _physics_process(_delta: float) -> void:
		frames += 1


# スイートのメンバに抱える: ローカル変数だけで持つと、生成された弾を数える先への参照が切れる
var _container: Node2D


## テスト用の数値。シーンが指す `shooter_stats.tres` は書き換えない: 1 個を全個体で共有する
## ため、書き換えると他のテストへ波及する
func _create_stats() -> EnemyStats:
	var stats: EnemyStats = auto_free(EnemyStats.new())
	stats.gravity = GRAVITY
	# 射撃型は定点である。0 は「その振る舞いを持たない」ことを表す
	stats.move_speed = 0.0
	stats.detect_range = DETECT_RANGE
	stats.telegraph_time = TELEGRAPH_TIME
	stats.attack_damage = ATTACK_DAMAGE
	stats.attack_speed = ATTACK_SPEED
	stats.attack_duration = 0.0
	stats.recover_time = RECOVER_TIME
	stats.bullet_max_distance = BULLET_MAX_DISTANCE
	return stats


## 敵を親のあるノードの下に置く。弾の追加先(敵の親)を、スイート自身と区別できるようにする
func _create_container() -> Node2D:
	_container = auto_free(Node2D.new())
	_container.position = CONTAINER_POSITION
	add_child(_container)
	return _container


## 自動の物理フレームを止めた射撃型。発射は `_physics_process` から駆動されるため、同期で
## 進めたフレーム数と `brain` の滞在時間の対応を保つには自動のフレームを止める必要がある。
## 位置はツリーへ載せた後に決める: 先に決めると、発射位置を `_ready()` の時点で控える実装が
## 同じ値を読めてしまい素通りする(タスク 4.1 の申し送りと同型)
func _create_driven_shooter() -> ShooterEnemy:
	var container: Node2D = _create_container()
	# 入れ物を auto_free するため子は登録しない: 入れ物の解放で一緒に解放される
	var enemy: ShooterEnemy = SHOOTER_SCENE.instantiate()
	enemy.stats = _create_stats()
	container.add_child(enemy)
	enemy.position = SPAWN_POSITION
	enemy.set_physics_process(false)
	return enemy


## 標的を敵とは別の親(スイート)の下へ置く。向きを親の座標系で測る実装は、この配置で角度が
## ずれる
func _place_target(enemy: ShooterEnemy, offset: Vector2) -> Node2D:
	var target: Node2D = auto_free(Node2D.new())
	add_child(target)
	target.global_position = enemy.global_position + offset
	enemy.target = target
	return target


## 1 物理フレームぶんの駆動を同期で起こす(`move_and_slide()` は含めない)。速度の決定と
## 状態の進行はどちらも `_physics_process` から駆動される
func _step(enemy: ShooterEnemy) -> void:
	enemy._update_velocity(DELTA)
	enemy._advance_brain(DELTA)


## 予備動作を抜けるまでに要するフレーム数。`Brain` は「判定 → 加算」の順で進めるため、状態へ
## 入るフレームと満了のフレームが 1 つずつ加わる(`ceil(duration / delta) + 2`)。実数を
## 直書きしない: 滞在時間や delta を動かすとフレーム数も変わる
func _frames_to_fire() -> int:
	return int(ceil(TELEGRAPH_TIME / DELTA)) + 2


func _projectiles_in_the_container() -> Array:
	var found: Array = []
	for child: Node in _container.get_children():
		if child is EnemyProjectile:
			found.append(child)
	return found


## 発射のフレームまで進め、生成された弾を返す。生成されなかった場合は null を返す
func _fire_once(enemy: ShooterEnemy) -> EnemyProjectile:
	for _frame: int in _frames_to_fire():
		_step(enemy)
	var projectiles: Array = _projectiles_in_the_container()
	if projectiles.size() != 1:
		return null
	return projectiles[0]


func test_shooter_scene_centers_a_16x16_placeholder_on_the_origin() -> void:
	var enemy: ShooterEnemy = auto_free(SHOOTER_SCENE.instantiate())
	var placeholder: ColorRect = enemy.get_node("Placeholder")
	var collision_shape: CollisionShape2D = enemy.get_node("CollisionShape2D")
	var shape: RectangleShape2D = collision_shape.shape

	assert_vector(placeholder.size).is_equal(PLACEHOLDER_SIZE)
	assert_vector(placeholder.position).is_equal(-PLACEHOLDER_SIZE * 0.5)
	assert_vector(shape.size).is_equal(PLACEHOLDER_SIZE)
	assert_vector(collision_shape.position).is_equal(Vector2.ZERO)


func test_shooter_scene_is_on_the_enemy_layer_and_collides_with_terrain() -> void:
	var enemy: ShooterEnemy = auto_free(SHOOTER_SCENE.instantiate())

	assert_int(enemy.collision_layer).is_equal(ENEMY_LAYER)
	assert_int(enemy.collision_mask).is_equal(TERRAIN_MASK)


func test_shooter_scene_carries_a_hurtbox_and_no_attackbox() -> void:
	# 被弾判定は 2 種で共有する(`hurtbox.tscn`)。近接の攻撃判定は突進型だけが持つ
	var enemy: ShooterEnemy = auto_free(SHOOTER_SCENE.instantiate())
	var hurtbox: Hurtbox = enemy.get_node("Hurtbox")
	var hurt_shape_node: CollisionShape2D = hurtbox.get_node("CollisionShape2D")
	var hurt_shape: RectangleShape2D = hurt_shape_node.shape

	assert_int(hurtbox.collision_layer).is_equal(ENEMY_LAYER)
	assert_int(hurtbox.collision_mask).is_equal(PLAYER_PROJECTILE_MASK)
	assert_vector(hurt_shape.size).is_equal(PLACEHOLDER_SIZE)
	assert_vector(hurtbox.position).is_equal(Vector2.ZERO)
	assert_bool(enemy.has_node("Attackbox")).is_false()


func test_shooter_scene_reads_the_stats_from_the_shared_file() -> void:
	var enemy: ShooterEnemy = auto_free(SHOOTER_SCENE.instantiate())

	assert_object(enemy.stats).is_instanceof(EnemyStats)
	assert_str(enemy.stats.resource_path).is_equal(SHOOTER_STATS_PATH)


func test_shooter_scene_does_not_copy_the_stats_per_instance() -> void:
	var enemy: ShooterEnemy = auto_free(SHOOTER_SCENE.instantiate())

	assert_bool(enemy.stats.resource_local_to_scene).is_false()


func test_shooter_scene_carries_the_enemy_projectile_scene() -> void:
	var enemy: ShooterEnemy = auto_free(SHOOTER_SCENE.instantiate())
	var scene: PackedScene = enemy.projectile_scene

	assert_object(scene).is_not_null()
	assert_str(scene.resource_path).is_equal(ENEMY_PROJECTILE_SCENE_PATH)
	var spawned: Node = auto_free(scene.instantiate())
	assert_object(spawned).is_instanceof(EnemyProjectile)


func test_shooter_returns_the_shooter_kind() -> void:
	var enemy: ShooterEnemy = auto_free(SHOOTER_SCENE.instantiate())

	assert_int(enemy.kind()).is_equal(EnemyKind.Kind.SHOOTER)


func test_shooter_starts_without_a_target() -> void:
	var enemy: ShooterEnemy = auto_free(SHOOTER_SCENE.instantiate())

	assert_object(enemy.target).is_null()
	assert_float(enemy.target_distance()).is_equal(INF)


func test_the_shooter_exposes_its_brain() -> void:
	var enemy: ShooterEnemy = _create_driven_shooter()

	assert_object(enemy.brain).is_instanceof(ShooterBrain)
	assert_int(enemy.brain.state).is_equal(EnemyState.State.IDLE)


func test_the_shooter_fires_one_projectile_toward_the_target() -> void:
	for row: Array in SHOT_TABLE:
		var offset: Vector2 = row[0]
		var expected_direction: Vector2 = row[1]
		var context: String = "offset=%s" % offset
		var enemy: ShooterEnemy = _create_driven_shooter()
		_place_target(enemy, offset)

		var projectile: EnemyProjectile = _fire_once(enemy)

		assert_object(projectile).append_failure_message(context).is_not_null()
		if projectile == null:
			continue
		# 向きと速さを 1 フレームの変位で見る: 期待値は単位ベクトル × 速さ × delta であり、
		# 向きを丸める実装・速さを直書きする実装はここで落ちる
		var start: Vector2 = projectile.position
		projectile._physics_process(DELTA)
		var travelled: Vector2 = projectile.position - start

		assert_vector(travelled).append_failure_message(context).is_equal_approx(
			expected_direction * BULLET_STEP, TOLERANCE
		)
		# 量は `stats` から流れる。既定値(10)と別の値であることで直書きの実装が落ちる
		assert_int(projectile.damage).append_failure_message(context).is_equal(ATTACK_DAMAGE)


func test_the_shot_starts_where_the_shooter_stands_and_joins_its_parent() -> void:
	var enemy: ShooterEnemy = _create_driven_shooter()
	_place_target(enemy, NEAR_OFFSET)

	var projectile: EnemyProjectile = _fire_once(enemy)

	assert_object(projectile).is_not_null()
	if projectile == null:
		return
	# 自分の子にしない: 弾が発射元と一緒に動いてしまう
	assert_object(projectile.get_parent()).is_same(_container)
	assert_vector(projectile.position).is_equal(enemy.position)
	assert_vector(projectile.global_position).is_equal(enemy.global_position)


func test_the_shot_carries_the_bullet_max_distance_from_the_stats() -> void:
	# 射程 24.0 は 1 フレーム 2.0px で 12 フレームぶんである。12 フレーム目までは生き、
	# 13 フレーム目に解放される。射程を実装へ直書きする変異・別の項目から読む変異、および
	# 位置を決める前に `launch()` を呼ぶ変異(射程の基準が原点になり 1 フレーム目で解放される)
	# がこの境界で落ちる
	var enemy: ShooterEnemy = _create_driven_shooter()
	_place_target(enemy, AXIS_OFFSET)

	var projectile: EnemyProjectile = _fire_once(enemy)

	assert_object(projectile).is_not_null()
	if projectile == null:
		return
	var frames_within_range: int = int(BULLET_MAX_DISTANCE / BULLET_STEP)
	for _frame: int in frames_within_range:
		projectile._physics_process(DELTA)
	assert_int(projectile.frames_moved).is_equal(frames_within_range)
	assert_bool(projectile.is_queued_for_deletion()).is_false()

	projectile._physics_process(DELTA)

	assert_bool(projectile.is_queued_for_deletion()).is_true()


func test_the_shooter_fires_only_on_the_frame_the_telegraph_ends() -> void:
	# 毎フレーム撃つ実装・発射のフレームがずれる実装を、連続したフレーム列で落とす
	var enemy: ShooterEnemy = _create_driven_shooter()
	_place_target(enemy, NEAR_OFFSET)
	var frames_to_fire: int = _frames_to_fire()
	var observed: Array[int] = []
	var expected: Array[int] = []

	for frame: int in frames_to_fire + COOLDOWN_OBSERVED_FRAMES:
		_step(enemy)
		observed.append(_projectiles_in_the_container().size())
		expected.append(0 if frame < frames_to_fire - 1 else 1)

	assert_array(observed).is_equal(expected)
	# 待機まで進んでいることを witness にする: 予備動作のままなら、そもそも発射のフレームを
	# 観測できていない
	assert_int(enemy.brain.state).is_equal(EnemyState.State.COOLDOWN)


func test_the_shooter_holds_its_fire_while_the_target_is_out_of_the_detect_range() -> void:
	# 標的までの距離が `brain` へ実際に流れていることの観測点。距離を定数(`0.0` 等)へ
	# 置き換える実装は、標的が画面外でも予備動作と発射を繰り返し、ここで弾を出して落ちる。
	# 1 周ぶん(発射のフレーム + 待機の一部)回しても 1 発も出ないことを見る
	var enemy: ShooterEnemy = _create_driven_shooter()
	_place_target(enemy, FAR_OFFSET)

	for _frame: int in _frames_to_fire() + COOLDOWN_OBSERVED_FRAMES:
		_step(enemy)

	assert_array(_projectiles_in_the_container()).is_empty()
	assert_int(enemy.brain.state).is_equal(EnemyState.State.IDLE)


func test_a_target_that_leaves_the_detect_range_mid_telegraph_still_draws_the_shot() -> void:
	# 発射の条件は「`update()` が真 + 標的が居る + 弾のシーンが設定済み」の 3 つだけであり、
	# 距離は条件ではない(要件 4.7)。予備動作は距離の変化で打ち切られない(要件 4.11)ため、
	# 予備動作の途中で索敵範囲の外へ抜けた回も弾は出る。発射の条件へ距離を足す実装はここで落ちる
	var enemy: ShooterEnemy = _create_driven_shooter()
	var target: Node2D = _place_target(enemy, NEAR_OFFSET)
	for _frame: int in _frames_to_fire() - 1:
		_step(enemy)
	# 発射の 1 フレーム前に予備動作の途中であることを witness にする
	assert_int(enemy.brain.state).is_equal(EnemyState.State.TELEGRAPH)
	target.global_position = enemy.global_position + ESCAPE_OFFSET

	_step(enemy)

	var projectiles: Array = _projectiles_in_the_container()
	assert_int(projectiles.size()).is_equal(1)
	assert_int(enemy.brain.state).is_equal(EnemyState.State.COOLDOWN)
	if projectiles.size() != 1:
		return
	# 向きは発射のフレームの標的の位置を指す: 予備動作へ入った時点の向きを控える実装は、
	# 退く前の (0.6, 0.8) を向いてここで落ちる
	var projectile: EnemyProjectile = projectiles[0]
	var start: Vector2 = projectile.position
	projectile._physics_process(DELTA)

	assert_vector(projectile.position - start).is_equal_approx(
		ESCAPE_DIRECTION * BULLET_STEP, TOLERANCE
	)


func test_the_shooter_keeps_its_horizontal_velocity_at_zero() -> void:
	# 索敵範囲の内外と、到達できる 3 状態のそれぞれで見る: `IDLE` の枝だけだと、代入を
	# `if brain.state == EnemyState.State.IDLE:` で囲う変異が素通りする。直前に非ゼロの速度を
	# 作るのは、0 から始めると代入そのものを落とす変異が素通りするためである。
	# 状態は観測するフレームの**開始時点**のものである(`_update_velocity()` は `brain` を
	# 進める前に走る)。各行は [文脈, 標的の変位, 観測の前に進めるフレーム数, 開始時点の状態]
	var cases: Array = [
		["idle in range", NEAR_OFFSET, 0, EnemyState.State.IDLE],
		["idle out of range", FAR_OFFSET, 0, EnemyState.State.IDLE],
		["telegraph", NEAR_OFFSET, 1, EnemyState.State.TELEGRAPH],
		["cooldown", NEAR_OFFSET, _frames_to_fire(), EnemyState.State.COOLDOWN],
	]

	for row: Array in cases:
		var context: String = row[0]
		var offset: Vector2 = row[1]
		var lead_frames: int = row[2]
		var state: int = row[3]
		var enemy: ShooterEnemy = _create_driven_shooter()
		_place_target(enemy, offset)
		for _frame: int in lead_frames:
			_step(enemy)
		# 意図した状態に達していることを witness にする: 達していないと、どの行も `IDLE` の
		# 繰り返しになって変異を落とせない
		assert_int(enemy.brain.state).append_failure_message(context).is_equal(state)
		enemy.velocity.x = STRAY_SPEED

		_step(enemy)

		assert_float(enemy.velocity.x).append_failure_message(context).is_equal(0.0)


func test_the_shooter_keeps_the_gravity_of_the_base() -> void:
	# 基底の `_update_velocity()` を呼んでいることの観測点。`super` を落とす変異はここで
	# 落ちる(基底の物理は突進型のシーンを器にして `enemy_test.gd` が押さえている)
	var enemy: ShooterEnemy = _create_driven_shooter()

	_step(enemy)

	assert_float(enemy.velocity.y).is_equal_approx(GRAVITY * DELTA, 0.001)


func test_the_shooter_fires_from_its_own_physics_frames() -> void:
	# 発射が物理フレームから駆動されていることの観測点。同期で駆動する他のケースは呼ぶ順を
	# テスト側が決めており、配線そのもの(`_physics_process` からの呼び出し)を見ていない
	var container: Node2D = _create_container()
	var enemy: ShooterEnemy = SHOOTER_SCENE.instantiate()
	var stats: EnemyStats = _create_stats()
	stats.gravity = FLOATING_GRAVITY
	stats.bullet_max_distance = LONG_BULLET_MAX_DISTANCE
	enemy.stats = stats
	container.add_child(enemy)
	enemy.position = SPAWN_POSITION
	# 標的は敵より後にツリーへ載せる: 物理フレームは木の順に走る
	_place_target(enemy, NEAR_OFFSET)

	await await_millis(SHOT_WAIT_MILLIS)

	# 待機まで進んでいることを witness にする: 予備動作のままなら、そもそも発射のフレームへ
	# 到達していない
	assert_int(enemy.brain.state).is_equal(EnemyState.State.COOLDOWN)
	var projectiles: Array = _projectiles_in_the_container()
	assert_int(projectiles.size()).is_equal(1)
	if projectiles.size() != 1:
		return
	var projectile: EnemyProjectile = projectiles[0]
	assert_int(projectile.frames_moved).is_greater(0)
	assert_int(projectile.damage).is_equal(ATTACK_DAMAGE)


func test_the_shooter_falls_straight_down_across_physics_frames() -> void:
	# 実フレームで駆動する経路の観測点。同期で駆動する他のケースは呼ぶ順をテスト側が決めており、
	# 配線そのものを見ていない
	var container: Node2D = _create_container()
	var enemy: ShooterEnemy = SHOOTER_SCENE.instantiate()
	enemy.stats = _create_stats()
	container.add_child(enemy)
	enemy.position = SPAWN_POSITION
	var counter: PhysicsFrameCounter = PhysicsFrameCounter.new()
	enemy.add_child(counter)
	# 標的は敵より後にツリーへ載せる: 物理フレームは木の順に走る
	_place_target(enemy, NEAR_OFFSET)

	await await_millis(WAIT_MILLIS)

	assert_int(counter.frames).is_greater(0)
	assert_float(enemy.position.x).is_equal(SPAWN_POSITION.x)
	# 落下していることを witness にする: 位置がまったく動かないなら、水平の 0 は「フレームが
	# 進まなかった」ことの結果かもしれない
	assert_float(enemy.position.y).is_greater(SPAWN_POSITION.y)
