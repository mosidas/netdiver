extends GdUnitTestSuite

const FRAGMENT_SCENE: PackedScene = preload("res://src/ability/analysis_fragment.tscn")
const STAGE_SOURCE_PATH: String = "res://src/stage/analysis_dev_stage.gd"

# 撃破の種別。写せる側と写せない側を対で置く: 片側だけを見ると、「常に生成する」実装と
# 「常に生成しない」実装のどちらかが素通りする
const TRANSFERABLE_KIND: int = EnemyKind.Kind.SHOOTER
const NON_TRANSFERABLE_KIND: int = EnemyKind.Kind.CHARGER

const PLAYER_NAME: String = "Player"
const ENEMY_NAME: String = "Enemy"
const OTHER_ENEMY_NAME: String = "OtherEnemy"
const ENEMY_PATH: NodePath = ^"Enemy"
const OTHER_ENEMY_PATH: NodePath = ^"OtherEnemy"

# ステージを原点から離す: 原点に置くと、敵の `position` を断片の位置にする実装も緑になる
const STAGE_POSITION: Vector2 = Vector2(53.0, -29.0)
# 2 体の敵を互いに別の位置へ置く: 重なっていると、`NodePath` を解決せずに最初の子を
# 読む実装が素通りする
const ENEMY_POSITION: Vector2 = Vector2(96.0, 40.0)
const OTHER_ENEMY_POSITION: Vector2 = Vector2(-72.0, 18.0)
const PLAYER_POSITION: Vector2 = Vector2(24.0, -36.0)

const TOLERANCE: Vector2 = Vector2(0.001, 0.001)

# `push_error` の文言はテストの側に複製を持つ: 実装の定数を参照すると、文言を変える変異が
# 自己成就して落ちない
const MISSING_FRAGMENT_SCENE_ERROR: String = (
	"AnalysisDevStage: fragment_scene が設定されていない。断片を生成せずに返る"
)

# ステージが取得へ関与していないことをソースの側からも見る記号。振る舞いの側の対は
# `test_a_transferable_defeat_calls_nothing_on_the_player()` が持つ
const PICKUP_SYMBOLS: PackedStringArray = ["_player(", "Player", "grant_upgrade", "grant_ability"]

# 判定の委譲先。振る舞いの側の対は写せる種別・写せない種別の 2 ケースが持つ
const TRANSFERABLE_JUDGEMENT_CALL: String = "AbilityAnalysis.is_transferable("

# 取得の呼び出しを控えるプレイヤー。ステージが受け手を引いて呼んだ時点で記録が残る。
# 実体の `Player` を継承する: 型で子を引く実装を捕らえるには、木の上の受け手が
# `Player` そのものでなければならない
const RECORDING_PLAYER_SOURCE: String = """
extends Player

var calls: Array[String] = []


func grant_upgrade() -> void:
	calls.append("grant_upgrade")


func grant_ability() -> void:
	calls.append("grant_ability")
"""


func test_the_kinds_used_here_sit_on_both_sides_of_the_analysis() -> void:
	# 種別の対応が反転したときにこのスイートが黙って裏返らないよう、両側の前提を先に固定する
	assert_bool(AbilityAnalysis.is_transferable(TRANSFERABLE_KIND)).is_true()
	assert_bool(AbilityAnalysis.is_transferable(NON_TRANSFERABLE_KIND)).is_false()


func test_the_defeat_of_a_transferable_kind_adds_one_fragment_to_the_stage() -> void:
	var stage: AnalysisDevStage = _create_stage()

	stage._on_enemy_defeated(TRANSFERABLE_KIND, ENEMY_PATH)
	await _await_deferred_add()

	var fragments: Array[AnalysisFragment] = _fragments_in_the_whole_tree()
	# 個数を固定する: 「1 つ以上」だと、撃破ごとに複数を残す実装が素通りする
	assert_array(fragments).has_size(1)
	if fragments.size() != 1:
		return
	# 撃破された敵の子にしない: 敵は `defeated` の直後に解放される
	assert_object(fragments[0].get_parent()).is_same(stage)


