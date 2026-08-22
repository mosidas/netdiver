extends GdUnitTestSuite

const STAGE_SCENE_PATH: String = "res://src/stage/analysis_dev_stage.tscn"
const STAGE_SCRIPT_PATH: String = "res://src/stage/analysis_dev_stage.gd"
const STAGE_DIRECTORY: String = "res://src/stage"
const SCENE_EXTENSION: String = "tscn"

const STAGE_SCENE: PackedScene = preload("res://src/stage/analysis_dev_stage.tscn")

const TERRAIN_LAYER: int = 1 << 0

const FLOOR_NAME: String = "Floor"
const WALL_NAMES: Array[String] = ["WallLeft", "WallRight"]
const PLAYER_NAME: String = "Player"
const ACTOR_NAMES: Array[String] = ["Player", "ShooterEnemy", "ChargerEnemy"]
const SHAPE_NAME: String = "CollisionShape2D"

const DEFEATED_HANDLER_NAME: String = "_on_enemy_defeated"
const DIED_HANDLER_NAME: String = "_on_player_died"

# 撃破の接続が束縛する引数の数。ハンドラは `[kind, NodePath]` を受け取り、束縛は後ろの 1 つ
const EXPECTED_BOUND_ARGUMENT_COUNT: int = 1

const EXPECTED_ENEMY_COUNT: int = 2
const EXPECTED_SHOOTER_COUNT: int = 1
const EXPECTED_CHARGER_COUNT: int = 1
const EXPECTED_PLAYER_COUNT: int = 1
const EXPECTED_ACTOR_COUNT: int = 3
const EXPECTED_ANALYSIS_STAGE_SCENE_COUNT: int = 1

# 走査が空振りしていないことの下限。`src/stage/` には仮ステージが 3 つ以上ある
const MINIMUM_SCANNED_SCENE_COUNT: int = 3

# 脅威の圏の半径。閾値「160 + その敵の detect_range」の 160 にあたる。
# 敵ごとの索敵範囲はテストへ直書きせず、その敵の `stats` から読む
const THREAT_RADIUS: float = 160.0
const MAX_ENEMIES_IN_THREAT_RING: int = 2

# 出現の仕組みに使われる型。ステージのどこにも現れないこと
const SPAWNER_CLASS_NAMES: Array[String] = ["Timer", "MultiplayerSpawner"]

# ルートが持ってよい `PackedScene` の `@export`。「1 つだけ」で見る:
# 「`fragment_scene` があること」だけを見ると、消し残った `pulse_scene` が素通りする
const EXPECTED_ROOT_PACKED_SCENE_EXPORTS: Array[String] = ["fragment_scene"]

# シーンが持ってよい `PackedScene` の参照。いずれも弾か断片であり、敵を出す口ではない。
# 「一致すること」ではなく「この集合に含まれること」で見る: 参照の有無ではなく、敵のシーンを
# 指す参照が現れないことがここの関心である
const ALLOWED_PACKED_SCENE_PROPERTIES: Array[String] = [
	"Player.projectile_scene",
	"ShooterEnemy.projectile_scene",
	"AnalysisDevStage.fragment_scene",
]

# 上の集合の検査が空振りしていないことの witness。撃つ側の 2 つは配置だけで必ず現れる
const REQUIRED_PACKED_SCENE_PROPERTIES: Array[String] = [
	"Player.projectile_scene",
	"ShooterEnemy.projectile_scene",
]

# 実フレームで敵の数が変わらないことを見る待ち時間。
# 下限: 物理フレームが 1 つ以上進むこと(60Hz で約 12 フレーム)。
# 上限: プレイヤーが死んで再読込が走らないこと。手前の射撃型は索敵の圏内に居るが、予備動作を
# 終えてから弾がプレイヤーまで飛ぶまでに 1 秒以上かかるため、この時間内に当たりは届かない
const OBSERVED_MILLIS: int = 200

const POSITION_TOLERANCE: float = 0.001


# ツリーへ載せない: `add_child()` すると `_ready()` と `_physics_process` が走り、
# 検証したい初期位置が動く(シーンの構成を検証するテストの規約)
func _instantiate_stage() -> Node2D:
	var stage: Node2D = auto_free(STAGE_SCENE.instantiate())
	assert_object(stage).is_not_null()
	return stage


