extends Node2D

## ピクセルアートのパイプライン確認用シーン。
## 320x180 の基準解像度で、Aseprite 由来のスプライトとタイルセットを並べて表示する。
## `godot -- <出力パス>` で起動すると、数フレーム後にビューポートを PNG へ保存して終了する。

const CAPTURE_DELAY_FRAMES := 4

@onready var _generated: AnimatedSprite2D = $GeneratedDrone
@onready var _enemy: AnimatedSprite2D = $EnemyDrone


func _ready() -> void:
	_generated.play(&"hover")
	_enemy.play(&"idle")

	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_capture_and_quit(args[0])


func _capture_and_quit(path: String) -> void:
	for _i in CAPTURE_DELAY_FRAMES:
		await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(path)
	if err != OK:
		push_error("スクリーンショットの保存に失敗した: %s (error %d)" % [path, err])
	else:
		print("screenshot: %s (%dx%d)" % [path, image.get_width(), image.get_height()])
	get_tree().quit(0 if err == OK else 1)