func test_the_handler_adds_no_fragment_inside_its_own_call() -> void:
	# 実機では `defeated` が弾の当たり(物理コールバック)の中から届くため、ハンドラ自身の
	# 呼び出しの中で当たり判定を持つ `Area2D` を木へ載せると、走査の最中に監視の状態を
	# 変えることになり物理サーバが拒否する。ここではその「自分の呼び出しの中では載せない」
	# ことを直接観測する。これが無いと、同期の追加へ戻す変更が落ちない
	var stage: AnalysisDevStage = _create_stage()
	var children_before: int = stage.get_child_count()

	stage._on_enemy_defeated(TRANSFERABLE_KIND, ENEMY_PATH)

	assert_array(_fragments_in_the_whole_tree()).is_empty()
	assert_int(stage.get_child_count()).is_equal(children_before)

	await _await_deferred_add()

	# 遅らせただけで出ないわけではないことを対で見る: 片側だけだと、断片を一切生成しない
	# 実装が素通りする
	assert_array(_fragments_in_the_whole_tree()).has_size(1)
	assert_int(stage.get_child_count()).is_equal(children_before + 1)


func test_the_defeat_of_a_non_transferable_kind_adds_no_fragment() -> void:
	# 写せない種別では断片が出ないこと自体が「この敵からは写せない」ことの表出である
	var stage: AnalysisDevStage = _create_stage()
	var children_before: int = stage.get_child_count()

	stage._on_enemy_defeated(NON_TRANSFERABLE_KIND, ENEMY_PATH)
	# 遅延の後まで見る: 同期の時点だけを見ると、遅れて出る実装を「出ない」と誤って読む
	await _await_deferred_add()

	assert_array(_fragments_in_the_whole_tree()).is_empty()
	assert_int(stage.get_child_count()).is_equal(children_before)


func test_the_fragment_appears_at_the_global_position_of_the_defeated_enemy() -> void:
	var stage: AnalysisDevStage = _create_stage()
	var enemy: Node2D = stage.get_node(ENEMY_PATH)
	# 局所座標と大域座標がずれていることを先に固定する: 重なっていると、`position` を
	# 読む実装も緑になる
	assert_vector(enemy.global_position).is_not_equal(enemy.position)

	stage._on_enemy_defeated(TRANSFERABLE_KIND, ENEMY_PATH)
	await _await_deferred_add()

	var fragments: Array[AnalysisFragment] = _fragments_in_the_whole_tree()
	assert_array(fragments).has_size(1)
	if fragments.size() != 1:
		return
	assert_vector(fragments[0].global_position).is_equal_approx(enemy.global_position, TOLERANCE)


func test_the_fragment_of_the_first_enemy_appears_at_that_instance() -> void:
	# 同じ種別の 2 体を置いて 1 体目を撃破する: 種別が同じでは、「両方が同じ相手を指す」誤りを
	# 「解決した先が当のインスタンス自身であること」でしか落とせない
	var stage: AnalysisDevStage = _create_stage()
	var enemy: Node2D = stage.get_node(ENEMY_PATH)
	var other: Node2D = stage.get_node(OTHER_ENEMY_PATH)
	assert_vector(enemy.global_position).is_not_equal(other.global_position)

	stage._on_enemy_defeated(TRANSFERABLE_KIND, ENEMY_PATH)
	await _await_deferred_add()

	var fragments: Array[AnalysisFragment] = _fragments_in_the_whole_tree()
	assert_array(fragments).has_size(1)
	if fragments.size() != 1:
		return
	assert_vector(fragments[0].global_position).is_equal_approx(enemy.global_position, TOLERANCE)
	assert_vector(fragments[0].global_position).is_not_equal(other.global_position)


func test_the_fragment_of_the_second_enemy_appears_at_that_instance() -> void:
	var stage: AnalysisDevStage = _create_stage()
	var enemy: Node2D = stage.get_node(ENEMY_PATH)
	var other: Node2D = stage.get_node(OTHER_ENEMY_PATH)

	stage._on_enemy_defeated(TRANSFERABLE_KIND, OTHER_ENEMY_PATH)
	await _await_deferred_add()

	var fragments: Array[AnalysisFragment] = _fragments_in_the_whole_tree()
	assert_array(fragments).has_size(1)
	if fragments.size() != 1:
		return
	assert_vector(fragments[0].global_position).is_equal_approx(other.global_position, TOLERANCE)
	assert_vector(fragments[0].global_position).is_not_equal(enemy.global_position)


