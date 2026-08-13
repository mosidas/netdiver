extends GdUnitTestSuite

const HURTBOX_SCENE: PackedScene = preload("res://src/enemy/hurtbox.tscn")
const CHARGER_SCENE: PackedScene = preload("res://src/enemy/charger_enemy.tscn")
const PROJECTILE_SCENE: PackedScene = preload("res://src/weapon/projectile.tscn")
const HURTBOX_SOURCE_PATH: String = "res://src/enemy/hurtbox.gd"

const ENEMY_LAYER: int = 1 << 3
const PLAYER_PROJECTILE_LAYER: int = 1 << 2
const HURTBOX_SIZE: Vector2 = Vector2(16.0, 16.0)

# 実装の文言を参照しない: 参照するとアサーションが自明になり、文言の退行を検出できない
const MISSING_TAKE_DAMAGE_ERROR: String = (
	"Hurtbox: 親が take_damage() を持たない。被弾を中継せずに返る"
)

# 既定値(30 / 15)と別の値を使う: 既定のままだと、相手の値を読まず直書きした実装でも緑になる
const MAX_HP: int = 24
const DAMAGE: int = 7

const PROJECTILE_SPEED: float = 180.0
const PROJECTILE_MAX_DISTANCE: float = 400.0
const PROJECTILE_SIZE: Vector2 = Vector2(4.0, 4.0)
const ENEMY_POSITION: Vector2 = Vector2.ZERO
# 弾が数フレームで届く距離に置く。射程では解放されない近さでもある
const PROJECTILE_START: Vector2 = Vector2(-40.0, 0.0)
# 敵の左端(-8)と弾の右端が重なる x。ここより手前で消えたなら接触以外が原因である
const CONTACT_X: float = ENEMY_POSITION.x - (HURTBOX_SIZE.x + PROJECTILE_SIZE.x) * 0.5
# 弾の軌道から敵が落ちない重力にする: 既定の 600 px/s² だと、弾が届く前に敵が矩形の高さを
# 超えて落ち、当たらないことが原因の緑になる
const SLOW_GRAVITY: float = 1.0

# 数フレーム(60 Hz で 1 フレーム約 17 ms)に対して余裕を取る: CI のランナーが遅い場合でも
# 物理フレームを消化させる
const WAIT_MILLIS: int = 500


## `damage` を持つ領域。`Projectile` を持ち込まずに中継の契約だけを試す
class DamagingArea:
	extends Area2D

	var damage: int = 0


## `take_damage()` を持つ所有者。受け取った量を控えて外から読めるようにする
class RecordingOwner:
	extends Node2D

	var amounts: Array[int] = []

	func take_damage(amount: int) -> void:
		amounts.append(amount)


func _create_shape(size: Vector2) -> CollisionShape2D:
	# 親を auto_free するため子は登録しない: 親の解放で一緒に解放される
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = size
	collision_shape.shape = rectangle
	return collision_shape


## 所有者ごとツリーへ載せた `Hurtbox`。`_ready()` を通さないと `area_entered` が繋がらない
func _add_hurtbox_under(owner_node: Node2D) -> Hurtbox:
	add_child(owner_node)
	var hurtbox: Hurtbox = auto_free(HURTBOX_SCENE.instantiate())
	owner_node.add_child(hurtbox)
	return hurtbox


func _create_damaging_area(damage: int) -> DamagingArea:
	var area: DamagingArea = auto_free(DamagingArea.new())
	area.damage = damage
	area.collision_layer = PLAYER_PROJECTILE_LAYER
	area.collision_mask = 0
	area.add_child(_create_shape(HURTBOX_SIZE))
	return area


func _create_plain_area() -> Area2D:
	var area: Area2D = auto_free(Area2D.new())
	area.collision_layer = PLAYER_PROJECTILE_LAYER
	area.collision_mask = 0
	area.add_child(_create_shape(HURTBOX_SIZE))
	return area


