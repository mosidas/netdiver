extends GdUnitTestSuite

const ENEMY_PROJECTILE_SCENE: PackedScene = preload("res://src/weapon/enemy_projectile.tscn")

const PLACEHOLDER_SIZE: Vector2 = Vector2(4.0, 4.0)
const ENEMY_PROJECTILE_LAYER: int = 1 << 4
const TERRAIN_AND_PLAYER_MASK: int = (1 << 0) | (1 << 1)
const TERRAIN_LAYER: int = 1 << 0
const PLAYER_LAYER: int = 1 << 1

const SPEED: float = 120.0
const DAMAGE: int = 9
const MAX_DISTANCE: float = 400.0
# 待ちの間に必ず超える短さにする。射程で解放されることの検証を待ち時間に頼らない
const SHORT_MAX_DISTANCE: float = 30.0
# 原点からの距離が MAX_DISTANCE を超える発射位置。距離の基準が原点だと即座に解放される
const FAR_LAUNCH_POSITION: Vector2 = Vector2(500.0, 0.0)
const AXIS_DIRECTION: Vector2 = Vector2(1.0, 0.0)
const DIAGONAL_DIRECTION: Vector2 = Vector2(1.0, -1.0)
# 非正規化かつ成分が分数の向き。Vector2i へ丸める実装は (3, -1) となり別の角度へ飛ぶ
const OBLIQUE_DIRECTION: Vector2 = Vector2(3.0, -1.5)
# 下限と上限の両方に余裕を取る(60 Hz、1 フレーム 2.0px)。下限は射程で解放されるケースで、
# SHORT_MAX_DISTANCE を超える 16 フレーム目 = 267ms に対して約 2.6 倍。上限は射程に届かない
# ことを見るケースで、MAX_DISTANCE に達する 200 フレーム目 = 3333ms に対して約 4.8 倍の猶予が
# ある。消化した数はアサーションで確かめるため、待ち時間そのものには依存しない
const WAIT_MILLIS: int = 700
const TOLERANCE: Vector2 = Vector2(0.001, 0.001)

# 弾が数フレームで届く位置に置く。矩形の縁が x = 11.0 で接し、弾は 2.0px 刻みで進むため
# 縁とちょうど一致するフレームが無い(一致すると重なりの成立が Godot の境界の扱いに依存する)。
# 重なりは 6 フレーム目、`Area2D` の通知の 1 フレームの遅れを足して解放は 7 フレーム目
# = 117ms であり、WAIT_MILLIS 700ms はその約 6 倍。射程 MAX_DISTANCE に達するのは
# 200 フレーム目 = 3333ms で、待ちの 4.8 倍の先にある(待ちの間に射程で解放されない)
const BODY_POSITION: Vector2 = Vector2(21.0, 0.0)
const BODY_SIZE: Vector2 = Vector2(16.0, 16.0)


## `take_damage()` を持つ body。プレイヤーの代わりに置く: 相手を型ではなくメソッドの有無で
## 見分ける契約を、`Player` を持ち込まずに試す
class RecordingBody:
	extends CharacterBody2D

	var projectile: EnemyProjectile
	var amounts: Array[int] = []

	## ダメージを受けた時点で弾が解放待ちだったか。`queue_free()` は実行を打ち切らないため、
	## ダメージの回数だけでは解放を `take_damage()` の前へ移す実装と区別できない
	var queued_when_damaged: Array[bool] = []

	func take_damage(amount: int) -> void:
		amounts.append(amount)
		queued_when_damaged.append(projectile.is_queued_for_deletion())


func test_launch_moves_the_enemy_projectile_along_the_direction() -> void:
	var projectile: EnemyProjectile = _create_enemy_projectile()
	add_child(projectile)

	projectile.launch(AXIS_DIRECTION, SPEED, DAMAGE, MAX_DISTANCE)
	await await_millis(WAIT_MILLIS)

	# 待ちが足りずフレームを消化しなかった場合と、動かなかった場合を区別する
	var frames: int = projectile.frames_moved
	assert_int(frames).is_greater(0)
	# 期待値を実数で直接書かない: physics/common/physics_ticks_per_second を変えると変位も変わる
	var expected_x: float = _frame_step() * frames
	assert_vector(projectile.position).is_equal_approx(Vector2(expected_x, 0.0), TOLERANCE)
	assert_int(projectile.damage).is_equal(DAMAGE)