# 位置は撃破の時点で読む。撃破された敵は `defeated` の直後に `queue_free()` されるため、
# 遅らせた先で同じ相手を解決できる保証が無い(解放の時期と遅延した呼び出しの時期の
# 前後関係はエンジンの実装の詳細であり、契約ではない)。ここでは撃破の直後に敵を木から
# 外し、`NodePath` を遅延の中で解決し直す実装が落ちることを見る
func test_the_fragment_appears_at_the_position_read_when_the_defeat_arrived() -> void:
	var stage: AnalysisDevStage = _create_stage()
	var enemy: Node2D = stage.get_node(ENEMY_PATH)
	var at: Vector2 = enemy.global_position

	stage._on_enemy_defeated(TRANSFERABLE_KIND, ENEMY_PATH)
	stage.remove_child(enemy)
	await _await_deferred_add()

	assert_bool(stage.has_node(ENEMY_PATH)).is_false()
	var fragments: Array[AnalysisFragment] = _fragments_in_the_whole_tree()
	assert_array(fragments).has_size(1)
	if fragments.size() != 1:
		return
	assert_vector(fragments[0].global_position).is_equal_approx(at, TOLERANCE)


func test_the_fragment_outlives_the_defeated_enemy() -> void:
	var stage: AnalysisDevStage = _create_stage()
	var enemy: Node2D = stage.get_node(ENEMY_PATH)

	stage._on_enemy_defeated(TRANSFERABLE_KIND, ENEMY_PATH)
	await _await_deferred_add()

	var fragments: Array[AnalysisFragment] = _fragments_in_the_whole_tree()
	assert_array(fragments).has_size(1)
	if fragments.size() != 1:
		return
	var fragment: AnalysisFragment = fragments[0]

	enemy.queue_free()
	await await_idle_frame()

	assert_bool(is_instance_valid(enemy)).is_false()
	# 敵の子にする実装は、敵の解放で断片ごと消える
	assert_bool(is_instance_valid(fragment)).is_true()
	if not is_instance_valid(fragment):
		return
	assert_object(fragment.get_parent()).is_same(stage)


func test_a_transferable_defeat_without_a_fragment_scene_pushes_an_error() -> void:
	var stage: AnalysisDevStage = _create_stage(false)
	var children_before: int = stage.get_child_count()

	var defeat: Callable = func() -> void: stage._on_enemy_defeated(TRANSFERABLE_KIND, ENEMY_PATH)
	await assert_error(defeat).is_push_error(MISSING_FRAGMENT_SCENE_ERROR)
	await _await_deferred_add()

	assert_int(stage.get_child_count()).is_equal(children_before)
	assert_array(_fragments_in_the_whole_tree()).is_empty()


func test_a_non_transferable_defeat_without_a_fragment_scene_pushes_no_error() -> void:
	# 「未設定なら常に報せる」実装はここで落ちる: 写せない種別では生成を試みないため、
	# 未設定であることは異常ではない
	var stage: AnalysisDevStage = _create_stage(false)
	var children_before: int = stage.get_child_count()

	var defeat: Callable = (
		func() -> void: stage._on_enemy_defeated(NON_TRANSFERABLE_KIND, ENEMY_PATH)
	)
	await assert_error(defeat).is_success()
	await _await_deferred_add()

	assert_int(stage.get_child_count()).is_equal(children_before)
	assert_array(_fragments_in_the_whole_tree()).is_empty()


func test_a_transferable_defeat_calls_nothing_on_the_player() -> void:
	# 取得はステージを経由しない: 断片が触れた相手を自分で呼ぶ。ステージが受け手を引いて
	# 呼ぶ実装は、記録の残る受け手を木に置いたここで落ちる
	var stage: AnalysisDevStage = _create_stage()
	var player: Player = stage.get_node(NodePath(PLAYER_NAME))

	stage._on_enemy_defeated(TRANSFERABLE_KIND, ENEMY_PATH)
	await _await_deferred_add()

	# 断片が出ていること。出ていなければ「呼ばれない」は空振りの緑になる
	assert_array(_fragments_in_the_whole_tree()).has_size(1)
	assert_array(player.get("calls")).is_empty()


func test_the_stage_source_names_no_pickup_symbol() -> void:
	# 静的な検査だけに頼らない: 同じ呼び出しを別の書き方で置いた実装は文字列の検査を
	# 素通りするため、振る舞い側のケースと対で置く
	var source: String = FileAccess.get_file_as_string(STAGE_SOURCE_PATH)

	# 走査が空振りしていないことを先に固定する: 読めないまま緑になると、検査が何も見ていない
	assert_str(source).is_not_empty()

	for symbol: String in PICKUP_SYMBOLS:
		assert_str(source).append_failure_message(symbol).not_contains(symbol)


