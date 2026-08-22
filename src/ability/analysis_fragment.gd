class_name AnalysisFragment
extends Area2D

## 撃破位置に残る解析の断片。触れた相手へ強化を渡して自身を解放する。
##
## 公開のメソッド・シグナル・プロパティを持たない: 契約は当たり判定の構成と、触れられたときの
## 振る舞いだけである。寿命も重力も吸引も持たないため、状態を 1 つも持たない。

const GRANT_UPGRADE_METHOD: StringName = &"grant_upgrade"


func _ready() -> void:
	# `area_entered` は使わない: プレイヤーは `CharacterBody2D` であって `Area2D` ではない
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	# 相手を型で見ない: 型へ静的に依存させると、単位を跨ぐ結び付きができる。
	# `push_error` を出さない: mask には触れうる相手しか載らないため、素通りは異常ではなく
	# 想定内である(`Attackbox` と同じ扱い)
	if not body.has_method(GRANT_UPGRADE_METHOD):
		return

	# 相手の状態を読まない: 既に強化を持っていても断片は消費される。二重の付与は相手の側の
	# 冪等性が吸収する
	body.call(GRANT_UPGRADE_METHOD)
	# `free()` を使わない: 物理コールバックの最中の解放は物理サーバの走査を壊す
	queue_free()
