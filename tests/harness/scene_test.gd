extends GdUnitTestSuite

const SPEED: float = 100.0
const MOVE_FRAMES: int = 3
# 3 物理フレーム(60 Hz で 50 ms)に対して余裕を取る: CI のランナーが遅い場合でも frames_to_move を消化させる
const WAIT_MILLIS: int = 500

# move_and_slide() を物理フレームの外で呼ぶと変位が描画フレームの delta で決まり値が安定しないため、
# _physics_process から指定回数だけ呼ぶスクリプトをノードに与える
const MOVER_SOURCE: String = """
extends CharacterBody2D

var frames_to_move: int = 0


func _physics_process(_delta: float) -> void:
	if frames_to_move <= 0:
		return
	frames_to_move -= 1
	move_and_slide()
"""


func test_body_moves_along_velocity_over_physics_frames() -> void:
	var body: CharacterBody2D = _create_body()
	add_child(body)
	body.velocity = Vector2(SPEED, 0.0)

	body.set("frames_to_move", MOVE_FRAMES)
	await await_millis(WAIT_MILLIS)

	# 期待値を 5.0 と直接書かない: physics/common/physics_ticks_per_second を変えると変位も変わる
	var expected_x: float = SPEED / float(Engine.physics_ticks_per_second) * MOVE_FRAMES
	assert_int(body.get("frames_to_move")).is_zero()
	assert_vector(body.position).is_equal_approx(Vector2(expected_x, 0.0), Vector2(0.001, 0.001))


func test_body_stays_in_place_without_velocity() -> void:
	var body: CharacterBody2D = _create_body()
	add_child(body)
	body.velocity = Vector2.ZERO

	body.set("frames_to_move", MOVE_FRAMES)
	await await_millis(WAIT_MILLIS)

	assert_bool(body.is_inside_tree()).is_true()
	# 待ちが足りずフレームを消化しなかった場合と、速度 0 で動かなかった場合を区別する
	assert_int(body.get("frames_to_move")).is_zero()
	assert_vector(body.position).is_equal(Vector2.ZERO)


func _create_body() -> CharacterBody2D:
	var mover_script: GDScript = GDScript.new()
	mover_script.source_code = MOVER_SOURCE
	mover_script.reload()

	var body: CharacterBody2D = auto_free(mover_script.new())
	var collision_shape: CollisionShape2D = auto_free(CollisionShape2D.new())
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = Vector2(16.0, 16.0)
	collision_shape.shape = rectangle
	body.add_child(collision_shape)
	return body
