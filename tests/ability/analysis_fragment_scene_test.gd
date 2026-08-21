extends GdUnitTestSuite

const FRAGMENT_SCENE_PATH: String = "res://src/ability/analysis_fragment.tscn"

# 既存の placeholder の色を持つシーン。色の値はテスト側へ複製せず、ここから読み出す。
# 複製すると、`.tscn` の色が後で変わったときに検査だけが古い値のまま残る。
# 仮ステージの地形は 2 色あり、床・壁は 3 つの仮ステージが共有し、足場は `dev_stage.tscn`
# だけが持つ。足場を取りこぼすと、その色を選んでも検査が緑になる
const EXISTING_PLACEHOLDER_SCENE_PATHS: Array[String] = [
	"res://src/player/player.tscn",
	"res://src/enemy/charger_enemy.tscn",
	"res://src/enemy/shooter_enemy.tscn",
	"res://src/weapon/projectile.tscn",
	"res://src/weapon/enemy_projectile.tscn",
	"res://src/stage/damage_zone.tscn",
	"res://src/stage/dev_stage.tscn",
	"res://src/stage/enemy_dev_stage.tscn",
	"res://src/stage/analysis_dev_stage.tscn",
]

const DEV_STAGE_SCENE_PATH: String = "res://src/stage/dev_stage.tscn"
const STEP_PLACEHOLDER_PATHS: Array[String] = [
	"Step1/Placeholder",
	"Step2/Placeholder",
	"Step3/Placeholder",
]
const FLOOR_PLACEHOLDER_PATH: String = "Floor/Placeholder"

const PLACEHOLDER_SIZE: Vector2 = Vector2(8.0, 8.0)
const EXPECTED_COLOR_RECT_COUNT: int = 1
const EXPECTED_COLLISION_SHAPE_COUNT: int = 1

const NO_COLLISION_LAYER: int = 0
const PLAYER_LAYER_MASK: int = 1 << 1

# 上の 9 シーンから読める相異なる色の数(プレイヤー・2 種の敵・2 種の弾・ダメージ帯・
# 床と壁・足場)。集めた色が空でも色の検査が緑になることを防ぐ下限
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


# 直下だけでなく木の全体で見る: 子孫へ 1 段下げただけの配置は直下の検査を素通りする
func _collision_shapes(root: Node) -> Array[CollisionShape2D]:
	var nodes: Array[Node] = []
	_collect_nodes(root, nodes)
	var found: Array[CollisionShape2D] = []
	for node: Node in nodes:
		if node is CollisionShape2D:
			found.append(node as CollisionShape2D)
	return found


func _instantiate(path: String) -> Node:
	var scene: PackedScene = load(path)
	assert_object(scene).append_failure_message(path).is_not_null()
	# ツリーへ載せない: `add_child()` すると `_ready()` と `_physics_process` が走り、
	# 構成ではなく動いた後の姿を見ることになる(spec.md §7 の検証の形式)
	var root: Node = auto_free(scene.instantiate())
	assert_object(root).append_failure_message(path).is_not_null()
	return root


func _instantiate_fragment() -> AnalysisFragment:
	var fragment: Node = _instantiate(FRAGMENT_SCENE_PATH)
	assert_bool(fragment is AnalysisFragment).append_failure_message(
		fragment.get_class()
	).is_true()
	return fragment as AnalysisFragment


func _placeholder(fragment: AnalysisFragment) -> ColorRect:
	var rects: Array[ColorRect] = _color_rects(fragment)
	assert_int(rects.size()).is_equal(EXPECTED_COLOR_RECT_COUNT)
	return rects[0]


func _collision_shape(fragment: AnalysisFragment) -> CollisionShape2D:
	var found: Array[CollisionShape2D] = _collision_shapes(fragment)
	assert_int(found.size()).is_equal(EXPECTED_COLLISION_SHAPE_COUNT)
	return found[0]


func _existing_placeholder_colors() -> Array[Color]:
	var colors: Array[Color] = []
	for path: String in EXISTING_PLACEHOLDER_SCENE_PATHS:
		for rect: ColorRect in _color_rects(_instantiate(path)):
			if not colors.has(rect.color):
				colors.append(rect.color)
	return colors


func test_the_scene_puts_the_fragment_on_no_collision_layer() -> void:
	# レイヤとマスクを別々に見る: 片方だけの検査は、もう片方を書き換える変異を素通りさせる
	assert_int(_instantiate_fragment().collision_layer).is_equal(NO_COLLISION_LAYER)


func test_the_scene_masks_the_player_layer_only() -> void:
	# 完全一致で見る: `has` 相当の非排他な検査だと、他のレイヤを足す変異が素通りする
	assert_int(_instantiate_fragment().collision_mask).is_equal(PLAYER_LAYER_MASK)


