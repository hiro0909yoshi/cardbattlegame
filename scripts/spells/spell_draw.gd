extends Node
class_name SpellDraw

## ドロー・手札操作の汎用化モジュール
## バトル外のマップ効果として使用する

var card_system_ref: CardSystem = null
var player_system_ref = null
var card_selection_handler: CardSelectionHandler = null
var ui_manager_ref = null
var board_system_ref = null
var spell_creature_place_ref = null

func setup(card_system: CardSystem, player_system = null):
	card_system_ref = card_system
	player_system_ref = player_system
	print("SpellDraw: セットアップ完了")

## BoardSystem参照を設定
func set_board_system(board_system):
	board_system_ref = board_system

## UIマネージャーを設定
func set_ui_manager(ui_manager):
	ui_manager_ref = ui_manager

## カード選択ハンドラーを設定
func set_card_selection_handler(handler: CardSelectionHandler):
	card_selection_handler = handler

## SpellCreaturePlace参照を設定
func set_spell_creature_place(spell_creature_place):
	spell_creature_place_ref = spell_creature_place

## 統合エントリポイント - effect辞書から適切な処理を実行
## 戻り値: Dictionary（結果情報、next_effectがある場合は再帰適用が必要）
func apply_effect(effect: Dictionary, player_id: int, context: Dictionary = {}) -> Dictionary:
	var effect_type = effect.get("effect_type", "")
	var result = {}
	
	match effect_type:
		"draw", "draw_cards":
			var count = effect.get("count", 1)
			result["drawn"] = draw_cards(player_id, count)
		
		"draw_by_rank":
			var rank = context.get("rank", 1)
			result["drawn"] = draw_by_rank(player_id, rank)
		
		"draw_by_type":
			var card_type = effect.get("card_type", "")
			if card_type != "":
				# card_type指定あり → 同期処理（秘術等）
				result = draw_card_by_type(player_id, card_type)
			else:
				# card_type指定なし → UI選択必要（プロフェシー等）
				_start_type_selection_draw(player_id)
				result["async"] = true
		
		"discard_and_draw_plus":
			result["drawn"] = discard_and_draw_plus(player_id)
		
		"check_hand_elements":
			# 密命：手札属性チェック（条件分岐）
			var required_elements = effect.get("required_elements", ["fire", "water", "wind", "earth"])
			var success_effect = effect.get("success_effect", {})
			var fail_effect = effect.get("fail_effect", {})
			
			var hand_elements = get_hand_creature_elements(player_id)
			var has_all = has_all_elements(player_id, required_elements)
			
			if has_all:
				print("[密命成功] 手札に4属性あり: %s" % str(hand_elements))
				result["next_effect"] = success_effect
			else:
				print("[密命失敗] 手札の属性: %s（必要: %s）" % [str(hand_elements), str(required_elements)])
				result["next_effect"] = fail_effect
		
		"destroy_curse_cards":
			# 全プレイヤーの呪いカード破壊（レイオブパージ用）
			result = destroy_curse_cards()
		
		"destroy_expensive_cards":
			# 全プレイヤーの高コストカード破壊（レイオブロウ用）
			var cost_threshold = effect.get("cost_threshold", 100)
			result = destroy_expensive_cards(cost_threshold)
		
		"destroy_duplicate_cards":
			# 対象プレイヤーの重複カード破壊（エロージョン用）
			# 合成時は全プレイヤー対象
			var all_players = effect.get("all_players", false)
			if all_players:
				result = destroy_duplicate_cards_all_players()
			else:
				var target_player_id = context.get("target_player_id", player_id)
				result = destroy_duplicate_cards(target_player_id)
		
		"destroy_selected_card":
			# 敵手札からカードを選んで破壊（シャッター、スクイーズ用）
			var target_player_id = context.get("target_player_id", -1)
			if target_player_id >= 0 and card_selection_handler:
				var filter_mode = effect.get("filter_mode", "destroy_any")
				var magic_bonus = effect.get("magic_bonus", 0)
				card_selection_handler.set_current_player(player_id)
				card_selection_handler.start_enemy_card_selection(target_player_id, filter_mode, func(card_index: int):
					if card_index >= 0 and magic_bonus > 0:
						if player_system_ref and target_player_id < player_system_ref.players.size():
							player_system_ref.players[target_player_id].magic_power += magic_bonus
							print("[スクイーズ] プレイヤー%d: G%d を獲得" % [target_player_id + 1, magic_bonus])
				)
				result["async"] = true
		
		"steal_selected_card":
			# 敵手札からカードを選んで奪取（セフト用）
			var target_player_id = context.get("target_player_id", -1)
			if target_player_id >= 0 and card_selection_handler:
				var filter_mode = effect.get("filter_mode", "destroy_spell")
				card_selection_handler.set_current_player(player_id)
				card_selection_handler.start_enemy_card_selection(target_player_id, filter_mode, func(_card_index: int):
					pass
				, true)
				result["async"] = true
		
		"destroy_from_deck_selection":
			# デッキ上部からカードを選んで破壊（ポイズンマインド用）
			var target_player_id = context.get("target_player_id", -1)
			if target_player_id >= 0 and card_selection_handler:
				var look_count = effect.get("look_count", 6)
				var draw_after = effect.get("draw_after", 0)
				card_selection_handler.set_current_player(player_id)
				card_selection_handler.start_deck_card_selection(target_player_id, look_count, func(_card_index: int):
					if draw_after > 0:
						draw_cards(player_id, draw_after)
				)
				result["async"] = true
		
		"draw_from_deck_selection":
			# デッキ上部からカードを選んでドロー（フォーサイト用）
			# 自分のデッキが対象
			if card_selection_handler:
				var look_count = effect.get("look_count", 6)
				card_selection_handler.set_current_player(player_id)
				card_selection_handler.start_deck_draw_selection(player_id, look_count, func(_card_index: int):
					pass  # ドロー処理はハンドラー内で完了
				)
				result["async"] = true
		
		"steal_item_conditional":
			# アイテム条件付き奪取（スニークハンド用）
			var target_player_id = context.get("target_player_id", -1)
			if target_player_id < 0 or not card_selection_handler:
				pass
			else:
				var required_count = effect.get("required_item_count", 2)
				var item_count = count_items_in_hand(target_player_id)
				if item_count >= required_count:
					card_selection_handler.set_current_player(player_id)
					card_selection_handler.start_enemy_card_selection(target_player_id, "item", func(_card_index: int):
						pass
					, true)  # is_steal = true
					result["async"] = true
				else:
					print("[スニークハンド] 条件未達: プレイヤー%d のアイテム数 %d < 必要数 %d" % [target_player_id + 1, item_count, required_count])
					result["failed"] = true
		
		"add_specific_card":
			# 特定カードを手札に生成（ハイプクイーン用）
			var card_id = effect.get("card_id", -1)
			result = add_specific_card_to_hand(player_id, card_id)
		
		"destroy_and_draw":
			# 敵手札破壊→敵がドロー（クラウドギズモ用）
			var target_player_id = context.get("target_player_id", -1)
			if target_player_id >= 0 and card_selection_handler:
				card_selection_handler.set_current_player(player_id)
				card_selection_handler.start_enemy_card_selection(target_player_id, "destroy_any", func(_card_index: int):
					# 破壊後に破壊された側が1枚ドロー
					draw_cards(target_player_id, 1)
				)
				result["async"] = true
		
		"swap_creature":
			# クリーチャー交換（レムレース用）
			var target_player_id = context.get("target_player_id", -1)
			var caster_tile_index = context.get("tile_index", -1)
			if target_player_id >= 0 and card_selection_handler and caster_tile_index >= 0:
				card_selection_handler.set_current_player(player_id)
				card_selection_handler.start_enemy_card_selection(target_player_id, "creature", func(_card_index: int):
					pass  # 奪取処理はハンドラー内で完了、土地処理は別途
				, true)  # is_steal = true
				# キャスタークリーチャーを土地から除去して敵手札に追加
				_move_caster_to_enemy_hand(caster_tile_index, target_player_id)
				result["async"] = true
		
		"transform_to_card":
			# 敵手札からカード選択→同名カード全変換（メタモルフォシス用）
			var target_player_id = context.get("target_player_id", -1)
			if target_player_id >= 0 and card_selection_handler:
				var transform_to_id = effect.get("transform_to_id", -1)
				card_selection_handler.set_current_player(player_id)
				card_selection_handler.start_transform_card_selection(target_player_id, "item_or_spell", transform_to_id)
				result["async"] = true
		
		"reset_deck":
			# 対象ブックを初期化（リバイバル用）
			var target_player_id = context.get("target_player_id", -1)
			if target_player_id >= 0:
				result = reset_deck_to_original(target_player_id)
		
		"destroy_deck_top":
			# 対象ブックの上1枚を破壊（コアトリクエ秘術用）
			var target_player_id = context.get("target_player_id", -1)
			var count = effect.get("count", 1)
			if target_player_id >= 0:
				for i in range(count):
					var destroy_result = destroy_deck_card_at_index(target_player_id, 0)
					if destroy_result.get("destroyed", false):
						result["destroyed"] = true
						result["card_name"] = destroy_result.get("card_name", "")
					else:
						break  # デッキが空になったら終了
		
		"draw_and_place":
			# カードを引いてクリーチャーだった場合配置（ワイルドセンス用）
			result = _apply_draw_and_place(effect, player_id)
		
		"check_hand_synthesis":
			# 手札に合成持ちカードがあるかチェック（フィロソフィー用）
			var success_effect = effect.get("success_effect", {})
			var fail_effect = effect.get("fail_effect", {})
			
			var has_synthesis = _has_synthesis_card_in_hand(player_id)
			if has_synthesis:
				print("[フィロソフィー] 合成持ちカードあり")
				result["next_effect"] = success_effect
			else:
				print("[フィロソフィー] 合成持ちカードなし")
				result["next_effect"] = fail_effect
		
		_:
			print("[SpellDraw] 未対応の効果タイプ: ", effect_type)
	
	return result