func _collect_nodes(node: Node, into: Array[Node]) -> void:
	into.append(node)
	for child: Node in node.get_children():
		_collect_nodes(child, into)


func _nodes_of(stage: Node) -> Array[Node]:
	var nodes: Array[Node] = []
	_collect_nodes(stage, nodes)
	return nodes


# 敵をステージの直下ではなく木の全体から数える: 中間ノードの下へ隠した 3 体目は、直下だけを
# 見ていると素通りする
func _enemies_in(stage: Node) -> Array[Enemy]:
	var enemies: Array[Enemy] = []
	for node: Node in _nodes_of(stage):
		if node is Enemy:
			enemies.append(node as Enemy)
	return enemies


func _enemies_in_the_whole_tree() -> Array[Enemy]:
	var enemies: Array[Enemy] = []
	for node: Node in _nodes_of(get_tree().root):
		if node is Enemy:
			enemies.append(node as Enemy)
	return enemies


# アクタを名前ではなく型で集める: 名前の一覧で引くと、同じ名前のまま別の型へ置き換える
# 変異と、名前を変えただけの配置の両方が観測できなくなる
func _actors_in(stage: Node) -> Array[Node2D]:
	var actors: Array[Node2D] = []
	for node: Node in _nodes_of(stage):
		if node is Player or node is Enemy:
			actors.append(node as Node2D)
	return actors


func _color_rects_of(node: Node) -> Array[ColorRect]:
	var rects: Array[ColorRect] = []
	for child: Node in node.get_children():
		if child is ColorRect:
			rects.append(child as ColorRect)
	return rects


# 見た目の範囲。`ColorRect` の `position` は矩形の左上を指す
func _visual_rect(node: Node) -> Rect2:
	var rects: Array[ColorRect] = _color_rects_of(node)
	assert_int(rects.size()).append_failure_message(str(node.name)).is_equal(1)
	if rects.size() != 1:
		return Rect2()
	var rect: ColorRect = rects[0]
	return Rect2(rect.global_position, rect.size)


func _rect_size(body: Node) -> Vector2:
	var shape_node: CollisionShape2D = body.get_node_or_null(NodePath(SHAPE_NAME))
	assert_object(shape_node).append_failure_message(str(body.name)).is_not_null()
	if shape_node == null:
		return Vector2.ZERO
	assert_bool(shape_node.shape is RectangleShape2D).append_failure_message(
		str(body.name)
	).is_true()
	if not (shape_node.shape is RectangleShape2D):
		return Vector2.ZERO
	return (shape_node.shape as RectangleShape2D).size


# 当たりの範囲。`CollisionShape2D` の `position` は形の中心を指すため、見た目の矩形とは
# 基準が違う。両方を見るのは、片方だけを動かす変異を通さないためである
func _collision_rect(body: Node) -> Rect2:
	var size: Vector2 = _rect_size(body)
	var shape_node: CollisionShape2D = body.get_node_or_null(NodePath(SHAPE_NAME))
	if shape_node == null:
		return Rect2()
	return Rect2(shape_node.global_position - size * 0.5, size)


func _terrain_bodies(stage: Node) -> Array[Node]:
	var terrain: Array[Node] = []
	for child: Node in stage.get_children():
		if child is StaticBody2D:
			terrain.append(child)
	return terrain


func _distance_to_player(stage: Node, enemy: Enemy) -> float:
	var player: Node2D = stage.get_node(NodePath(PLAYER_NAME))
	return enemy.global_position.distance_to(player.global_position)


func _viewport_width() -> float:
	# 基準解像度はステージではなくプロジェクト設定が持つ。テストへ複製しない
	var width: float = float(ProjectSettings.get_setting("display/window/size/viewport_width"))
	assert_float(width).is_greater(0.0)
	return width


func _packed_scene_export_names(node: Node) -> Array[String]:
	var names: Array[String] = []
	for property: Dictionary in node.get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		# 値ではなく宣言の型で見る: `node.get(...) is PackedScene` は、宣言だけ残って
		# 値が未設定になった `@export` を見落とす
		if int(property["type"]) != TYPE_OBJECT:
			continue
		if str(property["class_name"]) != "PackedScene":
			continue
		names.append(str(property["name"]))
	return names


