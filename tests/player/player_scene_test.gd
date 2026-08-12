extends GdUnitTestSuite

const PLAYER_SCENE: PackedScene = preload("res://src/player/player.tscn")
const PLAYER_SOURCE_PATH: String = "res://src/player/player.gd"

const PLACEHOLDER_SIZE: Vector2 = Vector2(12.0, 32.0)
const PLAYER_LAYER: int = 1 << 1
const TERRAIN_MASK: int = 1 << 0

const MOVE_FRAMES: int = 3
# 3 物理フレーム(60 Hz で 50 ms)に対して余裕を取る: CI のランナーが遅い場合でも 3 フレームを消化させる
const WAIT_MILLIS: int = 500
const DELTA: float = 1.0 / 60.0

# lambda はローカル変数を値コピーで捕捉するため呼び出し回数を外へ出せない。
# 状態を持つオブジェクトのメソッドを Callable として渡す
const INPUT_STUB_SOURCE: String = """
extends RefCounted

var call_count: int = 0
var move_frames: int = 0


func read() -> PlayerCommand:
	call_count += 1
	var command := PlayerCommand.new()
	if call_count <= move_frames:
		command.move_x = 1.0
	return command
"""


func _create_input_stub(move_frames: int) -> RefCounted:
	var stub_script: GDScript = GDScript.new()
	stub_script.source_code = INPUT_STUB_SOURCE
	stub_script.reload()

	var stub: RefCounted = auto_free(stub_script.new())
	stub.set("move_frames", move_frames)
	return stub


func _function_body(source: String, function_name: String) -> String:
	var body: PackedStringArray = PackedStringArray()
	var is_inside: bool = false
	for line: String in source.split("\n"):
		if line.begins_with("func "):
			is_inside = line.begins_with("func %s(" % function_name)
			continue
		if is_inside:
			body.append(line)
	return "\n".join(body)


func test_apply_command_sets_the_horizontal_speed_from_move_x() -> void:
	var player: Player = auto_free(PLAYER_SCENE.instantiate())
	var command: PlayerCommand = auto_free(PlayerCommand.new())

	command.move_x = 1.0
	player.apply_command(command, DELTA, false)

	assert_float(player.velocity.x).is_equal(player.stats.move_speed)

	command.move_x = -1.0
	player.apply_command(command, DELTA, false)

	assert_float(player.velocity.x).is_equal(-player.stats.move_speed)


func test_injected_input_source_moves_the_player_over_physics_frames() -> void:
	var player: Player = auto_free(PLAYER_SCENE.instantiate())
	var stub: RefCounted = _create_input_stub(MOVE_FRAMES)
	player.input_source = Callable(stub, "read")
	add_child(player)

	await await_millis(WAIT_MILLIS)

	# 期待値を 5.0 と直接書かない: physics/common/physics_ticks_per_second を変えると変位も変わる
	var expected_x: float = player.stats.move_speed / float(Engine.physics_ticks_per_second) * MOVE_FRAMES
	# 待ちが足りずフレームを消化しなかった場合と、移動しなかった場合を区別する
	assert_int(int(stub.get("call_count"))).is_greater_equal(MOVE_FRAMES)
	assert_vector(player.position).is_equal_approx(Vector2(expected_x, 0.0), Vector2(0.001, 0.001))


func test_input_source_can_be_replaced() -> void:
	var player: Player = auto_free(PLAYER_SCENE.instantiate())
	var stub: RefCounted = _create_input_stub(0)

	player.input_source = Callable(stub, "read")

	assert_bool(player.input_source.is_valid()).is_true()
	assert_object(player.input_source.get_object()).is_same(stub)


func test_input_source_defaults_to_player_input_read() -> void:
	var player: Player = auto_free(PLAYER_SCENE.instantiate())

	assert_bool(player.input_source.is_valid()).is_true()
	assert_str(player.input_source.get_method()).is_equal("read")
	# static メソッドの Callable は、インスタンスではなくスクリプトのリソースを保持する
	assert_object(player.input_source.get_object()).is_same(PlayerInput)


func test_player_scene_centers_a_12x32_placeholder_on_the_origin() -> void:
	var player: Player = auto_free(PLAYER_SCENE.instantiate())
	var placeholder: ColorRect = player.get_node("Placeholder")
	var collision_shape: CollisionShape2D = player.get_node("CollisionShape2D")
	var shape: RectangleShape2D = collision_shape.shape

	assert_vector(placeholder.size).is_equal(PLACEHOLDER_SIZE)
	assert_vector(placeholder.position).is_equal(-PLACEHOLDER_SIZE * 0.5)
	assert_vector(shape.size).is_equal(PLACEHOLDER_SIZE)
	assert_vector(collision_shape.position).is_equal(Vector2.ZERO)


func test_player_scene_is_on_the_player_layer_and_collides_with_terrain() -> void:
	var player: Player = auto_free(PLAYER_SCENE.instantiate())

	assert_int(player.collision_layer).is_equal(PLAYER_LAYER)
	assert_int(player.collision_mask).is_equal(TERRAIN_MASK)


func test_player_scene_carries_stats() -> void:
	var player: Player = auto_free(PLAYER_SCENE.instantiate())

	assert_object(player.stats).is_not_null()
	assert_object(player.stats).is_instanceof(PlayerStats)


func test_physics_process_calls_move_and_slide_after_apply_command() -> void:
	var body: String = _function_body(FileAccess.get_file_as_string(PLAYER_SOURCE_PATH), "_physics_process")

	assert_str(body).contains("apply_command(")
	assert_str(body).contains("move_and_slide()")
	assert_int(body.find("apply_command(")).is_less(body.find("move_and_slide()"))


func test_apply_command_does_not_call_move_and_slide() -> void:
	var body: String = _function_body(FileAccess.get_file_as_string(PLAYER_SOURCE_PATH), "apply_command")

	assert_str(body).not_contains("move_and_slide")