func _create_enemy() -> ChargerEnemy:
	var enemy: ChargerEnemy = auto_free(CHARGER_SCENE.instantiate())
	# シーンが指す `charger_stats.tres` を書き換えない: 1 個を全個体で共有するため、
	# 書き換えると他のテストへ波及する
	var stats: EnemyStats = auto_free(EnemyStats.new())
	stats.max_hp = MAX_HP
	stats.gravity = SLOW_GRAVITY
	enemy.stats = stats
	enemy.position = ENEMY_POSITION
	return enemy


func _hurtbox_of(enemy: ChargerEnemy) -> Hurtbox:
	return enemy.get_node("Hurtbox")


func _frame_step() -> float:
	return PROJECTILE_SPEED / float(Engine.physics_ticks_per_second)


func test_hurtbox_scene_is_on_the_enemy_layer_and_watches_player_projectiles() -> void:
	var hurtbox: Hurtbox = auto_free(HURTBOX_SCENE.instantiate())

	assert_int(hurtbox.collision_layer).is_equal(ENEMY_LAYER)
	assert_int(hurtbox.collision_mask).is_equal(PLAYER_PROJECTILE_LAYER)


func test_hurtbox_scene_carries_a_16x16_shape_on_the_origin() -> void:
	var hurtbox: Hurtbox = auto_free(HURTBOX_SCENE.instantiate())
	var collision_shape: CollisionShape2D = hurtbox.get_node("CollisionShape2D")
	var shape: RectangleShape2D = collision_shape.shape

	assert_vector(shape.size).is_equal(HURTBOX_SIZE)
	assert_vector(collision_shape.position).is_equal(Vector2.ZERO)


func test_the_charger_carries_a_hurtbox_that_does_not_stick_out_of_its_body() -> void:
	# はみ出すと、弾の解放(本体との接触)と被弾(`Hurtbox`)の片方だけが成立しうる
	var enemy: ChargerEnemy = auto_free(CHARGER_SCENE.instantiate())
	var body_shape_node: CollisionShape2D = enemy.get_node("CollisionShape2D")
	var body_shape: RectangleShape2D = body_shape_node.shape
	var hurtbox: Hurtbox = _hurtbox_of(enemy)
	var hurtbox_shape_node: CollisionShape2D = hurtbox.get_node("CollisionShape2D")
	var hurtbox_shape: RectangleShape2D = hurtbox_shape_node.shape

	assert_vector(hurtbox_shape.size).is_equal(body_shape.size)
	assert_vector(hurtbox.position).is_equal(Vector2.ZERO)
	assert_vector(hurtbox_shape_node.position).is_equal(body_shape_node.position)


func test_the_hurtbox_of_the_charger_keeps_the_layers_of_the_shared_scene() -> void:
	var enemy: ChargerEnemy = auto_free(CHARGER_SCENE.instantiate())

	var hurtbox: Hurtbox = _hurtbox_of(enemy)

	assert_int(hurtbox.collision_layer).is_equal(ENEMY_LAYER)
	assert_int(hurtbox.collision_mask).is_equal(PLAYER_PROJECTILE_LAYER)


func test_hurtbox_relays_the_damage_of_an_entering_area_to_its_owner() -> void:
	var owner_node: RecordingOwner = auto_free(RecordingOwner.new())
	_add_hurtbox_under(owner_node)
	var area: DamagingArea = _create_damaging_area(DAMAGE)
	add_child(area)

	await await_millis(WAIT_MILLIS)

	assert_array(owner_node.amounts).is_equal([DAMAGE])


func test_hurtbox_ignores_an_area_without_a_damage_property() -> void:
	var owner_node: RecordingOwner = auto_free(RecordingOwner.new())
	var hurtbox: Hurtbox = _add_hurtbox_under(owner_node)
	var area: Area2D = _create_plain_area()
	add_child(area)

	await await_millis(WAIT_MILLIS)

	# 重なりが成立したことを併せて見る: 待ちが足りずに何も起きなかった場合と区別する
	assert_array(hurtbox.get_overlapping_areas()).contains([area])
	assert_array(owner_node.amounts).is_empty()


