extends GdUnitTestSuite

# 既定値(30)と別の値を使う: 既定のままだと、`stats` を読まず値を直書きした実装でも緑になる
const MAX_HP: int = 24
const DAMAGE: int = 10
const OVERKILL: int = MAX_HP + DAMAGE

# 実装の文言を参照しない: 参照するとアサーションが自明になり、文言の退行を検出できない
const INVALID_AMOUNT_ERROR_FORMAT: String = (
	"Enemy.take_damage(): amount は正でなければならない(現在値: %s)。状態を変えずに返る"
)


func _create_stats() -> EnemyStats:
	var stats: EnemyStats = auto_free(EnemyStats.new())
	stats.max_hp = MAX_HP
	return stats


## ツリーへ載せていない `Enemy`。体力・撃破の契約はこの形で成立する
func _create_enemy() -> Enemy:
	var enemy: Enemy = auto_free(Enemy.new())
	enemy.stats = _create_stats()
	return enemy


func test_hp_starts_at_the_max_hp_of_the_stats() -> void:
	var enemy: Enemy = _create_enemy()

	assert_int(enemy.hp).is_equal(MAX_HP)


func test_take_damage_reduces_the_hp_by_the_amount() -> void:
	var enemy: Enemy = _create_enemy()

	enemy.take_damage(DAMAGE)

	assert_int(enemy.hp).is_equal(MAX_HP - DAMAGE)
	assert_bool(enemy.is_defeated).is_false()


func test_take_damage_does_not_take_the_hp_below_zero() -> void:
	var enemy: Enemy = _create_enemy()

	enemy.take_damage(OVERKILL)

	assert_int(enemy.hp).is_equal(0)


func test_defeated_is_emitted_once_with_the_kind_when_the_hp_reaches_zero() -> void:
	var enemy: Enemy = _create_enemy()
	# 発火を Array へ控える: lambda はローカル変数を値コピーで捕捉するが、Array は参照として
	# 捕捉されるため外側から読める
	var emissions: Array = []
	enemy.defeated.connect(func(kind: int) -> void: emissions.append(kind))

	enemy.take_damage(MAX_HP)

	assert_array(emissions).is_equal([EnemyKind.Kind.CHARGER])


func test_defeated_is_not_emitted_while_the_hp_remains() -> void:
	var enemy: Enemy = _create_enemy()
	var emissions: Array = []
	enemy.defeated.connect(func(kind: int) -> void: emissions.append(kind))

	enemy.take_damage(MAX_HP - 1)

	assert_array(emissions).is_empty()
	assert_int(enemy.hp).is_equal(1)


func test_is_defeated_stays_false_while_the_hp_remains() -> void:
	var enemy: Enemy = _create_enemy()

	enemy.take_damage(MAX_HP - 1)

	assert_bool(enemy.is_defeated).is_false()


func test_is_defeated_becomes_true_when_the_hp_reaches_zero() -> void:
	var enemy: Enemy = _create_enemy()

	enemy.take_damage(MAX_HP)

	assert_bool(enemy.is_defeated).is_true()


func test_take_damage_after_the_defeat_changes_neither_the_hp_nor_the_signal() -> void:
	var enemy: Enemy = _create_enemy()
	var emissions: Array = []
	enemy.defeated.connect(func(kind: int) -> void: emissions.append(kind))
	enemy.take_damage(MAX_HP)

	enemy.take_damage(DAMAGE)

	assert_int(enemy.hp).is_equal(0)
	assert_bool(enemy.is_defeated).is_true()
	assert_array(emissions).is_equal([EnemyKind.Kind.CHARGER])


func test_defeated_is_emitted_before_the_enemy_is_released() -> void:
	var enemy: Enemy = _create_enemy()
	# 受け手の中から解放の有無と is_defeated を読む: 発火の時点で敵が生きており、撃破の状態が
	# 済んでいることを、順序の要求として固定する
	var observed: Array = []
	var record: Callable = func(_kind: int) -> void: observed.append(
		[is_instance_valid(enemy), enemy.is_defeated]
	)
	enemy.defeated.connect(record)

	enemy.take_damage(MAX_HP)

	assert_array(observed).is_equal([[true, true]])


func test_the_enemy_is_released_after_the_defeat() -> void:
	var enemy: Enemy = _create_enemy()

	enemy.take_damage(MAX_HP)
	# 解放は現在のフレームの終わりに行われる。待ち時間には余裕を取る
	await await_millis(100)

	assert_bool(is_instance_valid(enemy)).is_false()


func test_take_damage_rejects_a_non_positive_amount() -> void:
	var enemy: Enemy = _create_enemy()

	await (
		assert_error(func() -> void: enemy.take_damage(0))
		. is_push_error(INVALID_AMOUNT_ERROR_FORMAT % 0)
	)
	await (
		assert_error(func() -> void: enemy.take_damage(-DAMAGE))
		. is_push_error(INVALID_AMOUNT_ERROR_FORMAT % -DAMAGE)
	)
	assert_int(enemy.hp).is_equal(MAX_HP)
	assert_bool(enemy.is_defeated).is_false()


func test_a_bare_enemy_returns_the_charger_kind() -> void:
	var enemy: Enemy = _create_enemy()

	assert_int(enemy.kind()).is_equal(EnemyKind.Kind.CHARGER)