# 斜めを軸方向と別のケースにする: 変位を x 成分だけで組む実装は軸方向のケースを素通りする
func test_launch_normalizes_a_diagonal_direction() -> void:
	var projectile: EnemyProjectile = _create_enemy_projectile()
	add_child(projectile)

	projectile.launch(DIAGONAL_DIRECTION, SPEED, DAMAGE, MAX_DISTANCE)
	await await_millis(WAIT_MILLIS)

	var frames: int = projectile.frames_moved
	assert_int(frames).is_greater(0)
	var expected_distance: float = _frame_step() * frames
	var expected_position: Vector2 = DIAGONAL_DIRECTION.normalized() * expected_distance
	assert_float(projectile.position.length()).is_equal_approx(expected_distance, 0.001)
	assert_vector(projectile.position).is_equal_approx(expected_position, TOLERANCE)


# 向きは Vector2(任意方向)であり Vector2i(8 方向)ではない。長さ 3.354 の分数の向きを渡し、
# 速さが speed になること(正規化)と角度が保たれること(丸めない)の両方を見る
func test_launch_normalizes_an_oblique_direction_without_rounding_it() -> void:
	var projectile: EnemyProjectile = _create_enemy_projectile()
	add_child(projectile)

	projectile.launch(OBLIQUE_DIRECTION, SPEED, DAMAGE, MAX_DISTANCE)
	await await_millis(WAIT_MILLIS)

	var frames: int = projectile.frames_moved
	assert_int(frames).is_greater(0)
	var expected_distance: float = _frame_step() * frames
	var expected_position: Vector2 = OBLIQUE_DIRECTION.normalized() * expected_distance
	assert_float(projectile.position.length()).is_equal_approx(expected_distance, 0.001)
	assert_vector(projectile.position).is_equal_approx(expected_position, TOLERANCE)


func test_enemy_projectile_stays_in_place_until_launched() -> void:
	var projectile: EnemyProjectile = _create_enemy_projectile()
	var witness: EnemyProjectile = _create_enemy_projectile()
	add_child(projectile)
	add_child(witness)

	witness.launch(AXIS_DIRECTION, SPEED, DAMAGE, MAX_DISTANCE)
	await await_millis(WAIT_MILLIS)

	# 待ちの間に物理フレームが進んだことを、発射済みの弾で示す
	assert_int(witness.frames_moved).is_greater(0)
	assert_int(projectile.frames_moved).is_zero()
	assert_vector(projectile.position).is_equal(Vector2.ZERO)


func test_enemy_projectile_frees_itself_when_it_exceeds_max_distance() -> void:
	var projectile: EnemyProjectile = _create_enemy_projectile()
	var exit_positions: Array[Vector2] = []
	add_child(projectile)
	_record_position_on_exit(projectile, exit_positions)

	projectile.launch(AXIS_DIRECTION, SPEED, DAMAGE, SHORT_MAX_DISTANCE)
	await await_millis(WAIT_MILLIS)

	assert_bool(is_instance_valid(projectile)).is_false()
	assert_array(exit_positions).has_size(1)
	var travelled: float = exit_positions[0].length()
	assert_float(travelled).is_greater(SHORT_MAX_DISTANCE)
	# 超えた最初のフレームで解放する。まるまる 1 フレーム分の余裕までを許容する
	assert_float(travelled).is_less_equal(SHORT_MAX_DISTANCE + _frame_step())


# 斜めを軸方向と別のケースにする: 距離を x 成分だけで測る実装は軸方向のケースを素通りする
func test_max_distance_is_measured_along_a_diagonal_direction() -> void:
	var projectile: EnemyProjectile = _create_enemy_projectile()
	var exit_positions: Array[Vector2] = []
	add_child(projectile)
	_record_position_on_exit(projectile, exit_positions)

	projectile.launch(DIAGONAL_DIRECTION, SPEED, DAMAGE, SHORT_MAX_DISTANCE)
	await await_millis(WAIT_MILLIS)

	assert_bool(is_instance_valid(projectile)).is_false()
	assert_array(exit_positions).has_size(1)
	var travelled: float = exit_positions[0].length()
	assert_float(travelled).is_greater(SHORT_MAX_DISTANCE)
	assert_float(travelled).is_less_equal(SHORT_MAX_DISTANCE + _frame_step())