## 1枚ドロー（ターン開始用）
func draw_one(player_id: int) -> Dictionary:
	"""
	ターン開始時の1枚ドロー
	
	戻り値: Dictionary（引いたカードデータ、引けなかった場合は空の辞書）
	"""
	if not card_system_ref:
		push_error("SpellDraw: CardSystemが設定されていません")
		return {}
	
	var card = card_system_ref.draw_card_for_player(player_id)
	
	if not card.is_empty():
		print("[ドロー] プレイヤー", player_id + 1, "が1枚引きました: ", card.get("name", "不明"))
	else:
		print("[ドロー] プレイヤー", player_id + 1, "はカードを引けませんでした")
	
	return card

## 固定枚数ドロー
func draw_cards(player_id: int, count: int) -> Array:
	"""
	指定枚数カードを引く
	
	用途: 「2枚引く」「3枚引く」などの固定ドロースペル
	
	引数:
	  player_id: プレイヤーID（0-3）
	  count: 引く枚数
	
	戻り値: Array（引いたカードデータの配列）
	"""
	if not card_system_ref:
		push_error("SpellDraw: CardSystemが設定されていません")
		return []
	
	if count <= 0:
		print("[ドロー] プレイヤー", player_id + 1, "は0枚指定のため何も引きません")
		return []
	
	var drawn = card_system_ref.draw_cards_for_player(player_id, count)
	print("[ドロー] プレイヤー", player_id + 1, "が", drawn.size(), "枚引きました（要求: ", count, "枚）")
	
	return drawn

## タイプ指定ドロー（プロフェシー用）
func draw_card_by_type(player_id: int, card_type: String) -> Dictionary:
	"""
	デッキから指定タイプのカードを1枚引く
	
	引数:
	  player_id: プレイヤーID
	  card_type: カードタイプ（"creature", "item", "spell"）
	
	戻り値: Dictionary
	  - drawn: bool（ドロー成功したか）
	  - card_name: String（引いたカード名）
	  - card_data: Dictionary（引いたカードのデータ）
	"""
	if not card_system_ref:
		push_error("SpellDraw: CardSystemが設定されていません")
		return {"drawn": false, "card_name": "", "card_data": {}}
	
	var deck = card_system_ref.player_decks.get(player_id, [])
	
	# デッキから指定タイプのカードを探す
	for i in range(deck.size()):
		var card_id = deck[i]
		var card_data = CardLoader.get_card_by_id(card_id)
		if card_data and card_data.get("type", "") == card_type:
			# 見つかった！デッキから削除して手札に加える
			card_system_ref.player_decks[player_id].remove_at(i)
			card_system_ref.return_card_to_hand(player_id, card_data.duplicate(true))
			var card_name = card_data.get("name", "?")
			print("[プロフェシー] プレイヤー%d: デッキから『%s』（%s）を引きました" % [player_id + 1, card_name, card_type])
			return {"drawn": true, "card_name": card_name, "card_data": card_data}
	
	# 該当タイプがデッキにない
	print("[プロフェシー] プレイヤー%d: デッキに%sがありません" % [player_id + 1, card_type])
	return {"drawn": false, "card_name": "", "card_data": {}}

