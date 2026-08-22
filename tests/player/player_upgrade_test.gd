extends GdUnitTestSuite

const PLAYER_SCENE: PackedScene = preload("res://src/player/player.tscn")
const PROJECT_SETTINGS_PATH: String = "res://project.godot"

# 既定値(max_health = 100)と別の値を使う: 既定のままだと、`stats` を読まず値を直書きした
# 実装でも緑になる
const MAX_HEALTH: int = 48
# 体力を減らすが 0 には達しない量。既定のどの値とも一致させない
const NON_LETHAL_DAMAGE: int = 13
# 1 回で 0 へ届く量
const LETHAL_DAMAGE: int = MAX_HEALTH

const DELTA: float = 0.0625

# 物理フレームを消化させる待ち。CI のランナーが遅い場合でも下限のフレーム数を満たすよう余裕を取る
const WAIT_MILLIS: int = 500
# 待ちの中で最低限消化していてほしいフレーム数
const MIN_FRAMES: int = 10

# `PlayerCommand` の項目数(要件 3.8)。強化のための入力を足すとここが増える
const COMMAND_FIELD_COUNT: int = 5

# `project.godot` の `[input]` が定義していなければならないアクション。これがちょうどの集合である
const FROZEN_INPUT_ACTIONS: Array[String] = [
	"move_left",
	"move_right",
	"aim_up",
	"aim_down",
	"jump",
	"fire_primary",
	"fire_secondary",
]

# 凍結時点(作業ブランチの分岐元)の `[input]` 節の sha256。アクション名の集合だけを見ると、
# 既存のアクションへイベントを足す変更を通す
const FROZEN_INPUT_SECTION_SHA256: String = (
	"d2a56d5042922b1126b62ced4112b5e8a566eea7583c965b80894997020ab982"
)

# 強化の種類・残り回数・残り時間を表す状態が持ち込まれたことを示す語
const FORBIDDEN_STATE_TOKENS: Array[String] = [
	"remaining",
	"uses",
	"charges",
	"count",
	"duration",
	"expire",
	"timer",
	"elapsed",
	"kind",
	"slot",
	"ability",
	"level",
	"stack",
]

# 凍結済みの `fired` の引数。GDScript はシグナルの宣言型を発火時に強制しないため、
# 受け取った値の型を見る振る舞い側のケースでは宣言の退行を捕らえられない。宣言そのものを
# `get_signal_list()` から読む。[名前, 型] の対で持ち、並びと個数も固定する
const FROZEN_FIRED_ARGUMENTS: Array = [
	["direction", TYPE_VECTOR2I],
	["is_secondary", TYPE_BOOL],
]
const FIRED_SIGNAL_NAME: String = "fired"

# `Player` のスクリプト変数のちょうどの集合。`FORBIDDEN_STATE_TOKENS` は、リストに当たらない
# 名前で状態を持ち込む変異(残り回数を `_burst_budget` と名付ける等)を素通りさせる。`Player` の
# 変数は有限であるため、集合そのものを固定して「足せない」ことで塞ぐ。
# 両方を置く: 個数と並びだけでは、既存の項目を残り回数の意味へ改名する変異が落ちない
const PLAYER_SCRIPT_VARIABLES: Array[String] = [
	"stats",
	"projectile_scene",
	"upgraded_secondary_tint",
	"health",
	"facing",
	"is_primary_upgraded",
	"input_source",
	"_is_primary_upgraded",
	"_primary_weapon",
	"_secondary_weapon",
]


func _create_stats() -> PlayerStats:
	var stats: PlayerStats = auto_free(PlayerStats.new())
	stats.max_health = MAX_HEALTH
	return stats


## ツリーへ載せていない `Player`。`stats` も与えない
func _create_bare_player() -> Player:
	return auto_free(Player.new())


## ツリーへ載せていない、`player.tscn` から生成した `Player`
func _create_detached_scene_player() -> Player:
	var player: Player = auto_free(PLAYER_SCENE.instantiate())
	player.stats = _create_stats()
	return player


## ツリーへ載せて `_ready()` を通した `Player`
func _create_ready_player() -> Player:
	var player: Player = auto_free(PLAYER_SCENE.instantiate())
	player.stats = _create_stats()
	add_child(player)
	return player


func _script_variables(target: Object) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for property: Dictionary in target.get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		found.append(property)
	return found


func _signal_arguments(target: Object, signal_name: String) -> Array:
	for signal_info: Dictionary in target.get_signal_list():
		if signal_info["name"] != signal_name:
			continue
		var arguments: Array = []
		for argument: Dictionary in signal_info["args"]:
			arguments.append([argument["name"], int(argument["type"])])
		return arguments
	return []


