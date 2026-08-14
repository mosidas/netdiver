class_name Attackbox
extends Area2D

## 突進の攻撃判定。有効な間に触れた相手へ 1 回だけダメージを与える。
##
## 与済みの記録をここに持つ: 判定が成立したことを知っているのはこの領域自身であり、
## 所有者へ持たせると触れた事実と記録が別の場所に分かれる。所有者は突進へ入るたびに
## `arm()` を呼んで記録を落とす。

const TAKE_DAMAGE_METHOD: StringName = &"take_damage"

## 与えるダメージ。シーンへ焼き込まない: 手触りの数値は `EnemyStats` に集約し、所有者が
## `stats.attack_damage` から代入する
@export var damage: int

# 1 回の突進で与済みかどうか。`arm()` で落とす
var _has_dealt: bool = false


func _ready() -> void:
	# `area_entered` は使わない: プレイヤーは `CharacterBody2D` であって `Area2D` ではない
	body_entered.connect(_on_body_entered)


## 与済みの記録を落とし、再びダメージを与えられる状態にする。
##
## 事前条件: 所有者は `monitoring` を真にする前に呼ぶ(真にしてから落とすと、その間の
## 接触が前の突進の記録で握り潰される)
func arm() -> void:
	_has_dealt = false


func _on_body_entered(body: Node2D) -> void:
	if _has_dealt:
		return

	# 相手を型で見ない: `Player` へ静的に依存させると、単位を跨ぐ結び付きができる。
	# `push_error` を出さない: mask にはプレイヤーしか載らないため、素通りは異常ではなく
	# 想定内である(`Hurtbox` の親の検査と非対称なのはこの理由による)。記録も消費しない
	if not body.has_method(TAKE_DAMAGE_METHOD):
		return

	_has_dealt = true
	body.call(TAKE_DAMAGE_METHOD, damage)
