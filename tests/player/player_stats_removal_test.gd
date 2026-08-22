extends GdUnitTestSuite

# 凍結済みの `tests/player/player_stats_test.gd` を変えずに、その検査が持たない排他性を
# 足すため、同じディレクトリへ別のスイートを置く(`tests/weapon/projectile_direction_test.gd`
# と同じ手段)。凍結側は `contains()` の非排他な検査であり、項目を足す変更を素通りさせる

const SOURCE_ROOT: String = "res://src"

# インスペクタへ出る項目のちょうどの集合。凍結側と同じ内容を自前で持つ: 参照すると片方の
# 書き換えが両方へ効き、アサーションが自明になる
const STAT_NAMES: Array[String] = [
	"move_speed",
	"gravity",
	"jump_speed",
	"max_health",
	"regen_delay",
	"regen_per_second",
	"primary_interval",
	"primary_damage",
	"primary_bullet_speed",
	"secondary_charge_time",
	"secondary_cooldown",
	"secondary_damage",
	"secondary_bullet_speed",
	"bullet_max_distance",
]

# `PlayerStats` から撤去した項目。下の 9 語にも含まれるが、`PlayerStats` の項目としての
# 不在は項目の集合の側でも見る(何を消したのかがテストから読めるようにする)
const REMOVED_STAT_NAMES: Array[String] = [
	"ability_uses",
	"ability_cooldown",
	"ability_damage",
	"ability_bullet_speed",
]

# 第 3 の武器枠とともに撤去した識別子。`src/` の下に 1 つも残っていてはならない。
# `tests/` を走査しない: このスイート自身が字面で 9 語を持つため、自己成就で落ちる
const REMOVED_SYMBOLS: Array[String] = [
	"AbilitySlot",
	"AnalysisPulse",
	"ability_slot",
	"ability_uses",
	"ability_cooldown",
	"ability_damage",
	"ability_bullet_speed",
	"ability_fired",
	"grant_ability",
]

# 陽性対照。`src/` に必ず現れる語。1 件も見つからないなら、読めているつもりで読めていない
const PRESENT_SYMBOL: String = "PlayerStats"

# 走査が届いていることを示す錨。`src/` の各ディレクトリから 1 つずつ取る: 総数だけを見ると、
# 再帰が途中で止まっていても緑になる
const SCAN_ANCHORS: Array[String] = [
	"res://src/ability/analysis_fragment.gd",
	"res://src/ability/analysis_fragment.tscn",
	"res://src/enemy/enemy.gd",
	"res://src/player/player.gd",
	"res://src/player/player_stats.gd",
	"res://src/stage/analysis_dev_stage.gd",
	"res://src/weapon/projectile.gd",
]

const SCANNED_EXTENSIONS: PackedStringArray = ["gd", "tscn", "tres"]

# 実装の文言を参照しない: 参照するとアサーションが自明になり、文言の退行を検出できない
const INVALID_STAT_ERROR_FORMAT: String = "Player: stats.%s は正でなければならない(現在値: %s)"

# 実装が名前で持ちようのない項目。`PlayerStats` へ項目が増えた状況をテストの中だけで作る
const UNKNOWN_STAT_NAME: String = "unknown_stat"


## 項目が 1 つ増えた `PlayerStats`。`Player` が検査の対象を名前で並べて持っていると、
## この派生型の項目は検査から漏れる
class ExtendedStats:
	extends PlayerStats

	@export var unknown_stat: float = 1.0


func _editor_visible_property_names(object: Object) -> Array[String]:
	var names: Array[String] = []
	for property: Dictionary in object.get_property_list():
		var usage: int = property["usage"]
		if usage & PROPERTY_USAGE_EDITOR != 0 and usage & PROPERTY_USAGE_SCRIPT_VARIABLE != 0:
			names.append(property["name"])
	return names


# `.gd.uid` と `.import` を拾わないよう拡張子で絞る。再帰する: 直下だけを見ると、
# 撤去した識別子がサブディレクトリに残っていても気付かない
func _source_paths_under(dir_path: String) -> PackedStringArray:
	var paths: PackedStringArray = []
	for file_name: String in DirAccess.get_files_at(dir_path):
		if SCANNED_EXTENSIONS.has(file_name.get_extension()):
			paths.append("%s/%s" % [dir_path, file_name])
	for sub_name: String in DirAccess.get_directories_at(dir_path):
		paths.append_array(_source_paths_under("%s/%s" % [dir_path, sub_name]))
	return paths


func test_the_stats_expose_exactly_the_declared_items_to_the_inspector() -> void:
	var stats: PlayerStats = auto_free(PlayerStats.new())

	var names: Array[String] = _editor_visible_property_names(stats)

	# 並びまで見る: 個数だけだと、1 つ消して 1 つ足す変異が素通りする
	assert_array(names).append_failure_message(
		"`PlayerStats` の @export が増減した: %s" % ", ".join(names)
	).is_equal(STAT_NAMES)


func test_the_stats_hold_none_of_the_removed_items() -> void:
	var stats: PlayerStats = auto_free(PlayerStats.new())

	var names: Array[String] = _editor_visible_property_names(stats)

	for removed_name: String in REMOVED_STAT_NAMES:
		assert_array(names).append_failure_message(removed_name).not_contains([removed_name])


# 項目を減らしても、`Player` が「全数値項目に正を課す」規律まで痩せてはならない。実装が
# 対象を `get_property_list()` から導いていることを、実装が名前で持ちようのない項目で示す。
# 14 項目を名前で並べただけの検査に書き換える変異は、このケースだけが落とす。
# このスイートに置く: 撤去の前は 4 項目を検証していたスイートが同じ形を持っており、その
# スイートごと消したためここが唯一の置き場になった(凍結側の既存スイートは改訂できない)
func test_the_stat_check_reaches_an_item_the_implementation_cannot_know_by_name() -> void:
	var stats: ExtendedStats = auto_free(ExtendedStats.new())
	stats.unknown_stat = 0.0
	var player: Player = auto_free(Player.new())
	player.stats = stats
	var expected: String = INVALID_STAT_ERROR_FORMAT % [UNKNOWN_STAT_NAME, stats.unknown_stat]

	await assert_error(func() -> void: add_child(player)).is_push_error(expected)


func test_the_scan_reaches_every_source_directory() -> void:
	# 走査が空振りしていないことを、下の検査より先に固定する。0 件・浅い走査のまま緑になると、
	# 撤去の検査が何も見ていない
	var paths: PackedStringArray = _source_paths_under(SOURCE_ROOT)

	assert_array(paths).contains(SCAN_ANCHORS)


func test_no_source_under_src_names_a_removed_symbol() -> void:
	var paths: PackedStringArray = _source_paths_under(SOURCE_ROOT)
	var found_present_symbol: bool = false

	for path: String in paths:
		var source: String = FileAccess.get_file_as_string(path)
		# 実在するのに空文字列なら、以降の検査は何も見ないまま緑になる
		assert_str(source).append_failure_message(path).is_not_empty()
		if source.contains(PRESENT_SYMBOL):
			found_present_symbol = true
		for symbol: String in REMOVED_SYMBOLS:
			assert_str(source).append_failure_message(
				"%s に %s が残っている" % [path, symbol]
			).not_contains(symbol)

	assert_bool(found_present_symbol).append_failure_message(
		"`%s` が %s の下に 1 件も無い。走査が働いていない" % [PRESENT_SYMBOL, SOURCE_ROOT]
	).is_true()
