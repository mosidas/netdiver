class_name Player
extends CharacterBody2D

## 徒歩パートの自機。
##
## 速度の計算は `apply_command()` に閉じる。物理フレームの外で位置を更新すると Godot が
## 描画フレームの delta を使い、同じ入力でも変位が定まらないため、位置の更新は
## `_physics_process` の中だけで行う。

@export var stats: PlayerStats

var facing: int = 1

## 入力の差し替え点。headless では `InputEvent` がエンジンを通らず `Input` を経由した
## 検証ができないため、テストが差し替えられるよう契約の一部として公開する
var input_source: Callable = PlayerInput.read


func apply_command(cmd: PlayerCommand, delta: float, is_on_floor: bool) -> void:
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