## 特定カードを手札に生成（ハイプクイーン用）
func add_specific_card_to_hand(player_id: int, card_id: int) -> Dictionary:
	"""
	CardLoaderから指定IDのカードデータを取得し、手札に追加する（無から生成）
	
	引数:
	  player_id: プレイヤーID（0-3）
	  card_id: 追加するカードのID
	
	戻り値: Dictionary
	  - success: bool
	  - card_name: String
	"""
	if not card_system_ref:
		push_error("SpellDraw: card_system_refが未設定")
		return {"success": false, "card_name": ""}
	
	var card_data = CardLoader.get_card_by_id(card_id)
	if card_data.is_empty():
		push_error("SpellDraw: カードID %d が見つかりません" % card_id)
		return {"success": false, "card_name": ""}
	
	# 手札に追加
	card_system_ref.return_card_to_hand(player_id, card_data.duplicate(true))
	var card_name = card_data.get("name", "?")
	print("[カード生成] プレイヤー%d: 『%s』を手札に追加" % [player_id + 1, card_name])
	
	# UI更新
	if ui_manager_ref and ui_manager_ref.hand_display:
		ui_manager_ref.hand_display.update_hand_display(player_id)
	
	return {"success": true, "card_name": card_name}

## キャスタークリーチャーを土地から敵手札へ移動（レムレース用）
func _move_caster_to_enemy_hand(tile_index: int, target_player_id: int):
	"""
	土地上のクリーチャーを削除し、そのカードを敵の手札に追加する
	
	引数:
	  tile_index: クリーチャーがいるタイルのインデックス
	  target_player_id: 移動先のプレイヤーID
	"""
	if not board_system_ref:
		push_error("SpellDraw: board_system_refが未設定")
		return
	
	if not board_system_ref.tile_nodes.has(tile_index):
		push_error("SpellDraw: タイル %d が見つかりません" % tile_index)
		return
	
	var tile = board_system_ref.tile_nodes[tile_index]
	if not tile or tile.creature_data.is_empty():
		push_error("SpellDraw: タイル %d にクリーチャーがいません" % tile_index)
		return
	
	# クリーチャーデータを取得
	var creature_data = tile.creature_data.duplicate(true)
	var creature_name = creature_data.get("name", "?")
	
	# 土地からクリーチャーを削除
	tile.remove_creature()
	
	# 敵の手札に追加
	if card_system_ref:
		card_system_ref.return_card_to_hand(target_player_id, creature_data)
		print("[クリーチャー交換] 『%s』がプレイヤー%dの手札に移動" % [creature_name, target_player_id + 1])

## 上限までドロー（手札補充）
func draw_until(player_id: int, target_hand_size: int) -> Array:
	"""
	手札が指定枚数になるまで引く
	
	例:
	  - 現在手札2枚、target=6 → 4枚引く
	  - 現在手札5枚、target=6 → 1枚引く
	  - 現在手札6枚、target=6 → 0枚引く（引かない）
	  - 現在手札7枚、target=6 → 0枚引く（引かない）
	
	用途:
	  - トゥームストーン（1038）: draw_until(player_id, 6)  # 6枚まで引く
	  - 5枚までドロースペル: draw_until(player_id, 5)
	
	引数:
	  player_id: プレイヤーID（0-3）
	  target_hand_size: 目標手札枚数
	
	戻り値: Array（引いたカードデータの配列）
	"""
	if not card_system_ref:
		push_error("SpellDraw: CardSystemが設定されていません")
		return []
	
	var current_hand_size = card_system_ref.get_hand_size_for_player(player_id)
	var needed = target_hand_size - current_hand_size
	
	if needed <= 0:
		print("[ドロー] プレイヤー", player_id + 1, "は既に", current_hand_size, 
			  "枚持っているため引きません（目標: ", target_hand_size, "枚）")
		return []
	
	var drawn = card_system_ref.draw_cards_for_player(player_id, needed)
	print("[ドロー] プレイヤー", player_id + 1, "が手札", target_hand_size, 
		  "枚まで補充（", drawn.size(), "枚引いた）")
	
	return drawn

## 手札全交換
func exchange_all_hand(player_id: int) -> Array:
	"""
	手札を全て捨てて同じ枚数引き直す
	
	例: 手札4枚 → 4枚捨てて4枚引く
	
	引数:
	  player_id: プレイヤーID（0-3）
	
	戻り値: Array（新しく引いたカードデータの配列）
	"""
	if not card_system_ref:
		push_error("SpellDraw: CardSystemが設定されていません")
		return []
	
	var hand_size = card_system_ref.get_hand_size_for_player(player_id)
	
	if hand_size == 0:
		print("[手札交換] プレイヤー", player_id + 1, "は手札が0枚のため交換しません")
		return []
	
	print("[手札交換] プレイヤー", player_id + 1, "が", hand_size, "枚の手札を交換します")
	
	# 全て捨てる（常にindex 0を捨てる、配列が縮むため）
	for i in range(hand_size):
		card_system_ref.discard_card(player_id, 0, "exchange")
	
	# 同じ枚数引く
	var drawn = card_system_ref.draw_cards_for_player(player_id, hand_size)
	print("[手札交換] プレイヤー", player_id + 1, "が", drawn.size(), "枚の新しい手札を引きました")
	
	return drawn

## 手札全捨て+元枚数ドロー（リンカネーション用）
func discard_and_draw_plus(player_id: int) -> Array:
	"""
	手札を全て捨て、その枚数分のカードを引く
	
	注: -1（使用カード）と+1（ボーナス）が相殺するため、元の手札枚数分引く
	
	引数:
	  player_id: プレイヤーID（0-3）
	
	戻り値: Array（引いたカードデータの配列）
	"""
	if not card_system_ref:
		push_error("SpellDraw: CardSystemが設定されていません")
		return []
	
	var hand_size = card_system_ref.get_hand_size_for_player(player_id)
	
	# 手札を全て捨てる
	for i in range(hand_size):
		card_system_ref.discard_card(player_id, 0, "reincarnation")
	
	# 元の手札枚数分引く
	var drawn = card_system_ref.draw_cards_for_player(player_id, hand_size)
	print("[リンカネーション] プレイヤー", player_id + 1, ": 手札入替 → ", drawn.size(), "枚ドロー")
	
	return drawn

## 順位に応じたドロー（ギフト用）
func draw_by_rank(player_id: int, rank: int) -> Array:
	"""
	順位と同じ枚数のカードを引く
	
	引数:
	  player_id: プレイヤーID（0-3）
	  rank: プレイヤーの順位（1位=1, 2位=2...）
	
	戻り値: Array（引いたカードデータの配列）
	"""
	if not card_system_ref:
		push_error("SpellDraw: CardSystemが設定されていません")
		return []
	
	if rank <= 0:
		return []
	
	var drawn = card_system_ref.draw_cards_for_player(player_id, rank)
	print("[順位ドロー] プレイヤー", player_id + 1, ": ", rank, "位 → ", drawn.size(), "枚ドロー")
	
	return drawn

