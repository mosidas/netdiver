class_name Player
extends CharacterBody2D

## 徒歩パートの自機。
##
## 速度の計算は `apply_command()` に閉じる。物理フレームの外で位置を更新すると Godot が
## 描画フレームの delta を使い、同じ入力でも変位が定まらないため、位置の更新は
## `_physics_process` の中だけで行う。

const MISSING_STATS_ERROR: String = "Player: stats が設定されていない。既定値の PlayerStats を使う"
const INVALID_DELTA_ERROR: String = "Player.apply_command(): delta は正でなければならない。速度を変えずに返る"
const INVALID_STAT_ERROR_FORMAT: String = "Player: stats.%s は正でなければならない(現在値: %s)"

@export var stats: PlayerStats

var facing: int = 1

## 入力の差し替え点。headless では `InputEvent` がエンジンを通らず `Input` を経由した
## 検証ができないため、テストが差し替えられるよう契約の一部として公開する
var input_source: Callable = PlayerInput.read


func _ready() -> void:
	if stats == null:
		push_error(MISSING_STATS_ERROR)
		stats = PlayerStats.new()
	_report_non_positive_stats()


func apply_command(cmd: PlayerCommand, delta: float, is_on_floor: bool) -> void:
	# ガードを関数の先頭に置く: 後ろに置くと、拒否する前に速度の代入が済んでしまう
	if delta <= 0.0:
		push_error(INVALID_DELTA_ERROR)
		return

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


func _physics_process(delta: float) -> void:
	var cmd: PlayerCommand = input_source.call()
	apply_command(cmd, delta, is_on_floor())
	move_and_slide()


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
