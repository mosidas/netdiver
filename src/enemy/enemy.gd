class_name Enemy
extends CharacterBody2D

## 2 種の敵が共有する基底。体力・撃破の判定をここに置き、種別ごとの差は `kind()` と
## 派生クラスの状態遷移が持つ。

signal defeated(kind: int)

const INVALID_AMOUNT_ERROR_FORMAT: String = (
	"Enemy.take_damage(): amount は正でなければならない(現在値: %s)。状態を変えずに返る"
)

## 手触りを決める数値。代入した時点で体力を満たす: `_ready()` で満たすと、ツリーへ載せずに
## `take_damage()` を呼ぶ経路で体力が 0 のままになる
@export var stats: EnemyStats:
	set(value):
		stats = value
		if stats != null:
			hp = stats.max_hp

var hp: int
var is_defeated: bool = false


## 体力を `amount` だけ減らす。0 に達した最初の 1 回だけ `defeated` を発火し、自身を解放する。
##
## 事前条件: `amount` は正。0 以下なら `push_error` を出して状態を変えない
## 事後条件: `0 <= hp <= stats.max_hp`
func take_damage(amount: int) -> void:
	# 引数の検査を撃破の判定より先に置く: 撃破済みでも呼び出し側の誤りは知らせる
	if amount <= 0:
		push_error(INVALID_AMOUNT_ERROR_FORMAT % amount)
		return

	if is_defeated:
		return

	hp = maxi(hp - amount, 0)
	if hp > 0:
		return

	# 解放より先に状態を確定して発火する: 受け手は撃破された敵の種別と状態を読む
	is_defeated = true
	defeated.emit(kind())
	queue_free()


## 敵の種別。派生クラスが上書きする。
func kind() -> int:
	return EnemyKind.Kind.CHARGER
