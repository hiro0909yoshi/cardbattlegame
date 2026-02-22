## カードレート評価システム
## カードの価値を数値化して、捨てる/交換/破壊などの判断に使用
## 使用方法: var evaluator = preload("res://scripts/cpu_ai/card_rate_evaluator.gd")
##           var rate = evaluator.get_rate(card)
extends RefCounted

# ===========================================
# クリーチャースキル（キーワード）補正値
# ===========================================

const SKILL_RATE_BONUS = {
	# 無効化系（高価値）
	"無効化": 50,              # アームドパラディン, ガーディアン, ワンダーウォール 等
	"結界": 40,                 # アモン, ギアリオン, グリマルキン 等
	"堅牢": 40,           # アクアデューク, アンフィビアン, オドラデク 等
	"鉄壁": 20,         # グルイースラッグ, ランドアーチン
	"領土守護": 30,   # バロン
	
	# 堅守
	"堅守": -5,               # オールドウィロウ, クリーピングフレイム, グレートフォシル 等
	"再生": 30,                 # エキノダーム, カクタスウォール, スケルトン 等
	"奮闘": 30,                 # アーキビショップ, カワヒメ, キャプテンコック 等
	"反射": 25,                 # デコイ
	"反射[1/2]": 30,            # ナイトエラント
	
	# 攻撃型
	"先制": 30,                 # アンドロギア, アーマードラゴン, エルフアーチャー 等
	"強化": 40,                 # ウルフアント, ケルベロス, デュラハン 等
	"強化術": 10,             # ウィッチ, エアロダッチェス, エンチャントレス 等
	"術攻撃": 10,             # コンジャラー, ラメエル, ワイルドボア
	"即死": 30,                 # アネイマブル, イエティ, キロネックス 等
	"刺突": 25,                 # トロージャンホース, ナイトメア, ピュトン, ファイアービーク
	"2回攻撃": 20,              # テトラーム
	"崩壊": 13,           # ガンジー
	"相討": 15,               # リビングボム
	
	# 特殊能力
	"アルカナアーツ": 40,                 # アイアンモンガー, アクアホーン, アモン 等
	"共鳴": 15,                 # アモン, ヴォジャノーイ, カーバンクル 等
	"加勢": 35,                 # アイアンモンガー, ウィザード, エリニュス 等
	"鼓舞": 40,                 # エルフ, コダマ, コーンフォーク 等
	"合体": 23,                 # アンドロギア, グランギア, スカイギア
	"合成": 15,                 # デッドウォーロード, ナイトエラント
	"形見": 25,                 # クリーピングコイン, コーンフォーク, フェイト, マミー
	"蘇生": 25,             # コールドフェザー, ネクロマンサー, バンシー
	"復活": 23,                 # フェニックス
	"変身": 18,                 # バルダンダース
	"レリック": 20, # リビングアムル, リビングアーマー, リビングクローブ 等
	
	# その他
	"蓄魔": 13,             # クリーピングコイン
	"吸魔": 18,             # アマゾン
	"課税": 10,           # グレートフォシル
	"拘束": 35,               # オールドウィロウ, ケルピー
	"瞬移": 13,             # ドリアード, ブリーズスピリット, ワイバーン
	"強襲": 13,           # パイレーツ
	"アイテム破壊": 40,         # カイザーペンギン, グレムリン, シルバンダッチェス
	"アイテム盗み": 23,         # シーフ
	"伝染": 10,             # エンチャントレス
	"変質": 13,             # スフィンクス
	"攻撃成功時": 35,           # ナイキー, 攻撃成功時に効果発動
	"増殖": 60,                 # マイコロン, バウダーイーター等
	"アイテム使用時ボーナス": 25, # ブルガサリ等
	"敵アイテム反応": 20,       # ブルガサリ等
	
	# マイナス効果
	"後手": -15,                # アウロラ, マカラ
	"周回回復不可": -10,        # スタチュー, レジェンドファロス
}

