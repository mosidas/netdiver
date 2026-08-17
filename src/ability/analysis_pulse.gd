class_name AnalysisPulse
extends Node2D

## 撃破した位置から標的へ飛び、到達を知らせる解析の演出。
##
## 位置の更新は `_physics_process` の中だけで行う。物理フレームの外で進めると Godot が
## 描画フレームの delta を使い、同じ設定でも到達までの時間が定まらない。

signal arrived(kind: int)

## プレイヤーの数値の集約側へ移さない: 演出の見え方を決める値であり、
## プレイヤーの手触りを決める値ではない
@export var flight_time: float = 0.4

var _kind: int = 0
var _from: Vector2 = Vector2.ZERO
var _target: Node2D = null
var _elapsed: float = 0.0

## 発射から到達までの間だけ真。到達で落とす: 落とさないと、解放されるまでの間に
## `arrived` が繰り返し出る
var _is_flying: bool = false


## 演出を `from` から `to` へ飛ばす。
##
## 事後条件: 呼び出しの直後の位置は `from` であり、`flight_time` の経過で `arrived` が
## 1 回だけ出る
func launch(kind: int, from: Vector2, to: Node2D) -> void:
	_kind = kind
	_from = from
	_target = to
	_elapsed = 0.0
	_is_flying = true
	# 1 フレーム目の物理処理を待たない: 待つと、撃破した位置ではなく生成時の位置から出たように見える
	global_position = from


func _physics_process(delta: float) -> void:
	if not _is_flying:
		return

	_elapsed += delta
	# 1 を超えさせない: `flight_time` が 1 フレームの整数倍でないとき、到達のフレームで
	# 標的を通り越した点に置かれる
	var progress: float = minf(_elapsed / flight_time, 1.0)
	# 発射時の標的の位置を目標に固定しない: 標的は動くため、固定すると到達点が標的から離れる
	global_position = _from.lerp(_target.global_position, progress)

	if _elapsed < flight_time:
		return

	_is_flying = false
	arrived.emit(_kind)
	# `free()` を使わない: 物理コールバックの最中に解放すると物理サーバの走査を壊す
	queue_free()
