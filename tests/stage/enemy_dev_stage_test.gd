extends GdUnitTestSuite

const ENEMY_DEV_STAGE_SCENE: PackedScene = preload("res://src/stage/enemy_dev_stage.tscn")

const TERRAIN_LAYER: int = 1 << 0

const FLOOR_NAME: String = "Floor"
const WALL_NAMES: Array[String] = ["WallLeft", "WallRight"]
const PLAYER_NAME: String = "Player"
const ACTOR_NAMES: Array[String] = ["Player", "ChargerEnemy", "ShooterEnemy"]
const SHAPE_NAME: String = "CollisionShape2D"

const DIED_HANDLER_NAME: String = "_on_player_died"

# 実装の定数を参照せずテスト側に持つ(main.tscn の差し替えを検出するため)
const EXPECTED_MAIN_SCENE: String = "res://main.tscn"

# 脅威の圏の半径。spec.md §7 9.2 の「160 + その敵の detect_range」の 160 にあたる
const THREAT_RADIUS: float = 160.0
const MAX_ENEMIES_IN_THREAT_RING: int = 2
const EXPECTED_ENEMY_COUNT: int = 2

# 出現の仕組みに使われる型。ステージのどこにも現れないこと
const SPAWNER_CLASS_NAMES: Array[String] = ["Timer", "MultiplayerSpawner"]

# シーンが持ってよい PackedScene の参照。いずれも弾であり、敵を出す口ではない
const ALLOWED_PACKED_SCENE_PROPERTIES: Array[String] = [
	"Player.projectile_scene",
	"ShooterEnemy.projectile_scene",
]

# 実フレームで敵の数が変わらないことを見る待ち時間。
# 下限: 物理フレームが 1 つ以上進むこと(60Hz で約 12 フレーム)。
# 上限: プレイヤーが死んで `reload_current_scene()` が走らないこと。突進型は初期距離 112px から
# 到達距離 90px まで 40px/s で詰めて 0.55 秒、そこから予備動作 0.4 秒で最初の当たりが 0.95 秒後、
# 体力 100 に対して 15 ずつのため死ぬまで数秒かかる。射撃型も予備動作 0.4 秒で 1 発目が出ない
const OBSERVED_MILLIS: int = 200

const POSITION_TOLERANCE: float = 0.001


func _instantiate_stage() -> Node2D:
	# ツリーへ載せない: `add_child()` すると `_ready()` と `_physics_process` が走り、
	# 検証したい初期位置が動く(spec.md §7 Requirement 9 の検証の形式)
	var stage: Node2D = auto_free(ENEMY_DEV_STAGE_SCENE.instantiate())
	assert_object(stage).is_not_null()
	return stage


func _collect_nodes(node: Node, into: Array[Node]) -> void:
	into.append(node)
	for child: Node in node.get_children():
		_collect_nodes(child, into)


func _enemies(stage: Node) -> Array[Enemy]:
	var enemies: Array[Enemy] = []
	for child: Node in stage.get_children():
		if child is Enemy:
			enemies.append(child as Enemy)
	return enemies


# 敵をステージの直下ではなく木の全体から数える: 追加先を別のノード(既存の子・ステージの親・
# 現在のシーン)へ変えただけのスポナーは、直下だけを見ていると素通りする
func _enemies_in_the_whole_tree() -> Array[Enemy]:
	var nodes: Array[Node] = []
	_collect_nodes(get_tree().root, nodes)
	var enemies: Array[Enemy] = []
	for node: Node in nodes:
		if node is Enemy:
			enemies.append(node as Enemy)
	return enemies


func _rect_size(body: Node) -> Vector2:
	var shape_node: CollisionShape2D = body.get_node_or_null(NodePath(SHAPE_NAME))
	assert_object(shape_node).append_failure_message(str(body.name)).is_not_null()
	assert_bool(shape_node.shape is RectangleShape2D).append_failure_message(
		str(body.name)
	).is_true()
	return (shape_node.shape as RectangleShape2D).size


func test_the_stage_places_terrain_and_the_three_actors() -> void:
	var stage := _instantiate_stage()

	var floor_body: Node = stage.get_node_or_null(NodePath(FLOOR_NAME))
	assert_bool(floor_body is StaticBody2D).append_failure_message(FLOOR_NAME).is_true()
	for wall_name: String in WALL_NAMES:
		var wall: Node = stage.get_node_or_null(NodePath(wall_name))
		assert_bool(wall is StaticBody2D).append_failure_message(wall_name).is_true()

	assert_bool(stage.get_node_or_null(^"Player") is Player).is_true()
	assert_bool(stage.get_node_or_null(^"ChargerEnemy") is ChargerEnemy).is_true()
	assert_bool(stage.get_node_or_null(^"ShooterEnemy") is ShooterEnemy).is_true()

	# 子は宣言した 5 つだけであること(数え漏らし・重複・余計な配置を固定する)
	var child_names: Array[String] = []
	for child: Node in stage.get_children():
		child_names.append(str(child.name))
	var expected_children: Array[String] = [FLOOR_NAME]
	expected_children.append_array(WALL_NAMES)
	expected_children.append_array(ACTOR_NAMES)
	assert_array(child_names).append_failure_message(str(child_names)).contains_exactly_in_any_order(
		expected_children
	)


