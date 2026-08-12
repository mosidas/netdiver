class_name Player
extends CharacterBody2D

## 徒歩パートの自機。
##
## 速度の計算は `apply_command()` に閉じる。物理フレームの外で位置を更新すると Godot が
## 描画フレームの delta を使い、同じ入力でも変位が定まらないため、位置の更新は
## `_physics_process` の中だけで行う。

@export var stats: PlayerStats

## 入力の差し替え点。headless では `InputEvent` がエンジンを通らず `Input` を経由した
## 検証ができないため、テストが差し替えられるよう契約の一部として公開する
var input_source: Callable = PlayerInput.read


func apply_command(cmd: PlayerCommand, delta: float, is_on_floor: bool) -> void:
	velocity.x = cmd.move_x * stats.move_speed


func _physics_process(delta: float) -> void:
	var cmd: PlayerCommand = input_source.call()
	apply_command(cmd, delta, is_on_floor())
	move_and_slide()
