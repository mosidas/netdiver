extends GdUnitTestSuite

const FRAGMENT_SOURCE_PATH: String = "res://src/ability/analysis_fragment.gd"

const NO_LAYER: int = 0
const PLAYER_LAYER: int = 1 << 1

# 接触を作るためにテストの側で与える当たり判定の寸法。断片のシーンが持つ寸法とは別の値に取る:
# シーンの構成は別のタスクの担当であり、値を写すと担当外の契約をここで固定してしまう
const CONTACT_SHAPE_SIZE: Vector2 = Vector2(12.0, 12.0)

# 断片を原点に置かない: 原点だと、位置を `Vector2.ZERO` へ落とす変異と静止を区別できない
const FRAGMENT_POSITION: Vector2 = Vector2(-37.0, 21.0)
# 当たり判定が重ならない距離。プレイヤーへ寄る実装は、ここから近づいて接触してしまう
const AWAY_POSITION: Vector2 = Vector2(240.0, -160.0)

# 60 Hz で約 24 フレーム。重なりの通知の遅れ(1 物理フレーム)の十数倍を取る
const WAIT_MILLIS: int = 400
# 待ちが足りずにフレームを消化しなかった場合と区別するための下限
const MIN_FRAMES: int = 4
# 重なりの成立に 1 フレーム、`Area2D` の重なりの通知の遅れにもう 1 フレーム
const MAX_CONTACT_FRAMES: int = 2

const DEFAULT_TIME_SCALE: float = 1.0
# 既定と別の値を置いてから接触させる: 既定のまま見ると、`Engine.time_scale` へ既定値を
# 代入する変異が素通りする
const OTHER_TIME_SCALE: float = 0.5


## `grant_upgrade()` を持つ body。プレイヤーの代わりに置く: `Player` を継承しないため、
## 相手を型ではなくメソッドの有無で見分ける契約を `Player` を持ち込まずに試せる
class GrantableBody:
	extends CharacterBody2D

	var grant_calls: int = 0

	## 強化を受け取った印。断片がこれを読まないことを 2 回目の接触で見る
	var is_upgraded: bool = false

	func grant_upgrade() -> void:
		grant_calls += 1
		is_upgraded = true


## `grant_upgrade()` を持つ `Area2D`。プレイヤーは `CharacterBody2D` であってこれではないため、
## 近づけても何も起きない。`area_entered` で受ける実装はここで落ちる
class GrantableArea:
	extends Area2D

	var grant_calls: int = 0

	func grant_upgrade() -> void:
		grant_calls += 1


## 消化した物理フレームを数え、断片の位置を毎フレーム控えるだけのノード。待ち時間が足りずに
## フレームを消化しなかった場合と、動かないことが正しい場合を区別する
class FragmentWitness:
	extends Node

	var fragment: Node2D
	var frames: int = 0
	var positions: Array[Vector2] = []

	func _physics_process(_delta: float) -> void:
		frames += 1
		if is_instance_valid(fragment):
			positions.append(fragment.global_position)


var _saved_time_scale: float = DEFAULT_TIME_SCALE
var _saved_paused: bool = false


func before_test() -> void:
	_saved_time_scale = Engine.time_scale
	_saved_paused = get_tree().paused


func after_test() -> void:
	# 失敗した回にも戻す: 残ると、実フレームで駆動する他のケースの進み方が変わる
	Engine.time_scale = _saved_time_scale
	get_tree().paused = _saved_paused


# 親を auto_free するため子は登録しない: 親の解放で一緒に解放される
func _create_collision_shape() -> CollisionShape2D:
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = CONTACT_SHAPE_SIZE
	collision_shape.shape = rectangle
	return collision_shape


## レイヤ・マスク・当たり判定の構成は断片のシーン(別のタスク)が持つ。スクリプト単体で接触が
## 成立する構成をここで与える
func _create_fragment(at: Vector2) -> AnalysisFragment:
	var fragment: AnalysisFragment = auto_free(AnalysisFragment.new())
	fragment.collision_layer = NO_LAYER
	fragment.collision_mask = PLAYER_LAYER
	fragment.position = at
	fragment.add_child(_create_collision_shape())
	return fragment


