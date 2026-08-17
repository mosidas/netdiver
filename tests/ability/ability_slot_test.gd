extends GdUnitTestSuite

# 2 進で厳密に表せる値を使い、クールダウンを 1 フレームの整数倍に取る:
# 累積の誤差で境界の判定が揺れると、経過をフレーム数で数えられない
const FRAME_DELTA: float = 0.0625
const COOLDOWN: float = 0.25
const FRAMES_PER_COOLDOWN: int = 4

# 取得のたびに別の回数を渡す: 同じ値を 2 回渡すと、加算する実装と置き換える実装を
# 区別できない。小さい側へ置き換える組も置く(大きいほうを残す実装を落とす)
const FIRST_USES: int = 5
const LARGER_USES: int = 7
const SMALLER_USES: int = 2
const SINGLE_USE: int = 1

# 拒否する呼び出しには、成功する呼び出しと別の値を渡す。0 と負の両方を置く:
# 片側だけでは、もう片側を素通りさせるガードが残る
const INVALID_USES: Array[int] = [0, -3]

# クールダウンの境界をフレーム数で置く: 発射したフレームから数えて FRAMES_PER_COOLDOWN
# フレーム後の経過がちょうど COOLDOWN(4 × 0.0625 = 0.25)になる
const FIRE_THEN_PRESS_AT_THE_COOLDOWN: Array[bool] = [true, false, false, false, true]
const FIRE_THEN_PRESS_ONE_FRAME_EARLY: Array[bool] = [true, false, false, true]

# 押しっぱなしのまま境界を跨ぐ列。縁を見ない実装は 5 フレーム目で 2 発目を出す
const HELD_PAST_THE_COOLDOWN: Array[bool] = [true, true, true, true, true, true]

# 実装の文言を固定する: 文言が変わると、利用者がログから原因を辿る手順が変わる
const INVALID_USES_ERROR_FORMAT: String = (
	"AbilitySlot.grant(): uses は正でなければならない(現在値: %s)。状態を変えずに返る"
)


# 押下の縁とクールダウンの明けの両方を満たしてから押す: この検査の対象は残り回数と
# is_empty であり、縁とクールダウンの条件で発射が落ちると対象を見失う
func _fire(slot: AbilitySlot) -> bool:
	for frame: int in FRAMES_PER_COOLDOWN:
		slot.update(false, FRAME_DELTA)
	return slot.update(true, FRAME_DELTA)


# 戻り値と残り回数を対で並べる: 別々のアサーションで見ると、「真を返すが減らない」
# 「減るが真を返さない」の片方だけを壊す変異が、対応の崩れとして現れない
func _run(slot: AbilitySlot, held_frames: Array[bool], delta: float = FRAME_DELTA) -> Array[Array]:
	var steps: Array[Array] = []
	for held: bool in held_frames:
		var fired: bool = slot.update(held, delta)
		steps.append([fired, slot.remaining_uses])
	return steps


func test_the_values_used_here_differ_from_the_defaults() -> void:
	# 既定値と一致する値を渡していないことを先に固定する: 既定のままだと、
	# 値を直書きした実装も緑になる
	var stats: PlayerStats = auto_free(PlayerStats.new())

	assert_float(stats.ability_cooldown).is_not_equal(COOLDOWN)
	assert_array([FIRST_USES, LARGER_USES, SMALLER_USES, SINGLE_USE]).not_contains(
		[stats.ability_uses]
	)


func test_a_new_slot_has_no_remaining_uses() -> void:
	var slot: AbilitySlot = auto_free(AbilitySlot.new(COOLDOWN))

	assert_int(slot.remaining_uses).is_equal(0)


func test_a_new_slot_is_empty() -> void:
	var slot: AbilitySlot = auto_free(AbilitySlot.new(COOLDOWN))

	assert_bool(slot.is_empty).is_true()


func test_grant_sets_the_remaining_uses() -> void:
	var slot: AbilitySlot = auto_free(AbilitySlot.new(COOLDOWN))

	slot.grant(FIRST_USES)

	assert_int(slot.remaining_uses).is_equal(FIRST_USES)


# 別の回数でもう 1 本置く: 回数を直書きした実装は両方では緑にならない
func test_grant_sets_a_different_count_of_remaining_uses() -> void:
	var slot: AbilitySlot = auto_free(AbilitySlot.new(COOLDOWN))

	slot.grant(SMALLER_USES)

	assert_int(slot.remaining_uses).is_equal(SMALLER_USES)


func test_a_granted_slot_is_not_empty() -> void:
	var slot: AbilitySlot = auto_free(AbilitySlot.new(COOLDOWN))

	slot.grant(SMALLER_USES)

	assert_bool(slot.is_empty).is_false()


func test_grant_replaces_a_larger_remaining_count_with_a_smaller_one() -> void:
	var slot: AbilitySlot = auto_free(AbilitySlot.new(COOLDOWN))
	slot.grant(FIRST_USES)

	slot.grant(SMALLER_USES)

	assert_int(slot.remaining_uses).is_equal(SMALLER_USES)


