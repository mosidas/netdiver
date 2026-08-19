extends GdUnitTestSuite

# enum の値域のすぐ外を両側に置く: 片側だけでは、下限か上限のどちらかしか見ない
# ガードが素通りする
const BELOW_THE_KINDS: int = -1
const ABOVE_THE_KINDS: int = 2

# 実装の文言を固定する: 文言が変わると、利用者がログから原因を辿る手順が変わる
const UNKNOWN_KIND_ERROR_FORMAT: String = (
	"AbilityAnalysis.is_transferable(): kind は EnemyKind.Kind の値でなければならない(現在値: %s)。"
	+ "偽を返す"
)

const PLAYER_SOURCE_DIR: String = "res://src/player/"
const PLAYER_SOURCE_PATH: String = "res://src/player/player.gd"
const ANALYSIS_DEV_STAGE_SOURCE_PATH: String = "res://src/stage/analysis_dev_stage.gd"
const KIND_SYMBOL: String = "EnemyKind"


func _gd_sources_in(dir_path: String) -> PackedStringArray:
	var paths: PackedStringArray = []
	for file_name: String in DirAccess.get_files_at(dir_path):
		if file_name.ends_with(".gd"):
			paths.append(dir_path + file_name)
	return paths


func test_the_shooter_kind_is_transferable() -> void:
	assert_bool(AbilityAnalysis.is_transferable(EnemyKind.Kind.SHOOTER)).is_true()


func test_the_charger_kind_is_not_transferable() -> void:
	assert_bool(AbilityAnalysis.is_transferable(EnemyKind.Kind.CHARGER)).is_false()


func test_the_defined_kinds_push_no_error() -> void:
	for kind: int in EnemyKind.Kind.values():
		await assert_error(
			func() -> void: AbilityAnalysis.is_transferable(kind)
		).append_failure_message("kind=%s" % kind).is_success()


func test_the_values_just_outside_the_kinds_are_not_defined_kinds() -> void:
	# 異常系のケースが有効な値を渡していないことを先に固定する: 種別が増えたとき、
	# 異常系のケースが黙って正常系へ変わるのを防ぐ
	var kinds: Array = EnemyKind.Kind.values()

	assert_array(kinds).not_contains([BELOW_THE_KINDS])
	assert_array(kinds).not_contains([ABOVE_THE_KINDS])


func test_a_value_below_the_kinds_is_not_transferable() -> void:
	assert_bool(AbilityAnalysis.is_transferable(BELOW_THE_KINDS)).is_false()


func test_a_value_above_the_kinds_is_not_transferable() -> void:
	assert_bool(AbilityAnalysis.is_transferable(ABOVE_THE_KINDS)).is_false()


func test_a_value_below_the_kinds_pushes_an_error() -> void:
	await assert_error(
		func() -> void: AbilityAnalysis.is_transferable(BELOW_THE_KINDS)
	).is_push_error(UNKNOWN_KIND_ERROR_FORMAT % BELOW_THE_KINDS)


func test_a_value_above_the_kinds_pushes_an_error() -> void:
	await assert_error(
		func() -> void: AbilityAnalysis.is_transferable(ABOVE_THE_KINDS)
	).is_push_error(UNKNOWN_KIND_ERROR_FORMAT % ABOVE_THE_KINDS)


func test_the_same_argument_returns_the_same_answer_after_the_other_kind() -> void:
	# 別の種別と異常値を挟んでから同じ引数へ戻る: 直前の答えを覚える実装なら、
	# 挟んだ呼び出しが答えを汚す
	var first: bool = AbilityAnalysis.is_transferable(EnemyKind.Kind.SHOOTER)
	AbilityAnalysis.is_transferable(EnemyKind.Kind.CHARGER)
	AbilityAnalysis.is_transferable(ABOVE_THE_KINDS)
	var second: bool = AbilityAnalysis.is_transferable(EnemyKind.Kind.SHOOTER)

	assert_bool(second).is_equal(first)

	var charger_first: bool = AbilityAnalysis.is_transferable(EnemyKind.Kind.CHARGER)
	AbilityAnalysis.is_transferable(EnemyKind.Kind.SHOOTER)
	var charger_second: bool = AbilityAnalysis.is_transferable(EnemyKind.Kind.CHARGER)

	assert_bool(charger_second).is_equal(charger_first)


# 種別による分岐の所在は静的な検査だけでは示せない(ソースの文字列を見る検査は、
# 同じ分岐を別の書き方で置いた実装を素通りさせる)。振る舞い側の対 — 撃破の配線が
# 種別で分岐せず両方の種別で演出を生成すること、写せない種別の到達で枠が変わらないこと —
# は仮ステージのテストが持つ
func test_the_player_sources_do_not_name_the_enemy_kind() -> void:
	var paths: PackedStringArray = _gd_sources_in(PLAYER_SOURCE_DIR)

	# 走査が空振りしていないことを先に固定する: 0 件のまま緑になると、検査が何も見ていない
	assert_array(paths).contains([PLAYER_SOURCE_PATH])

	for path: String in paths:
		var source: String = FileAccess.get_file_as_string(path)

		assert_str(source).append_failure_message(path).is_not_empty()
		assert_str(source).append_failure_message(path).not_contains(KIND_SYMBOL)


func test_the_analysis_dev_stage_source_does_not_name_the_enemy_kind() -> void:
	var source: String = FileAccess.get_file_as_string(ANALYSIS_DEV_STAGE_SOURCE_PATH)

	if source.is_empty():
		# 対象がまだ無い間、この検査は空振りする。空振りと「実在するのに読めない」を
		# 区別する: 実在するのに空文字列なら、以降の検査は何も見ないまま緑になる
		assert_bool(FileAccess.file_exists(ANALYSIS_DEV_STAGE_SOURCE_PATH)).is_false()
		return

	assert_str(source).not_contains(KIND_SYMBOL)
