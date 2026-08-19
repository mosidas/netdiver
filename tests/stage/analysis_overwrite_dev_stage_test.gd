extends GdUnitTestSuite

const STAGE_SCRIPT_PATH: String = "res://src/stage/analysis_dev_stage.gd"

const STAGE_SCENE: PackedScene = preload("res://src/stage/analysis_overwrite_dev_stage.tscn")
const FIRST_STAGE_SCENE: PackedScene = preload("res://src/stage/analysis_dev_stage.tscn")

# 配線のスクリプトが 1 本であることを数える場所。`analysis_` で始まる `.gd` が増えれば、
# 2 つ目のシーン専用の配線が書かれたことになる
const STAGE_SOURCE_DIR: String = "res://src/stage/"
const SHARED_SCRIPT_PREFIX: String = "analysis_"
const SHARED_SCRIPT_FILE_NAME: String = "analysis_dev_stage.gd"

const TERRAIN_LAYER: int = 1 << 0

const FLOOR_NAME: String = "Floor"
const WALL_NAMES: Array[String] = ["WallLeft", "WallRight"]
const PLAYER_NAME: String = "Player"
const ACTOR_NAMES: Array[String] = ["Player", "ShooterEnemy", "ShooterEnemy2"]
const SHAPE_NAME: String = "CollisionShape2D"

const DEFEATED_HANDLER_NAME: String = "_on_enemy_defeated"
const DIED_HANDLER_NAME: String = "_on_player_died"

# 撃破の接続が束縛する引数の数。ハンドラは `[kind, NodePath]` を受け取り、束縛は後ろの 1 つ
const EXPECTED_BOUND_ARGUMENT_COUNT: int = 1

const EXPECTED_ENEMY_COUNT: int = 2
const EXPECTED_SHOOTER_COUNT: int = 2
const EXPECTED_CHARGER_COUNT: int = 0
const EXPECTED_PLAYER_COUNT: int = 1

# 脅威の圏の半径。閾値「160 + その敵の detect_range」の 160 にあたる。
# 敵ごとの索敵範囲はテストへ直書きせず、その敵の `stats` から読む
const THREAT_RADIUS: float = 160.0
const MAX_ENEMIES_IN_THREAT_RING: int = 2

# 出現の仕組みに使われる型。ステージのどこにも現れないこと
const SPAWNER_CLASS_NAMES: Array[String] = ["Timer", "MultiplayerSpawner"]

# シーンが持ってよい PackedScene の参照。いずれも弾か解析の演出であり、敵を出す口ではない。
# 「一致すること」ではなく「この集合に含まれること」で見る: 参照の有無ではなく、敵のシーンを
# 指す参照が現れないことがここの関心である
const ALLOWED_PACKED_SCENE_PROPERTIES: Array[String] = [
	"Player.projectile_scene",
	"ShooterEnemy.projectile_scene",
	"ShooterEnemy2.projectile_scene",
	"AnalysisDevStage.pulse_scene",
]

# 上の集合の検査が空振りしていないことの witness。撃つ側の 3 つは配置だけで必ず現れる
const REQUIRED_PACKED_SCENE_PROPERTIES: Array[String] = [
	"Player.projectile_scene",
	"ShooterEnemy.projectile_scene",
	"ShooterEnemy2.projectile_scene",
]

# 実フレームで敵の数が変わらないことを見る待ち時間。
# 下限: 物理フレームが 1 つ以上進むこと(60Hz で約 12 フレーム)。
# 上限: プレイヤーが死んで再読込が走らないこと。手前の射撃型は索敵の圏内に居るが、予備動作と
# 弾の飛翔を合わせて 1 秒以上かかるため、この時間内に当たりは届かない
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


func _rect_size(body: Node) -> Vector2:
	var shape_node: CollisionShape2D = body.get_node_or_null(NodePath(SHAPE_NAME))
	assert_object(shape_node).append_failure_message(str(body.name)).is_not_null()
	assert_bool(shape_node.shape is RectangleShape2D).append_failure_message(
		str(body.name)
	).is_true()
	return (shape_node.shape as RectangleShape2D).size


func _terrain_bodies(stage: Node) -> Array[Node]:
	var terrain: Array[Node] = []
	for child: Node in stage.get_children():
		if child is StaticBody2D:
			terrain.append(child)
	return terrain


func _distance_to_player(stage: Node, enemy: Enemy) -> float:
	var player: Node2D = stage.get_node(NodePath(PLAYER_NAME))
	return enemy.global_position.distance_to(player.global_position)


func test_the_scene_root_carries_the_shared_stage_script() -> void:
	var stage := _instantiate_stage()

	assert_bool(stage is AnalysisDevStage).append_failure_message(
		str(stage.get_class())
	).is_true()
	var script: Script = stage.get_script()
	assert_object(script).is_not_null()
	assert_str(str(script.resource_path)).is_equal(STAGE_SCRIPT_PATH)


func test_both_dev_stage_scenes_carry_the_very_same_script_resource() -> void:
	# 同一性まで見る: 配線を写した別のスクリプトを付ける形は、型でも経路の文字列でも
	# 落ちうるが、同じ内容の 2 本目という誤りはここで落ちる
	# (`ResourceLoader` はキャッシュを返すため、同一のリソースなら参照も同一になる)
	var stage := _instantiate_stage()
	var first_stage: Node2D = auto_free(FIRST_STAGE_SCENE.instantiate())

	assert_object(first_stage.get_script()).is_not_null()
	assert_object(stage.get_script()).is_same(first_stage.get_script())


