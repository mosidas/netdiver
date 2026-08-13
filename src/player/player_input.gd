class_name PlayerInput
extends RefCounted

## 実際の入力デバイスから 1 フレーム分の `PlayerCommand` を作る。
##
## `Input` を参照するのはこのクラスだけに閉じる。headless では `InputEvent` が
## エンジンを通らず、`Input` に触れるコードはテストで検証できないため、
## 移動・照準・射撃のロジック側へ `Input` を持ち込まない。


static func read() -> PlayerCommand:
	var command := PlayerCommand.new()
	# ゲームパッドの軸は中間値を返すため、get_axis の値をそのまま使わず符号だけを取る
	command.move_x = signf(Input.get_axis(&"move_left", &"move_right"))
	command.aim_y = signf(Input.get_axis(&"aim_up", &"aim_down"))
	command.jump_pressed = Input.is_action_just_pressed(&"jump")
	command.primary_held = Input.is_action_pressed(&"fire_primary")
	command.secondary_held = Input.is_action_pressed(&"fire_secondary")
	return command
