extends GdUnitTestSuite


func test_clampi_limits_value_to_range() -> void:
	assert_int(clampi(15, 0, 10)).is_equal(10)
	assert_int(clampi(-5, 0, 10)).is_equal(0)
	assert_int(clampi(7, 0, 10)).is_between(0, 10)


func test_lerpf_interpolates_between_bounds() -> void:
	assert_float(lerpf(0.0, 10.0, 0.5)).is_equal(5.0)
	assert_float(lerpf(0.0, 1.0, 0.1)).is_equal_approx(0.1, 0.0001)
	assert_float(lerpf(2.0, 8.0, 0.0)).is_equal(2.0)


func test_normalized_vector_has_unit_length() -> void:
	var direction: Vector2 = Vector2(3.0, 4.0).normalized()

	assert_float(direction.length()).is_equal_approx(1.0, 0.0001)
	assert_vector(direction).is_equal_approx(Vector2(0.6, 0.8), Vector2(0.0001, 0.0001))


func test_move_toward_stops_at_target() -> void:
	var position: Vector2 = Vector2.ZERO.move_toward(Vector2(10.0, 0.0), 25.0)

	assert_vector(position).is_equal(Vector2(10.0, 0.0))


func test_move_toward_advances_by_step_when_target_is_far() -> void:
	var position: Vector2 = Vector2.ZERO.move_toward(Vector2(100.0, 0.0), 25.0)

	assert_vector(position).is_equal(Vector2(25.0, 0.0))


func test_format_builds_label_from_values() -> void:
	var label: String = "HP: %d/%d" % [3, 5]

	assert_str(label).is_equal("HP: 3/5")
	assert_str(label).starts_with("HP:")
	assert_str(label).contains("3/5")


func test_filtered_and_sorted_values_keep_ascending_order() -> void:
	var values: Array[int] = [5, 2, 9, 1, 7]

	var filtered: Array[int] = values.filter(func(value: int) -> bool: return value > 2)
	filtered.sort()

	assert_array(filtered).contains_exactly([5, 7, 9])
	assert_array(filtered).has_size(3)
	assert_array(values).has_size(5)


func test_dictionary_get_returns_fallback_for_missing_key() -> void:
	var config: Dictionary = {"speed": 100, "jump": 250}

	assert_dict(config).contains_key_value("speed", 100)
	assert_dict(config).not_contains_keys(["dash"])
	assert_int(config.get("dash", 0)).is_zero()


func test_boolean_conditions_combine() -> void:
	var on_floor: bool = true
	var jump_requested: bool = false

	assert_bool(on_floor and not jump_requested).is_true()
	assert_bool(on_floor and jump_requested).is_false()
