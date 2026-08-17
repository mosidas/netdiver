class_name EnemyStats
extends Resource

## 敵の手触りを決める数値。種別ごとの実体は `.tres`(`charger_stats.tres` /
## `shooter_stats.tres`)に置き、1 個を全個体で共有する。
##
## `move_speed`・`attack_duration`・`bullet_max_distance` の 0 は「その振る舞いを持たない」
## ことを表す。

@export var max_hp: int = 30
@export var gravity: float = 600.0

@export var move_speed: float = 40.0
@export var detect_range: float = 128.0

@export var telegraph_time: float = 0.4
@export var attack_damage: int = 15
@export var attack_speed: float = 150.0
@export var attack_duration: float = 0.6
@export var recover_time: float = 0.8

@export var bullet_max_distance: float = 0.0