func _create_grantable_body(at: Vector2) -> GrantableBody:
	var body: GrantableBody = auto_free(GrantableBody.new())
	body.collision_layer = PLAYER_LAYER
	body.collision_mask = NO_LAYER
	body.position = at
	body.add_child(_create_collision_shape())
	return body


## `grant_upgrade()` を持たない body。持つ側と同じ型に取る: 型とメソッドの有無が相関した
## スタブだけだと、`has_method()` を `body is CharacterBody2D` へ置き換える変異が素通りする
func _create_plain_body(at: Vector2) -> CharacterBody2D:
	var body: CharacterBody2D = auto_free(CharacterBody2D.new())
	body.collision_layer = PLAYER_LAYER
	body.collision_mask = NO_LAYER
	body.position = at
	body.add_child(_create_collision_shape())
	return body


func _create_grantable_area(at: Vector2) -> GrantableArea:
	var area: GrantableArea = auto_free(GrantableArea.new())
	area.collision_layer = PLAYER_LAYER
	area.collision_mask = NO_LAYER
	area.position = at
	area.add_child(_create_collision_shape())
	return area


func _add_witness(fragment: Node2D) -> FragmentWitness:
	var witness: FragmentWitness = auto_free(FragmentWitness.new())
	witness.fragment = fragment
	add_child(witness)
	return witness


func _script_variable_names(object: Object) -> Array[String]:
	var names: Array[String] = []
	for property: Dictionary in object.get_property_list():
		if property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE != 0:
			names.append(property["name"])
	return names


func test_the_fragment_is_an_area() -> void:
	var fragment: AnalysisFragment = auto_free(AnalysisFragment.new())

	assert_object(fragment).is_instanceof(Area2D)


func test_taking_the_fragment_leaves_the_pause_untouched() -> void:
	# 接触を同期で作り、実フレームで駆動するケースより前に置く: `SceneTree.paused` を書き換える
	# 実装は物理フレームを止めるため、実フレームのケースでは失敗ではなく待ちとして現れる
	var running_fragment: AnalysisFragment = _create_fragment(FRAGMENT_POSITION)
	add_child(running_fragment)
	var paused_fragment: AnalysisFragment = _create_fragment(FRAGMENT_POSITION)
	add_child(paused_fragment)
	var body: GrantableBody = _create_grantable_body(AWAY_POSITION)

	running_fragment.body_entered.emit(body)
	var paused_after_running_contact: bool = get_tree().paused
	# 既定と別の値のところでも接触させる: 既定(偽)のところだけで見ると、`paused` へ既定値を
	# 代入する変異(ポーズ中に取得すると勝手に再開する)が素通りする
	get_tree().paused = true
	paused_fragment.body_entered.emit(body)
	var paused_after_paused_contact: bool = get_tree().paused
	# 観測した直後に戻す: ポーズを残すと、後続のケースが物理フレームを消化できない
	get_tree().paused = _saved_paused

	# 接触が起きたことを先に固定する: 起きていないと「触れても止めない」ことを見ていない
	assert_int(body.grant_calls).is_equal(2)
	assert_bool(paused_after_running_contact).is_false()
	assert_bool(paused_after_paused_contact).is_true()