func test_every_terrain_body_carries_a_rectangle_shape_on_the_terrain_layer() -> void:
	var stage := _instantiate_stage()

	var terrain: Array[Node] = []
	for child: Node in stage.get_children():
		if child is StaticBody2D:
			terrain.append(child)
	assert_int(terrain.size()).is_equal(1 + WALL_NAMES.size())

	for body: Node in terrain:
		assert_int((body as StaticBody2D).collision_layer).append_failure_message(
			str(body.name)
		).is_equal(TERRAIN_LAYER)
		var size: Vector2 = _rect_size(body)
		assert_bool(size.x > 0.0 and size.y > 0.0).append_failure_message(
			"%s size=%s" % [body.name, size]
		).is_true()


func test_every_actor_stands_on_the_floor_between_the_walls() -> void:
	var stage := _instantiate_stage()
	var floor_body: Node2D = stage.get_node(NodePath(FLOOR_NAME))
	var floor_top: float = floor_body.global_position.y - _rect_size(floor_body).y * 0.5

	var left_wall: Node2D = stage.get_node(NodePath(WALL_NAMES[0]))
	var right_wall: Node2D = stage.get_node(NodePath(WALL_NAMES[1]))
	var left_face: float = left_wall.global_position.x + _rect_size(left_wall).x * 0.5
	var right_face: float = right_wall.global_position.x - _rect_size(right_wall).x * 0.5

	for actor_name: String in ACTOR_NAMES:
		var actor: Node2D = stage.get_node(NodePath(actor_name))
		var half_height: float = _rect_size(actor).y * 0.5
		var half_width: float = _rect_size(actor).x * 0.5
		# 床の上に立つこと。浮いていると重力で落ちてから戦いが始まり、初期位置の算術がずれる
		assert_float(actor.global_position.y + half_height).append_failure_message(
			actor_name
		).is_equal_approx(floor_top, POSITION_TOLERANCE)
		assert_float(actor.global_position.x - half_width).append_failure_message(
			actor_name
		).is_greater(left_face)
		assert_float(actor.global_position.x + half_width).append_failure_message(
			actor_name
		).is_less(right_face)


