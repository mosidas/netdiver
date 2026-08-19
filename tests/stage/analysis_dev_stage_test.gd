extends GdUnitTestSuite

const PULSE_SCENE: PackedScene = preload("res://src/ability/analysis_pulse.tscn")
const PLAYER_SCENE: PackedScene = preload("res://src/player/player.tscn")

# 撃破の種別。ハンドラは種別で分岐しないため、両方の値を同じ形で通す
const SHOOTER: int = EnemyKind.Kind.SHOOTER
const CHARGER: int = EnemyKind.Kind.CHARGER

const PLAYER_NAME: String = "Player"
const ENEMY_NAME: String = "Enemy"
const OTHER_ENEMY_NAME: String = "OtherEnemy"
const ENEMY_PATH: NodePath = ^"Enemy"
const OTHER_ENEMY_PATH: NodePath = ^"OtherEnemy"

# ステージを原点から離す: 原点に置くと、敵の `position` を始点にする実装も緑になる
const STAGE_POSITION: Vector2 = Vector2(53.0, -29.0)
# 敵とプレイヤーを互いに別の位置へ置く: 重なっていると、演出の標的が敵でもプレイヤーでも
# 同じ位置へ着く
const ENEMY_POSITION: Vector2 = Vector2(96.0, 40.0)
const OTHER_ENEMY_POSITION: Vector2 = Vector2(-72.0, 18.0)
const PLAYER_POSITION: Vector2 = Vector2(24.0, -36.0)

# 既定(3)と別の回数を渡す: 既定のままだと、`stats` を読まずに回数を直書きする実装も緑になる
const ABILITY_USES: int = 5

# 手で回す飛行のフレーム数。既定の 0.4 秒のままだと、到達まで待つ時間がケースごとに伸びる
const FLIGHT_FRAMES: int = 8

# 数フレーム(60 Hz で 1 フレーム約 17 ms)に対して余裕を取る: 遅いランナーでも
# 飛行の 8 フレームを消化させる
const WAIT_MILLIS: int = 500

const TOLERANCE: Vector2 = Vector2(0.001, 0.001)

# `push_error` の文言はテストの側に複製を持つ: 実装の定数を参照すると、文言を変える変異が
# 自己成就して落ちない
const MISSING_PULSE_SCENE_ERROR: String = (
	"AnalysisDevStage: pulse_scene が設定されていない。解析の演出を生成せずに返る"
)

# ツリーへ載せた `Player` が自前の入力で撃たないようにする。lambda は使わない
const NEUTRAL_INPUT_SOURCE: String = """
extends RefCounted


func read() -> PlayerCommand:
	return PlayerCommand.new()
"""


func test_the_values_used_here_differ_from_the_defaults() -> void:
	# 既定値と一致する値を渡していないことを先に固定する: 既定のままだと、取得の回数を
	# 直書きした実装も緑になる
	var stats: PlayerStats = auto_free(PlayerStats.new())
	assert_int(ABILITY_USES).is_not_equal(stats.ability_uses)


func test_the_defeat_of_a_shooter_adds_one_pulse_to_the_stage() -> void:
	var stage: AnalysisDevStage = _create_stage()

	stage._on_enemy_defeated(SHOOTER, ENEMY_PATH)

	var pulses: Array[AnalysisPulse] = _pulses_in_the_whole_tree()
	assert_array(pulses).has_size(1)
	if pulses.size() != 1:
		return
	# 撃破された敵の子にしない: 敵は `defeated` の直後に解放される
	assert_object(pulses[0].get_parent()).is_same(stage)


func test_the_defeat_of_a_charger_adds_one_pulse_to_the_stage() -> void:
	# 写せない種別でも演出は出る。片方の種別だけを見ると、「常に生成する」実装と
	# 「片方だけ生成する」実装を区別できない
	var stage: AnalysisDevStage = _create_stage()

	stage._on_enemy_defeated(CHARGER, ENEMY_PATH)

	var pulses: Array[AnalysisPulse] = _pulses_in_the_whole_tree()
	assert_array(pulses).has_size(1)
	if pulses.size() != 1:
		return
	assert_object(pulses[0].get_parent()).is_same(stage)


func test_the_pulse_starts_at_the_global_position_of_the_defeated_enemy() -> void:
	var stage: AnalysisDevStage = _create_stage()
	var enemy: Node2D = stage.get_node(ENEMY_PATH)
	# 局所座標と大域座標がずれていることを先に固定する: 重なっていると、`position` を
	# 読む実装も緑になる
	assert_vector(enemy.global_position).is_not_equal(enemy.position)

	stage._on_enemy_defeated(SHOOTER, ENEMY_PATH)

	var pulses: Array[AnalysisPulse] = _pulses_in_the_whole_tree()
	assert_array(pulses).has_size(1)
	if pulses.size() != 1:
		return
	assert_vector(pulses[0].global_position).is_equal_approx(enemy.global_position, TOLERANCE)