## 手札のクリーチャー属性を取得
func get_hand_creature_elements(player_id: int) -> Array:
	"""
	手札のクリーチャーカードから属性を収集
	
	引数:
	  player_id: プレイヤーID（0-3）
	
	戻り値: Array（属性文字列の配列、重複なし）
	"""
	var elements = []
	if not card_system_ref:
		return elements
	
	var hand = card_system_ref.get_all_cards_for_player(player_id)
	for card in hand:
		if card.get("type", "") == "creature":
			var elem = card.get("element", "")
			if elem != "" and elem not in elements:
				elements.append(elem)
	
	return elements

## 手札に指定属性が全てあるかチェック
func has_all_elements(player_id: int, required_elements: Array) -> bool:
	"""
	手札のクリーチャーに指定された全属性が揃っているかチェック
	
	引数:
	  player_id: プレイヤーID（0-3）
	  required_elements: 必要な属性の配列（例: ["fire", "water", "wind", "earth"]）
	
	戻り値: bool
	"""
	var hand_elements = get_hand_creature_elements(player_id)
	
	for elem in required_elements:
		if elem not in hand_elements:
			return false
	
	return true

# ========================================
# 手札破壊系
# ========================================

## 呪いカードのspell_type一覧
const CURSE_SPELL_TYPES = [
	"複数特殊能力付与",
	"世界呪い",
	"単体特殊能力付与"
]

## 呪いカードかどうか判定
func is_curse_card(card: Dictionary) -> bool:
	"""
	カードが呪いスペルかどうかを判定
	
	判定基準: spell_typeが呪い系（複数特殊能力付与、世界呪い、単体特殊能力付与）
	
	引数:
	  card: カードデータ
	
	戻り値: bool
	"""
	if card.get("type") != "spell":
		return false
	return card.get("spell_type", "") in CURSE_SPELL_TYPES

## 全プレイヤーの手札から呪いカードを破壊
func destroy_curse_cards() -> Dictionary:
	"""
	全プレイヤーの手札から呪いカードを破壊する（レイオブパージ用）
	
	戻り値: Dictionary
	  - total_destroyed: int（破壊した総枚数）
	  - by_player: Array（プレイヤーごとの破壊枚数）
	"""
	if not card_system_ref:
		push_error("SpellDraw: CardSystemが設定されていません")
		return {"total_destroyed": 0, "by_player": []}
	
	var total_destroyed = 0
	var by_player = []
	
	# 全プレイヤーの手札をチェック
	for player_id in range(4):
		var destroyed_count = 0
		var hand = card_system_ref.get_all_cards_for_player(player_id)
		
		# 逆順でチェック（削除時にインデックスがずれないように）
		for i in range(hand.size() - 1, -1, -1):
			var card = hand[i]
			if is_curse_card(card):
				card_system_ref.discard_card(player_id, i, "destroy")
				print("[呪いカード破壊] プレイヤー%d: %s" % [player_id + 1, card.get("name", "?")])
				destroyed_count += 1
		
		by_player.append(destroyed_count)
		total_destroyed += destroyed_count
	
	print("[レイオブパージ] 合計 %d 枚の呪いカードを破壊" % total_destroyed)
	
	return {
		"total_destroyed": total_destroyed,
		"by_player": by_player
	}

## 全プレイヤーの手札から高コストカードを破壊
func destroy_expensive_cards(cost_threshold: int) -> Dictionary:
	"""
	全プレイヤーの手札から指定コスト以上のカードを破壊する（レイオブロウ用）
	
	引数:
	  cost_threshold: コスト閾値（この値以上のカードを破壊）
	
	戻り値: Dictionary
	  - total_destroyed: int（破壊した総枚数）
	  - by_player: Array（プレイヤーごとの破壊枚数）
	"""
	if not card_system_ref:
		push_error("SpellDraw: CardSystemが設定されていません")
		return {"total_destroyed": 0, "by_player": []}
	
	var total_destroyed = 0
	var by_player = []
	
	# 全プレイヤーの手札をチェック
	for player_id in range(4):
		var destroyed_count = 0
		var hand = card_system_ref.get_all_cards_for_player(player_id)
		
		# 逆順でチェック（削除時にインデックスがずれないように）
		for i in range(hand.size() - 1, -1, -1):
			var card = hand[i]
			# costがintの場合と辞書の場合の両方に対応
			var cost_data = card.get("cost", 0)
			var card_cost = 0
			if cost_data is Dictionary:
				card_cost = cost_data.get("mp", 0)
			else:
				card_cost = cost_data
			
			if card_cost >= cost_threshold:
				card_system_ref.discard_card(player_id, i, "destroy")
				print("[高コストカード破壊] プレイヤー%d: %s (G%d)" % [player_id + 1, card.get("name", "?"), card_cost])
				destroyed_count += 1
		
		by_player.append(destroyed_count)
		total_destroyed += destroyed_count
	
	print("[レイオブロウ] 合計 %d 枚のG%d以上カードを破壊" % [total_destroyed, cost_threshold])
	
	return {
		"total_destroyed": total_destroyed,
		"by_player": by_player
	}

## 対象プレイヤーの手札から重複カードを破壊
func destroy_duplicate_cards(target_player_id: int) -> Dictionary:
	"""
	対象プレイヤーの手札から重複カード（同名カードが2枚以上）を全て破壊する（エロージョン用）
	
	引数:
	  target_player_id: 対象プレイヤーID
	
	戻り値: Dictionary
	  - total_destroyed: int（破壊した総枚数）
	  - duplicates: Array（破壊したカード名のリスト）
	"""
	if not card_system_ref:
		push_error("SpellDraw: CardSystemが設定されていません")
		return {"total_destroyed": 0, "duplicates": []}
	
	var hand = card_system_ref.get_all_cards_for_player(target_player_id)
	
	# カード名ごとの出現回数をカウント
	var name_count = {}
	for card in hand:
		var card_name = card.get("name", "")
		if card_name != "":
			name_count[card_name] = name_count.get(card_name, 0) + 1
	
	# 重複しているカード名を特定
	var duplicate_names = []
	for card_name in name_count.keys():
		if name_count[card_name] >= 2:
			duplicate_names.append(card_name)
	
	if duplicate_names.is_empty():
		print("[エロージョン] プレイヤー%d: 重複カードなし" % [target_player_id + 1])
		return {"total_destroyed": 0, "duplicates": []}
	
	# 逆順で重複カードを破壊
	var destroyed_count = 0
	for i in range(hand.size() - 1, -1, -1):
		var card = hand[i]
		var card_name = card.get("name", "")
		if card_name in duplicate_names:
			card_system_ref.discard_card(target_player_id, i, "destroy")
			print("[重複カード破壊] プレイヤー%d: %s" % [target_player_id + 1, card_name])
			destroyed_count += 1
	
	print("[エロージョン] プレイヤー%d: %d 枚の重複カードを破壊（%s）" % [target_player_id + 1, destroyed_count, str(duplicate_names)])
	
	return {
		"total_destroyed": destroyed_count,
		"duplicates": duplicate_names
	}


