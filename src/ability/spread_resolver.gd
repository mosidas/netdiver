class_name SpreadResolver
extends RefCounted

## 拡散の 3 方向を決める純粋関数。
##
## 引数だけに依存し、ノードの状態を持たない。

const INVALID_DIRECTION_ERROR_FORMAT: String = (
	"SpreadResolver.resolve(): direction は 8 方向のいずれかでなければならない(現在値: %s)。"
	+ "空の配列を返す"
)

## 8 方向を時計回り(画面座標。y は下向き)に並べた環。
##
## 隣を成分の計算で導かない: 斜めと水平・垂直の隣り合いを成分だけで表そうとすると、
## 環の折り返しの扱いが場所ごとに分かれる
const CLOCKWISE_RING: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(1, 1),
	Vector2i(0, 1),
	Vector2i(-1, 1),
	Vector2i(-1, 0),
	Vector2i(-1, -1),
	Vector2i(0, -1),
	Vector2i(1, -1),
]


## `direction` とその両隣を `[中央, 反時計回りの隣, 時計回りの隣]` の順で返す。
##
## 事前条件: `direction` は 8 方向のいずれか。満たさない場合は `push_error` を出し、
## 空の配列を返す
## 事後条件: 戻り値は 3 要素。要素はすべて相異なる 8 方向であり `Vector2i.ZERO` を含まない
static func resolve(direction: Vector2i) -> Array[Vector2i]:
	var index: int = CLOCKWISE_RING.find(direction)
	if index < 0:
		push_error(INVALID_DIRECTION_ERROR_FORMAT % direction)
		return []

	var size: int = CLOCKWISE_RING.size()
	# 呼び出しごとに新しい配列を組む: 環そのものや使い回しの配列を返すと、
	# 呼び出し側の書き換えが次の呼び出しへ残る
	var spread: Array[Vector2i] = []
	spread.append(direction)
	spread.append(CLOCKWISE_RING[(index - 1 + size) % size])
	spread.append(CLOCKWISE_RING[(index + 1) % size])
	return spread