func test_grant_replaces_a_smaller_remaining_count_with_a_larger_one() -> void:
	var slot: AbilitySlot = auto_free(AbilitySlot.new(COOLDOWN))
	slot.grant(SMALLER_USES)

	slot.grant(LARGER_USES)

	assert_int(slot.remaining_uses).is_equal(LARGER_USES)


# 置き換えは残り回数だけでなく撃てる回数にも現れる: 大きい回数から小さい回数へ
# 置き換えた後は、置き換えた回数だけ撃つと空になる
func test_a_replaced_slot_runs_out_after_the_replacing_count_of_shots() -> void:
	var slot: AbilitySlot = auto_free(AbilitySlot.new(COOLDOWN))
	slot.grant(FIRST_USES)

	slot.grant(SMALLER_USES)
	var fired: Array[bool] = []
	for shot: int in SMALLER_USES:
		fired.append(_fire(slot))

	assert_array(fired).is_equal([true, true])
	assert_int(slot.remaining_uses).is_equal(0)
	assert_bool(slot.is_empty).is_true()


func test_grant_keeps_the_remaining_uses_for_a_non_positive_count() -> void:
	for uses: int in INVALID_USES:
		var slot: AbilitySlot = auto_free(AbilitySlot.new(COOLDOWN))
		# 残り回数が正である状態で拒否させる: 空の状態で拒否させると、
		# 状態を 0 へ落とす変異が no-op になって素通りする
		slot.grant(FIRST_USES)

		slot.grant(uses)

		var context: String = "uses=%s" % uses
		assert_int(slot.remaining_uses).append_failure_message(context).is_equal(FIRST_USES)
		assert_bool(slot.is_empty).append_failure_message(context).is_false()


# 拒否が振る舞いの側でも状態を変えていないことを見る: 拒否の後も、拒否の前と同じだけ撃てる
func test_a_rejected_grant_leaves_the_slot_usable() -> void:
	for uses: int in INVALID_USES:
		var slot: AbilitySlot = auto_free(AbilitySlot.new(COOLDOWN))
		slot.grant(SMALLER_USES)

		slot.grant(uses)

		var context: String = "uses=%s" % uses
		assert_bool(_fire(slot)).append_failure_message(context).is_true()
		assert_int(slot.remaining_uses).append_failure_message(context).is_equal(SMALLER_USES - 1)


func test_grant_pushes_an_error_for_a_non_positive_count() -> void:
	for uses: int in INVALID_USES:
		var slot: AbilitySlot = auto_free(AbilitySlot.new(COOLDOWN))
		slot.grant(FIRST_USES)

		await assert_error(func() -> void: slot.grant(uses)).is_push_error(
			INVALID_USES_ERROR_FORMAT % uses
		)


func test_a_valid_grant_pushes_no_error() -> void:
	var slot: AbilitySlot = auto_free(AbilitySlot.new(COOLDOWN))

	await assert_error(func() -> void: slot.grant(SINGLE_USE)).is_success()


func test_the_slot_becomes_empty_when_the_last_use_is_spent() -> void:
	var slot: AbilitySlot = auto_free(AbilitySlot.new(COOLDOWN))
	slot.grant(SINGLE_USE)

	var fired: bool = _fire(slot)

	assert_bool(fired).is_true()
	assert_int(slot.remaining_uses).is_equal(0)
	assert_bool(slot.is_empty).is_true()


func test_the_slot_is_not_empty_while_uses_remain_after_a_shot() -> void:
	var slot: AbilitySlot = auto_free(AbilitySlot.new(COOLDOWN))
	slot.grant(SMALLER_USES)

	var fired: bool = _fire(slot)

	assert_bool(fired).is_true()
	assert_int(slot.remaining_uses).is_equal(SMALLER_USES - 1)
	assert_bool(slot.is_empty).is_false()


func test_granting_again_fills_an_emptied_slot() -> void:
	var slot: AbilitySlot = auto_free(AbilitySlot.new(COOLDOWN))
	slot.grant(SINGLE_USE)
	_fire(slot)

	slot.grant(FIRST_USES)

	assert_int(slot.remaining_uses).is_equal(FIRST_USES)
	assert_bool(slot.is_empty).is_false()


# is_empty が残り回数から導かれることは、grant() の直後だけでは示せない
# (grant() で偽に置く独立の bool でも通る)。取得と発射を挟んだ各段で対応を見る
func test_is_empty_follows_the_remaining_uses_at_every_step() -> void:
	var slot: AbilitySlot = auto_free(AbilitySlot.new(COOLDOWN))
	var states: Array[Array] = [[slot.remaining_uses, slot.is_empty]]
	var fired: Array[bool] = []

	slot.grant(SMALLER_USES)
	states.append([slot.remaining_uses, slot.is_empty])
	for shot: int in SMALLER_USES:
		fired.append(_fire(slot))
		states.append([slot.remaining_uses, slot.is_empty])
	slot.grant(SINGLE_USE)
	states.append([slot.remaining_uses, slot.is_empty])

	assert_array(fired).is_equal([true, true])
	assert_array(states).is_equal(
		[[0, true], [SMALLER_USES, false], [SMALLER_USES - 1, false], [0, true], [SINGLE_USE, false]]
	)