func test_the_start_of_the_pulse_follows_the_bound_node_path() -> void:
	# 2 体を置いて 2 体目を撃破する: 1 体だけだと、`NodePath` を解決せずに最初の子を
	# 始点にする実装が素通りする
	var stage: AnalysisDevStage = _create_stage()
	var enemy: Node2D = stage.get_node(ENEMY_PATH)
	var other: Node2D = stage.get_node(OTHER_ENEMY_PATH)

	stage._on_enemy_defeated(SHOOTER, OTHER_ENEMY_PATH)

	var pulses: Array[AnalysisPulse] = _pulses_in_the_whole_tree()
	assert_array(pulses).has_size(1)
	if pulses.size() != 1:
		return
	assert_vector(pulses[0].global_position).is_equal_approx(other.global_position, TOLERANCE)
	assert_vector(pulses[0].global_position).is_not_equal(enemy.global_position)


func test_the_pulse_outlives_the_defeated_enemy() -> void:
	var stage: AnalysisDevStage = _create_stage()
	var enemy: Node2D = stage.get_node(ENEMY_PATH)

	stage._on_enemy_defeated(SHOOTER, ENEMY_PATH)

	var pulses: Array[AnalysisPulse] = _pulses_in_the_whole_tree()
	assert_array(pulses).has_size(1)
	if pulses.size() != 1:
		return
	var pulse: AnalysisPulse = pulses[0]
	# 飛行を engine に進めさせない: 到達で自分から解放されると、敵の解放との区別が付かない
	pulse.set_physics_process(false)

	enemy.queue_free()
	await await_idle_frame()

	assert_bool(is_instance_valid(enemy)).is_false()
	# 敵の子にする実装は、敵の解放で演出ごと消える
	assert_bool(is_instance_valid(pulse)).is_true()
	if not is_instance_valid(pulse):
		return
	assert_object(pulse.get_parent()).is_same(stage)


func test_the_engine_flies_the_pulse_to_the_player_and_grants_the_ability() -> void:
	# 実フレームで駆動する唯一のケース: 手で `_physics_process` を回すヘルパだけに頼ると、
	# 演出が木に載って自分で進むことを観測できない
	var stage: AnalysisDevStage = _create_stage()
	var player: Player = stage.get_node(NodePath(PLAYER_NAME))
	var enemy: Node2D = stage.get_node(ENEMY_PATH)

	stage._on_enemy_defeated(SHOOTER, ENEMY_PATH)

	var pulses: Array[AnalysisPulse] = _pulses_in_the_whole_tree()
	assert_array(pulses).has_size(1)
	if pulses.size() != 1:
		return
	var pulse: AnalysisPulse = pulses[0]
	# 飛行時間を縮める: 既定の 0.4 秒のままだと、待ち時間がフレーム数と結び付かない
	pulse.flight_time = _flight_time(FLIGHT_FRAMES)
	var arrivals: Array[Vector2] = []
	var targets: Array[Vector2] = []
	pulse.arrived.connect(_record_arrival.bind(pulse, player, arrivals, targets))

	await await_millis(WAIT_MILLIS)

	assert_array(arrivals).has_size(1)
	if arrivals.size() != 1:
		return
	# 到達の位置がプレイヤーの位置であること。標的が敵のままなら、演出は始点から動かない
	assert_vector(arrivals[0]).is_equal_approx(targets[0], TOLERANCE)
	assert_vector(targets[0]).is_not_equal(enemy.global_position)
	# 到達が配線されていること。`arrived` を繋がない実装はここで落ちる
	assert_int(_remaining_uses(player)).is_equal(ABILITY_USES)


func test_the_arrival_of_a_charger_grants_nothing() -> void:
	var stage: AnalysisDevStage = _create_stage()
	var player: Player = stage.get_node(NodePath(PLAYER_NAME))

	stage._on_enemy_defeated(CHARGER, ENEMY_PATH)

	var pulses: Array[AnalysisPulse] = _pulses_in_the_whole_tree()
	assert_array(pulses).has_size(1)
	if pulses.size() != 1:
		return
	var pulse: AnalysisPulse = pulses[0]
	pulse.flight_time = _flight_time(FLIGHT_FRAMES)
	var kinds: Array[int] = []
	pulse.arrived.connect(func(kind: int) -> void: kinds.append(kind))
	# engine と手回しを混ぜない: 混ざると到達のフレームを数えられない
	pulse.set_physics_process(false)

	_advance(pulse, FLIGHT_FRAMES)

	# 到達そのものは起きていること。起きていなければ「取得しない」は空振りの緑になる
	assert_array(kinds).is_equal([CHARGER])
	assert_int(_remaining_uses(player)).is_equal(0)