func _input_section() -> String:
	var lines: PackedStringArray = FileAccess.get_file_as_string(PROJECT_SETTINGS_PATH).split("\n")
	var section: PackedStringArray = PackedStringArray()
	var is_inside: bool = false
	for line: String in lines:
		if line.begins_with("["):
			if is_inside:
				break
			is_inside = line == "[input]"
		if is_inside:
			section.append(line)
	return "\n".join(section)


# 検証で使う値が既定と一致しないことを固定する番人。一致すると、`stats` を読まない実装が
# 素通りする
func test_the_values_used_here_differ_from_the_defaults() -> void:
	var defaults: PlayerStats = auto_free(PlayerStats.new())

	assert_int(MAX_HEALTH).is_not_equal(defaults.max_health)
	assert_int(NON_LETHAL_DAMAGE).is_not_equal(defaults.primary_damage)
	assert_int(NON_LETHAL_DAMAGE).is_not_equal(defaults.max_health)
	assert_int(LETHAL_DAMAGE).is_not_equal(defaults.max_health)
	assert_bool(NON_LETHAL_DAMAGE < MAX_HEALTH).is_true()


func test_a_new_player_is_not_upgraded() -> void:
	assert_bool(_create_bare_player().is_primary_upgraded).is_false()
	assert_bool(_create_detached_scene_player().is_primary_upgraded).is_false()
	assert_bool(_create_ready_player().is_primary_upgraded).is_false()


func test_grant_upgrade_makes_the_player_upgraded() -> void:
	var player: Player = _create_ready_player()

	player.grant_upgrade()

	assert_bool(player.is_primary_upgraded).is_true()


func test_grant_upgrade_is_idempotent() -> void:
	var player: Player = _create_ready_player()

	player.grant_upgrade()
	# 2 回目までの間に体力を減らさない: 減らすと死亡によるリセットと混ざる
	player.grant_upgrade()

	assert_bool(player.is_primary_upgraded).is_true()
	assert_int(player.health.current).is_equal(MAX_HEALTH)


func test_the_upgrade_survives_the_passage_of_physics_frames() -> void:
	var player: Player = _create_ready_player()
	# lambda はローカル変数を値コピーで捕捉するが、Array は参照として捕捉されるため外から読める
	var frames: Array = []
	player.input_source = (
		func() -> PlayerCommand:
			frames.append(true)
			return PlayerCommand.new()
	)
	player.grant_upgrade()

	await await_millis(WAIT_MILLIS)

	# 待ちが足りずフレームを消化しなかった場合と、時間で消えなかった場合を区別する
	assert_int(frames.size()).is_greater_equal(MIN_FRAMES)
	assert_bool(player.is_primary_upgraded).is_true()


func test_assigning_the_property_directly_does_not_change_it() -> void:
	var not_upgraded: Player = _create_ready_player()

	not_upgraded.is_primary_upgraded = true

	assert_bool(not_upgraded.is_primary_upgraded).is_false()

	var upgraded: Player = _create_ready_player()
	upgraded.grant_upgrade()

	upgraded.is_primary_upgraded = false

	assert_bool(upgraded.is_primary_upgraded).is_true()


func test_setting_the_property_by_name_does_not_change_it() -> void:
	var not_upgraded: Player = _create_ready_player()

	not_upgraded.set("is_primary_upgraded", true)

	assert_bool(not_upgraded.is_primary_upgraded).is_false()

	var upgraded: Player = _create_ready_player()
	upgraded.grant_upgrade()

	upgraded.set("is_primary_upgraded", false)

	assert_bool(upgraded.is_primary_upgraded).is_true()


func test_grant_upgrade_works_on_a_player_outside_the_tree() -> void:
	var bare: Player = _create_bare_player()
	var from_scene: Player = _create_detached_scene_player()

	bare.grant_upgrade()
	from_scene.grant_upgrade()

	assert_bool(bare.is_primary_upgraded).is_true()
	assert_bool(from_scene.is_primary_upgraded).is_true()


func test_grant_upgrade_does_not_inspect_the_health() -> void:
	var damaged: Player = _create_ready_player()
	damaged.take_damage(NON_LETHAL_DAMAGE)

	damaged.grant_upgrade()

	assert_int(damaged.health.current).is_equal(MAX_HEALTH - NON_LETHAL_DAMAGE)
	assert_bool(damaged.is_primary_upgraded).is_true()

	var full: Player = _create_ready_player()

	full.grant_upgrade()

	assert_int(full.health.current).is_equal(MAX_HEALTH)
	assert_bool(full.is_primary_upgraded).is_true()


