## 触れているプレイヤーへ一定の周期でダメージを与える領域。
##
## 敵が入るまでの間、体力の減少・自動回復・リトライを実行時に確かめるために置く。
class_name DamageZone
extends Area2D

## ダメージを与える周期(秒)
const DAMAGE_INTERVAL: float = 1.0

const TAKE_DAMAGE_METHOD: StringName = &"take_damage"

@export var damage: int = 15

# 触れている body ごとの、最後にダメージを与えてからの経過時間
var _elapsed: Dictionary = {}


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _physics_process(delta: float) -> void:
	# keys() は複製を返すため、走査の途中で _elapsed から取り除いてよい
	for body: Node in _elapsed.keys():
		if not is_instance_valid(body):
			_elapsed.erase(body)
			continue

		var elapsed: float = float(_elapsed[body]) + delta
		# 剰余を繰り越す: 1 フレームが周期より長い場合でも与える回数が減らない
		while elapsed >= DAMAGE_INTERVAL:
			elapsed -= DAMAGE_INTERVAL
			body.call(TAKE_DAMAGE_METHOD, damage)
		_elapsed[body] = elapsed


# 触れた瞬間に 1 回目を与える。周期の起点を接触に置くことで、領域に入った手応えが即座に出る
func _on_body_entered(body: Node2D) -> void:
	if not body.has_method(TAKE_DAMAGE_METHOD):
		return

	_elapsed[body] = 0.0
	body.call(TAKE_DAMAGE_METHOD, damage)


func _on_body_exited(body: Node2D) -> void:
	_elapsed.erase(body)
