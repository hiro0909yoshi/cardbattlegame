extends GutTest

## RankCalculator のテスト
## ターン数 → ランク計算が正しいかを検証


func test_rank_ss():
	# 14ターン以下はSSランク
	assert_eq(RankCalculator.calculate_rank(10), "SS")
	assert_eq(RankCalculator.calculate_rank(14), "SS")


func test_rank_s():
	# 15〜19ターンはSランク
	assert_eq(RankCalculator.calculate_rank(15), "S")
	assert_eq(RankCalculator.calculate_rank(19), "S")


func test_rank_a():
	# 20〜24ターンはAランク
	assert_eq(RankCalculator.calculate_rank(20), "A")
	assert_eq(RankCalculator.calculate_rank(24), "A")


func test_rank_b():
	# 25〜29ターンはBランク
	assert_eq(RankCalculator.calculate_rank(25), "B")
	assert_eq(RankCalculator.calculate_rank(29), "B")


func test_rank_c():
	# 30ターン以上はCランク
	assert_eq(RankCalculator.calculate_rank(30), "C")
	assert_eq(RankCalculator.calculate_rank(100), "C")


func test_rank_boundary():
	# 境界値テスト
	assert_eq(RankCalculator.calculate_rank(14), "SS")  # SSの上限
	assert_eq(RankCalculator.calculate_rank(15), "S")   # Sの下限


func test_is_better_rank():
	# SSはSより良い
	assert_true(RankCalculator.is_better_rank("SS", "S"))
	# SはAより良い
	assert_true(RankCalculator.is_better_rank("S", "A"))
	# CはSSより悪い
	assert_false(RankCalculator.is_better_rank("C", "SS"))
	# 同ランクは「より良い」ではない
	assert_false(RankCalculator.is_better_rank("A", "A"))


func test_is_valid_rank():
	assert_true(RankCalculator.is_valid_rank("SS"))
	assert_true(RankCalculator.is_valid_rank("C"))
	assert_false(RankCalculator.is_valid_rank("D"))
	assert_false(RankCalculator.is_valid_rank(""))