# ===========================================
# スペル効果補正値
# ===========================================

const SPELL_EFFECT_BONUS = {
	# ダメージ系
	"damage": 81,                        # マジックボルト, サンダークラップ, ストーンブラスト 等
	"destroy_selected_card": 100,         # シャッター, スクイーズ
	"destroy_expensive_cards": 40,       # レイオブロウ
	"destroy_duplicate_cards": 100,       # エロージョン
	"destroy_curse_cards": 60,           # レイオブパージ
	"destroy_from_deck_selection": 91,   # ポイズンマインド
	"destroy_after_battle": 91,          # シニリティ
	
	# 土地系
	"change_element": 51,                # アースシフト, ウォーターシフト, エアーシフト 等
	"change_element_bidirectional": 30,  # ストームシフト, マグマシフト
	"change_element_to_dominant": 40,    # インフルエンス
	"change_level": 110,                  # アステロイド, サドンインパクト
	"conditional_level_change": 40,      # フラットランド
	"find_and_change_highest_level": 80, # サブサイド
	"abandon_land": 80,                  # ランドトランス
	"align_mismatched_lands": 40,        # ホームグラウンド
	
	# EP系
	"drain_magic": 71,                   # ドレインマジック
	"drain_magic_by_lap_diff": 40,       # スピードペナルティ
	"drain_magic_by_land_count": 40,     # ランドドレイン
	"drain_magic_conditional": 40,       # フラクション
	"gain_magic_by_lap": 61,             # マナ
	"gain_magic_by_rank": 81,            # ギフト
	"gain_magic_from_destroyed_count": 60, # インシネレート
	"gain_magic_from_land_chain": 40,    # ロングライン
	"gain_magic_from_spell_cost": 40,    # クレアボヤンス
	"balance_all_magic": 60,             # レディビジョン
	
	# 刻印系
	"creature_curse": 40,                # イモビライズ, エアリアル, マジックシェルター
	"player_curse": 50,                  # クワイエチュード, ブレス, トゥルース
	"world_curse": 70,                   # ライズオブサン, ボンドオブラバーズ, インペリアルガード 等
	"land_curse": 60,                    # ブラストトラップ
	"bounty_curse": 40,                  # バウンティハント
	"command_growth_curse": 50,          # ドミナントグロース
	"curse_movement_reverse": 60,        # カオスパニック
	"life_force_curse": 60,              # エンジェルギフト
	"plague_curse": 50,                  # プレイグ
	"random_stat_curse": 50,             # リキッドフォーム
	"apply_curse": 50,                   # グラナイト
	
	# ドロー系
	"draw": 50,                          # グリード, ディジーズ, デビリティ 等
	"draw_cards": 50,                    # ホープ
	"draw_by_type": 40,                  # プロフェシー
	"draw_by_rank": 40,                  # ギフト
	"draw_from_deck_selection": 40,      # フォーサイト
	"draw_and_place": 40,                # ワイルドセンス
	"discard_and_draw_plus": 80,         # リンカネーション
	"reset_deck": 50,                    # リバイバル
	
	# 移動系
	"warp_to_target": 70,                # マジカルリープ
	"warp_to_nearest_vacant": 70,        # エスケープ
	"warp_to_nearest_gate": 70,          # フォームポータル
	"move_to_adjacent_enemy": 60,        # アウトレイジ
	"move_steps": 60,                    # チャリオット
	"dice_fixed": 110,                    # ホーリーワード1, ホーリーワード3, ホーリーワード6, ホーリーワード8
	"dice_range": 40,                    # ヘイスト
	"dice_range_magic": 40,              # ジャーニー
	"dice_multi": 40,                    # フライ
	"forced_stop": 90,                   # クイックサンド
	"gate_pass": 90,                     # リミッション
	
	# 回復・補助系
	"full_heal": 40,                     # ライフストリーム, リストア
	"permanent_hp_change": 40,           # グロースボディ, ファットボディ, マスグロース
	"permanent_ap_change": 40,           # ファットボディ
	"stat_boost": 40,                    # バイタリティ
	"stat_reduce": 40,                   # ディジーズ
	"purify_all": 40,                    # ピュアリファイ
	"clear_down": 50,                    # リストア
	"down_clear": 60,                    # アラーム
	"indomitable": 40,                   # ライズアップ
	"metal_form": 40,                    # メタルフォーム
	"magic_barrier": 60,                 # エナジーフィールド
	
	# 特殊
	"return_to_hand": 81,                # エグザイル, フィアー, ホーリーバニッシュ
	"swap_board_creatures": 40,          # リリーフ
	"swap_with_hand": 60,                # エクスチェンジ
	"steal_selected_card": 90,           # セフト
	"steal_item_conditional": 90,        # スニークハンド
	"place_creature": 40,                # ゴブリンズレア, スパルトイ
	"transform": 40,                     # ターンウォール
	"transform_to_card": 59,             # メタモルフォシス
	"discord_transform": 40,             # ディスコード
	"grant_mystic_arts": 40,             # ウィザー, ドレインシジル, スプリント
	"use_target_mystic_art": 40,         # テンプテーション
	"check_hand_elements": 40,           # アセンブルカード
	"check_hand_synthesis": 40,          # フィロソフィー
	"secret_tiny_army": 40,              # タイニーアーミー
	
	# 通行料系
	"toll_multiplier": 60,               # グリード
	"toll_fixed": 60,                    # ユニフォーミティ
	"toll_disable": 80,                  # パードン
	"toll_share": 60,                    # ドリームトレイン
	"land_effect_disable": 40,           # ディスエレメント
	
	# 戦闘系
	"battle_disable": 60,                # ディラニー, ディスペア
	"skill_nullify": 72,                 # ボーテックス
	"ap_nullify": 50,                    # デビリティ
	"peace": 70,                         # ピース
}