func test_the_scene_root_carries_the_stage_script() -> void:
	var stage := _instantiate_stage()

	assert_bool(stage is AnalysisDevStage).append_failure_message(
		str(stage.get_class())
	).is_true()
	# 型だけでなくスクリプトの出どころまで見る: 配線の実装を写した別のスクリプトを付ける形は
	# 型の検査だけでは落ちない
	var script: Script = stage.get_script()
	assert_object(script).is_not_null()
	assert_str(str(script.resource_path)).is_equal(STAGE_SCRIPT_PATH)


func test_the_project_holds_exactly_one_analysis_dev_stage_scene() -> void:
	# ファイル名を固定で列挙しない: 列挙すると、3 つ目の仮ステージを足しても検査が通る。
	# `src/stage/` を走査してルートの型で数える
	var directory: DirAccess = DirAccess.open(STAGE_DIRECTORY)
	assert_object(directory).is_not_null()
	if directory == null:
		return

	var scanned: Array[String] = []
	var analysis_stages: Array[String] = []
	for file_name: String in directory.get_files():
		if file_name.get_extension() != SCENE_EXTENSION:
			continue
		var path: String = STAGE_DIRECTORY.path_join(file_name)
		scanned.append(path)
		var scene: PackedScene = load(path)
		assert_object(scene).append_failure_message(path).is_not_null()
		if scene == null:
			continue
		var root: Node = auto_free(scene.instantiate())
		if root is AnalysisDevStage:
			analysis_stages.append(path)

	# 走査が空振りしていないこと。0 件を数えても「1 つだけ」は成立しない
	assert_int(scanned.size()).append_failure_message(str(scanned)).is_greater_equal(
		MINIMUM_SCANNED_SCENE_COUNT
	)
	assert_array(analysis_stages).append_failure_message(str(analysis_stages)).has_size(
		EXPECTED_ANALYSIS_STAGE_SCENE_COUNT
	)
	assert_array(analysis_stages).append_failure_message(str(analysis_stages)).contains(
		[STAGE_SCENE_PATH]
	)


func test_the_stage_places_terrain_and_the_three_actors() -> void:
	var stage := _instantiate_stage()

	assert_bool(stage.get_node_or_null(NodePath(FLOOR_NAME)) is StaticBody2D).append_failure_message(
		FLOOR_NAME
	).is_true()
	for wall_name: String in WALL_NAMES:
		assert_bool(stage.get_node_or_null(NodePath(wall_name)) is StaticBody2D).append_failure_message(
			wall_name
		).is_true()

	assert_bool(stage.get_node_or_null(^"Player") is Player).is_true()
	assert_bool(stage.get_node_or_null(^"ShooterEnemy") is ShooterEnemy).is_true()
	assert_bool(stage.get_node_or_null(^"ChargerEnemy") is ChargerEnemy).is_true()

	# 子は宣言した 6 つだけであること(数え漏らし・重複・余計な配置を固定する)
	var child_names: Array[String] = []
	for child: Node in stage.get_children():
		child_names.append(str(child.name))
	var expected_children: Array[String] = [FLOOR_NAME]
	expected_children.append_array(WALL_NAMES)
	expected_children.append_array(ACTOR_NAMES)
	assert_array(child_names).append_failure_message(str(child_names)).contains_exactly_in_any_order(
		expected_children
	)


func test_the_stage_holds_one_shooter_and_one_charger() -> void:
	# 種別ごとの体数を直接固定する: 脅威の圏の検査だけに任せると、同じ種別を 2 体置く
	# 誤りが素通りする
	var stage := _instantiate_stage()

	var shooters: int = 0
	var chargers: int = 0
	for enemy: Enemy in _enemies_in(stage):
		if enemy is ShooterEnemy:
			shooters += 1
		elif enemy is ChargerEnemy:
			chargers += 1
	assert_int(shooters).is_equal(EXPECTED_SHOOTER_COUNT)
	assert_int(chargers).is_equal(EXPECTED_CHARGER_COUNT)
	# 合計も別に見る: 種別ごとの数だけだと、どちらでもない `Enemy` の 3 体目が素通りする
	assert_int(_enemies_in(stage).size()).is_equal(EXPECTED_ENEMY_COUNT)