func test_the_stage_directory_holds_a_single_analysis_script() -> void:
	# 同一性の検査だけでは「2 本目を置いたがどのシーンからも使っていない」状態を許す。
	# 配線の実装が 1 本であることを、ファイルの側からも固定する
	var sources: Array[String] = []
	for file_name: String in DirAccess.get_files_at(STAGE_SOURCE_DIR):
		if file_name.begins_with(SHARED_SCRIPT_PREFIX) and file_name.ends_with(".gd"):
			sources.append(file_name)

	assert_array(sources).append_failure_message(str(sources)).contains_exactly(
		[SHARED_SCRIPT_FILE_NAME]
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
	assert_bool(stage.get_node_or_null(^"ShooterEnemy2") is ShooterEnemy).is_true()

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


func test_the_stage_holds_two_shooters_and_no_charger() -> void:
	# 種別ごとの体数を直接固定する: 脅威の圏の検査だけに任せると、種別を取り違えた配置が
	# 素通りする(このシーンの用途は同種別の再取得である)
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
	# 配線はステージの直下の子を型で走査してプレイヤーを引く。中間ノードの下へ入れると
	# 演出の標的が null になり、目視で何も飛ばなくなる
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

	for enemy: Enemy in enemies:
		# `_ready()` で接続する実装では、`instantiate()` した時点の接続は 0 件になる
		var connections: Array = enemy.get_signal_connection_list(&"defeated")
		assert_int(connections.size()).append_failure_message(str(enemy.name)).is_equal(1)
		if connections.size() != 1:
			continue

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

		# 束縛された経路がその敵自身へ解決すること。このシーンは同種別の 2 体であり、
		# 両方が同じ敵を指す誤りはこの検査でしか落ちない。
		# `get_node()` ではなく `get_node_or_null()` で引く: 解決できない経路の誤りを
		# エンジンのエラーではなく、このアサーションの失敗として見せる
		assert_object(stage.get_node_or_null(bound[0] as NodePath)).append_failure_message(
			"%s -> %s" % [enemy.name, bound[0]]
		).is_same(enemy)


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


func test_the_stage_declares_the_pulse_scene() -> void:
	var stage: AnalysisDevStage = _instantiate_stage() as AnalysisDevStage
	assert_object(stage).is_not_null()

	assert_object(stage.pulse_scene).is_not_null()


func test_the_declared_pulse_scene_instantiates_an_analysis_pulse() -> void:
	# 参照の中身まで見る: null でないことだけでは、別の `PackedScene` を差す誤りが素通りする
	var stage: AnalysisDevStage = _instantiate_stage() as AnalysisDevStage
	assert_object(stage).is_not_null()
	assert_object(stage.pulse_scene).is_not_null()
	if stage == null or stage.pulse_scene == null:
		return

	var pulse: Node = auto_free(stage.pulse_scene.instantiate())
	assert_bool(pulse is AnalysisPulse).append_failure_message(
		"%s (%s)" % [pulse.name, pulse.get_class()]
	).is_true()


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


func test_the_two_enemies_stand_apart_from_each_other() -> void:
	# 同種別の 2 体は名前でしか見分けが付かない。重なった配置は目視の手順(2 体目を後から
	# 撃破する)を成立させない
	var stage := _instantiate_stage()
	var enemies: Array[Enemy] = _enemies_in(stage)
	assert_int(enemies.size()).is_equal(EXPECTED_ENEMY_COUNT)
	if enemies.size() != EXPECTED_ENEMY_COUNT:
		return

	var gap: float = enemies[0].global_position.distance_to(enemies[1].global_position)
	var span: float = _rect_size(enemies[0]).x * 0.5 + _rect_size(enemies[1]).x * 0.5
	assert_float(gap).append_failure_message(
		"%s と %s が %f しか離れていない" % [enemies[0].name, enemies[1].name, gap]
	).is_greater(span)


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

	assert_float(far_distance).append_failure_message(
		"%s は初期状態で索敵範囲の内側に居る" % far_enemy.name
	).is_greater(far_enemy.stats.detect_range)
	# 手前の敵は索敵範囲の内側であること。両方を外へ出すと、目視でどちらも動かない場になる
	assert_float(near_distance).append_failure_message(
		"%s は索敵範囲の外に居る" % near_enemy.name
	).is_less_equal(near_enemy.stats.detect_range)


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


func test_the_terrain_fits_the_base_resolution_in_width() -> void:
	var stage := _instantiate_stage()
	var width: float = float(ProjectSettings.get_setting("display/window/size/viewport_width"))
	assert_bool(width > 0.0).is_true()

	var terrain: Array[Node] = _terrain_bodies(stage)
	assert_int(terrain.size()).is_equal(1 + WALL_NAMES.size())

	# 幅だけを見る: 壁は画面の上端より高く伸びており、縦は基準解像度に収まらない
	for body: Node in terrain:
		var half_width: float = _rect_size(body).x * 0.5
		var left: float = (body as Node2D).global_position.x - half_width
		var right: float = (body as Node2D).global_position.x + half_width
		assert_bool(left >= 0.0 and right <= width).append_failure_message(
			"%s: %f..%f" % [body.name, left, right]
		).is_true()


func test_the_stage_holds_no_camera() -> void:
	# カメラを置かない(追従を前提にしない = 幅が基準解像度に収まっていることの対)
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
	# 参照してよい PackedScene は弾と解析の演出だけであること
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
