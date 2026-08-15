class_name ShooterBrain
extends RefCounted

## 射撃型の状態遷移。IDLE → TELEGRAPH → COOLDOWN → IDLE を滞在時間で進め、予備動作を
## 抜けるフレームだけ真(このフレームで発射する)を返す。
##
## ノードにしない: 経過時間は呼び出し側が `update()` で進めるため、物理フレームを必要としない。
## 発射そのものは持たず、`ShooterEnemy` が真を返したフレームで敵弾を生成する。

var state: int = EnemyState.State.IDLE

var _telegraph_time: float
var _recover_time: float
var _detect_range: float
var _elapsed: float = 0.0


## 引数の検査を持たない: 値の出どころは `EnemyStats` であり、不正な値は `Enemy._ready()` が
## 検査する
func _init(stats: EnemyStats) -> void:
	_telegraph_time = stats.telegraph_time
	_recover_time = stats.recover_time
	# 索敵範囲(detect_range)を条件にする: 弾は距離によらず飛ぶため、突進型のように到達距離
	# (attack_speed * attack_duration)で絞る理由が無い
	_detect_range = stats.detect_range


## 状態を 1 フレーム分進める。標的が不在のとき、呼び出し側は距離に `INF` を渡す。
## 戻り値はこのフレームで発射するかどうかであり、真になるのは予備動作を抜ける 1 フレームだけ。
##
## 事後条件: `state` は `EnemyState.State` の 3 値(IDLE / TELEGRAPH / COOLDOWN)のいずれか
func update(delta: float, distance_to_target: float) -> bool:
	match state:
		EnemyState.State.IDLE:
			if distance_to_target <= _detect_range:
				_enter(EnemyState.State.TELEGRAPH)
		EnemyState.State.TELEGRAPH:
			if _has_elapsed(_telegraph_time, delta):
				# 距離で分岐しない(突進型は取りやめる): 弾は向きさえ決まれば当たりうるため、
				# 標的を失った回も待機へ進める。弾を作らない判断は `ShooterEnemy` が持つ
				_enter(EnemyState.State.COOLDOWN)
				return true
		EnemyState.State.COOLDOWN:
			if _has_elapsed(_recover_time, delta):
				_enter(EnemyState.State.IDLE)
	return false


# 判定を delta を足す前に行う: 足してから判定すると、満了したフレームの delta が遷移元と
# 遷移先の両方に数えられ、予備動作から発射までが telegraph_time より短くなる
func _has_elapsed(duration: float, delta: float) -> bool:
	if _elapsed >= duration:
		return true
	_elapsed += delta
	return false


func _enter(next_state: int) -> void:
	state = next_state
	# 経過を持ち越さない: 持ち越すと 2 周目以降の滞在時間が短くなる
	_elapsed = 0.0