func test_a_body_with_grant_upgrade_takes_the_fragment_and_releases_it() -> void:
	var fragment: AnalysisFragment = _create_fragment(FRAGMENT_POSITION)
	var body: GrantableBody = _create_grantable_body(FRAGMENT_POSITION)
	# 型で見る実装をここで落とす: 触れる側はプレイヤーではない
	var as_node: Node = body
	assert_bool(as_node is Player).is_false()
	var witness: FragmentWitness = _add_witness(fragment)
	add_child(body)
	add_child(fragment)
	# 断片の側の接続の後に繋ぐ: 断片が接触を処理し終えた直後の状態を読むため
	var contact_frames: Array[int] = []
	var valid_after_contact: Array[bool] = []
	var queued_after_contact: Array[bool] = []
	fragment.body_entered.connect(
		func(_body: Node2D) -> void:
			contact_frames.append(witness.frames)
			valid_after_contact.append(is_instance_valid(fragment))
			queued_after_contact.append(fragment.is_queued_for_deletion())
	)

	await await_millis(WAIT_MILLIS)

	assert_int(witness.frames).is_greater(MIN_FRAMES)
	assert_int(body.grant_calls).is_equal(1)
	assert_array(contact_frames).has_size(1)
	assert_int(contact_frames[0]).is_between(1, MAX_CONTACT_FRAMES)
	# `free()` へ変える変異はこの対で落ちる: 即座の解放だと真にならない
	assert_array(valid_after_contact).is_equal([true])
	assert_array(queued_after_contact).is_equal([true])
	assert_bool(is_instance_valid(fragment)).is_false()


func test_the_fragment_outlives_the_contact_callback_and_is_gone_one_frame_later() -> void:
	# `queue_free()` と `free()` の違いはここに現れる: 接触のコールバックの中では解放されず、
	# その次のフレームで解放される
	var fragment: AnalysisFragment = _create_fragment(FRAGMENT_POSITION)
	add_child(fragment)
	var body: GrantableBody = _create_grantable_body(AWAY_POSITION)
	var valid_right_after: Array[bool] = []
	var contact: Callable = func() -> void:
		fragment.body_entered.emit(body)
		valid_right_after.append(is_instance_valid(fragment))

	await assert_error(contact).is_success()

	assert_int(body.grant_calls).is_equal(1)
	assert_array(valid_right_after).is_equal([true])
	assert_bool(fragment.is_queued_for_deletion()).is_true()

	await await_idle_frame()

	assert_bool(is_instance_valid(fragment)).is_false()


func test_a_body_without_grant_upgrade_leaves_the_fragment_in_place() -> void:
	var fragment: AnalysisFragment = _create_fragment(FRAGMENT_POSITION)
	var body: CharacterBody2D = _create_plain_body(FRAGMENT_POSITION)
	var witness: FragmentWitness = _add_witness(fragment)
	add_child(body)
	add_child(fragment)
	var contacts: Array[bool] = []
	fragment.body_entered.connect(func(_body: Node2D) -> void: contacts.append(true))

	await await_millis(WAIT_MILLIS)

	assert_int(witness.frames).is_greater(MIN_FRAMES)
	# 接触そのものは届いている: 素通りの原因が構成の誤りでないことを先に固定する
	assert_array(contacts).is_equal([true])
	assert_bool(fragment.is_queued_for_deletion()).is_false()
	assert_bool(is_instance_valid(fragment)).is_true()
	assert_vector(fragment.global_position).is_equal(FRAGMENT_POSITION)


func test_the_fragment_reports_no_error_for_a_body_without_grant_upgrade() -> void:
	# マスクにはプレイヤーしか載らないため、素通りは異常ではなく想定内である
	var fragment: AnalysisFragment = _create_fragment(FRAGMENT_POSITION)
	add_child(fragment)
	var body: CharacterBody2D = _create_plain_body(AWAY_POSITION)

	await assert_error(func() -> void: fragment.body_entered.emit(body)).is_success()

	assert_bool(fragment.is_queued_for_deletion()).is_false()
	assert_bool(is_instance_valid(fragment)).is_true()


func test_an_area_that_offers_grant_upgrade_does_not_take_the_fragment() -> void:
	var fragment: AnalysisFragment = _create_fragment(FRAGMENT_POSITION)
	var area: GrantableArea = _create_grantable_area(FRAGMENT_POSITION)
	var witness: FragmentWitness = _add_witness(fragment)
	add_child(area)
	add_child(fragment)
	var overlaps: Array[bool] = []
	fragment.area_entered.connect(func(_area: Area2D) -> void: overlaps.append(true))

	await await_millis(WAIT_MILLIS)

	assert_int(witness.frames).is_greater(MIN_FRAMES)
	# 重なりは `area_entered` としては届いている。届いていながら何も起きないことが、
	# 受け取る信号を `body_entered` に限る契約である
	assert_array(overlaps).is_equal([true])
	assert_int(area.grant_calls).is_zero()
	assert_bool(fragment.is_queued_for_deletion()).is_false()
	assert_bool(is_instance_valid(fragment)).is_true()


