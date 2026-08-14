class_name ChargerEnemy
extends Enemy

## 接近して突進する敵。体力・重力・標的の解決は `Enemy` が持ち、ここは `ChargerBrain` の
## 状態を水平の速度と `Attackbox` の有効・無効へ写す。滞在時間の計測と遷移の判断は持たない。

const ATTACKBOX_NODE: NodePath = ^"Attackbox"

## 状態遷移。外から読める公開点であり、契約の一部である
var brain: ChargerBrain

# 突進を始めた時点の標的の側。突進中に読み直さない: 予備動作を見て退避した相手を追い続けると、
# 退避そのものが成立しなくなる
var _charge_direction: float = 0.0

# 突進の攻撃判定。シーンの子として宣言され、`brain.is_attack_active` に合わせて切り替える
var _attackbox: Attackbox


func _ready() -> void:
	# 基底の検査より後に作る: `ChargerBrain` は生成時に数値を写し取るため、`stats` 未設定の
	# フォールバックより先に作ると存在しない `stats` を読む
	super()
	brain = ChargerBrain.new(stats)
	_attackbox = get_node(ATTACKBOX_NODE)
	# シーンへ焼き込まず、ここで手触りの数値から写す
	_attackbox.damage = stats.attack_damage
	# 自分の撃破をシグナルで受け取る: 次の `_physics_process` を待つと、撃破されたフレームの
	# 残りで攻撃判定が生きたままになる。解放はフレームの終わりであり、その間に触れた相手へ
	# ダメージが入る
	defeated.connect(_on_defeated)


func _physics_process(delta: float) -> void:
	super(delta)
	# 速度の決定(`_update_velocity()`)へ混ぜない: あちらは移動のために速度を決める関数で
	# あり、攻撃判定の有効・無効はその関心の外にある
	_sync_attackbox()


func kind() -> int:
	return EnemyKind.Kind.CHARGER


func _update_velocity(delta: float) -> void:
	super._update_velocity(delta)

	var distance: float = target_distance()
	var direction: float = _target_direction()
	var was_charging: bool = brain.state == EnemyState.State.CHARGE
	brain.update(delta, distance)

	match brain.state:
		EnemyState.State.IDLE:
			if distance <= stats.detect_range:
				velocity.x = stats.move_speed * direction
			else:
				velocity.x = 0.0
		EnemyState.State.CHARGE:
			if not was_charging:
				_charge_direction = direction
			velocity.x = stats.attack_speed * _charge_direction
		_:
			velocity.x = 0.0


# 攻撃判定を `brain.is_attack_active` に一致させる。有効になる縁で与済みの記録を落とす:
# 落とさないと 2 回目以降の突進でダメージが入らない。`monitoring` を縁の判定に使うのは、
# 攻撃判定が有効だったかどうかを知っているのが `Attackbox` 自身だからである
func _sync_attackbox() -> void:
	# 撃破時の停止を `brain` との一致より優先する(要件 3.10 が 3.5 を支配する)。代入の
	# 後ろで偽へ戻さず早期に返るのは、`arm()` を縁の内側に閉じたままにするためである:
	# 後ろで戻すと `is_attack_active` が真のまま毎フレーム「偽→真の縁」と誤認する
	if is_defeated:
		return

	var is_active: bool = brain.is_attack_active
	if is_active and not _attackbox.monitoring:
		_attackbox.arm()
	_attackbox.monitoring = is_active


# 撃破された時点で攻撃判定を閉じる。`brain` は止めない: 状態遷移は解放までの残りのフレームで
# 参照されうる公開点であり、撃破の有無で意味を変えない
func _on_defeated(_kind: int) -> void:
	_attackbox.disarm()


# 標的の側(-1 / 0 / +1)。不在なら 0 を返す: 向きの決まらないフレームで水平に動かさない
func _target_direction() -> float:
	if not is_instance_valid(target):
		return 0.0
	return signf(target.global_position.x - global_position.x)