func test_enemy_projectile_keeps_flying_while_it_is_within_max_distance() -> void:
	var projectile: EnemyProjectile = _create_enemy_projectile()
	add_child(projectile)

	projectile.launch(AXIS_DIRECTION, SPEED, DAMAGE, MAX_DISTANCE)
	await await_millis(WAIT_MILLIS)

	assert_bool(is_instance_valid(projectile)).is_true()
	var frames: int = projectile.frames_moved
	assert_int(frames).is_greater(0)
	# 射程に届かないまま待ちが終わったことを確かめる。届いていれば解放が正しく、検証が空振りする
	var travelled: float = _frame_step() * frames
	assert_float(travelled).is_less(MAX_DISTANCE)
	assert_vector(projectile.position).is_equal_approx(Vector2(travelled, 0.0), TOLERANCE)


func test_max_distance_is_measured_from_the_launch_position() -> void:
	var projectile: EnemyProjectile = _create_enemy_projectile()
	# 「ツリーへ載せる → 位置を決める → launch()」の順で書く: 位置を先に決めると、射程の基準を
	# `_ready()` の時点(生成時の位置)で取る誤実装が同じ値を読めてしまい、素通りする
	add_child(projectile)
	projectile.position = FAR_LAUNCH_POSITION

	projectile.launch(AXIS_DIRECTION, SPEED, DAMAGE, MAX_DISTANCE)
	await await_millis(WAIT_MILLIS)

	assert_bool(is_instance_valid(projectile)).is_true()
	var frames: int = projectile.frames_moved
	assert_int(frames).is_greater(0)
	var travelled: float = _frame_step() * frames
	assert_float(travelled).is_less(MAX_DISTANCE)
	assert_vector(projectile.position).is_equal_approx(
		FAR_LAUNCH_POSITION + Vector2(travelled, 0.0), TOLERANCE
	)


func test_enemy_projectile_frees_itself_when_it_touches_terrain() -> void:
	var terrain: StaticBody2D = _create_terrain()
	var projectile: EnemyProjectile = _create_enemy_projectile()
	var exit_positions: Array[Vector2] = []
	add_child(terrain)
	add_child(projectile)
	_record_position_on_exit(projectile, exit_positions)

	projectile.launch(AXIS_DIRECTION, SPEED, DAMAGE, MAX_DISTANCE)
	await await_millis(WAIT_MILLIS)

	assert_bool(is_instance_valid(projectile)).is_false()
	_assert_released_on_contact(exit_positions)


# 地形の経路と分岐の両側である: ダメージを受けるのは `take_damage()` を持つ相手だけであり、
# 解放はどちらの経路でも起きる
func test_enemy_projectile_damages_the_player_it_touches_and_then_frees_itself() -> void:
	var projectile: EnemyProjectile = _create_enemy_projectile()
	var body: RecordingBody = _create_player_body(projectile)
	var exit_positions: Array[Vector2] = []
	add_child(body)
	add_child(projectile)
	_record_position_on_exit(projectile, exit_positions)

	projectile.launch(AXIS_DIRECTION, SPEED, DAMAGE, MAX_DISTANCE)
	await await_millis(WAIT_MILLIS)

	# 量は launch() で受け取った値である。既定の EnemyStats・実装の定数から読み直す実装は、
	# ここが DAMAGE(既定値と別の値)であることで落ちる
	assert_array(body.amounts).is_equal([DAMAGE])
	# ダメージを与えてから解放する。逆順の実装はここが [true] になる
	assert_array(body.queued_when_damaged).is_equal([false])
	assert_bool(is_instance_valid(projectile)).is_false()
	_assert_released_on_contact(exit_positions)