# ===========================================
# アイテム効果補正値
# ===========================================

const ITEM_EFFECT_BONUS = {
	# スキル付与系
	"grant_skill": 15,                   # シャドウブレイズ, ストームシールド, マジックシールド 等
	"grant_first_strike": 20,            # アージェントキー, イーグルレイピア, サキュバスリング, スリング
	"grant_last_strike": 50,             # ダイヤアーマー
	"grant_double_attack": 50,           # トンファ
	
	# 無効化系
	"nullify_item_manipulation": 50,     # エンジェルケープ, ティアリングハロー, トゥームストーン
	"nullify_all_enemy_abilities": 80,  # ウォーロックディスク
	"nullify_reflect": 50,               # ムラサメ
	
	# 攻撃系
	"scroll_attack": 25,                 # オーラストライク, シャドウブレイズ, スパークボール 等
	"instant_death": 50,                 # バーニングハート
	"ap_drain": 30,                      # サキュバスリング
	
	# 防御系
	"reflect_damage": 60,                # アングリーマスク, スパイクシールド, ミラーホブロン, メイガスミラー
	"item_return": 20,                   # エターナルメイル, ソウルレイ, ブーメラン
	
	# ステータス変動
	"fixed_stat": 30,                    # ペトリフストーン
	"random_stat_bonus": 50,             # スペクターローブ
	"element_count_bonus": 40,           # ストームハルバード, マグマフレイル
	"owned_land_count_bonus": 60,        # ストームアーマー, マグマアーマー
	"chain_count_ap_bonus": 70,          # チェーンソー
	"hand_count_multiplier": 50,         # フォースアンクレット
	"same_element_as_enemy_count": 40,   # シェイドクロー
	"element_mismatch_bonus": 20,        # プリズムワンド
	
	# 特殊
	"transform": 25,                     # ツインスパイク, ドラゴンオーブ, ネクロプラズマ
	"change_element": 30,                # ニュートラルクローク
	"destroy_item": 60,                  # グレムリンアイ, リアクトアーマー
	"apply_curse": 40,                   # バインドウィップ, ムーンシミター
	"revive": 50,                        # ネクロスカラベ
	"legacy_magic": 35,                  # ゴールドグース
	"draw_cards_on_death": 10,           # トゥームストーン
	"level_up_on_win": 10,               # シルバープロウ
	"magic_on_enemy_survive": 20,        # ゴールドハンマー
	"magic_from_damage": 30,             # ゼラチンアーマー
	"revenge_mhp_damage": 40,            # ナパームアロー
}

