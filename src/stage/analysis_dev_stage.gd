class_name AnalysisDevStage
extends Node2D

## 解析の確認用の仮ステージ。
##
## 撃破 → 断片の出現 → 干渉の配線を持つ。プレイヤー単体の手触りを見る `DevStage` とも
## 戦闘を見る `EnemyDevStage` とも別に置き、どちらも変更しない。

const MISSING_FRAGMENT_SCENE_ERROR: String = (
	"AnalysisDevStage: fragment_scene が設定されていない。断片を生成せずに返る"
)

## 断片のシーン。値の出どころを 1 箇所にするため、参照はシーンの宣言で与える
@export var fragment_scene: PackedScene


## 敵の撃破を受け、写せる種別のときだけ撃破位置へ断片を残す。
##
## 撃破された敵は `binds` の `NodePath` で受け取る: 生のノード参照はシーンの `[connection]`
## の宣言に書けず、`_ready()` での接続に頼ると `instantiate()` だけでは接続が復元されない。
##
## 種別の判定を自分で持たない: 判定を写すと、写せる種別を足すときに書き換える場所が増える。
##
## 取得の配線を持たない: 断片は触れた相手へ自分で強化を渡すため、ステージは受け手を引かない
##
## 未設定の報せだけはこの呼び出しの中で出す: 遅らせると、呼び出し側が異常を観測する窓の
## 外へ出てしまう
func _on_enemy_defeated(kind: int, enemy_path: NodePath) -> void:
	if not AbilityAnalysis.is_transferable(kind):
		return

	# 種別の判定より後に置く: 前に置くと、生成を試みない種別の撃破でも未設定を報せてしまう
	if fragment_scene == null:
		push_error(MISSING_FRAGMENT_SCENE_ERROR)
		return

	var enemy: Node2D = get_node(enemy_path)
	# 位置はここで読む: 撃破された敵は `defeated` の直後に解放されるため、遅らせた先で
	# `global_position` を読める保証が無い。撃破の時点の値が残すべき位置である
	_place_fragment.call_deferred(enemy.global_position)


# 生成と追加を遅らせる: `defeated` は敵の当たり判定(`Hurtbox` の `area_entered`)から
# 届くため、この関数は物理コールバックの最中に走る。そこで当たり判定を持つ `Area2D` を
# 木へ載せると、走査の最中に監視の状態を変えることになり物理サーバが拒否する
# (`_on_player_died()` が再読込を遅らせるのと同じ理由)。
#
# 生成も遅らせる: このフレームでステージが解放された場合、遅らせた呼び出しは丸ごと
# 捨てられ、木に載らない断片が取り残されない
func _place_fragment(at: Vector2) -> void:
	var fragment: AnalysisFragment = fragment_scene.instantiate()
	# 撃破された敵の子にしない: 敵は `defeated` の直後に解放されるため、子にすると
	# 断片も一緒に消える
	add_child(fragment)
	# 木へ載せてから位置を決める: 載せる前に置いた位置は、載せた時点でステージの位置の
	# 分だけずれる
	fragment.global_position = at


# 再開位置を持たない: `DevStage`・`EnemyDevStage` と同じく、常にシーンごと読み直して
# 先頭からやり直す。
#
# 読み直しを遅らせる: `died` は敵の攻撃の当たり(`EnemyProjectile`・`Attackbox` の
# `body_entered`)から届くため、この関数は物理コールバックの最中に走る。そこで現在のシーンを
# 差し替えると、コールバックの最中に `CollisionObject2D` を消すことになり物理サーバの走査を
# 壊す(`EnemyProjectile._release()` が `free()` を避けるのと同じ理由)
func _on_player_died() -> void:
	get_tree().reload_current_scene.call_deferred()