func test_the_single_player_is_a_direct_child_of_the_stage() -> void:
	var stage := _instantiate_stage()

	var players: Array[Node] = []
	for node: Node in _nodes_of(stage):
		if node is Player:
			players.append(node)
	assert_int(players.size()).is_equal(EXPECTED_PLAYER_COUNT)
	if players.size() != EXPECTED_PLAYER_COUNT:
		return
	assert_object(players[0].get_parent()).is_same(stage)


func test_every_enemy_defeat_is_wired_to_the_stage_and_binds_its_own_path() -> void:
	var stage := _instantiate_stage()
	var enemies: Array[Enemy] = _enemies_in(stage)
	# 検査が空振りしていないこと(接続を持つ相手が居ること)
	assert_int(enemies.size()).is_equal(EXPECTED_ENEMY_COUNT)

	var declared_connections: int = 0
	for enemy: Enemy in enemies:
		# `_ready()` で接続する実装では、`instantiate()` した時点の接続は 0 件になる
		var connections: Array = enemy.get_signal_connection_list(&"defeated")
		assert_int(connections.size()).append_failure_message(str(enemy.name)).is_equal(1)
		if connections.size() != 1:
			continue
		declared_connections += 1

		var callable: Callable = connections[0]["callable"]
		assert_object(callable.get_object()).append_failure_message(str(enemy.name)).is_same(stage)
		assert_str(str(callable.get_method())).append_failure_message(
			str(enemy.name)
		).is_equal(DEFEATED_HANDLER_NAME)
		assert_bool(stage.has_method(DEFEATED_HANDLER_NAME)).is_true()

		var bound: Array = callable.get_bound_arguments()
		assert_int(bound.size()).append_failure_message(
			"%s: %s" % [enemy.name, bound]
		).is_equal(EXPECTED_BOUND_ARGUMENT_COUNT)
		if bound.size() != EXPECTED_BOUND_ARGUMENT_COUNT:
			continue
		assert_bool(bound[0] is NodePath).append_failure_message(
			"%s: %s" % [enemy.name, type_string(typeof(bound[0]))]
		).is_true()
		if not (bound[0] is NodePath):
			continue

		# 束縛された経路がその敵自身へ解決すること。ここを見ないと、すべての接続が同じ敵を
		# 指す誤りが素通りする。
		# `get_node()` ではなく `get_node_or_null()` で引く: 解決できない経路の誤りを
		# エンジンのエラーではなく、このアサーションの失敗として見せる
		assert_object(stage.get_node_or_null(bound[0] as NodePath)).append_failure_message(
			"%s -> %s" % [enemy.name, bound[0]]
		).is_same(enemy)

	# 接続の本数が敵の数と一致すること。1 体ずつ見るだけでは、宣言を 1 本消したときに
	# 「その敵の接続が 0 件」としか読めず、本数の不足として観測できない
	assert_int(declared_connections).append_failure_message(
		"%d 体の敵に対して宣言された接続は %d 本" % [enemies.size(), declared_connections]
	).is_equal(enemies.size())


func test_every_enemy_targets_the_player_by_the_scene_declaration() -> void:
	var stage := _instantiate_stage()
	var player: Node2D = stage.get_node(NodePath(PLAYER_NAME))
	var enemies: Array[Enemy] = _enemies_in(stage)
	assert_int(enemies.size()).is_equal(EXPECTED_ENEMY_COUNT)

	for enemy: Enemy in enemies:
		# `[node]` ヘッダの `node_paths` が無いと、宣言した経路は `instantiate()` の後に
		# 静かに `null` へ落ちる。同一性まで見ることで「宣言であること」が 1 本で固まる
		assert_object(enemy.target).append_failure_message(str(enemy.name)).is_same(player)