func test_the_scene_holds_exactly_one_color_rect() -> void:
	var rects: Array[ColorRect] = _color_rects(_instantiate_fragment())

	var names: Array[String] = []
	for rect: ColorRect in rects:
		names.append(str(rect.name))
	assert_int(rects.size()).append_failure_message(str(names)).is_equal(
		EXPECTED_COLOR_RECT_COUNT
	)


func test_the_placeholder_measures_eight_by_eight_pixels() -> void:
	assert_vector(_placeholder(_instantiate_fragment()).size).is_equal(PLACEHOLDER_SIZE)


func test_the_placeholder_is_centered_on_the_node_origin() -> void:
	var fragment: AnalysisFragment = _instantiate_fragment()
	var placeholder: ColorRect = _placeholder(fragment)

	# 親がルートであることを対に置く: 子孫へ下げると `position` の基準が断片の原点でなくなり、
	# 中心に見えて実際はずれる
	assert_object(placeholder.get_parent()).is_same(fragment)
	# 左上を原点に置くと、断片が撃破位置から半分ずれて出る
	assert_vector(placeholder.position).is_equal(-PLACEHOLDER_SIZE * 0.5)


func test_the_collision_shape_measures_eight_by_eight_pixels() -> void:
	var shape: Shape2D = _collision_shape(_instantiate_fragment()).shape
	assert_object(shape).is_not_null()
	assert_bool(shape is RectangleShape2D).append_failure_message(
		shape.get_class()
	).is_true()

	assert_vector((shape as RectangleShape2D).size).is_equal(PLACEHOLDER_SIZE)


func test_the_collision_shape_is_centered_on_the_node_origin() -> void:
	var fragment: AnalysisFragment = _instantiate_fragment()
	var collision_shape: CollisionShape2D = _collision_shape(fragment)

	assert_object(collision_shape.get_parent()).is_same(fragment)
	# `CollisionShape2D` の `position` は形の中心を指す。原点に置けば当たり判定が断片の
	# 中心に来る(`ColorRect` は左上を指すため基準が違う)
	assert_vector(collision_shape.position).is_equal(Vector2.ZERO)


func test_the_placeholder_color_is_absent_from_the_existing_placeholder_colors() -> void:
	var color: Color = _placeholder(_instantiate_fragment()).color
	var existing: Array[Color] = _existing_placeholder_colors()

	# 走査の空振りと区別する: 集めた色が空だと `not_contains` は何も見ずに緑になる
	assert_int(existing.size()).append_failure_message(str(existing)).is_greater_equal(
		MINIMUM_EXISTING_COLOR_COUNT
	)
	# 「9 つのどれとも異なる」ではなく「読み出した集合に含まれない」で書く:
	# placeholder が増えたときに比較の対象が自動で追随する
	assert_array(existing).append_failure_message(
		"%s は既存の placeholder の色 %s に含まれる" % [color, existing]
	).not_contains([color])


func test_the_compared_colors_cover_both_terrain_colors_of_the_dev_stages() -> void:
	# 比較の対象から `dev_stage.tscn` が抜けると、足場と同じ色を選んでも色の検査が緑になる
	var dev_stage: Node = _instantiate(DEV_STAGE_SCENE_PATH)
	var floor_rect: ColorRect = dev_stage.get_node(NodePath(FLOOR_PLACEHOLDER_PATH))
	assert_object(floor_rect).is_not_null()

	var existing: Array[Color] = _existing_placeholder_colors()
	assert_array(existing).append_failure_message(str(existing)).contains(
		[floor_rect.color]
	)

	for path: String in STEP_PLACEHOLDER_PATHS:
		var step: ColorRect = dev_stage.get_node(NodePath(path))
		assert_object(step).append_failure_message(path).is_not_null()
		# 足場が床と同じ色ならこの番人は何も守っていない
		assert_bool(step.color == floor_rect.color).append_failure_message(
			"%s: %s" % [path, step.color]
		).is_false()
		assert_array(existing).append_failure_message(
			"%s: %s / %s" % [path, step.color, existing]
		).contains([step.color])


func test_the_same_scan_finds_nodes_nested_below_the_root() -> void:
	# 走査が常に空を返す変異を落とす対。孫の位置に置いて再帰そのものも観測する
	var stub: Node2D = auto_free(Node2D.new())
	var branch: Node2D = Node2D.new()
	stub.add_child(branch)
	branch.add_child(ColorRect.new())
	branch.add_child(CollisionShape2D.new())

	assert_int(_color_rects(stub).size()).is_equal(1)
	assert_int(_collision_shapes(stub).size()).is_equal(1)
