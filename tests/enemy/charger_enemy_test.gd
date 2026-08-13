extends GdUnitTestSuite

const CHARGER_SCENE: PackedScene = preload("res://src/enemy/charger_enemy.tscn")

# 埋め込みサブリソースの `resource_path` は
# `res://src/enemy/charger_enemy.tscn::Resource_xxxx` になり、この比較で落ちる
const CHARGER_STATS_PATH: String = "res://src/enemy/charger_stats.tres"

const PLACEHOLDER_SIZE: Vector2 = Vector2(16.0, 16.0)

const ENEMY_LAYER: int = 1 << 3
const TERRAIN_MASK: int = 1 << 0


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
