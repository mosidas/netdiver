class_name Hurtbox
extends Area2D

## 敵が被弾を受け取る領域。入ってきた領域の `damage` を所有者(親)へ中継する。
##
## 弾をここで解放しない。弾は自身が本体(`Enemy`)との接触で解放するため、ここでも
## 解放すると二重になる。

const DAMAGE_PROPERTY: StringName = &"damage"
const TAKE_DAMAGE_METHOD: StringName = &"take_damage"

const MISSING_TAKE_DAMAGE_ERROR: String = (
	"Hurtbox: 親が take_damage() を持たない。被弾を中継せずに返る"
)


func _ready() -> void:
	# `body_entered` は使わない: プレイヤーの弾は `Area2D` であって `PhysicsBody2D` ではない
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	# 相手を型で見ない: `Projectile` へ静的に依存させると、同じ形の別の領域を受け取れなくなる
	var damage: Variant = area.get(DAMAGE_PROPERTY)
	if damage == null:
		return

	var owner_node: Node = get_parent()
	if owner_node == null or not owner_node.has_method(TAKE_DAMAGE_METHOD):
		push_error(MISSING_TAKE_DAMAGE_ERROR)
		return

	owner_node.call(TAKE_DAMAGE_METHOD, damage)
