class_name ChargerBrain
extends RefCounted

## 突進型の状態遷移。IDLE → TELEGRAPH → CHARGE → RECOVER → IDLE を滞在時間で進める。
##
## ノードにしない: 経過時間は呼び出し側が `update()` で進めるため、物理フレームを必要としない。
## 移動そのものは持たず、`ChargerEnemy` が `state` を速度と攻撃判定へ写す。

var state: int = EnemyState.State.IDLE
var is_attack_active: bool = false

var _telegraph_time: float
var _attack_duration: float
var _recover_time: float
var _attack_reach: float
var _elapsed: float = 0.0


## 引数の検査を持たない: 値の出どころは `EnemyStats` であり、不正な値は `Enemy._ready()` が
## 検査する
func _init(stats: EnemyStats) -> void:
	_telegraph_time = stats.telegraph_time
	_attack_duration = stats.attack_duration
	_recover_time = stats.recover_time
	# 索敵範囲(detect_range)を条件にしない: 届かない位置から突進を始めると、予備動作が
	# 空振りに終わる
	_attack_reach = stats.attack_speed * stats.attack_duration


## 状態を 1 フレーム分進める。
##
## 事後条件: `state` は `EnemyState.State` の 4 値(IDLE / TELEGRAPH / CHARGE / RECOVER)の
## いずれか。`is_attack_active` は `state` が CHARGE のときだけ真
func update(delta: float, distance_to_target: float) -> void:
	match state:
		EnemyState.State.IDLE:
			if distance_to_target <= _attack_reach:
				_enter(EnemyState.State.TELEGRAPH)
		EnemyState.State.TELEGRAPH:
			if _has_elapsed(_telegraph_time, delta):
				_enter(EnemyState.State.CHARGE)
		EnemyState.State.CHARGE:
			if _has_elapsed(_attack_duration, delta):
				_enter(EnemyState.State.RECOVER)
		EnemyState.State.RECOVER:
			if _has_elapsed(_recover_time, delta):
				_enter(EnemyState.State.IDLE)


# 判定を delta を足す前に行う: 足してから判定すると、満了したフレームの delta が遷移元と
# 遷移先の両方に数えられ、予備動作から突進までが telegraph_time より短くなる
func _has_elapsed(duration: float, delta: float) -> bool:
	if _elapsed >= duration:
		return true
	_elapsed += delta
	return false


func _enter(next_state: int) -> void:
	state = next_state
	# 経過を持ち越さない: 持ち越すと 2 周目以降の滞在時間が短くなる
	_elapsed = 0.0
	is_attack_active = next_state == EnemyState.State.CHARGE
