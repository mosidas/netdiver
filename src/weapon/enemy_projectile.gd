class_name EnemyProjectile
extends Area2D

## 敵が撃ち出す弾。
##
## 位置の更新は `_physics_process` の中だけで行う。物理フレームの外で位置を進めると
## Godot が描画フレームの delta を使い、同じ入力でも変位が定まらない。

const TAKE_DAMAGE_METHOD: StringName = &"take_damage"

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
var _launch_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	# `area_entered` では地形もプレイヤーも拾えない: どちらも `PhysicsBody2D` であって
	# `Area2D` ではない
	body_entered.connect(_on_body_entered)


## 弾を発射する。射程はこの呼び出しの時点の位置から測る。
##
## 事前条件: 呼び出し側は発射位置を設定してから呼ぶ。発射後に位置を動かすと、その移動分が
## 射程から差し引かれる。
@warning_ignore("shadowed_variable")
func launch(direction: Vector2, speed: float, damage: int, max_distance: float) -> void:
	self.damage = damage
	_max_distance = max_distance
	# 生成時の位置を基準にしない: 呼び出し側は生成してから発射位置を決めるため基準がずれる
	_launch_position = position
	# 向きを 8 方向へ丸めない: 近距離ほど狙いと実際の飛翔がずれる
	_velocity = direction.normalized() * speed


func _physics_process(delta: float) -> void:
	if _velocity.is_zero_approx():
		return
	frames_moved += 1
	position += _velocity * delta
	if position.distance_to(_launch_position) > _max_distance:
		_release()


func _on_body_entered(body: Node2D) -> void:
	# 相手を型で見ない: `Player` へ静的に依存させると、単位を跨ぐ結び付きができる。
	# 触れた相手のうち `take_damage()` を持たないもの(地形)はダメージの対象ではない
	if body.has_method(TAKE_DAMAGE_METHOD):
		# 解放より先に与える: 後にすると、受け手が弾の状態を見て振る舞いを決められない
		body.call(TAKE_DAMAGE_METHOD, damage)
	_release()


func _release() -> void:
	# `free()` を使わない: 物理コールバックの最中に解放すると物理サーバの走査を壊す
	queue_free()