## 全プレイヤーの重複カードを破壊（エロージョン合成用）
func destroy_duplicate_cards_all_players() -> Dictionary:
	"""
	全プレイヤーの手札から重複カードを破壊する（エロージョン合成用）
	
	戻り値: Dictionary
	  - total_destroyed: int（破壊した総枚数）
	  - by_player: Array（プレイヤーごとの結果）
	"""
	if not player_system_ref:
		push_error("SpellDraw: PlayerSystemが設定されていません")
		return {"total_destroyed": 0, "by_player": []}
	
	var total_destroyed = 0
	var by_player = []
	
	for player_id in range(player_system_ref.players.size()):
		var result = destroy_duplicate_cards(player_id)
		total_destroyed += result.get("total_destroyed", 0)
		by_player.append({
			"player_id": player_id,
			"destroyed": result.get("total_destroyed", 0),
			"duplicates": result.get("duplicates", [])
		})
	
	print("[エロージョン合成] 全プレイヤーから合計 %d 枚の重複カードを破壊" % total_destroyed)
	
	return {
		"total_destroyed": total_destroyed,
		"by_player": by_player
	}


## 指定インデックスのカードを破壊
func destroy_card_at_index(target_player_id: int, card_index: int) -> Dictionary:
	"""
	対象プレイヤーの手札から指定インデックスのカードを破壊する
	
	引数:
	  target_player_id: 対象プレイヤーID
	  card_index: 破壊するカードのインデックス
	
	戻り値: Dictionary
	  - destroyed: bool（破壊成功したか）
	  - card_name: String（破壊したカード名）
	  - card_data: Dictionary（破壊したカードのデータ）
	"""
	if not card_system_ref:
		push_error("SpellDraw: CardSystemが設定されていません")
		return {"destroyed": false, "card_name": "", "card_data": {}}
	
	var hand = card_system_ref.get_all_cards_for_player(target_player_id)
	
	if card_index < 0 or card_index >= hand.size():
		print("[手札破壊] 無効なインデックス: %d（手札枚数: %d）" % [card_index, hand.size()])
		return {"destroyed": false, "card_name": "", "card_data": {}}
	
	var destroyed_card = hand[card_index]
	var card_name = destroyed_card.get("name", "?")
	
	# カードを破壊
	card_system_ref.discard_card(target_player_id, card_index, "destroy")
	print("[手札破壊] プレイヤー%d: %s を破壊" % [target_player_id + 1, card_name])
	
	return {
		"destroyed": true,
		"card_name": card_name,
		"card_data": destroyed_card
	}

## 対象プレイヤーの手札に条件に合うカードがあるかチェック
func has_cards_matching_filter(target_player_id: int, filter_mode: String) -> bool:
	"""
	対象プレイヤーの手札にフィルター条件に合うカードがあるかチェック
	
	引数:
	  target_player_id: 対象プレイヤーID
	  filter_mode: フィルターモード（"destroy_item_spell", "destroy_any", "destroy_spell"）
	
	戻り値: bool
	"""
	if not card_system_ref:
		return false
	
	var hand = card_system_ref.get_all_cards_for_player(target_player_id)
	
	if hand.is_empty():
		return false
	
	for card in hand:
		var card_type = card.get("type", "")
		match filter_mode:
			"destroy_item_spell":
				if card_type == "item" or card_type == "spell":
					return true
			"destroy_any":
				return true
			"destroy_spell":
				if card_type == "spell":
					return true
			"item":
				if card_type == "item":
					return true
			"creature":
				if card_type == "creature":
					return true
	
	return false

## 対象プレイヤーの手札のアイテム数をカウント
func count_items_in_hand(target_player_id: int) -> int:
	"""
	対象プレイヤーの手札にあるアイテムカードの枚数をカウント
	
	引数:
	  target_player_id: 対象プレイヤーID
	
	戻り値: int（アイテム枚数）
	"""
	if not card_system_ref:
		return 0
	
	var hand = card_system_ref.get_all_cards_for_player(target_player_id)
	var count = 0
	
	for card in hand:
		if card.get("type", "") == "item":
			count += 1
	
	return count

## 指定インデックスのカードを奪取
func steal_card_at_index(from_player_id: int, to_player_id: int, card_index: int) -> Dictionary:
	"""
	対象プレイヤーの手札から指定インデックスのカードを奪う
	
	引数:
	  from_player_id: 奪われるプレイヤーID
	  to_player_id: 奪うプレイヤーID
	  card_index: 奪うカードのインデックス
	
	戻り値: Dictionary
	  - stolen: bool（奪取成功したか）
	  - card_name: String（奪ったカード名）
	  - card_data: Dictionary（奪ったカードのデータ）
	"""
	if not card_system_ref:
		push_error("SpellDraw: CardSystemが設定されていません")
		return {"stolen": false, "card_name": "", "card_data": {}}
	
	var hand = card_system_ref.get_all_cards_for_player(from_player_id)
	
	if card_index < 0 or card_index >= hand.size():
		print("[カード奪取] 無効なインデックス: %d（手札枚数: %d）" % [card_index, hand.size()])
		return {"stolen": false, "card_name": "", "card_data": {}}
	
	var stolen_card = hand[card_index].duplicate(true)
	var card_name = stolen_card.get("name", "?")
	
	# from_player の手札から削除（捨て札ではなく直接削除）
	card_system_ref.player_hands[from_player_id]["data"].remove_at(card_index)
	
	# to_player の手札に追加
	card_system_ref.player_hands[to_player_id]["data"].append(stolen_card)
	
	print("[カード奪取] プレイヤー%d → プレイヤー%d: %s を奪取" % [from_player_id + 1, to_player_id + 1, card_name])
	
	# 手札更新シグナル
	card_system_ref.emit_signal("hand_updated")
	
	return {
		"stolen": true,
		"card_name": card_name,
		"card_data": stolen_card
	}

