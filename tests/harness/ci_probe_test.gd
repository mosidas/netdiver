extends GdUnitTestSuite

# CI が失敗を検出することの確認用。確認後に削除する
func test_intentional_failure() -> void:
	assert_int(1).is_equal(2)