func test_the_player_death_is_wired_to_the_stage_by_the_scene_declaration() -> void:
	var stage := _instantiate_stage()
	var player: Player = stage.get_node(NodePath(PLAYER_NAME))

	# `_ready()` で接続する実装では、`instantiate()` した時点の接続は 0 件になる
	var connections: Array = player.get_signal_connection_list(&"died")
	assert_int(connections.size()).is_equal(1)
	if connections.size() != 1:
		return

	var callable: Callable = connections[0]["callable"]
	assert_object(callable.get_object()).is_same(stage)
	assert_str(str(callable.get_method())).is_equal(DIED_HANDLER_NAME)
	assert_bool(stage.has_method(DIED_HANDLER_NAME)).is_true()


func test_the_declared_fragment_scene_instantiates_an_analysis_fragment() -> void:
	# 参照の中身まで見る: null でないことだけでは、別の `PackedScene` を差す誤りが素通りする
	var stage: AnalysisDevStage = _instantiate_stage() as AnalysisDevStage
	assert_object(stage).is_not_null()
	if stage == null:
		return
	assert_object(stage.fragment_scene).is_not_null()
	if stage.fragment_scene == null:
		return

	var fragment: Node = auto_free(stage.fragment_scene.instantiate())
	assert_bool(fragment is AnalysisFragment).append_failure_message(
		"%s (%s)" % [fragment.name, fragment.get_class()]
	).is_true()


func test_the_stage_root_declares_exactly_one_packed_scene_export() -> void:
	# 第 3 の枠の演出を差していた `pulse_scene` の消し残りを落とす。値ではなく宣言を数えるため、
	# 値を外しただけの残骸もここに現れる
	var stage := _instantiate_stage()

	var exports: Array[String] = _packed_scene_export_names(stage)
	assert_array(exports).append_failure_message(str(exports)).contains_exactly_in_any_order(
		EXPECTED_ROOT_PACKED_SCENE_EXPORTS
	)


func test_every_terrain_body_carries_a_rectangle_shape_on_the_terrain_layer() -> void:
	var stage := _instantiate_stage()

	var terrain: Array[Node] = _terrain_bodies(stage)
	assert_int(terrain.size()).is_equal(1 + WALL_NAMES.size())

	for body: Node in terrain:
		assert_int((body as StaticBody2D).collision_layer).append_failure_message(
			str(body.name)
		).is_equal(TERRAIN_LAYER)
		var size: Vector2 = _rect_size(body)
		assert_bool(size.x > 0.0 and size.y > 0.0).append_failure_message(
			"%s size=%s" % [body.name, size]
		).is_true()


func test_every_actor_fits_inside_the_floor_horizontally() -> void:
	# 水平方向だけを見るケース。垂直方向と 1 つにまとめると、床を横に縮める変異が
	# 「立っている」の検査に隠れて素通りする
	var stage := _instantiate_stage()
	var floor_body: Node2D = stage.get_node(NodePath(FLOOR_NAME))
	var floor_visual: Rect2 = _visual_rect(floor_body)

	# 見た目の床と当たりの床が重なっていること。ずれていると、この検査は実体と別のものを見る
	assert_vector(floor_visual.position).append_failure_message(
		"%s vs %s" % [floor_visual, _collision_rect(floor_body)]
	).is_equal_approx(_collision_rect(floor_body).position, Vector2.ONE * POSITION_TOLERANCE)
	assert_vector(floor_visual.size).is_equal_approx(
		_collision_rect(floor_body).size, Vector2.ONE * POSITION_TOLERANCE
	)

	var actors: Array[Node2D] = _actors_in(stage)
	# 走査が空振りしていないこと(見る相手が 3 体居ること)
	assert_int(actors.size()).is_equal(EXPECTED_ACTOR_COUNT)

	for actor: Node2D in actors:
		var visual: Rect2 = _visual_rect(actor)
		assert_float(visual.position.x).append_failure_message(
			"%s: %s は床 %s の左へはみ出す" % [actor.name, visual, floor_visual]
		).is_greater_equal(floor_visual.position.x)
		assert_float(visual.end.x).append_failure_message(
			"%s: %s は床 %s の右へはみ出す" % [actor.name, visual, floor_visual]
		).is_less_equal(floor_visual.end.x)


