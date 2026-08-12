class_name SecondaryWeapon
extends RefCounted

## 副武器の充電とクールダウンを進める状態機械。
##
## ノードにしない: 経過時間は呼び出し側が `update()` で進めるため、物理フレームを必要としない。

var charge_ratio: float = 0.0
var is_cooling_down: bool = false

var _charge_time: float
var _cooldown: float
var _cooldown_elapsed: float = 0.0


## 引数の検査を持たない: 値の出どころは `PlayerStats` であり、0 以下の値は
## `Player._ready()` が検査する
func _init(charge_time: float, cooldown: float) -> void:
	_charge_time = charge_time
	_cooldown = cooldown


## 充電の進行とクールダウンの経過の両方を 1 フレーム分進め、発射するなら真を返す。
##
## 事後条件: 真を返した直後は `is_cooling_down` が真で `charge_ratio` が 0.0
func update(held: bool, delta: float) -> bool:
	if is_cooling_down:
		_cooldown_elapsed += delta
		if _cooldown_elapsed >= _cooldown:
			is_cooling_down = false
		# 明けたフレームで充電を始めない: 同じ delta を冷却と充電の両方へ数えると、
		# 発射から次の発射までが cooldown + charge_time より短くなる
		return false

	if held:
		charge_ratio = minf(charge_ratio + delta / _charge_time, 1.0)
		return false

	# ここから先は離したフレーム。充電が満ちていなければ捨てる
	if charge_ratio < 1.0:
		# 進んだ分を残さない: 残すと次の充電が短くなり、待ちが charge_time より縮む
		charge_ratio = 0.0
		return false

	charge_ratio = 0.0
	is_cooling_down = true
	# 経過を持ち越さない: 持ち越すとクールダウンが 2 発目以降で短くなる
	_cooldown_elapsed = 0.0
	return true