# ===========================================
# メイン評価メソッド
# ===========================================

## カードのレートを取得
static func get_rate(card: Dictionary) -> int:
	# JSONに直接指定があればそれを使う
	if card.has("rate"):
		return card["rate"]
	
	# カードタイプで分岐
	var card_type = card.get("type", "")
	match card_type:
		"creature":
			return _calculate_creature_rate(card)
		"spell":
			return _calculate_spell_rate(card)
		"item":
			return _calculate_item_rate(card)
	
	return 50  # デフォルト


## 複数カードをレート順にソート（降順: 高い方が先）
static func sort_by_rate_desc(cards: Array) -> Array:
	var sorted = cards.duplicate()
	sorted.sort_custom(func(a, b): return get_rate(a) > get_rate(b))
	return sorted


## 複数カードをレート順にソート（昇順: 低い方が先）
static func sort_by_rate_asc(cards: Array) -> Array:
	var sorted = cards.duplicate()
	sorted.sort_custom(func(a, b): return get_rate(a) < get_rate(b))
	return sorted


## 最もレートの低いカードを取得
static func get_lowest_rate_card(cards: Array) -> Dictionary:
	if cards.is_empty():
		return {}
	
	var lowest = cards[0]
	var lowest_rate = get_rate(lowest)
	
	for card in cards:
		var rate = get_rate(card)
		if rate < lowest_rate:
			lowest_rate = rate
			lowest = card
	
	return lowest


## 最もレートの高いカードを取得
static func get_highest_rate_card(cards: Array) -> Dictionary:
	if cards.is_empty():
		return {}
	
	var highest = cards[0]
	var highest_rate = get_rate(highest)
	
	for card in cards:
		var rate = get_rate(card)
		if rate > highest_rate:
			highest_rate = rate
			highest = card
	
	return highest


# ===========================================
# タイプ別計算
# ===========================================

## クリーチャーのレート計算
static func _calculate_creature_rate(card: Dictionary) -> int:
	var st = card.get("st", card.get("ap", 0))
	var hp = card.get("hp", 0)
	var cost = card.get("cost", 0)
	if cost is Dictionary:
		cost = cost.get("ep", 0)
	
	# ベース: (ST + HP) // 2
	var base = (st + hp) / 2
	
	# スキル補正
	var skill_bonus = _calculate_skill_bonus(card)
	
	# コスト補正（コストが高いほど減点）
	var cost_penalty = cost / 5
	
	return base + skill_bonus - cost_penalty


## スペルのレート計算
static func _calculate_spell_rate(card: Dictionary) -> int:
	# effect_parsedから効果タイプを取得
	var effect_parsed = card.get("effect_parsed", {})
	var effects = effect_parsed.get("effects", [])
	
	# 効果タイプ補正（複数効果の場合は合算）
	var effect_bonus = 0
	for effect in effects:
		var effect_type = effect.get("effect_type", "")
		effect_bonus += SPELL_EFFECT_BONUS.get(effect_type, 20)
	
	# 効果がない場合のデフォルト
	if effect_bonus == 0:
		effect_bonus = 30
	
	return effect_bonus


