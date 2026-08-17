class_name ShooterEnemy
extends Enemy

## 定点から撃つ敵。体力・重力・標的の解決は `Enemy` が持ち、ここは `ShooterBrain` が発射を
## 告げたフレームで敵弾を 1 発生成する。滞在時間の計測と遷移の判断は持たない。

const MISSING_PROJECTILE_SCENE_ERROR: String = (
	"ShooterEnemy: projectile_scene が設定されていない。弾を生成せずに返る"
)

## 敵弾のシーン。値の出どころを 1 箇所にするため、参照はシーンから与える
@export var projectile_scene: PackedScene

## 状態遷移。外から読める公開点であり、契約の一部である
var brain: ShooterBrain


func _ready() -> void:
	# 基底の検査より後に作る: `ShooterBrain` は生成時に数値を写し取るため、`stats` 未設定の
	# フォールバックより先に作ると存在しない `stats` を読む
	super()
	brain = ShooterBrain.new(stats)


func _physics_process(delta: float) -> void:
	super(delta)
	# 速度の決定(`_update_velocity()`)へ混ぜない: あちらは移動のために速度を決める関数で
	# あり、発射はその関心の外にある
	_advance_brain(delta)


func kind() -> int:
	return EnemyKind.Kind.SHOOTER


func _update_velocity(delta: float) -> void:
	super._update_velocity(delta)
	# 定点から撃つ: 水平には動かず、重力にのみ従う。距離を取って撃つ役割は移動で崩さない
	velocity.x = 0.0


# 状態を 1 フレーム進め、予備動作を抜けたフレームだけ弾を撃つ。標的が不在のフレームは距離を
# `INF` として渡す(基底の `target_distance()` が決める)
func _advance_brain(delta: float) -> void:
	if brain.update(delta, target_distance()):
		_fire()


# 敵弾を 1 発生成して標的へ向けて撃つ。撃てない 2 つの経路はどちらも弾を作らずに返り、
# 周期は止めない(発射の可否は状態遷移の外にある)。
#
# 弾を自分の子にしない: 発射元と一緒に動いてしまい、進行方向どおりに飛ばなくなる
func _fire() -> void:
	# 弾のシーンの検査を標的の検査より先に置く: 両方が成立するフレームでも配線の誤りは知らせる
	# (受け入れ基準 4.9 を 4.13 より優先する。人間が確定済みの判断)
	if projectile_scene == null:
		push_error(MISSING_PROJECTILE_SCENE_ERROR)
		return

	# 標的の不在は報告しない: 配線の誤りではなく、戦闘の途中で普通に起きる
	if not is_instance_valid(target):
		return

	var projectile: EnemyProjectile = projectile_scene.instantiate()
	get_parent().add_child(projectile)
	# 位置を決めてから `launch()` を呼ぶ: 射程は `launch()` の時点の位置から測る
	projectile.global_position = global_position
	projectile.launch(
		_target_direction(), stats.attack_speed, stats.attack_damage, stats.bullet_max_distance
	)


# 標的へ向かう単位ベクトル。8 方向へ丸めない: 近距離ほど狙いと実際の飛翔がずれる
func _target_direction() -> Vector2:
	return global_position.direction_to(target.global_position)