func test_the_upgrade_state_is_a_single_bool() -> void:
	var player: Player = _create_ready_player()
	var property_types: Dictionary = {}
	var offending_names: Array[String] = []

	for property: Dictionary in _script_variables(player):
		var property_name: String = property["name"]
		property_types[property_name] = int(property["type"])
		for token: String in FORBIDDEN_STATE_TOKENS:
			if property_name.to_lower().contains(token):
				offending_names.append(property_name)
				break
		# インスペクタへ出る項目を除く: `@export` は設定値・見え方であって §6.2 が言う状態ではない。
		# 残り回数・残り時間を `@export` で持ち込む形は上の語の検査が捕らえる
		if int(property["usage"]) & PROPERTY_USAGE_EDITOR != 0:
			continue
		if property_name.contains("upgrad") and int(property["type"]) != TYPE_BOOL:
			offending_names.append(property_name)

	assert_array(offending_names).append_failure_message(
		"強化の種類・残り回数・残り時間を思わせる状態がある: %s" % ", ".join(offending_names)
	).is_empty()
	assert_dict(property_types).contains_key_value("is_primary_upgraded", TYPE_BOOL)


func test_the_player_keeps_exactly_the_declared_script_variables() -> void:
	var player: Player = _create_ready_player()
	var names: Array[String] = []
	for property: Dictionary in _script_variables(player):
		names.append(property["name"])

	# 個数だけでなく並びまで見る: 個数だけだと、1 つ消して 1 つ足す変異が素通りする
	assert_array(names).append_failure_message(
		"`Player` のスクリプト変数が増減した: %s" % ", ".join(names)
	).is_equal(PLAYER_SCRIPT_VARIABLES)


func test_the_player_command_keeps_exactly_five_fields() -> void:
	var command: PlayerCommand = auto_free(PlayerCommand.new())

	assert_int(_script_variables(command).size()).is_equal(COMMAND_FIELD_COUNT)


func test_the_fired_signal_keeps_its_declared_arguments() -> void:
	var player: Player = _create_ready_player()

	var arguments: Array = _signal_arguments(player, FIRED_SIGNAL_NAME)

	# 走査が空振りしていないことを先に固定する: 名前を取り違えると空のまま緑になる
	assert_array(arguments).is_not_empty()
	# 名前・型・並び・個数を一度に見る: 個数を見ないと、3 つ目を足す変更が素通りする
	assert_array(arguments).append_failure_message(
		"`%s` の宣言が変わった: %s" % [FIRED_SIGNAL_NAME, arguments]
	).is_equal(FROZEN_FIRED_ARGUMENTS)


func test_the_project_input_section_is_unchanged() -> void:
	var section: String = _input_section()
	var action_names: Array[String] = []
	for line: String in section.split("\n"):
		if line.begins_with("[") or not line.contains("={"):
			continue
		action_names.append(line.get_slice("=", 0))

	assert_array(action_names).is_equal(FROZEN_INPUT_ACTIONS)
	assert_str(section.sha256_text()).is_equal(FROZEN_INPUT_SECTION_SHA256)


func test_reaching_zero_health_clears_the_upgrade() -> void:
	var player: Player = _create_ready_player()
	player.grant_upgrade()

	player.take_damage(LETHAL_DAMAGE)

	assert_int(player.health.current).is_equal(0)
	assert_bool(player.is_primary_upgraded).is_false()


func test_the_upgrade_is_already_cleared_when_died_is_received() -> void:
	var player: Player = _create_ready_player()
	var observed: Array = []
	player.died.connect(func() -> void: observed.append(player.is_primary_upgraded))
	player.grant_upgrade()

	player.take_damage(LETHAL_DAMAGE)

	# 受け手が読んだ時点で既に偽であること。並びを入れ替える変異はここでしか落ちない
	assert_array(observed).is_equal([false])


func test_reaching_zero_health_clears_the_upgrade_outside_the_tree() -> void:
	var player: Player = auto_free(Player.new())
	player.stats = _create_stats()
	var observed: Array = []
	player.died.connect(func() -> void: observed.append(player.is_primary_upgraded))
	player.grant_upgrade()

	player.take_damage(LETHAL_DAMAGE)

	assert_array(observed).is_equal([false])
	assert_bool(player.is_primary_upgraded).is_false()


func test_damage_that_leaves_health_keeps_the_upgrade() -> void:
	var player: Player = _create_ready_player()
	player.grant_upgrade()

	player.take_damage(NON_LETHAL_DAMAGE)
	player.take_damage(NON_LETHAL_DAMAGE)
	player.apply_command(auto_free(PlayerCommand.new()), DELTA, true)

	assert_int(player.health.current).is_equal(MAX_HEALTH - NON_LETHAL_DAMAGE * 2)
	assert_bool(player.is_primary_upgraded).is_true()
