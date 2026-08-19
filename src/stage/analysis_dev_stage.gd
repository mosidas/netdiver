class_name AnalysisDevStage
extends Node2D

## 解析の確認用の仮ステージ。
##
## 撃破 → 演出 → 到達 → 取得の配線を持つ。プレイヤー単体の手触りを見る `DevStage` とも
## 戦闘を見る `EnemyDevStage` とも別に置き、どちらも変更しない。
## 配置だけが違う 2 つのシーンでこのスクリプトを共有する: 配線はどちらのシーンでも同じであり、
## 実装を 2 つに分けると同じ配線を 2 度検証することになる。

const MISSING_PULSE_SCENE_ERROR: String = (
	"AnalysisDevStage: pulse_scene が設定されていない。解析の演出を生成せずに返る"
)

## 解析の演出のシーン。値の出どころを 1 箇所にするため、参照はシーンの宣言で与える
@export var pulse_scene: PackedScene


## 敵の撃破を受け、撃破位置からプレイヤーへ解析の演出を飛ばす。
##
## 撃破された敵は `binds` の `NodePath` で受け取る: 生のノード参照はシーンの `[connection]`
## の宣言に書けず、`_ready()` での接続に頼ると `instantiate()` だけでは接続が復元されない。
##
## 種別で分岐しない: 解析はどちらの種別でも走り、写せるかどうかの判断は到達の側にある
func _on_enemy_defeated(kind: int, enemy_path: NodePath) -> void:
	if pulse_scene == null:
		push_error(MISSING_PULSE_SCENE_ERROR)
		return

	var enemy: Node2D = get_node(enemy_path)
	var pulse: AnalysisPulse = pulse_scene.instantiate()
	# 撃破された敵の子にしない: 敵は `defeated` の直後に解放されるため、子にすると
	# 演出も一緒に消える
	add_child(pulse)
	pulse.arrived.connect(_on_pulse_arrived)
	# 木へ載せてから `launch()` する: 載せる前に置いた始点は、載せた時点でステージの
	# 位置の分だけずれる
	pulse.launch(kind, enemy.global_position, _player())


## 演出の到達を受け、写せる種別のときだけ能力を配る。
##
## 種別の判定を自分で持たない: 判定を写すと、写せる種別を足すときに書き換える場所が増える
func _on_pulse_arrived(kind: int) -> void:
	if not AbilityAnalysis.is_transferable(kind):
		return
	_player().grant_ability()


# 再開位置を持たない: `DevStage`・`EnemyDevStage` と同じく、常にシーンごと読み直して
# 先頭からやり直す。
#
# 読み直しを遅らせる: `died` は敵の攻撃の当たり(`EnemyProjectile`・`Attackbox` の
# `body_entered`)から届くため、この関数は物理コールバックの最中に走る。そこで現在のシーンを
# 差し替えると、コールバックの最中に `CollisionObject2D` を消すことになり物理サーバの走査を
# 壊す(`EnemyProjectile._release()` が `free()` を避けるのと同じ理由)
func _on_player_died() -> void:
	get_tree().reload_current_scene.call_deferred()


# プレイヤーを名前ではなく型で引く: 名前はシーンごとの都合で変わりうるが、演出の標的と
# 能力の受け手はどちらも 1 体しか居ないプレイヤーで一意に決まる
func _player() -> Player:
	for child: Node in get_children():
		if child is Player:
			return child as Player
	return null
