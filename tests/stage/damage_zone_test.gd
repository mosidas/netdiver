extends GdUnitTestSuite

const DAMAGE_ZONE_SCENE: PackedScene = preload("res://src/stage/damage_zone.tscn")
const PLAYER_SCENE: PackedScene = preload("res://src/player/player.tscn")

const PLAYER_MASK: int = 1 << 1
const TERRAIN_LAYER: int = 1 << 0
const NO_LAYER: int = 0

# 既定値(15)と別の値にする: 実装が既定値を直書きしても緑になる退行を捕らえる
const DAMAGE: int = 7
const MAX_HEALTH: int = 60

# 待ちの 1.5 秒より確実に長く取る: 既定の 3.0 のままにすると「待ちの間は回復しない」ことが
# 既定値に依存し、値の出どころの一本化が検証できない
const REGEN_DELAY: float = 4.0
const REGEN_PER_SECOND: float = 8.0

# 周期の境界 1.0 秒と次の 2.0 秒の中間で判定する。前後に 0.5 秒の余裕がある
const WAIT_MILLIS: int = 1500
const EXPECTED_HITS: int = 2

const FLOOR_SIZE: Vector2 = Vector2(200.0, 16.0)
const FLOOR_POSITION: Vector2 = Vector2.ZERO
const ZONE_POSITION: Vector2 = Vector2(0.0, -30.0)
const PLAYER_START: Vector2 = Vector2(0.0, -40.0)
# 領域の外は横へずらして取る。真上に置くと落下の途中で領域を通り抜けてダメージが入る
const OUTSIDE_POSITION: Vector2 = Vector2(80.0, -40.0)
# 領域から引き離す先。床の外なので落下し続けるが、離脱の検証には足場が要らない
const AWAY_POSITION: Vector2 = Vector2(0.0, -400.0)

# 入力を読まない: Input はここでの検証対象ではなく、headless では InputEvent が通らない
const IDLE_INPUT_SOURCE: String = """
extends RefCounted


func read() -> PlayerCommand:
	return PlayerCommand.new()
"""


# Callable は RefCounted の所有者を強く参照しない。スイートが抱えないと入力の差し替え先が
# 解放され、_physics_process が null のインスタンスを呼ぶ
var _input_stubs: Array = []


func _make_idle_input() -> RefCounted:
	var script := GDScript.new()
	script.source_code = IDLE_INPUT_SOURCE
	script.reload()
	var stub: RefCounted = script.new()
	_input_stubs.append(stub)
	return stub


func _make_stats() -> PlayerStats:
	var stats := PlayerStats.new()
	stats.max_health = MAX_HEALTH
	stats.regen_delay = REGEN_DELAY
	stats.regen_per_second = REGEN_PER_SECOND
	return stats


func _make_floor() -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = TERRAIN_LAYER
	body.position = FLOOR_POSITION
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = FLOOR_SIZE
	shape_node.shape = shape
	body.add_child(shape_node)
	return body


func _make_player(start: Vector2) -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	# stats の差し替えは add_child() より前に行う: Health は _ready() で作られ、
	# 後から差し替えても max_health・regen_delay は古い値のまま残る
	player.stats = _make_stats()
	player.input_source = _make_idle_input().read
	player.position = start
	return player


# 床の上へプレイヤーを立たせる: 足場が無いと 1.5 秒で 600px 以上落下して領域から抜け、
# 実装が正しくても 2 回目のダメージが入らない
func _build_stage(player_start: Vector2) -> Array:
	var container: Node2D = auto_free(Node2D.new())
	var zone: DamageZone = DAMAGE_ZONE_SCENE.instantiate()
	zone.damage = DAMAGE
	zone.position = ZONE_POSITION
	var player: Player = _make_player(player_start)

	container.add_child(_make_floor())
	container.add_child(zone)
	container.add_child(player)
	add_child(container)

	return [zone, player]


func test_the_zone_watches_only_the_player_layer() -> void:
	var zone: DamageZone = auto_free(DAMAGE_ZONE_SCENE.instantiate())

	assert_int(zone.collision_mask).is_equal(PLAYER_MASK)
	assert_int(zone.collision_layer).is_equal(NO_LAYER)


func test_touching_the_zone_costs_health_once_per_second() -> void:
	var built: Array = _build_stage(PLAYER_START)
	var player: Player = built[1]

	await await_millis(WAIT_MILLIS)

	assert_int(player.health.current).is_equal(MAX_HEALTH - DAMAGE * EXPECTED_HITS)


func test_a_player_outside_the_zone_keeps_its_health() -> void:
	var built: Array = _build_stage(OUTSIDE_POSITION)
	var player: Player = built[1]

	await await_millis(WAIT_MILLIS)

	assert_int(player.health.current).is_equal(MAX_HEALTH)


func test_leaving_the_zone_stops_the_damage() -> void:
	var built: Array = _build_stage(PLAYER_START)
	var zone: DamageZone = built[0]
	var player: Player = built[1]

	# 1 回目(接触)だけを受けた状態から離脱させ、周期の 2 回目が来ないことを見る
	await await_millis(200)
	var after_entering: int = player.health.current
	zone.position = AWAY_POSITION
	await await_millis(WAIT_MILLIS)

	assert_int(after_entering).is_equal(MAX_HEALTH - DAMAGE)
	assert_int(player.health.current).is_equal(after_entering)
