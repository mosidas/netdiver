class_name SpreadResolver
extends RefCounted

## 拡散の 3 方向を決める純粋関数。
##
## 引数だけに依存し、ノードの状態を持たない。

## 中央から左右へ振る角度(度)。
##
## 呼び出し側や PlayerStats に同じ値を置かない: 2 箇所に持つと、片方だけを変えたときに
## 弾の広がりと当たり判定の想定がずれる
const SPREAD_DEGREES: float = 20.0

const INVALID_DIRECTION_ERROR_FORMAT: String = (
	"SpreadResolver.resolve(): direction は 8 方向のいずれかでなければならない(現在値: %s)。"
	+ "空の配列を返す"
)

## 引数として妥当な向きの集合。
##
## 隣り合いの環として使わない: 20 度は 45 度刻みの格子に載らず、環の隣接では表せない。
## 事前条件の検査にだけ使う
const EIGHT_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(1, 1),
	Vector2i(0, 1),
	Vector2i(-1, 1),
	Vector2i(-1, 0),
	Vector2i(-1, -1),
	Vector2i(0, -1),
	Vector2i(1, -1),
]


## `direction` を正規化した向きと、そこから左右へ `SPREAD_DEGREES` 度回した向きを
## `[中央, 反時計回り, 時計回り]` の順で返す。
##
## 事前条件: `direction` は 8 方向のいずれか。満たさない場合は `push_error` を出し、
## 空の配列を返す
## 事後条件: 戻り値は 3 要素。すべて長さ 1 の向きであり `Vector2.ZERO` を含まない
static func resolve(direction: Vector2i) -> Array[Vector2]:
	if not EIGHT_DIRECTIONS.has(direction):
		push_error(INVALID_DIRECTION_ERROR_FORMAT % direction)
		return []

	var center: Vector2 = Vector2(direction).normalized()
	var offset: float = deg_to_rad(SPREAD_DEGREES)

	# 呼び出しごとに新しい配列を組む: 使い回しの配列を返すと、
	# 呼び出し側の書き換えが次の呼び出しへ残る
	var spread: Array[Vector2] = []
	spread.append(center)
	# 反時計回りに負の角を渡す: 画面座標(y は下向き)では Vector2.rotated() の
	# 正の角が時計回りに対応する
	spread.append(center.rotated(-offset))
	spread.append(center.rotated(offset))
	return spread
