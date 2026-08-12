class_name PrimaryWeapon
extends RefCounted

## 主武器の発射間隔を測る状態機械。
##
## ノードにしない: 経過時間は呼び出し側が `tick()` で進めるため、物理フレームを必要としない。

var _interval: float
var _elapsed: float


## 引数の検査を持たない: `interval` の出どころは `PlayerStats` であり、0 以下の値は
## `Player._ready()` が検査する。`interval` が 0 でも「0 秒以上経過した」は常に成り立つ
func _init(interval: float) -> void:
	_interval = interval
	# 経過時間を 0 から始めない: 生成直後の最初の入力で 1 回分待たされる
	_elapsed = interval


func tick(delta: float) -> void:
	_elapsed += delta


## 発射できるなら真を返し、経過時間の計測を最初からやり直す。
##
## 事後条件: 真を返す間隔は常に `interval` 以上。偽を返した場合は状態を変えない
func try_fire() -> bool:
	if _elapsed < _interval:
		return false

	# 余りを繰り越さない: 繰り越すと待ちが interval より短くなり、事後条件を破る
	_elapsed = 0.0
	return true
