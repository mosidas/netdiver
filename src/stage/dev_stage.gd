## 動作確認用の仮ステージ。
##
## 床・段差・壁と Player を置いた、実行時に手触りを確かめるための場。
## 本番のステージは別の作業単位で作るため、ここでは TileMapLayer を使わない。
class_name DevStage
extends Node2D


# 再開位置を持たない: 常にシーンごと読み直してステージの先頭からやり直す。
# 途中再開の状態を持つと、手触りの確認が「どこから再開したか」に依存する
func _on_player_died() -> void:
	get_tree().reload_current_scene()
