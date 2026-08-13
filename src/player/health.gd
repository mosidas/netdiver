class_name Health
extends RefCounted

## 体力・自動回復の待機時間・回復の進行を進める状態機械。
##
## ノードにしない: 経過時間は呼び出し側が `tick()` で進めるため、物理フレームを必要としない。

signal depleted

const INVALID_AMOUNT_ERROR_FORMAT: String = (
	"Health.take_damage(): amount は正でなければならない(現在値: %s)。状態を変えずに返る"
)

var current: int
var is_depleted: bool = false

var _max_value: int
var _regen_delay: float
var _regen_per_second: float
var _elapsed_since_damage: float = 0.0
# 回復は連続量だが current は整数。1 に満たない分をここへ蓄える
var _regen_remainder: float = 0.0


## 引数の検査を持たない: 値の出どころは `PlayerStats` であり、0 以下の値は
## `Player._ready()` が検査する
func _init(max_value: int, regen_delay: float, regen_per_second: float) -> void:
	_max_value = max_value
	_regen_delay = regen_delay
	_regen_per_second = regen_per_second
	current = max_value


## 体力を `amount` だけ減らし、回復の待機時間の計測を最初からやり直す。
## 体力が 0 に達した最初の 1 回だけ `depleted` を発火する。
##
## 事前条件: `amount` は正。0 以下なら `push_error` を出して状態を変えない
## 事後条件: `0 <= current <= max_value`
func take_damage(amount: int) -> void:
	# 引数の検査を枯渇の判定より先に置く: 枯渇していても呼び出し側の誤りは知らせる
	if amount <= 0:
		push_error(INVALID_AMOUNT_ERROR_FORMAT % amount)
		return

	if is_depleted:
		return

	current = clampi(current - amount, 0, _max_value)
	_elapsed_since_damage = 0.0
	# 端数を残さない: 残すと被弾のたびに次の回復の 1 点目が早まる
	_regen_remainder = 0.0

	if current == 0:
		is_depleted = true
		depleted.emit()


## 待機時間の経過と自動回復を 1 フレーム分進める。
##
## 事後条件: `0 <= current <= max_value`
func tick(delta: float) -> void:
	if is_depleted:
		return

	if _elapsed_since_damage < _regen_delay:
		_elapsed_since_damage += delta
		# 待機を消化したフレームでは回復しない: 同じ delta を待機と回復の両方へ数えると、
		# 被弾から回復の開始までが regen_delay より短くなる
		return

	_regen_remainder += _regen_per_second * delta
	var gained: int = floori(_regen_remainder)
	if gained <= 0:
		return

	_regen_remainder -= float(gained)
	current = mini(current + gained, _max_value)