func test_the_stage_source_delegates_the_transferable_judgement() -> void:
	# 写せるかどうかの判定は 1 箇所にある。この検査が無いと、同じ答えを返す比較を
	# ここへ直に書く実装(種別の名前を出さない書き方)が振る舞いの側で区別できない
	var source: String = FileAccess.get_file_as_string(STAGE_SOURCE_PATH)

	assert_str(source).is_not_empty()
	assert_str(source).contains(TRANSFERABLE_JUDGEMENT_CALL)


func test_the_handler_runs_no_reload_inside_its_own_call() -> void:
	# 実機では `died` が敵の攻撃の当たり(物理コールバック)の中から届くため、ハンドラ自身の
	# 呼び出しの中で再読込を走らせると現在のシーンの CollisionObject2D をコールバックの
	# 最中に消すことになる。ここではその「自分の呼び出しの中では走らせない」ことを直接観測する。
	#
	# 観測できる理由: `assert_error()` は自前の logger を持ち、渡した Callable の実行中に出た
	# エンジンのエラーを拾う。再読込がこの場で走れば `current_scene` が null であることを
	# エンジンがエラーとして押すため、同期に走る実装はここで落ちる。
	#
	# 前提のガード: テストの実行中 `current_scene` は null であり、遅延された再読込は何も
	# 差し替えずに終わる。gdUnit のアサーションの失敗は関数の実行を打ち切らないため、
	# 早期に抜ける枝を対で置く
	assert_object(get_tree().current_scene).is_null()
	if get_tree().current_scene != null:
		return

	var stage: AnalysisDevStage = auto_free(AnalysisDevStage.new())
	add_child(stage)

	# 遅延された再読込はこの窓の外(フレームの終わり)で走るため、この回のログには
	# `ERROR: Parameter "current_scene" is null.` が 1 件出る。**これは正常である**
	var die: Callable = func() -> void: stage._on_player_died()
	await assert_error(die).is_success()


# 遅らせた追加が済むまで待つ。ハンドラは追加を `call_deferred` へ回すため、呼び出しの直後の
# 木にはまだ断片が無い。実機の `defeated` は物理コールバックの最中に届き、そこで当たり判定を
# 持つ `Area2D` を木へ載せると物理サーバの走査を壊すためである
func _await_deferred_add() -> void:
	await await_idle_frame()


func _create_stage(with_fragment_scene: bool = true) -> AnalysisDevStage:
	var stage: AnalysisDevStage = auto_free(AnalysisDevStage.new())
	if with_fragment_scene:
		stage.fragment_scene = FRAGMENT_SCENE
	add_child(stage)
	stage.position = STAGE_POSITION

	_add_enemy(stage, ENEMY_NAME, ENEMY_POSITION)
	_add_enemy(stage, OTHER_ENEMY_NAME, OTHER_ENEMY_POSITION)
	_add_player(stage)
	return stage


# 敵の実体を置かない: このスイートが見るのは配線であり、`Enemy` の振る舞いではない。
# ハンドラは撃破の位置と種別しか読まないため、位置を持つノードで足りる
func _add_enemy(stage: Node2D, node_name: String, at: Vector2) -> Node2D:
	var enemy: Node2D = auto_free(Node2D.new())
	enemy.name = node_name
	stage.add_child(enemy)
	enemy.position = at
	return enemy


func _add_player(stage: Node2D) -> Player:
	var player_script: GDScript = GDScript.new()
	player_script.source_code = RECORDING_PLAYER_SOURCE
	player_script.reload()
	var player: Player = auto_free(player_script.new())
	player.name = PLAYER_NAME
	player.stats = auto_free(PlayerStats.new())
	# 自前の物理を止める: このスイートが見るのはステージの配線であり、受け手の移動ではない
	player.set_physics_process(false)
	stage.add_child(player)
	player.position = PLAYER_POSITION
	return player


func _collect_nodes(node: Node, into: Array[Node]) -> void:
	into.append(node)
	for child: Node in node.get_children():
		_collect_nodes(child, into)


# 断片をステージの直下ではなく木の全体から数える: 追加先を別のノード(敵・ステージの親)へ
# 変えただけの実装は、直下だけを見ていると「生成しない」と誤って読める
func _fragments_in_the_whole_tree() -> Array[AnalysisFragment]:
	var nodes: Array[Node] = []
	_collect_nodes(get_tree().root, nodes)
	var fragments: Array[AnalysisFragment] = []
	for node: Node in nodes:
		if node is AnalysisFragment:
			fragments.append(node as AnalysisFragment)
	return fragments
