class_name Projectile
extends Area2D

## 武器が撃ち出す弾。
##
## 位置の更新は `_physics_process` の中だけで行う。物理フレームの外で位置を進めると
## Godot が描画フレームの delta を使い、同じ入力でも変位が定まらない。

var damage: int = 0

## 位置を進めた物理フレームの数。
##
## 待ち時間から消化フレーム数を決められないため、テストが変位の期待値を算出する観測点として
## 公開する。`Engine.get_physics_frames()` の差分では代用しない: ツリーへ載せた時刻と
## フレーム境界の関係で 1 フレームずれ、「待ちが足りずに進まなかった」と
## 「進まないことが正しい」を区別できない
var frames_moved: int = 0

var _velocity: Vector2 = Vector2.ZERO
var _max_distance: float = 0.0


@warning_ignore("shadowed_variable")
func launch(direction: Vector2i, speed: float, damage: int, max_distance: float) -> void:
	self.damage = damage
	_max_distance = max_distance
	# Vector2i のまま長さを測らない: 斜めの向きで速さが speed を超える
	_velocity = Vector2(direction).normalized() * speed


func _physics_process(delta: float) -> void:
	if _velocity.is_zero_approx():
		return
	frames_moved += 1
	position += _velocity * delta
