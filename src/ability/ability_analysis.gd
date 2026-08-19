class_name AbilityAnalysis
extends RefCounted

## 撃破した敵の種別から、プレイヤーへ写せる手続きを持つかを決める純粋関数。
##
## 引数だけに依存し、ノードの状態を持たない。
## 種別で分岐する場所をここ 1 つに限る: プレイヤーもステージも種別を見ないことで、
## 写せる種別を足すときに書き換える場所が 1 つに収まる。

const UNKNOWN_KIND_ERROR_FORMAT: String = (
	"AbilityAnalysis.is_transferable(): kind は EnemyKind.Kind の値でなければならない(現在値: %s)。"
	+ "偽を返す"
)


## `kind` の敵の制御をプレイヤーへ写せるなら真を返す。
##
## 事前条件: `kind` は `EnemyKind.Kind` の値。満たさない場合は `push_error` を出し、
## 偽を返す(配線の誤りであり、写せると誤認して能力を配らない)
static func is_transferable(kind: int) -> bool:
	# 有効な値を enum から導く: 値を書き写すと、種別が増えたときに写しが古いまま残る
	if not EnemyKind.Kind.values().has(kind):
		push_error(UNKNOWN_KIND_ERROR_FORMAT % kind)
		return false

	# 射撃型だけを写す: 突進型の制御は移動であり、写すと回避行動が増えて
	# 攻撃の同時数の見積もりが崩れる
	return kind == EnemyKind.Kind.SHOOTER