## アイテムのレート計算
static func _calculate_item_rate(card: Dictionary) -> int:
	# アイテムは基礎値+30（交換対象にならないため優先度を上げる）
	var base = 30
	
	# effect_parsedからステータスボーナスを取得
	var effect_parsed = card.get("effect_parsed", {})
	var stat_bonus = effect_parsed.get("stat_bonus", {})
	var ap_mod = stat_bonus.get("ap", 0)
	var hp_mod = stat_bonus.get("hp", 0)
	
	# ステータス修正値を加算
	base += ap_mod + hp_mod
	
	# 効果補正
	var effects = effect_parsed.get("effects", [])
	var effect_bonus = 0
	for effect in effects:
		var effect_type = effect.get("effect_type", "")
		effect_bonus += ITEM_EFFECT_BONUS.get(effect_type, 20)
		
		# grant_skillで付与するスキルの補正を追加
		if effect_type == "grant_skill":
			var skill_name = effect.get("skill", "")
			if SKILL_RATE_BONUS.has(skill_name):
				effect_bonus += SKILL_RATE_BONUS[skill_name]
	
	# キーワード補正（アイテムのkeywords）
	var keywords = effect_parsed.get("keywords", [])
	var keyword_bonus = 0
	for keyword in keywords:
		if SKILL_RATE_BONUS.has(keyword):
			keyword_bonus += SKILL_RATE_BONUS[keyword]
	
	return base + effect_bonus + keyword_bonus


## スキル補正値を計算（クリーチャー用）
static func _calculate_skill_bonus(card: Dictionary) -> int:
	var bonus = 0
	
	# ability_parsedからキーワードを取得
	var ability_parsed = card.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	var keyword_conditions = ability_parsed.get("keyword_conditions", {})
	
	for keyword in keywords:
		if SKILL_RATE_BONUS.has(keyword):
			var keyword_bonus = SKILL_RATE_BONUS[keyword]
			# 無効化[術攻撃]は価値が低い
			if keyword == "無効化":
				var nullify_cond = keyword_conditions.get("無効化", {})
				if nullify_cond is Dictionary and nullify_cond.get("nullify_type", "") == "scroll_attack":
					keyword_bonus = 20  # 術攻撃無効化は低めに設定
			bonus += keyword_bonus
	
	# mystic_artsを持っている場合、アルカナアーツボーナスを追加（keywordsにアルカナアーツがない場合のみ）
	# トップレベルのmystic_artsまたはability_parsed.mystic_artsをチェック
	var has_mystic_arts = false
	if card.has("mystic_arts") and card.get("mystic_arts") != null:
		has_mystic_arts = true
	elif ability_parsed.has("mystic_arts") and not ability_parsed.get("mystic_arts", []).is_empty():
		has_mystic_arts = true
	
	if has_mystic_arts and "アルカナアーツ" not in keywords:
		bonus += SKILL_RATE_BONUS.get("アルカナアーツ", 0)
	
	# cannot_use（使用不可アイテム）のペナルティ
	var restrictions = card.get("restrictions", {})
	var cannot_use = restrictions.get("cannot_use", [])
	for item_type in cannot_use:
		if item_type == "防具":
			bonus -= 15
		elif item_type == "アクセサリ":
			bonus -= 10
	
	# effectsのトリガーをチェック（攻撃成功時など）
	var effects = ability_parsed.get("effects", [])
	for effect in effects:
		var trigger = effect.get("trigger", "")
		var effect_type = effect.get("effect_type", "")
		var condition = effect.get("condition", "")
		if trigger == "on_attack_success":
			bonus += SKILL_RATE_BONUS.get("攻撃成功時", 0)
		# 増殖効果
		if effect_type == "spawn_copy_on_defend_survive" or effect_type == "split_on_move":
			bonus += SKILL_RATE_BONUS.get("増殖", 0)
		# アイテム使用時ボーナス
		if effect_type == "on_item_use_bonus":
			bonus += SKILL_RATE_BONUS.get("アイテム使用時ボーナス", 0)
		# 敵アイテム反応（conditionが文字列の場合のみチェック）
		if typeof(condition) == TYPE_STRING and condition == "enemy_item_used":
			bonus += SKILL_RATE_BONUS.get("敵アイテム反応", 0)
	
	return bonus