## デッキ上部のカードを取得（破壊はしない）
func get_top_cards_from_deck(player_id: int, count: int) -> Array:
	"""
	対象プレイヤーのデッキ上部から指定枚数のカードを取得
	
	引数:
	  player_id: 対象プレイヤーID
	  count: 取得枚数
	
	戻り値: Array[Dictionary]（カードデータの配列）
	"""
	if not card_system_ref:
		return []
	
	var deck = card_system_ref.player_decks.get(player_id, [])
	if deck.is_empty():
		return []
	
	var actual_count = min(count, deck.size())
	var result = []
	
	var RateEvaluator = load("res://scripts/cpu_ai/card_rate_evaluator.gd")
	print("[デッキ確認] プレイヤー%d のデッキ上部%d枚:" % [player_id + 1, actual_count])
	for i in range(actual_count):
		# デッキはカードIDの配列なので、CardLoaderからデータを取得
		var card_id = deck[i]
		var card_data = CardLoader.get_card_by_id(card_id)
		if card_data and not card_data.is_empty():
			var data_copy = card_data.duplicate(true)
			result.append(data_copy)
			var rate = RateEvaluator.get_rate(card_data)
			print("  [%d] %s (ID: %d, レート: %d)" % [i, card_data.get("name", "?"), card_id, rate])
	
	return result

## デッキ上部の指定インデックスのカードを破壊
func destroy_deck_card_at_index(player_id: int, card_index: int) -> Dictionary:
	"""
	対象プレイヤーのデッキ上部から指定インデックスのカードを破壊
	
	引数:
	  player_id: 対象プレイヤーID
	  card_index: 破壊するカードのインデックス（デッキ上部からの位置）
	
	戻り値: Dictionary
	  - destroyed: bool（破壊成功したか）
	  - card_name: String（破壊したカード名）
	  - card_data: Dictionary（破壊したカードのデータ）
	"""
	if not card_system_ref:
		push_error("SpellDraw: CardSystemが設定されていません")
		return {"destroyed": false, "card_name": "", "card_data": {}}
	
	var deck = card_system_ref.player_decks.get(player_id, [])
	
	if card_index < 0 or card_index >= deck.size():
		print("[デッキ破壊] 無効なインデックス: %d（デッキ枚数: %d）" % [card_index, deck.size()])
		return {"destroyed": false, "card_name": "", "card_data": {}}
	
	# デッキはカードIDの配列なので、CardLoaderからデータを取得
	var card_id = deck[card_index]
	var destroyed_card = CardLoader.get_card_by_id(card_id)
	var card_name = destroyed_card.get("name", "?") if destroyed_card else "?"
	
	# デッキから削除
	card_system_ref.player_decks[player_id].remove_at(card_index)
	print("[デッキ破壊] プレイヤー%d: インデックス%d の %s をデッキから破壊" % [player_id + 1, card_index, card_name])
	
	# 破壊後のデッキ上部を表示
	var remaining_deck = card_system_ref.player_decks[player_id]
	var show_count = min(3, remaining_deck.size())
	print("[デッキ破壊後] 次にドローされる%d枚:" % show_count)
	for i in range(show_count):
		var next_card_id = remaining_deck[i]
		var next_card = CardLoader.get_card_by_id(next_card_id)
		print("  [%d] %s" % [i, next_card.get("name", "?") if next_card else "?"])
	
	return {
		"destroyed": true,
		"card_name": card_name,
		"card_data": destroyed_card if destroyed_card else {}
	}

## デッキ上部の指定インデックスのカードを手札に加える
func draw_from_deck_at_index(player_id: int, card_index: int) -> Dictionary:
	"""
	対象プレイヤーのデッキ上部から指定インデックスのカードを手札に加える（フォーサイト用）
	
	引数:
	  player_id: 対象プレイヤーID
	  card_index: 引くカードのインデックス（デッキ上部からの位置）
	
	戻り値: Dictionary
	  - drawn: bool（ドロー成功したか）
	  - card_name: String（引いたカード名）
	  - card_data: Dictionary（引いたカードのデータ）
	"""
	if not card_system_ref:
		push_error("SpellDraw: CardSystemが設定されていません")
		return {"drawn": false, "card_name": "", "card_data": {}}
	
	var deck = card_system_ref.player_decks.get(player_id, [])
	
	if card_index < 0 or card_index >= deck.size():
		print("[デッキドロー] 無効なインデックス: %d（デッキ枚数: %d）" % [card_index, deck.size()])
		return {"drawn": false, "card_name": "", "card_data": {}}
	
	# デッキはカードIDの配列なので、CardLoaderからデータを取得
	var card_id = deck[card_index]
	var drawn_card = CardLoader.get_card_by_id(card_id)
	var card_name = drawn_card.get("name", "?") if drawn_card else "?"
	
	# デッキから削除
	card_system_ref.player_decks[player_id].remove_at(card_index)
	
	# 手札に加える
	if drawn_card:
		card_system_ref.return_card_to_hand(player_id, drawn_card.duplicate(true))
		print("[フォーサイト] プレイヤー%d: デッキから『%s』を選んで引きました" % [player_id + 1, card_name])
	
	return {
		"drawn": true,
		"card_name": card_name,
		"card_data": drawn_card if drawn_card else {}
	}

## タイプ選択UIを表示してカードを引く（プロフェシー用）
func execute_draw_by_type_with_ui(player_id: int) -> Dictionary:
	"""
	カードタイプを選択してそのタイプのカードを1枚引く
	
	引数:
	  player_id: プレイヤーID（0-3）
	
	戻り値: Dictionary
	  - drawn: bool（ドロー成功したか）
	  - card_name: String（引いたカード名）
	  - selected_type: String（選択されたタイプ）
	"""
	if not ui_manager_ref:
		push_error("SpellDraw: UIManagerが設定されていません")
		return {"drawn": false, "card_name": "", "selected_type": ""}
	
	# SpellAndMysticUI を取得または作成
	var spell_and_mystic_ui = ui_manager_ref.get_node_or_null("SpellAndMysticUI")
	if not spell_and_mystic_ui:
		var SpellAndMysticUIClass = load("res://scripts/ui_components/spell_and_mystic_ui.gd")
		if not SpellAndMysticUIClass:
			return {"drawn": false, "card_name": "", "selected_type": ""}
		spell_and_mystic_ui = SpellAndMysticUIClass.new()
		spell_and_mystic_ui.name = "SpellAndMysticUI"
		spell_and_mystic_ui.set_ui_manager(ui_manager_ref)
		ui_manager_ref.add_child(spell_and_mystic_ui)
	
	# ガイド表示
	if ui_manager_ref.phase_label:
		ui_manager_ref.phase_label.text = "引くカードのタイプを選択してください"
	
	# タイプ選択UIを表示
	spell_and_mystic_ui.show_type_selection()
	
	# タイプ選択を待機
	var selected_type = await spell_and_mystic_ui.type_selected
	
	# UIを非表示
	spell_and_mystic_ui.hide_all()
	
	# 選択されたタイプのカードを引く
	var result = draw_card_by_type(player_id, selected_type)
	
	if result.get("drawn", false):
		if ui_manager_ref.phase_label:
			ui_manager_ref.phase_label.text = "『%s』を引きました" % result.get("card_name", "?")
	else:
		if ui_manager_ref.phase_label:
			ui_manager_ref.phase_label.text = "デッキに該当タイプがありません"
	
	# 手札表示を更新
	if ui_manager_ref.hand_display:
		ui_manager_ref.hand_display.update_hand_display(player_id)
	
	return {
		"drawn": result.get("drawn", false),
		"card_name": result.get("card_name", ""),
		"selected_type": selected_type
	}