func test_the_arrival_of_a_shooter_grants_the_ability() -> void:
	var stage: AnalysisDevStage = _create_stage()
	var player: Player = stage.get_node(NodePath(PLAYER_NAME))

	stage._on_pulse_arrived(SHOOTER)

	assert_int(_remaining_uses(player)).is_equal(ABILITY_USES)


func test_the_arrival_of_a_charger_keeps_the_remaining_uses() -> void:
	var stage: AnalysisDevStage = _create_stage()
	var player: Player = stage.get_node(NodePath(PLAYER_NAME))
	player.grant_ability()
	# 1 回使ってから届ける: 満杯のまま確かめると、種別を見ずに取得し直す変異が同じ値へ
	# 落ち着いて素通りする
	assert_bool(player.ability_slot.update(true, _frame_delta())).is_true()
	assert_int(player.ability_slot.remaining_uses).is_equal(ABILITY_USES - 1)

	stage._on_pulse_arrived(CHARGER)

	assert_int(player.ability_slot.remaining_uses).is_equal(ABILITY_USES - 1)


func test_a_defeat_without_a_pulse_scene_pushes_an_error_and_adds_no_child() -> void:
	var stage: AnalysisDevStage = _create_stage(false)
	var children_before: int = stage.get_child_count()

	var defeat: Callable = func() -> void: stage._on_enemy_defeated(SHOOTER, ENEMY_PATH)
	await assert_error(defeat).is_push_error(MISSING_PULSE_SCENE_ERROR)

	assert_int(stage.get_child_count()).is_equal(children_before)
	assert_array(_pulses_in_the_whole_tree()).is_empty()


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


func _frame_delta() -> float:
	return 1.0 / float(Engine.physics_ticks_per_second)


func _flight_time(frames: int) -> float:
	return _frame_delta() * frames


func _advance(pulse: AnalysisPulse, frames: int) -> void:
	for _frame: int in frames:
		pulse._physics_process(_frame_delta())


func _create_stage(with_pulse_scene: bool = true) -> AnalysisDevStage:
	var stage: AnalysisDevStage = auto_free(AnalysisDevStage.new())
	if with_pulse_scene:
		stage.pulse_scene = PULSE_SCENE
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
	var player: Player = auto_free(PLAYER_SCENE.instantiate())
	var stats: PlayerStats = auto_free(PlayerStats.new())
	stats.ability_uses = ABILITY_USES
	player.stats = stats
	player.input_source = Callable(_create_input_stub(), "read")
	stage.add_child(player)
	player.position = PLAYER_POSITION
	return player


func _create_input_stub() -> RefCounted:
	var stub_script: GDScript = GDScript.new()
	stub_script.source_code = NEUTRAL_INPUT_SOURCE
	stub_script.reload()
	return auto_free(stub_script.new())


# 到達の瞬間の 2 つの位置を対で控える: 別々のフレームで読むと、標的が動く分だけずれる
func _record_arrival(
	_kind: int,
	pulse: AnalysisPulse,
	player: Node2D,
	arrivals: Array[Vector2],
	targets: Array[Vector2]
) -> void:
	arrivals.append(pulse.global_position)
	targets.append(player.global_position)


# 枠がまだ作られていない状態を 0 として読む: `ability_slot` は最初の物理フレーム
# または `grant_ability()` で作られるため、取得しない経路では null のままになりうる
func _remaining_uses(player: Player) -> int:
	if player.ability_slot == null:
		return 0
	return player.ability_slot.remaining_uses


func _collect_nodes(node: Node, into: Array[Node]) -> void:
	into.append(node)
	for child: Node in node.get_children():
		_collect_nodes(child, into)


# 演出をステージの直下ではなく木の全体から数える: 追加先を別のノード(敵・ステージの親)へ
# 変えただけの実装は、直下だけを見ていると「生成しない」と誤って読める
func _pulses_in_the_whole_tree() -> Array[AnalysisPulse]:
	var nodes: Array[Node] = []
	_collect_nodes(get_tree().root, nodes)
	var pulses: Array[AnalysisPulse] = []
	for node: Node in nodes:
		if node is AnalysisPulse:
			pulses.append(node as AnalysisPulse)
	return pulses