func test_every_actor_starts_inside_the_base_resolution() -> void:
	var stage := _instantiate_stage()
	# 基準解像度はステージではなくプロジェクト設定が持つ。テストへ複製しない
	var width: float = float(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var height: float = float(ProjectSettings.get_setting("display/window/size/viewport_height"))
	assert_bool(width > 0.0 and height > 0.0).is_true()

	for actor_name: String in ACTOR_NAMES:
		var actor: Node2D = stage.get_node(NodePath(actor_name))
		var half: Vector2 = _rect_size(actor) * 0.5
		assert_bool(
			(
				actor.global_position.x - half.x >= 0.0
				and actor.global_position.x + half.x <= width
				and actor.global_position.y - half.y >= 0.0
				and actor.global_position.y + half.y <= height
			)
		).append_failure_message("%s: %s" % [actor_name, actor.global_position]).is_true()


func test_each_enemy_points_its_target_at_the_player_by_the_scene_declaration() -> void:
	var stage := _instantiate_stage()
	var player: Player = stage.get_node(NodePath(PLAYER_NAME))
	var enemies: Array[Enemy] = _enemies(stage)
	assert_int(enemies.size()).is_equal(EXPECTED_ENEMY_COUNT)

	for enemy: Enemy in enemies:
		# `instantiate()` は `_ready()` を呼ばない。`_ready()` で標的を検索する実装ではここが
		# null になる(9.9 の「シーンの宣言で指す」を、宣言であることまで含めて固定する)
		assert_object(enemy.target).append_failure_message(str(enemy.name)).is_same(player)


func test_the_player_death_is_wired_to_the_stage_by_the_scene_declaration() -> void:
	var stage := _instantiate_stage()
	var player: Player = stage.get_node(NodePath(PLAYER_NAME))

	# `_ready()` で接続する実装では、`instantiate()` した時点の接続は 0 件になる
	var connections: Array = player.get_signal_connection_list(&"died")
	assert_int(connections.size()).is_equal(1)

	var callable: Callable = connections[0]["callable"]
	assert_object(callable.get_object()).is_same(stage)
	assert_str(str(callable.get_method())).is_equal(DIED_HANDLER_NAME)
	assert_bool(stage.has_method(DIED_HANDLER_NAME)).is_true()


func test_at_most_two_enemies_stand_inside_the_threat_ring() -> void:
	var stage := _instantiate_stage()
	var player: Node2D = stage.get_node(NodePath(PLAYER_NAME))

	var inside: Array[String] = []
	for enemy: Enemy in _enemies(stage):
		# 索敵範囲はテストへ直書きせず、その敵の stats から読む
		assert_object(enemy.stats).append_failure_message(str(enemy.name)).is_not_null()
		var threshold: float = THREAT_RADIUS + enemy.stats.detect_range
		var distance: float = enemy.global_position.distance_to(player.global_position)
		if distance <= threshold:
			inside.append("%s(%f <= %f)" % [enemy.name, distance, threshold])

	assert_int(inside.size()).append_failure_message(str(inside)).is_less_equal(
		MAX_ENEMIES_IN_THREAT_RING
	)


func test_every_enemy_can_reach_the_player_from_its_initial_position() -> void:
	# 6.2 の目視確認(敵の攻撃を受けてプレイヤーが死ぬ)が成立する配置であることの前提。
	# 索敵範囲の外に置くと、プレイヤーを動かさない限り敵が何もしない場になる
	var stage := _instantiate_stage()
	var player: Node2D = stage.get_node(NodePath(PLAYER_NAME))
	var enemies: Array[Enemy] = _enemies(stage)
	assert_int(enemies.size()).is_equal(EXPECTED_ENEMY_COUNT)

	var shooters: int = 0
	for enemy: Enemy in enemies:
		var distance: float = enemy.global_position.distance_to(player.global_position)
		assert_float(distance).append_failure_message(
			"%s は索敵範囲の外にいる" % enemy.name
		).is_less_equal(enemy.stats.detect_range)
		if enemy.stats.bullet_max_distance > 0.0:
			shooters += 1
			assert_float(distance).append_failure_message(
				"%s の弾がプレイヤーに届かない" % enemy.name
			).is_less_equal(enemy.stats.bullet_max_distance)

	# 弾の射程を見る枝が空振りしていないこと
	assert_int(shooters).is_equal(1)


func test_the_stage_holds_no_spawner() -> void:
	var stage := _instantiate_stage()
	var nodes: Array[Node] = []
	_collect_nodes(stage, nodes)

	for node: Node in nodes:
		assert_array(SPAWNER_CLASS_NAMES).append_failure_message(
			"%s は %s である" % [node.name, node.get_class()]
		).not_contains([node.get_class()])
		assert_bool(str(node.name).to_lower().contains("spawn")).append_failure_message(
			str(node.name)
		).is_false()

	# シーンのどこかが敵のシーンを参照していれば、動的に出す口になる。
	# 参照してよい PackedScene は弾の 2 件だけであること
	var packed_scene_properties: Array[String] = []
	for node: Node in nodes:
		for property: Dictionary in node.get_property_list():
			if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
				continue
			if node.get(property["name"]) is PackedScene:
				packed_scene_properties.append("%s.%s" % [node.name, property["name"]])
	assert_array(packed_scene_properties).append_failure_message(
		str(packed_scene_properties)
	).contains_exactly_in_any_order(ALLOWED_PACKED_SCENE_PROPERTIES)

	# ステージのスクリプトは変数を持たない。出現の予定・残数を持ちようがない
	for property: Dictionary in stage.get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		assert_str(str(property["name"])).append_failure_message(
			"EnemyDevStage が状態を持っている: %s" % property["name"]
		).is_empty()


func test_no_enemy_appears_while_the_stage_runs() -> void:
	# 「スポナーを持たない」ことを静的な検査だけで示さない。実フレームを進めて敵が増えないことを見る
	var stage: Node2D = auto_free(ENEMY_DEV_STAGE_SCENE.instantiate())
	add_child(stage)
	# 観測が空振りしていないこと(ステージが 2 体を持ってツリーへ載っている)の witness
	assert_int(_enemies(stage).size()).is_equal(EXPECTED_ENEMY_COUNT)

	# 絶対数ではなく差分を見る: 他のスイートが残した敵がツリーに居ても成立させる
	var before: int = _enemies_in_the_whole_tree().size()
	var frames_before: int = Engine.get_physics_frames()
	await await_millis(OBSERVED_MILLIS)
	var frames: int = int(Engine.get_physics_frames()) - frames_before

	assert_int(frames).append_failure_message("物理フレームが進んでいない").is_greater(0)
	assert_int(_enemies_in_the_whole_tree().size()).append_failure_message(
		"%d フレームで木の中の敵の数が %d から変わった" % [frames, before]
	).is_equal(before)


func test_the_main_scene_setting_is_left_untouched() -> void:
	var main_scene: String = str(ProjectSettings.get_setting("application/run/main_scene"))

	assert_str(main_scene).is_equal(EXPECTED_MAIN_SCENE)