## タイプ選択ドロー開始（callback方式・プロフェシー用）
func _start_type_selection_draw(player_id: int):
	"""
	カードタイプ選択UIを表示してドローを実行（非同期callback方式）
	"""
	if not ui_manager_ref:
		push_error("SpellDraw: UIManagerが設定されていません")
		return
	
	# SpellAndMysticUI を取得または作成
	var spell_and_mystic_ui = ui_manager_ref.get_node_or_null("SpellAndMysticUI")
	if not spell_and_mystic_ui:
		var SpellAndMysticUIClass = load("res://scripts/ui_components/spell_and_mystic_ui.gd")
		if not SpellAndMysticUIClass:
			return
		spell_and_mystic_ui = SpellAndMysticUIClass.new()
		spell_and_mystic_ui.name = "SpellAndMysticUI"
		spell_and_mystic_ui.set_ui_manager(ui_manager_ref)
		ui_manager_ref.add_child(spell_and_mystic_ui)
	
	# ガイド表示
	if ui_manager_ref.phase_label:
		ui_manager_ref.phase_label.text = "引くカードのタイプを選択してください"
	
	# タイプ選択UIを表示
	spell_and_mystic_ui.show_type_selection()
	
	# タイプ選択シグナルを接続
	if spell_and_mystic_ui.is_connected("type_selected", _on_type_selected):
		spell_and_mystic_ui.disconnect("type_selected", _on_type_selected)
	spell_and_mystic_ui.type_selected.connect(_on_type_selected.bind(player_id, spell_and_mystic_ui), CONNECT_ONE_SHOT)

## タイプ選択完了時のコールバック
func _on_type_selected(selected_type: String, player_id: int, spell_ui: Node):
	# UIを非表示
	spell_ui.hide_all()
	
	# 選択されたタイプのカードを引く
	var result = draw_card_by_type(player_id, selected_type)
	
	if result.get("drawn", false):
		if ui_manager_ref and ui_manager_ref.phase_label:
			ui_manager_ref.phase_label.text = "『%s』を引きました" % result.get("card_name", "?")
	else:
		if ui_manager_ref and ui_manager_ref.phase_label:
			ui_manager_ref.phase_label.text = "デッキに該当タイプがありません"
	
	# 手札表示を更新
	if ui_manager_ref and ui_manager_ref.hand_display:
		ui_manager_ref.hand_display.update_hand_display(player_id)

# ========================================
# メタモルフォシス・リバイバル用
# ========================================

## 同名カードを全て特定カードに変換（メタモルフォシス用）
func transform_cards_to_specific(target_player_id: int, selected_card_name: String, selected_card_id: int, transform_to_id: int) -> Dictionary:
	"""
	対象プレイヤーの手札とデッキから指定名のカードを全て別カードに変換する
	
	引数:
	  target_player_id: 対象プレイヤーID
	  selected_card_name: 変換元カード名
	  selected_card_id: 変換元カードID
	  transform_to_id: 変換先カードID（ホーリーワード6 = 2100）
	
	戻り値: Dictionary
	  - transformed_count: int（変換した枚数）
	  - hand_count: int（手札で変換した枚数）
	  - deck_count: int（デッキで変換した枚数）
	  - original_name: String（変換元カード名）
	  - new_name: String（変換先カード名）
	"""
	if not card_system_ref:
		push_error("SpellDraw: CardSystemが設定されていません")
		return {"transformed_count": 0, "hand_count": 0, "deck_count": 0, "original_name": "", "new_name": ""}
	
	# 変換先カードデータを取得
	var new_card_data = CardLoader.get_card_by_id(transform_to_id)
	if new_card_data.is_empty():
		push_error("SpellDraw: 変換先カードID %d が見つかりません" % transform_to_id)
		return {"transformed_count": 0, "hand_count": 0, "deck_count": 0, "original_name": selected_card_name, "new_name": ""}
	
	var new_card_name = new_card_data.get("name", "?")
	var hand_count = 0
	var deck_count = 0
	
	# 手札を走査して同名カードを変換
	var hand = card_system_ref.player_hands[target_player_id]["data"]
	for i in range(hand.size()):
		var card = hand[i]
		if card.get("name", "") == selected_card_name:
			hand[i] = new_card_data.duplicate(true)
			hand_count += 1
			print("[メタモルフォシス] 手札: 『%s』→『%s』に変換" % [selected_card_name, new_card_name])
	
	# デッキを走査して同IDカードを変換
	var deck = card_system_ref.player_decks.get(target_player_id, [])
	for i in range(deck.size()):
		if deck[i] == selected_card_id:
			card_system_ref.player_decks[target_player_id][i] = transform_to_id
			deck_count += 1
			print("[メタモルフォシス] デッキ: 『%s』→『%s』に変換" % [selected_card_name, new_card_name])
	
	var total_count = hand_count + deck_count
	print("[メタモルフォシス] プレイヤー%d: 合計 %d 枚を『%s』に変換（手札: %d, デッキ: %d）" % [target_player_id + 1, total_count, new_card_name, hand_count, deck_count])
	
	# 手札更新シグナル
	card_system_ref.emit_signal("hand_updated")
	
	# UI更新
	if ui_manager_ref and ui_manager_ref.hand_display:
		ui_manager_ref.hand_display.update_hand_display(target_player_id)
	
	return {
		"transformed_count": total_count,
		"hand_count": hand_count,
		"deck_count": deck_count,
		"original_name": selected_card_name,
		"new_name": new_card_name
	}