func test_every_actor_stands_on_top_of_the_floor() -> void:
	# 垂直方向だけを見るケース
	var stage := _instantiate_stage()
	var floor_body: Node2D = stage.get_node(NodePath(FLOOR_NAME))
	var floor_top: float = _collision_rect(floor_body).position.y
	var floor_visual_top: float = _visual_rect(floor_body).position.y

	var actors: Array[Node2D] = _actors_in(stage)
	assert_int(actors.size()).is_equal(EXPECTED_ACTOR_COUNT)

	for actor: Node2D in actors:
		# 床の上に立つこと。浮いていると重力で落ちてから戦いが始まり、初期位置の算術がずれる
		assert_float(_collision_rect(actor).end.y).append_failure_message(
			str(actor.name)
		).is_equal_approx(floor_top, POSITION_TOLERANCE)
		# 見た目も床へ沈まないこと。当たりだけを見ると、`ColorRect` を下へ伸ばす変異が残る
		assert_float(_visual_rect(actor).end.y).append_failure_message(
			"%s: %s は床 %f へ沈む" % [actor.name, _visual_rect(actor), floor_visual_top]
		).is_less_equal(floor_visual_top + POSITION_TOLERANCE)


func test_at_most_two_enemies_stand_inside_the_threat_ring() -> void:
	var stage := _instantiate_stage()
	var enemies: Array[Enemy] = _enemies_in(stage)
	# 検査が空振りしていないこと(数える対象が居ること)
	assert_int(enemies.size()).is_equal(EXPECTED_ENEMY_COUNT)

	var inside: Array[String] = []
	for enemy: Enemy in enemies:
		# 索敵範囲はテストへ直書きせず、その敵の stats から読む
		assert_object(enemy.stats).append_failure_message(str(enemy.name)).is_not_null()
		var threshold: float = THREAT_RADIUS + enemy.stats.detect_range
		var distance: float = _distance_to_player(stage, enemy)
		if distance <= threshold:
			inside.append("%s(%f <= %f)" % [enemy.name, distance, threshold])

	assert_int(inside.size()).append_failure_message(str(inside)).is_less_equal(
		MAX_ENEMIES_IN_THREAT_RING
	)


func test_the_far_enemy_starts_outside_its_own_detect_range() -> void:
	# 手前の敵を先に相手にできる配置であること。脅威の圏とは別の閾値であり、
	# 別のアサーションで見る
	var stage := _instantiate_stage()
	var enemies: Array[Enemy] = _enemies_in(stage)
	assert_int(enemies.size()).is_equal(EXPECTED_ENEMY_COUNT)
	if enemies.size() != EXPECTED_ENEMY_COUNT:
		return

	var near_enemy: Enemy = enemies[0]
	var far_enemy: Enemy = enemies[1]
	if _distance_to_player(stage, near_enemy) > _distance_to_player(stage, far_enemy):
		near_enemy = enemies[1]
		far_enemy = enemies[0]
	var near_distance: float = _distance_to_player(stage, near_enemy)
	var far_distance: float = _distance_to_player(stage, far_enemy)
	# 遠近が決まること。重なっていると「遠いほう」が実装の並び順で決まってしまう
	assert_float(far_distance).append_failure_message(
		"%f vs %f" % [near_distance, far_distance]
	).is_greater(near_distance)

	# 閾値はその敵自身の索敵範囲から取る。テストへ距離の期待値を書き写さない
	assert_float(far_distance).append_failure_message(
		"%s は初期状態で索敵範囲の内側に居る" % far_enemy.name
	).is_greater(far_enemy.stats.detect_range)
	# 手前の敵は索敵範囲の内側であること。両方を外へ出すと、目視でどちらも動かない場になる
	assert_float(near_distance).append_failure_message(
		"%s は索敵範囲の外に居る" % near_enemy.name
	).is_less_equal(near_enemy.stats.detect_range)