func test_a_body_that_already_holds_the_upgrade_takes_another_fragment() -> void:
	# 断片は相手の状態を読まない: 2 回目の接触でも呼ばれて解放される
	var body: GrantableBody = _create_grantable_body(FRAGMENT_POSITION)
	add_child(body)
	var first: AnalysisFragment = _create_fragment(FRAGMENT_POSITION)
	add_child(first)

	await await_millis(WAIT_MILLIS)

	assert_bool(body.is_upgraded).is_true()
	assert_int(body.grant_calls).is_equal(1)
	assert_bool(is_instance_valid(first)).is_false()

	var second: AnalysisFragment = _create_fragment(FRAGMENT_POSITION)
	add_child(second)

	await await_millis(WAIT_MILLIS)

	assert_int(body.grant_calls).is_equal(2)
	assert_bool(is_instance_valid(second)).is_false()


func test_the_fragment_stays_where_it_was_left_while_the_frames_pass() -> void:
	# 寿命も重力も吸引も持たない。取りに来ていないプレイヤーを同じ場に置く: 寄っていく実装は
	# 位置が変わり、やがて接触して解放される
	var fragment: AnalysisFragment = _create_fragment(FRAGMENT_POSITION)
	var body: GrantableBody = _create_grantable_body(AWAY_POSITION)
	var witness: FragmentWitness = _add_witness(fragment)
	add_child(body)
	add_child(fragment)

	await await_millis(WAIT_MILLIS)

	assert_int(witness.frames).is_greater(MIN_FRAMES)
	assert_array(witness.positions).has_size(witness.frames)
	for index: int in witness.positions.size():
		var context: String = "frame=%s" % (index + 1)
		assert_vector(witness.positions[index]).append_failure_message(context).is_equal(
			FRAGMENT_POSITION
		)
	assert_int(body.grant_calls).is_zero()
	assert_bool(fragment.is_queued_for_deletion()).is_false()
	assert_bool(is_instance_valid(fragment)).is_true()


func test_taking_the_fragment_leaves_the_time_scale_untouched() -> void:
	assert_float(OTHER_TIME_SCALE).is_not_equal(DEFAULT_TIME_SCALE)
	Engine.time_scale = OTHER_TIME_SCALE

	var fragment: AnalysisFragment = _create_fragment(FRAGMENT_POSITION)
	var body: GrantableBody = _create_grantable_body(FRAGMENT_POSITION)
	var witness: FragmentWitness = _add_witness(fragment)
	add_child(body)
	add_child(fragment)

	await await_millis(WAIT_MILLIS)

	assert_int(witness.frames).is_greater(MIN_FRAMES)
	# 接触が起きたことを先に固定する: 起きていないと「触れても止めない」ことを見ていない
	assert_int(body.grant_calls).is_equal(1)
	assert_float(Engine.time_scale).is_equal(OTHER_TIME_SCALE)
	assert_bool(get_tree().paused).is_false()


func test_the_fragment_holds_no_script_variable() -> void:
	var fragment: AnalysisFragment = auto_free(AnalysisFragment.new())
	var stub: GrantableBody = auto_free(GrantableBody.new())

	# 走査の空振りと区別する: 同じ走査がスタブの変数は拾う
	assert_array(_script_variable_names(stub)).contains(["grant_calls", "is_upgraded"])
	# 名前を列挙して禁じない: 別名の項目を足す変異が素通りする。断片は種別も寿命も持たないため、
	# スクリプト変数が 1 つも無いことで示す
	assert_array(_script_variable_names(fragment)).is_empty()


func test_the_fragment_source_does_not_name_the_player() -> void:
	var source: String = FileAccess.get_file_as_string(FRAGMENT_SOURCE_PATH)

	assert_str(source).is_not_empty()
	assert_str(source).not_contains("Player")
