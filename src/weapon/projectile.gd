class_name Projectile
extends Area2D

## 武器が撃ち出す弾。
##
## 位置の更新は `_physics_process` の中だけで行う。物理フレームの外で位置を進めると
## Godot が描画フレームの delta を使い、同じ入力でも変位が定まらない。

const ZERO_DIRECTION_ERROR: String = (
	"Projectile.launch(): direction は Vector2i.ZERO であってはならない。弾を進めずに返る"
)
const INVALID_LAUNCH_VALUE_ERROR_FORMAT: String = (
	"Projectile.launch(): %s は正でなければならない(現在値: %s)。弾を進めずに返る"
)

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
	# `area_entered` では地形を拾えない: 地形は `StaticBody2D` であって `Area2D` ではない
	body_entered.connect(_on_body_entered)


## 弾を発射する。射程はこの呼び出しの時点の位置から測る。
##
## 事前条件: 呼び出し側は発射位置を設定してから呼ぶ。発射後に位置を動かすと、その移動分が
## 射程から差し引かれる。`direction` は `Vector2.ZERO` 以外、`speed`・`damage`・
## `max_distance` は正。違反した場合は弾を進めずに返る。
##
## `direction` に `Vector2i` を使わない: 整数のベクトルは 8 方向の格子の上の値しか表せず、
## 水平から 20 度のような向きを渡せない。その向きのために弾のクラスを分ける案は採らない。
## レイヤ・射程・地形との衝突・解放のしかたが同じものが 2 つに分かれる。8 方向は `Vector2i`
## からの暗黙変換でそのまま渡せるため、整数の向きを渡す呼び出し側は変えずに済む。
##
## `ZERO_DIRECTION_ERROR` の文言だけが `Vector2i.ZERO` を指したまま残る: 実装の定数を
## 参照せず同じ文言を自分の定数として持つテスト(`tests/weapon/projectile_test.gd`)が
## 文言の退行を検出しており、そのテストは改訂しない方針であるため、文言を据え置く。
## 文言の訂正は、そのテストを改訂する作業単位で行う。
@warning_ignore("shadowed_variable")
func launch(direction: Vector2, speed: float, damage: int, max_distance: float) -> void:
	# ガードを関数の先頭に置く: 後ろに置くと、拒否する前に damage と射程の代入が済んでしまう
	# 短さは見ない: 長さが 0 でない限り `normalized()` は向きを返すため、短い向きを弾くのは
	# 事前条件(`Vector2.ZERO` でないこと)より広い
	if direction == Vector2.ZERO:
		push_error(ZERO_DIRECTION_ERROR)
		return
	if speed <= 0.0:
		push_error(INVALID_LAUNCH_VALUE_ERROR_FORMAT % ["speed", speed])
		return
	if damage <= 0:
		push_error(INVALID_LAUNCH_VALUE_ERROR_FORMAT % ["damage", damage])
		return
	if max_distance <= 0.0:
		push_error(INVALID_LAUNCH_VALUE_ERROR_FORMAT % ["max_distance", max_distance])
		return

	self.damage = damage
	_max_distance = max_distance
	# 生成時の位置を基準にしない: 呼び出し側は生成してから発射位置を決めるため基準がずれる
	_launch_position = position
	# 向きを 8 方向へ丸めない: 8 方向の格子に載らない向きへ撃てなくなる。正規化を省くのも
	# 不可。斜めや長さが 1 を超える向きで速さが speed を超える
	_velocity = direction.normalized() * speed


func _physics_process(delta: float) -> void:
	if _velocity.is_zero_approx():
		return
	frames_moved += 1
	position += _velocity * delta
	if position.distance_to(_launch_position) > _max_distance:
		_release()


func _on_body_entered(_body: Node2D) -> void:
	_release()


func _release() -> void:
	# `free()` を使わない: 物理コールバックの最中に解放すると物理サーバの走査を壊す
	queue_free()
