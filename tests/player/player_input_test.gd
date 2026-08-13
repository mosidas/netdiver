extends GdUnitTestSuite

# project.godot が定義していなければならない入力アクション(要件 8.1)。
# PlayerInput.read() が読む名前と一致する
const REQUIRED_ACTIONS: Array[StringName] = [
	&"move_left",
	&"move_right",
	&"aim_up",
	&"aim_down",
	&"jump",
	&"fire_primary",
	&"fire_secondary",
]


# 1 件でも欠けると PlayerInput.read() がその操作を読めなくなる。欠落は全件を報告する
func test_the_project_defines_every_input_action() -> void:
	var missing: Array[String] = []
	for action: StringName in REQUIRED_ACTIONS:
		if not InputMap.has_action(action):
			missing.append(str(action))

	assert_array(missing).append_failure_message(
		"入力アクションが未定義: %s" % ", ".join(missing)
	).is_empty()
