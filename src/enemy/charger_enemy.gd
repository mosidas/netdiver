class_name ChargerEnemy
extends Enemy

## 接近して突進する敵。体力・重力・標的の解決は `Enemy` が持つ。


func kind() -> int:
	return EnemyKind.Kind.CHARGER