func test_the_stage_fits_the_base_resolution_in_width() -> void:
	# 名前の一覧ではなく型で走査する: 名前で引くと、一覧に無い名前で置いたノードが素通りする。
	# 幅だけを見る: 壁は画面の上端より高く伸びており、縦は基準解像度に収まらない
	var stage := _instantiate_stage()
	var width: float = _viewport_width()

	var measured: int = 0
	for node: Node in _nodes_of(stage):
		var rect: Rect2 = Rect2()
		if node is ColorRect:
			rect = Rect2((node as ColorRect).global_position, (node as ColorRect).size)
		elif node is CollisionShape2D and (node as CollisionShape2D).shape is RectangleShape2D:
			var size: Vector2 = ((node as CollisionShape2D).shape as RectangleShape2D).size
			rect = Rect2((node as CollisionShape2D).global_position - size * 0.5, size)
		else:
			continue
		measured += 1
		assert_bool(rect.position.x >= 0.0 and rect.end.x <= width).append_failure_message(
			"%s: %f..%f (幅 %f)" % [node.name, rect.position.x, rect.end.x, width]
		).is_true()

	# 走査が空振りしていないこと。0 個を測っても「収まっている」は成立しない
	assert_int(measured).is_greater(0)


func test_the_stage_holds_no_camera() -> void:
	# カメラを置かない(追従を前提にしない = 幅が基準解像度に収まっていることの対)。
	# 名前ではなく型で見る
	var stage := _instantiate_stage()

	for node: Node in _nodes_of(stage):
		assert_bool(node is Camera2D).append_failure_message(
			"%s は Camera2D である" % node.name
		).is_false()


func test_the_stage_holds_no_spawner() -> void:
	var stage := _instantiate_stage()
	var nodes: Array[Node] = _nodes_of(stage)

	for node: Node in nodes:
		assert_array(SPAWNER_CLASS_NAMES).append_failure_message(
			"%s は %s である" % [node.name, node.get_class()]
		).not_contains([node.get_class()])
		assert_bool(str(node.name).to_lower().contains("spawn")).append_failure_message(
			str(node.name)
		).is_false()

	# シーンのどこかが敵のシーンを参照していれば、動的に出す口になる。
	# 参照してよい PackedScene は弾と断片だけであること
	var packed_scene_properties: Array[String] = []
	for node: Node in nodes:
		for property: Dictionary in node.get_property_list():
			if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
				continue
			if node.get(property["name"]) is PackedScene:
				packed_scene_properties.append("%s.%s" % [node.name, property["name"]])
	for found: String in packed_scene_properties:
		assert_array(ALLOWED_PACKED_SCENE_PROPERTIES).append_failure_message(found).contains(
			[found]
		)
	# 集めるしくみが空振りしていないこと
	assert_array(packed_scene_properties).append_failure_message(
		str(packed_scene_properties)
	).contains(REQUIRED_PACKED_SCENE_PROPERTIES)


func test_no_enemy_appears_while_the_stage_runs() -> void:
	# 「スポナーを持たない」ことを静的な検査だけで示さない。実フレームを進めて敵が増えないことを見る
	var stage: Node2D = auto_free(STAGE_SCENE.instantiate())
	add_child(stage)
	# 観測が空振りしていないこと(ステージが 2 体を持ってツリーへ載っている)の witness
	assert_int(_enemies_in(stage).size()).is_equal(EXPECTED_ENEMY_COUNT)

	# 絶対数ではなく差分を見る: 他のスイートが残した敵がツリーに居ても成立させる
	var before: int = _enemies_in_the_whole_tree().size()
	var frames_before: int = Engine.get_physics_frames()
	await await_millis(OBSERVED_MILLIS)
	var frames: int = int(Engine.get_physics_frames()) - frames_before

	assert_int(frames).append_failure_message("物理フレームが進んでいない").is_greater(0)
	assert_int(_enemies_in_the_whole_tree().size()).append_failure_message(
		"%d フレームで木の中の敵の数が %d から変わった" % [frames, before]
	).is_equal(before)


func test_the_same_scan_finds_nodes_nested_below_the_root() -> void:
	# 走査が常に空を返す変異を落とす対。孫の位置に置いて再帰そのものも観測する
	var stub: Node2D = auto_free(Node2D.new())
	var branch: Node2D = Node2D.new()
	stub.add_child(branch)
	branch.add_child(ColorRect.new())

	assert_int(_nodes_of(stub).size()).is_equal(3)