## デッキを元の構成で再構築（リバイバル用）
func reset_deck_to_original(target_player_id: int) -> Dictionary:
	"""
	対象プレイヤーのデッキを元の構成で再構築する
	手札・捨て札はそのまま、デッキのみ初期化
	
	引数:
	  target_player_id: 対象プレイヤーID
	
	戻り値: Dictionary
	  - success: bool
	  - new_deck_size: int（新デッキ枚数）
	  - player_name: String
	"""
	if not card_system_ref:
		push_error("SpellDraw: CardSystemが設定されていません")
		return {"success": false, "new_deck_size": 0, "player_name": ""}
	
	# プレイヤー名を取得
	var player_name = "プレイヤー%d" % (target_player_id + 1)
	if player_system_ref and target_player_id < player_system_ref.players.size():
		player_name = player_system_ref.players[target_player_id].name
	
	# 元のデッキデータを取得
	var original_deck_data = _get_original_deck_data(target_player_id)
	if original_deck_data.is_empty():
		print("[リバイバル] プレイヤー%d: 元のデッキデータが取得できません" % [target_player_id + 1])
		return {"success": false, "new_deck_size": 0, "player_name": player_name}
	
	# 現在のデッキをクリア
	card_system_ref.player_decks[target_player_id].clear()
	
	# 元のデッキデータから再構築
	for card_id in original_deck_data.keys():
		var count = original_deck_data[card_id]
		for i in range(count):
			card_system_ref.player_decks[target_player_id].append(card_id)
	
	# シャッフル
	card_system_ref.player_decks[target_player_id].shuffle()
	
	var new_deck_size = card_system_ref.player_decks[target_player_id].size()
	print("[リバイバル] %s: デッキを初期化（%d枚）" % [player_name, new_deck_size])
	
	return {
		"success": true,
		"new_deck_size": new_deck_size,
		"player_name": player_name
	}

## 元のデッキデータを取得（プレイヤーIDに応じて）
func _get_original_deck_data(player_id: int) -> Dictionary:
	"""
	プレイヤーIDに応じた元のデッキデータ（カードID: 枚数）を取得
	
	引数:
	  player_id: プレイヤーID
	
	戻り値: Dictionary {card_id: count}
	"""
	# プレイヤー0とプレイヤー1: GameDataから取得
	if player_id == 0 or player_id == 1:
		return GameData.get_current_deck().get("cards", {})
	
	# プレイヤー2以降: デフォルトデッキ（ID 1-12 を各3枚）
	var default_deck = {}
	for card_id in range(1, 13):
		default_deck[card_id] = 3
	return default_deck

## 手札にアイテムまたはスペルがあるかチェック
func has_item_or_spell_in_hand(target_player_id: int) -> bool:
	"""
	対象プレイヤーの手札にアイテムまたはスペルがあるかチェック
	
	引数:
	  target_player_id: 対象プレイヤーID
	
	戻り値: bool
	"""
	if not card_system_ref:
		return false
	
	var hand = card_system_ref.get_all_cards_for_player(target_player_id)
	
	for card in hand:
		var card_type = card.get("type", "")
		if card_type == "item" or card_type == "spell":
			return true
	
	return false


## draw_and_place効果を適用（ワイルドセンス用）
func _apply_draw_and_place(effect: Dictionary, player_id: int) -> Dictionary:
	var draw_count = effect.get("draw_count", 1)
	var placement_mode = effect.get("placement_mode", "random")
	var card_type_filter = effect.get("card_type_filter", "creature")
	var result = {"success": false, "placed": []}
	
	if not card_system_ref:
		print("[draw_and_place] CardSystemがありません")
		return result
	
	# カードを引く
	var drawn_cards = card_system_ref.draw_cards_for_player(player_id, draw_count)
	
	if drawn_cards.is_empty():
		print("[draw_and_place] カードを引けませんでした")
		return result
	
	for card in drawn_cards:
		var card_type = card.get("type", "")
		var card_name = card.get("name", "?")
		var card_id = card.get("id", -1)
		
		print("[draw_and_place] 引いたカード: %s (type: %s)" % [card_name, card_type])
		
		# フィルター条件をチェック（クリーチャーのみ配置）
		if card_type_filter == "creature" and card_type == "creature":
			# 手札からカードを除去（引いたカードは手札の最後に追加される）
			var hand = card_system_ref.get_all_cards_for_player(player_id)
			if hand.size() > 0:
				# 手札の最後から同じIDのカードを探す（複数枚ある可能性があるため）
				var card_index = -1
				for i in range(hand.size() - 1, -1, -1):
					if hand[i].get("id", -1) == card_id:
						card_index = i
						break
				
				if card_index >= 0:
					card_system_ref.use_card_for_player(player_id, card_index)
					print("[draw_and_place] 手札からカードを消費: index=%d" % card_index)
			
			# 配置処理
			if placement_mode == "random" and spell_creature_place_ref and board_system_ref:
				var success = spell_creature_place_ref.place_creature_random(
					board_system_ref, player_id, card_id, CardLoader, true
				)
				if success:
					print("[draw_and_place] %s をランダムな空地に配置しました" % card_name)
					result["placed"].append(card_name)
					result["success"] = true
				else:
					print("[draw_and_place] 配置失敗 - 空地がありません")
		else:
			print("[draw_and_place] %s はクリーチャーではないため手札に残ります" % card_name)
	
	return result


## 手札に合成を持つカードがあるかチェック（フィロソフィー用）
func _has_synthesis_card_in_hand(player_id: int) -> bool:
	"""
	対象プレイヤーの手札に合成効果を持つカードがあるかチェック
	
	合成を持つカード:
	  - クリーチャー: CreatureSynthesis.SYNTHESIS_CREATURE_IDSに含まれる
	  - スペル: SpellSynthesis.SYNTHESIS_SPELL_IDSに含まれる
	
	引数:
	  player_id: プレイヤーID
	
	戻り値: bool
	"""
	if not card_system_ref:
		return false
	
	var hand = card_system_ref.get_all_cards_for_player(player_id)
	var synthesis_creature_ids = CreatureSynthesis.get_synthesis_creature_ids()
	var synthesis_spell_ids = SpellSynthesis.get_synthesis_spell_ids()
	
	for card in hand:
		var card_id = card.get("id", -1)
		var card_type = card.get("type", "")
		
		# クリーチャー合成チェック
		if card_type == "creature" and card_id in synthesis_creature_ids:
			print("[フィロソフィー] 合成カード発見（クリーチャー）: %s" % card.get("name", "?"))
			return true
		
		# スペル合成チェック
		if card_type == "spell" and card_id in synthesis_spell_ids:
			print("[フィロソフィー] 合成カード発見（スペル）: %s" % card.get("name", "?"))
			return true
	
	return false
