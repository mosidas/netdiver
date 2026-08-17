extends GdUnitTestSuite

const PULSE_SCENE_PATH: String = "res://src/ability/analysis_pulse.tscn"

# 既存の placeholder の色を持つシーン。色の値はテスト側へ複製せず、ここから読み出す。
# 仮ステージの地形は 2 色あり、床・壁は `enemy_dev_stage.tscn`、足場は `dev_stage.tscn` にある。
# タスク 5.2 の新しい仮ステージは同じ床・壁の色を写すため、既存の 2 つで比較の対象を覆える
const EXISTING_PLACEHOLDER_SCENE_PATHS: Array[String] = [
	"res://src/player/player.tscn",
	"res://src/enemy/charger_enemy.tscn",
	"res://src/enemy/shooter_enemy.tscn",
	"res://src/weapon/projectile.tscn",
	"res://src/weapon/enemy_projectile.tscn",
	"res://src/stage/damage_zone.tscn",
	"res://src/stage/enemy_dev_stage.tscn",
	"res://src/stage/dev_stage.tscn",
]

const DEV_STAGE_SCENE_PATH: String = "res://src/stage/dev_stage.tscn"
const STEP_PLACEHOLDER_PATH: String = "Step1/Placeholder"
const FLOOR_PLACEHOLDER_PATH: String = "Floor/Placeholder"

const PLACEHOLDER_SIZE: Vector2 = Vector2(6.0, 6.0)
const EXPECTED_COLOR_RECT_COUNT: int = 1

# 上の 8 シーンから読める相異なる色の数(プレイヤー・2 種の敵・2 種の弾・ダメージ帯・
# 床と壁・足場)。集めた色が空でも 4.16 が緑になることを防ぐ下限
const MINIMUM_EXISTING_COLOR_COUNT: int = 8


func _collect_nodes(node: Node, into: Array[Node]) -> void:
	into.append(node)
	for child: Node in node.get_children():
		_collect_nodes(child, into)


func _color_rects(root: Node) -> Array[ColorRect]:
	var nodes: Array[Node] = []
	_collect_nodes(root, nodes)
	var rects: Array[ColorRect] = []
	for node: Node in nodes:
		if node is ColorRect:
			rects.append(node as ColorRect)
	return rects


# 当たり判定は直下だけでなく木の全体で見る: 子孫へ 1 段下げただけの配置は直下の検査を素通りする
func _collision_objects(root: Node) -> Array[Node]:
	var nodes: Array[Node] = []
	_collect_nodes(root, nodes)
	var found: Array[Node] = []
	for node: Node in nodes:
		if node is CollisionObject2D:
			found.append(node)
	return found


func _instantiate(path: String) -> Node:
	var scene: PackedScene = load(path)
	assert_object(scene).append_failure_message(path).is_not_null()
	# ツリーへ載せない: `add_child()` すると `_physics_process` が走り、構成ではなく
	# 動いた後の姿を見ることになる(spec.md §7 の検証の形式)
	var root: Node = auto_free(scene.instantiate())
	assert_object(root).append_failure_message(path).is_not_null()
	return root


func _instantiate_pulse() -> AnalysisPulse:
	var pulse: Node = _instantiate(PULSE_SCENE_PATH)
	assert_bool(pulse is AnalysisPulse).is_true()
	return pulse as AnalysisPulse


func _placeholder() -> ColorRect:
	var rects: Array[ColorRect] = _color_rects(_instantiate_pulse())
	assert_int(rects.size()).is_equal(EXPECTED_COLOR_RECT_COUNT)
	return rects[0]


func _existing_placeholder_colors() -> Array[Color]:
	var colors: Array[Color] = []
	for path: String in EXISTING_PLACEHOLDER_SCENE_PATHS:
		for rect: ColorRect in _color_rects(_instantiate(path)):
			if not colors.has(rect.color):
				colors.append(rect.color)
	return colors


func test_the_scene_holds_exactly_one_color_rect() -> void:
	var rects: Array[ColorRect] = _color_rects(_instantiate_pulse())

	var names: Array[String] = []
	for rect: ColorRect in rects:
		names.append(str(rect.name))
	assert_int(rects.size()).append_failure_message(str(names)).is_equal(
		EXPECTED_COLOR_RECT_COUNT
	)


func test_the_placeholder_measures_six_by_six_pixels() -> void:
	assert_vector(_placeholder().size).is_equal(PLACEHOLDER_SIZE)


func test_the_placeholder_is_centered_on_the_node_origin() -> void:
	# 左上を原点に置くと、演出が撃破位置から半分ずれて出る
	assert_vector(_placeholder().position).is_equal(-PLACEHOLDER_SIZE * 0.5)


func test_the_placeholder_color_is_absent_from_the_existing_placeholder_colors() -> void:
	var color: Color = _placeholder().color
	var existing: Array[Color] = _existing_placeholder_colors()

	# 「6 つのどれとも異なる」ではなく「読み出した集合に含まれない」で書く:
	# placeholder が増えたときに比較の対象が自動で追随する
	assert_array(existing).append_failure_message(
		"%s は既存の placeholder の色 %s に含まれる" % [color, existing]
	).not_contains([color])


func test_the_compared_colors_cover_both_terrain_colors_of_the_dev_stages() -> void:
	# 比較の対象から `dev_stage.tscn` が抜けると、足場と同じ色を選んでも 4.16 が緑になる
	var dev_stage: Node = _instantiate(DEV_STAGE_SCENE_PATH)
	var step: ColorRect = dev_stage.get_node(NodePath(STEP_PLACEHOLDER_PATH))
	var floor_rect: ColorRect = dev_stage.get_node(NodePath(FLOOR_PLACEHOLDER_PATH))
	assert_object(step).is_not_null()
	assert_object(floor_rect).is_not_null()
	# 足場が床と同じ色ならこの番人は何も守っていない
	assert_bool(step.color == floor_rect.color).append_failure_message(
		str(step.color)
	).is_false()

	var existing: Array[Color] = _existing_placeholder_colors()

	assert_array(existing).append_failure_message(str(existing)).contains(
		[step.color, floor_rect.color]
	)
	assert_int(existing.size()).append_failure_message(str(existing)).is_greater_equal(
		MINIMUM_EXISTING_COLOR_COUNT
	)


func test_the_scene_holds_no_collision_object() -> void:
	var found: Array[Node] = _collision_objects(_instantiate_pulse())

	var names: Array[String] = []
	for node: Node in found:
		names.append("%s(%s)" % [node.name, node.get_class()])
	assert_int(found.size()).append_failure_message(str(names)).is_equal(0)


func test_the_same_scan_finds_a_collision_object_in_a_stub_that_holds_one() -> void:
	# 走査が常に 0 を返す変異を落とす対。孫の位置に置いて再帰そのものも観測する
	var stub: Node2D = auto_free(Node2D.new())
	var branch: Node2D = Node2D.new()
	stub.add_child(branch)
	branch.add_child(Area2D.new())

	assert_int(_collision_objects(stub).size()).is_equal(1)
