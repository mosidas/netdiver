class_name Player
extends CharacterBody2D

## 徒歩パートの自機。
##
## 速度の計算は `apply_command()` に閉じる。物理フレームの外で位置を更新すると Godot が
## 描画フレームの delta を使い、同じ入力でも変位が定まらないため、位置の更新は
## `_physics_process` の中だけで行う。

signal died
signal fired(direction: Vector2i, is_secondary: bool)

const MISSING_STATS_ERROR: String = "Player: stats が設定されていない。既定値の PlayerStats を使う"
const INVALID_DELTA_ERROR: String = "Player.apply_command(): delta は正でなければならない。速度を変えずに返る"
const INVALID_STAT_ERROR_FORMAT: String = "Player: stats.%s は正でなければならない(現在値: %s)"
const MISSING_PROJECTILE_SCENE_ERROR: String = (
	"Player: projectile_scene が設定されていない。弾を生成せずに返る"
)

@export var stats: PlayerStats

## 弾のシーン。値の出どころを 1 箇所にするため、参照はインスペクタから与える
@export var projectile_scene: PackedScene

## 体力。待機時間の計測と回復の進行は `Health` が持ち、`Player` は経過時間を自分で持たない
var health: Health

var facing: int = 1

## 入力の差し替え点。headless では `InputEvent` がエンジンを通らず `Input` を経由した
## 検証ができないため、テストが差し替えられるよう契約の一部として公開する
var input_source: Callable = PlayerInput.read

var _primary_weapon: PrimaryWeapon
var _secondary_weapon: SecondaryWeapon


func _ready() -> void:
	if stats == null:
		push_error(MISSING_STATS_ERROR)
		stats = PlayerStats.new()
	_report_non_positive_stats()
	_ensure_health()


func apply_command(cmd: PlayerCommand, delta: float, is_on_floor: bool) -> void:
	# ガードを関数の先頭に置く: 後ろに置くと、拒否する前に速度の代入が済んでしまう
	if delta <= 0.0:
		push_error(INVALID_DELTA_ERROR)
		return

	_ensure_health()
	health.tick(delta)

	velocity.x = cmd.move_x * stats.move_speed

	# 引数の is_on_floor を使い、同名のメソッド is_on_floor() を呼ばない: ツリーに載せていない
	# ノードではメソッドが常に偽を返し、地上の振る舞いを検証できない
	if is_on_floor:
		# 接地中に垂直の速度を 0 へ戻す: 重力が蓄積したままだと、離陸直後の落下が速くなる
		velocity.y = -stats.jump_speed if cmd.jump_pressed else 0.0
	else:
		velocity.y += stats.gravity * delta

	if not is_zero_approx(cmd.move_x):
		# signi() に float を渡さない: 切り捨てを経るため ±1 以外の move_x で 0 になり、
		# facing が -1 または 1 という不変条件が壊れる
		facing = int(signf(cmd.move_x))

	# 方向の決定を AimResolver に委ねる: ここで 8 方向を組み立て直すと決め方が二重になる
	var direction: Vector2i = AimResolver.resolve(cmd.move_x, cmd.aim_y, facing, is_on_floor)
	_update_weapons(cmd, direction, delta)


## 体力を `amount` だけ減らす。減らし方と枯渇の判定は `Health` に委ねる。
##
## 事前条件: `amount` は正。0 以下なら `Health` が `push_error` を出して状態を変えない
func take_damage(amount: int) -> void:
	_ensure_health()
	health.take_damage(amount)


func _physics_process(delta: float) -> void:
	var cmd: PlayerCommand = input_source.call()
	apply_command(cmd, delta, is_on_floor())
	move_and_slide()


func _update_weapons(cmd: PlayerCommand, direction: Vector2i, delta: float) -> void:
	_ensure_weapons()

	_primary_weapon.tick(delta)
	# 押していないときに try_fire() を呼ばない: 呼ぶと経過時間が戻り、押した瞬間の 1 発が遅れる
	if cmd.primary_held and _primary_weapon.try_fire():
		_spawn_projectile(direction, stats.primary_bullet_speed, stats.primary_damage, false)

	if _secondary_weapon.update(cmd.secondary_held, delta):
		_spawn_projectile(direction, stats.secondary_bullet_speed, stats.secondary_damage, true)


# `_ready()` からも呼ぶが、ここでも作れるようにする: `apply_command()` と `take_damage()` は
# ツリーへ載せずに呼べる契約であり、`_ready()` を通らない経路で health が null になる
func _ensure_health() -> void:
	if health != null:
		return
	health = Health.new(stats.max_health, stats.regen_delay, stats.regen_per_second)
	# エッジの検出は Health が持つ。Player は中継するだけで保持状態を持たない
	health.depleted.connect(_on_health_depleted)


func _on_health_depleted() -> void:
	died.emit()


# 武器を `_ready()` で作らない: `apply_command()` はツリーへ載せずに呼べる契約であり、
# `_ready()` を通らない呼び出しで武器が null になる
func _ensure_weapons() -> void:
	if _primary_weapon != null:
		return
	_primary_weapon = PrimaryWeapon.new(stats.primary_interval)
	_secondary_weapon = SecondaryWeapon.new(stats.secondary_charge_time, stats.secondary_cooldown)


func _spawn_projectile(direction: Vector2i, speed: float, damage: int, is_secondary: bool) -> void:
	# 生成できなかったときに発火しない: 弾の無い発射を受け手が本物の 1 発と区別できない
	if not _launch_projectile(direction, speed, damage):
		return
	fired.emit(direction, is_secondary)


func _launch_projectile(direction: Vector2i, speed: float, damage: int) -> bool:
	if projectile_scene == null:
		push_error(MISSING_PROJECTILE_SCENE_ERROR)
		return false

	var projectile: Projectile = projectile_scene.instantiate()
	# 自分の子にしない: 弾がプレイヤーと一緒に動き、進行方向どおりに飛ばなくなる。
	# 親が無いときだけ自分へ載せる
	var container: Node = get_parent()
	if container == null:
		container = self
	container.add_child(projectile)

	# 位置を決めてから launch() する: 射程は launch() を呼んだ時点の位置から測る
	projectile.global_position = global_position
	projectile.launch(direction, speed, damage, stats.bullet_max_distance)
	return true


# 項目名の並びをここに持たず get_property_list() から導く: 並びを持つと、`PlayerStats` へ
# 項目を足したときに検査から漏れる
func _report_non_positive_stats() -> void:
	for property: Dictionary in stats.get_property_list():
		var usage: int = property["usage"]
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE == 0 or usage & PROPERTY_USAGE_EDITOR == 0:
			continue
		var type: int = property["type"]
		if type != TYPE_FLOAT and type != TYPE_INT:
			continue

		var stat_name: String = property["name"]
		var value: Variant = stats.get(stat_name)
		if float(value) <= 0.0:
			push_error(INVALID_STAT_ERROR_FORMAT % [stat_name, value])
