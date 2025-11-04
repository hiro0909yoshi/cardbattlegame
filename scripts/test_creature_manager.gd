extends Node
## CreatureManager テストスクリプト
## 既存システムに影響を与えずに新システムをテスト

var creature_manager: CreatureManager
var test_results: Array = []

func _ready():
	print("\n" + "=".repeat(60))
	print("CreatureManager 単体テスト開始")
	print("=".repeat(60) + "\n")
	
	# CreatureManagerインスタンスを作成
	creature_manager = CreatureManager.new()
	creature_manager.set_debug_mode(true)
	add_child(creature_manager)
	
	# テスト実行
	run_all_tests()
	
	# 結果表示
	print_test_results()
	
	# 終了
	get_tree().quit()

func run_all_tests():
	test_01_basic_set_and_get()
	test_02_reference_modification()
	test_03_empty_dictionary_handling()
	test_04_has_creature()
	test_05_clear_data()
	test_06_multiple_creatures()
	test_07_find_by_element()
	test_08_get_all_creatures()
	test_09_validate_integrity()
	test_10_save_load()

## テスト01: 基本的なset/get
func test_01_basic_set_and_get():
	var test_name = "基本的なset/get"
	print("\n[テスト01] ", test_name)
	
	var creature_data = {
		"name": "テストクリーチャー",
		"hp": 100,
		"max_hp": 100,
		"element": "fire"
	}
	
	creature_manager.set_data(0, creature_data)
	var retrieved = creature_manager.get_data_ref(0)
	
	var passed = (
		retrieved.get("name") == "テストクリーチャー" and
		retrieved.get("hp") == 100 and
		retrieved.get("element") == "fire"
	)
	
	add_test_result(test_name, passed)

## テスト02: 参照による変更
func test_02_reference_modification():
	var test_name = "参照による変更"
	print("\n[テスト02] ", test_name)
	
	var creature_data = {
		"name": "参照テスト",
		"hp": 50,
		"max_hp": 100
	}
	
	creature_manager.set_data(1, creature_data)
	
	# 参照を取得して変更
	var ref = creature_manager.get_data_ref(1)
	ref["hp"] = 75
	
	# 再度取得して確認
	var retrieved = creature_manager.get_data_ref(1)
	var passed = (retrieved.get("hp") == 75)
	
	add_test_result(test_name, passed)

## テスト03: 空辞書の扱い
func test_03_empty_dictionary_handling():
	var test_name = "空辞書の扱い"
	print("\n[テスト03] ", test_name)
	
	# データを設定
	creature_manager.set_data(2, {"name": "削除テスト"})
	
	# 空辞書を設定（削除）
	creature_manager.set_data(2, {})
	
	# データが削除されているか確認
	var has = creature_manager.has_creature(2)
	var passed = (not has)
	
	add_test_result(test_name, passed)

## テスト04: has_creature
func test_04_has_creature():
	var test_name = "has_creature"
	print("\n[テスト04] ", test_name)
	
	# データあり
	creature_manager.set_data(3, {"name": "存在チェック"})
	var has_with_data = creature_manager.has_creature(3)
	
	# データなし
	var has_without_data = creature_manager.has_creature(999)
	
	var passed = (has_with_data and not has_without_data)
	
	add_test_result(test_name, passed)

## テスト05: clear_data
func test_05_clear_data():
	var test_name = "clear_data"
	print("\n[テスト05] ", test_name)
	
	creature_manager.set_data(4, {"name": "クリアテスト"})
	creature_manager.clear_data(4)
	
	var passed = (not creature_manager.has_creature(4))
	
	add_test_result(test_name, passed)

## テスト06: 複数クリーチャー
func test_06_multiple_creatures():
	var test_name = "複数クリーチャー管理"
	print("\n[テスト06] ", test_name)
	
	# 複数設定
	for i in range(10, 15):
		creature_manager.set_data(i, {
			"name": "クリーチャー%d" % i,
			"element": "fire" if i % 2 == 0 else "water"
		})
	
	var count = creature_manager.get_creature_count()
	var passed = (count >= 5)  # 他のテストのデータも含まれる可能性があるため >=
	
	add_test_result(test_name, passed)

## テスト07: find_by_element
func test_07_find_by_element():
	var test_name = "属性検索"
	print("\n[テスト07] ", test_name)
	
	# テストデータ設定
	creature_manager.clear_all()
	creature_manager.set_data(20, {"element": "fire"})
	creature_manager.set_data(21, {"element": "water"})
	creature_manager.set_data(22, {"element": "fire"})
	
	var fire_creatures = creature_manager.find_by_element("fire")
	var passed = (fire_creatures.size() == 2)
	
	add_test_result(test_name, passed)

## テスト08: get_all_creatures
func test_08_get_all_creatures():
	var test_name = "全クリーチャー取得"
	print("\n[テスト08] ", test_name)
	
	creature_manager.clear_all()
	creature_manager.set_data(30, {"name": "A"})
	creature_manager.set_data(31, {"name": "B"})
	creature_manager.set_data(32, {"name": "C"})
	
	var all = creature_manager.get_all_creatures()
	var passed = (all.size() == 3)
	
	add_test_result(test_name, passed)

## テスト09: validate_integrity
func test_09_validate_integrity():
	var test_name = "整合性チェック"
	print("\n[テスト09] ", test_name)
	
	creature_manager.clear_all()
	creature_manager.set_data(40, {"name": "整合性テスト"})
	
	var passed = creature_manager.validate_integrity()
	
	add_test_result(test_name, passed)

## テスト10: セーブ/ロード
func test_10_save_load():
	var test_name = "セーブ/ロード"
	print("\n[テスト10] ", test_name)
	
	creature_manager.clear_all()
	creature_manager.set_data(50, {"name": "セーブテスト", "hp": 100})
	creature_manager.set_data(51, {"name": "ロードテスト", "hp": 200})
	
	# セーブ
	var save_data = creature_manager.get_save_data()
	
	# クリア
	creature_manager.clear_all()
	
	# ロード
	creature_manager.load_from_save_data(save_data)
	
	# 確認
	var creature_50 = creature_manager.get_data_ref(50)
	var creature_51 = creature_manager.get_data_ref(51)
	
	var passed = (
		creature_50.get("name") == "セーブテスト" and
		creature_50.get("hp") == 100 and
		creature_51.get("name") == "ロードテスト" and
		creature_51.get("hp") == 200
	)
	
	add_test_result(test_name, passed)

## テスト結果を記録
func add_test_result(test_name: String, passed: bool):
	test_results.append({"name": test_name, "passed": passed})
	if passed:
		print("  ✅ PASSED")
	else:
		print("  ❌ FAILED")

## テスト結果を表示
func print_test_results():
	print("\n" + "=".repeat(60))
	print("テスト結果サマリー")
	print("=".repeat(60))
	
	var total = test_results.size()
	var passed = 0
	
	for result in test_results:
		if result["passed"]:
			passed += 1
			print("  ✅ ", result["name"])
		else:
			print("  ❌ ", result["name"])
	
	print("\n結果: %d/%d テストが成功" % [passed, total])
	
	if passed == total:
		print("🎉 すべてのテストが成功しました！")
	else:
		print("⚠️  一部のテストが失敗しました。")
	
	print("=".repeat(60) + "\n")
