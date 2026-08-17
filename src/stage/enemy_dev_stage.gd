## 敵の確認用の仮ステージ。
##
## 床・壁と Player・ChargerEnemy・ShooterEnemy を置いた、敵との戦闘を実行時に確かめるための場。
## プレイヤー単体の手触りを見る `DevStage` とは別に置く(あちらは変更しない)。
## 敵は 1 体ずつ置いて動的には出さない。出現の仕組みを持つと、確認したい戦闘が実行のたびに変わる。
class_name EnemyDevStage
extends Node2D


# 再開位置を持たない: `DevStage` と同じく、常にシーンごと読み直して先頭からやり直す。
# 途中再開の状態を持つと、手触りの確認が「どこから再開したか」に依存する。
#
# 読み直しを遅らせる: `died` は敵の攻撃の当たり(`EnemyProjectile`・`Attackbox` の
# `body_entered`)から届くため、この関数は物理コールバックの最中に走る。そこで現在のシーンを
# 差し替えると、コールバックの最中に `CollisionObject2D` を消すことになり物理サーバの走査を
# 壊す(`EnemyProjectile._release()` が `free()` を避けるのと同じ理由)
func _on_player_died() -> void:
	get_tree().reload_current_scene.call_deferred()