# 取得した枠は最初の押下で撃てる。クールダウンを明けた状態に置かない実装
# (経過を 0 のままにする)は、このケースだけが落とす
func test_the_first_press_after_a_grant_fires_without_waiting_for_the_cooldown() -> void:
	var slot: AbilitySlot = auto_free(AbilitySlot.new(COOLDOWN))
	slot.grant(FIRST_USES)

	var steps: Array[Array] = _run(slot, [true])

	assert_array(steps).is_equal([[true, FIRST_USES - 1]])


# 3 つの条件がすべて真のケース。押していないフレームでは残り回数も動かない
func test_a_press_fires_and_spends_one_use_when_every_condition_holds() -> void:
	var slot: AbilitySlot = auto_free(AbilitySlot.new(COOLDOWN))
	slot.grant(FIRST_USES)

	var steps: Array[Array] = _run(slot, [false, false, false, false, true])

	assert_array(steps).is_equal(
		[
			[false, FIRST_USES],
			[false, FIRST_USES],
			[false, FIRST_USES],
			[false, FIRST_USES],
			[true, FIRST_USES - 1],
		]
	)


# 縁だけを偽にしたケース(クールダウンは明けており、残り回数も正)
func test_a_button_held_from_the_first_frame_fires_only_on_that_frame() -> void:
	var slot: AbilitySlot = auto_free(AbilitySlot.new(COOLDOWN))
	slot.grant(FIRST_USES)

	var steps: Array[Array] = _run(slot, [true, true, true])

	assert_array(steps).is_equal(
		[[true, FIRST_USES - 1], [false, FIRST_USES - 1], [false, FIRST_USES - 1]]
	)


# 押しっぱなしのまま境界を跨いでも 2 発目は出ない: 上の 3 フレームの列だけでは、
# 2 発目がクールダウンで止まっているのか縁で止まっているのかを区別できない
func test_a_button_held_past_the_cooldown_does_not_fire_again() -> void:
	var slot: AbilitySlot = auto_free(AbilitySlot.new(COOLDOWN))
	slot.grant(FIRST_USES)

	var steps: Array[Array] = _run(slot, HELD_PAST_THE_COOLDOWN)

	assert_array(steps).is_equal(
		[
			[true, FIRST_USES - 1],
			[false, FIRST_USES - 1],
			[false, FIRST_USES - 1],
			[false, FIRST_USES - 1],
			[false, FIRST_USES - 1],
			[false, FIRST_USES - 1],
		]
	)


# クールダウンだけを偽にしたケース(縁であり、残り回数も正)。境界の内側
func test_a_press_one_frame_short_of_the_cooldown_does_not_fire() -> void:
	var slot: AbilitySlot = auto_free(AbilitySlot.new(COOLDOWN))
	slot.grant(FIRST_USES)

	var steps: Array[Array] = _run(slot, FIRE_THEN_PRESS_ONE_FRAME_EARLY)

	assert_array(steps).is_equal(
		[
			[true, FIRST_USES - 1],
			[false, FIRST_USES - 1],
			[false, FIRST_USES - 1],
			[false, FIRST_USES - 1],
		]
	)


# 境界の外側。1 つ手前のケースと対で、比較を >= から > へ変える変異を落とす
func test_a_press_exactly_at_the_cooldown_fires_again() -> void:
	var slot: AbilitySlot = auto_free(AbilitySlot.new(COOLDOWN))
	slot.grant(FIRST_USES)

	var steps: Array[Array] = _run(slot, FIRE_THEN_PRESS_AT_THE_COOLDOWN)

	assert_array(steps).is_equal(
		[
			[true, FIRST_USES - 1],
			[false, FIRST_USES - 1],
			[false, FIRST_USES - 1],
			[false, FIRST_USES - 1],
			[true, FIRST_USES - 2],
		]
	)


# 経過は delta で測る。フレーム数で数える実装は、1 フレームで COOLDOWN を渡しても
# 3 フレーム分を待たせる
func test_the_cooldown_measures_elapsed_time_rather_than_frame_count() -> void:
	var slot: AbilitySlot = auto_free(AbilitySlot.new(COOLDOWN))
	slot.grant(FIRST_USES)
	var steps: Array[Array] = []

	steps.append([slot.update(true, FRAME_DELTA), slot.remaining_uses])
	steps.append([slot.update(false, COOLDOWN), slot.remaining_uses])
	steps.append([slot.update(true, FRAME_DELTA), slot.remaining_uses])

	assert_array(steps).is_equal(
		[[true, FIRST_USES - 1], [false, FIRST_USES - 1], [true, FIRST_USES - 2]]
	)