func test_enemy_projectile_pushes_no_error_for_a_body_without_take_damage() -> void:
	# メソッドの有無を見ずに全員へ与えようとする実装は、この経路で存在しないメソッドを呼ぶ。
	# 相手はプレイヤーと同じ `CharacterBody2D` に取る: 型とメソッドの有無が相関したスタブ
	# だけだと、`has_method()` を `body is CharacterBody2D` へ置き換える変異(spec.md §8 が
	# 禁じる「型で見る」実装)が素通りする
	var projectile: EnemyProjectile = _create_enemy_projectile()
	var plain_body: CharacterBody2D = auto_free(CharacterBody2D.new())
	add_child(projectile)

	await assert_error(func() -> void: projectile.body_entered.emit(plain_body)).is_success()

	assert_bool(projectile.is_queued_for_deletion()).is_true()


func test_enemy_projectile_scene_is_on_the_enemy_projectile_layer() -> void:
	var projectile: EnemyProjectile = _create_enemy_projectile()

	assert_int(projectile.collision_layer).is_equal(ENEMY_PROJECTILE_LAYER)
	assert_int(projectile.collision_mask).is_equal(TERRAIN_AND_PLAYER_MASK)


func test_enemy_projectile_scene_centers_a_4x4_placeholder_on_the_origin() -> void:
	var projectile: EnemyProjectile = _create_enemy_projectile()
	var placeholder: ColorRect = projectile.get_node("Placeholder")
	var collision_shape: CollisionShape2D = projectile.get_node("CollisionShape2D")
	var shape: RectangleShape2D = collision_shape.shape

	assert_vector(placeholder.size).is_equal(PLACEHOLDER_SIZE)
	assert_vector(placeholder.position).is_equal(-PLACEHOLDER_SIZE * 0.5)
	assert_vector(shape.size).is_equal(PLACEHOLDER_SIZE)
	assert_vector(collision_shape.position).is_equal(Vector2.ZERO)


func _create_enemy_projectile() -> EnemyProjectile:
	return auto_free(ENEMY_PROJECTILE_SCENE.instantiate())


## 地形の代わりに置く body。`take_damage()` を持たず、弾の mask のうち地形のレイヤに載る
func _create_terrain() -> StaticBody2D:
	var terrain: StaticBody2D = auto_free(StaticBody2D.new())
	terrain.collision_layer = TERRAIN_LAYER
	terrain.collision_mask = 0
	terrain.position = BODY_POSITION
	terrain.add_child(_create_collision_shape())
	return terrain


## プレイヤーの代わりに置く body。弾の mask のうちプレイヤーのレイヤに載せ、こちらからは
## 何も見ない(mask 0)
func _create_player_body(projectile: EnemyProjectile) -> RecordingBody:
	var body: RecordingBody = auto_free(RecordingBody.new())
	body.projectile = projectile
	body.collision_layer = PLAYER_LAYER
	body.collision_mask = 0
	body.position = BODY_POSITION
	body.add_child(_create_collision_shape())
	return body


# 親を auto_free するため子は登録しない: 親の解放で一緒に解放される
func _create_collision_shape() -> CollisionShape2D:
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = BODY_SIZE
	collision_shape.shape = rectangle
	return collision_shape


# 解放の原因が接触であることを位置で示す。縁が重なる位置より手前で解放されていたら別の原因で
# あり、2 フレーム分(重なりに届くまでに最大 1 フレーム、`Area2D` の重なりの通知の遅れで
# さらに 1 フレーム)を超えて進んでいたら判定が遅れている
func _assert_released_on_contact(exit_positions: Array[Vector2]) -> void:
	assert_array(exit_positions).has_size(1)
	var contact_x: float = BODY_POSITION.x - (BODY_SIZE.x + PLACEHOLDER_SIZE.x) * 0.5
	var step: float = _frame_step()
	assert_float(exit_positions[0].x).is_greater(contact_x)
	assert_float(exit_positions[0].x).is_less_equal(contact_x + 2.0 * step)


# 解放後は位置を読めないため、ツリーを離れる直前の位置を控える
func _record_position_on_exit(projectile: EnemyProjectile, positions: Array[Vector2]) -> void:
	var record: Callable = func() -> void: positions.append(projectile.position)
	projectile.tree_exiting.connect(record)


func _frame_step() -> float:
	return SPEED / float(Engine.physics_ticks_per_second)
