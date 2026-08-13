class_name Enemy
extends CharacterBody2D

## 2 種の敵が共有する基底。体力・撃破の判定をここに置き、種別ごとの差は `kind()` と
## 派生クラスの状態遷移が持つ。

signal defeated(kind: int)

const INVALID_AMOUNT_ERROR_FORMAT: String = (
	"Enemy.take_damage(): amount は正でなければならない(現在値: %s)。状態を変えずに返る"
)
const MISSING_STATS_ERROR: String = "Enemy: stats が設定されていない。既定値の EnemyStats を使う"
const NON_POSITIVE_STAT_ERROR_FORMAT: String = "Enemy: stats.%s は正でなければならない(現在値: %s)"
const NEGATIVE_STAT_ERROR_FORMAT: String = "Enemy: stats.%s は 0 以上でなければならない(現在値: %s)"

## 0 が「その振る舞いを持たない」ことを表す項目。実装が名前で持つのはこの集合だけで、
## 検査の対象そのものは `get_property_list()` から導く
const ZERO_ALLOWED_STAT_NAMES: Array[String] = [
	"move_speed",
	"attack_duration",
	"bullet_max_distance",
]

## 手触りを決める数値。代入した時点で体力を満たす: `_ready()` で満たすと、ツリーへ載せずに
## `take_damage()` を呼ぶ経路で体力が 0 のままになる
@export var stats: EnemyStats:
	set(value):
		stats = value
		if stats != null:
			hp = stats.max_hp

var hp: int
var is_defeated: bool = false


func _ready() -> void:
	if stats == null:
		push_error(MISSING_STATS_ERROR)
		stats = EnemyStats.new()
	_report_invalid_stats()


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


# 項目名の並びをここに持たず get_property_list() から導く: 並びを持つと、`EnemyStats` へ
# 項目を足したときに検査から漏れる。値は補正しない: 手触りの数値を実装が黙って書き換えると、
# `.tres` を直した結果と実行時の挙動が食い違う
func _report_invalid_stats() -> void:
	for property: Dictionary in stats.get_property_list():
		var usage: int = property["usage"]
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE == 0 or usage & PROPERTY_USAGE_EDITOR == 0:
			continue
		var type: int = property["type"]
		if type != TYPE_FLOAT and type != TYPE_INT:
			continue

		var stat_name: String = property["name"]
		var value: Variant = stats.get(stat_name)
		if ZERO_ALLOWED_STAT_NAMES.has(stat_name):
			if float(value) < 0.0:
				push_error(NEGATIVE_STAT_ERROR_FORMAT % [stat_name, value])
		elif float(value) <= 0.0:
			push_error(NON_POSITIVE_STAT_ERROR_FORMAT % [stat_name, value])
