class_name AimResolver
extends RefCounted

## 射撃方向を決める純粋関数。
##
## 入力・向き・接地の 3 つだけに依存し、ノードの状態を持たない。


static func resolve(move_x: float, aim_y: float, facing: int, is_on_floor: bool) -> Vector2i:
	# signi() に float を渡さない: 切り捨てを経るため ±1 未満の入力が 0 に潰れ、
	# 斜めの入力が水平・垂直へ寄る
	var direction: Vector2i = Vector2i(int(signf(move_x)), int(signf(aim_y)))

	# 接地中は下の成分を落とす: 真下へ撃っても地面に当たるだけであり、
	# 斜め下の入力を水平へ寄せる
	if is_on_floor and direction.y > 0:
		direction.y = 0

	if direction == Vector2i.ZERO:
		return Vector2i(facing, 0)
	return direction