func test_hurtbox_pushes_no_error_for_an_area_without_a_damage_property() -> void:
	# 6.2 の「何もしない」には `push_error` を出さないことも含む。所有者の検査を `damage` の
	# 検査より前に置く実装は、このケースだけが落ちる
	var hurtbox: Hurtbox = _add_hurtbox_under(auto_free(Node2D.new()))
	var area: Area2D = _create_plain_area()

	# ツリーへ載せずに通知だけを起こす: 物理フレームで起きる `push_error` は
	# `assert_error` の観測窓の外にある
	await assert_error(func() -> void: hurtbox.area_entered.emit(area)).is_success()


func test_hurtbox_pushes_an_error_when_its_owner_cannot_take_damage() -> void:
	var hurtbox: Hurtbox = _add_hurtbox_under(auto_free(Node2D.new()))
	var area: DamagingArea = _create_damaging_area(DAMAGE)

	await (
		assert_error(func() -> void: hurtbox.area_entered.emit(area))
		. is_push_error(MISSING_TAKE_DAMAGE_ERROR)
	)

	assert_bool(is_instance_valid(area)).is_true()


func test_hurtbox_does_not_release_the_area_that_entered_it() -> void:
	var owner_node: RecordingOwner = auto_free(RecordingOwner.new())
	_add_hurtbox_under(owner_node)
	var area: DamagingArea = _create_damaging_area(DAMAGE)
	add_child(area)

	await await_millis(WAIT_MILLIS)

	# 中継が起きたことを witness にする: 重なりが成立していなければ解放されないのは自明になる
	assert_array(owner_node.amounts).is_equal([DAMAGE])
	assert_bool(is_instance_valid(area)).is_true()
	assert_bool(area.is_queued_for_deletion()).is_false()


func test_hurtbox_never_frees_anything() -> void:
	var source: String = FileAccess.get_file_as_string(HURTBOX_SOURCE_PATH)

	assert_str(source).is_not_empty()
	# `queue_free(` と `free(` の両方を落とす: 弾の解放は弾自身が行う
	assert_str(source).not_contains("free(")


func test_a_player_projectile_reduces_the_hp_and_is_released_by_itself() -> void:
	var enemy: ChargerEnemy = _create_enemy()
	add_child(enemy)
	var projectile: Projectile = auto_free(PROJECTILE_SCENE.instantiate())
	projectile.position = PROJECTILE_START
	add_child(projectile)
	# 解放後は位置を読めないため、ツリーを離れる直前の位置を控える
	var exit_positions: Array[Vector2] = []
	projectile.tree_exiting.connect(func() -> void: exit_positions.append(projectile.position))

	projectile.launch(Vector2i(1, 0), PROJECTILE_SPEED, DAMAGE, PROJECTILE_MAX_DISTANCE)
	await await_millis(WAIT_MILLIS)

	assert_int(enemy.hp).is_equal(MAX_HP - DAMAGE)
	assert_bool(enemy.is_defeated).is_false()
	assert_bool(is_instance_valid(projectile)).is_false()
	assert_array(exit_positions).has_size(1)
	assert_float(exit_positions[0].x).is_greater(CONTACT_X)
	# 上限は 2 フレーム分。重なりに届くまでに最大 1 フレーム、`Area2D` の重なりの通知が
	# 1 物理フレーム遅れるためさらに 1 フレーム
	assert_float(exit_positions[0].x).is_less_equal(CONTACT_X + 2.0 * _frame_step())


func test_three_primary_hits_defeat_the_charger() -> void:
	# 弾の damage をプレイヤー側の既定値から読む: 撃破の粒度は 2 つの単位の値の関係であり、
	# テストへ写すと片方が動いたときに緑のままになる
	var player_stats: PlayerStats = auto_free(PlayerStats.new())
	var primary_damage: int = player_stats.primary_damage
	var enemy: ChargerEnemy = auto_free(CHARGER_SCENE.instantiate())
	var emissions: Array = []
	enemy.defeated.connect(func(kind: int) -> void: emissions.append(kind))

	enemy.take_damage(primary_damage)
	enemy.take_damage(primary_damage)
	var emissions_after_two_hits: Array = emissions.duplicate()
	enemy.take_damage(primary_damage)

	assert_array(emissions_after_two_hits).is_empty()
	assert_array(emissions).is_equal([EnemyKind.Kind.CHARGER])
	assert_int(enemy.hp).is_equal(0)
