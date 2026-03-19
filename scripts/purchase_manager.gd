extends RefCounted
class_name PurchaseManager

## 課金管理クラス
## 商品定義の読み込みと購入処理を管理。
## 現在はデバッグモード（即付与）。将来Apple/Google決済に差し替え。
##
## サーバー移行時の変更点:
##   1. purchase() をサーバーAPIに差し替え
##   2. レシート検証を追加
##   3. 商品定義をサーバーから取得に変更

const PACKAGES_PATH = "res://data/stone_packages.json"

var _packages: Array[Dictionary] = []
var _is_debug_mode: bool = true  # true=即付与、false=ストアAPI経由


func _init():
	_load_packages()


## 商品定義を読み込む
func _load_packages():
	_packages.clear()
	if not FileAccess.file_exists(PACKAGES_PATH):
		print("[PurchaseManager] 商品定義ファイルが見つかりません: ", PACKAGES_PATH)
		return

	var file = FileAccess.open(PACKAGES_PATH, FileAccess.READ)
	if not file:
		return

	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	file.close()

	if err != OK:
		print("[PurchaseManager] JSONパースエラー: ", json.get_error_message())
		return

	var data = json.data
	if data is Array:
		for item in data:
			_packages.append(item)
		_packages.sort_custom(_sort_by_order)

	print("[PurchaseManager] %d件の商品を読み込みました" % _packages.size())


func _sort_by_order(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("sort_order", 0)) < int(b.get("sort_order", 0))


## 全商品を取得
func get_all_packages() -> Array[Dictionary]:
	return _packages


## 商品IDで取得
func get_package(package_id: String) -> Dictionary:
	for pkg in _packages:
		if pkg.get("id", "") == package_id:
			return pkg
	return {}


## 購入処理（デバッグモード: 即付与 / 本番: ストアAPI）
func purchase(package_id: String) -> Dictionary:
	var pkg = get_package(package_id)
	if pkg.is_empty():
		return {"success": false, "error": "商品が見つかりません"}

	if _is_debug_mode:
		return _debug_purchase(pkg)

	# 本番モード（将来実装）
	# return await _store_purchase(pkg)
	return {"success": false, "error": "ストア連携は未実装です"}


## デバッグ用: 即時付与
func _debug_purchase(pkg: Dictionary) -> Dictionary:
	var stone_amount = int(pkg.get("stone_amount", 0))
	var bonus = int(pkg.get("bonus_amount", 0))
	var total = stone_amount + bonus

	GameData.add_stone(total)

	return {
		"success": true,
		"package_id": pkg.get("id", ""),
		"stone_amount": stone_amount,
		"bonus_amount": bonus,
		"total": total,
	}


## 将来実装: ストアAPI経由の購入
## func _store_purchase(pkg: Dictionary) -> Dictionary:
##     # 1. ストアの決済画面を呼び出し
##     # 2. レシートを受け取る
##     # 3. サーバーにレシートを送信して検証
##     # 4. サーバーが課金石を付与
##     pass
