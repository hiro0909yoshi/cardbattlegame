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
	"防魔": 40,                 # アモン, ギアリオン, グリマルキン 等
	"HP効果無効": 40,           # アクアデューク, アンフィビアン, オドラデク 等
	"移動侵略無効": 20,         # グルイースラッグ, ランドアーチン
	"土地破壊・変性無効": 30,   # バロン
	
	# 防御型
	"防御型": 15,               # オールドウィロウ, クリーピングフレイム, グレートフォシル 等
	"再生": 15,                 # エキノダーム, カクタスウォール, スケルトン 等
	"不屈": 20,                 # アーキビショップ, カワヒメ, キャプテンコック 等
	"反射": 25,                 # デコイ
	"反射[1/2]": 30,            # ナイトエラント
	
	# 攻撃型
	"先制": 20,                 # アンドロギア, アーマードラゴン, エルフアーチャー 等
	"強打": 40,                 # ウルフアント, ケルベロス, デュラハン 等
	"巻物強打": 10,             # ウィッチ, エアロダッチェス, エンチャントレス 等
	"巻物攻撃": 10,             # コンジャラー, ラメエル, ワイルドボア
	"即死": 30,                 # アネイマブル, イエティ, キロネックス 等
	"貫通": 25,                 # トロージャンホース, ナイトメア, ピュトン, ファイアービーク
	"2回攻撃": 20,              # テトラーム
	"戦闘後破壊": 13,           # ガンジー
	"道連れ": 15,               # リビングボム
	
	# 特殊能力
	"秘術": 40,                 # アイアンモンガー, アクアホーン, アモン 等
	"感応": 15,                 # アモン, ヴォジャノーイ, カーバンクル 等
	"援護": 18,                 # アイアンモンガー, ウィザード, エリニュス 等
	"応援": 13,                 # エルフ, コダマ, コーンフォーク 等
	"合体": 23,                 # アンドロギア, グランギア, スカイギア
	"合成": 15,                 # デッドウォーロード, ナイトエラント
	"遺産": 15,                 # クリーピングコイン, コーンフォーク, フェイト, マミー
	"死者復活": 25,             # コールドフェザー, ネクロマンサー, バンシー
	"復活": 23,                 # フェニックス
	"変身": 18,                 # バルダンダース
	"アイテムクリーチャー": 20, # リビングアムル, リビングアーマー, リビングクローブ 等
	
	# その他
	"魔力獲得": 13,             # クリーピングコイン
	"魔力奪取": 18,             # アマゾン
	"通行料変化": 10,           # グレートフォシル
	"足どめ": 15,               # オールドウィロウ, ケルピー
	"空地移動": 13,             # ドリアード, ブリーズスピリット, ワイバーン
	"敵領地移動": 13,           # パイレーツ
	"アイテム破壊": 20,         # カイザーペンギン, グレムリン, シルバンダッチェス
	"アイテム盗み": 23,         # シーフ
	"呪い拡散": 10,             # エンチャントレス
	"強制変化": 13,             # スフィンクス
	
	# マイナス効果
	"後手": -15,                # アウロラ, マカラ
	"周回回復不可": -10,        # スタチュー, レジェンドファロス
}

# ===========================================
# スペル効果補正値
# ===========================================

const SPELL_EFFECT_BONUS = {
	# ダメージ系
	"damage": 40,                        # マジックボルト, サンダークラップ, ストーンブラスト 等
	"destroy_selected_card": 60,         # シャッター, スクイーズ
	"destroy_expensive_cards": 50,       # レイオブロウ
	"destroy_duplicate_cards": 30,       # エロージョン
	"destroy_curse_cards": 25,           # レイオブパージ
	"destroy_from_deck_selection": 40,   # ポイズンマインド
	"destroy_after_battle": 35,          # シニリティ
	
	# 土地系
	"change_element": 35,                # アースシフト, ウォーターシフト, エアーシフト 等
	"change_element_bidirectional": 40,  # ストームシフト, マグマシフト
	"change_element_to_dominant": 45,    # インフルエンス
	"change_level": 40,                  # アステロイド, サドンインパクト
	"conditional_level_change": 35,      # フラットランド
	"find_and_change_highest_level": 50, # サブサイド
	"abandon_land": 20,                  # ランドトランス
	"align_mismatched_lands": 35,        # ホームグラウンド
	
	# 魔力系
	"drain_magic": 50,                   # ドレインマジック
	"drain_magic_by_lap_diff": 45,       # スピードペナルティ
	"drain_magic_by_land_count": 55,     # ランドドレイン
	"drain_magic_conditional": 45,       # フラクション
	"gain_magic_by_lap": 40,             # マナ
	"gain_magic_by_rank": 45,            # ギフト
	"gain_magic_from_destroyed_count": 40, # インシネレート
	"gain_magic_from_land_chain": 50,    # ロングライン
	"gain_magic_from_spell_cost": 35,    # クレアボヤンス
	"balance_all_magic": 30,             # レディビジョン
	
	# 呪い系
	"creature_curse": 40,                # イモビライズ, スピリットウォーク, マジックシェルター
	"player_curse": 50,                  # クワイエチュード, バリアー, バンフィズム
	"world_curse": 70,                   # ウェイストワールド, ジョイントワールド, ソリッドワールド 等
	"land_curse": 45,                    # ブラストトラップ
	"bounty_curse": 40,                  # バウンティハント
	"command_growth_curse": 35,          # ドミナントグロース
	"curse_movement_reverse": 40,        # カオスパニック
	"life_force_curse": 55,              # ライフフォース
	"plague_curse": 60,                  # プレイグ
	"random_stat_curse": 30,             # リキッドフォーム
	"apply_curse": 40,                   # マスファンタズム
	
	# ドロー系
	"draw": 35,                          # グリード, ディジーズ, デビリティ 等
	"draw_cards": 35,                    # ホープ
	"draw_by_type": 45,                  # プロフェシー
	"draw_by_rank": 40,                  # ギフト
	"draw_from_deck_selection": 50,      # フォーサイト
	"draw_and_place": 55,                # ワイルドセンス
	"discard_and_draw_plus": 30,         # リンカネーション
	"reset_deck": 25,                    # リバイバル
	
	# 移動系
	"warp_to_target": 50,                # マジカルリープ
	"warp_to_nearest_vacant": 40,        # エスケープ
	"warp_to_nearest_gate": 45,          # フォームポータル
	"move_to_adjacent_enemy": 55,        # アウトレイジ
	"move_steps": 35,                    # チャリオット
	"dice_fixed": 60,                    # ホーリーワード1, ホーリーワード3, ホーリーワード6, ホーリーワード8
	"dice_range": 40,                    # ヘイスト
	"dice_range_magic": 45,              # チャージステップ
	"dice_multi": 50,                    # フライ
	"forced_stop": 40,                   # クイックサンド
	"gate_pass": 30,                     # リミッション
	
	# 回復・補助系
	"full_heal": 35,                     # ライフストリーム, リストア
	"permanent_hp_change": 40,           # グロースボディ, ファットボディ, マスグロース
	"permanent_ap_change": 40,           # ファットボディ
	"stat_boost": 35,                    # バイタリティ
	"stat_reduce": 30,                   # ディジーズ
	"purify_all": 40,                    # ピュアリファイ
	"clear_down": 25,                    # リストア
	"down_clear": 25,                    # アラーム
	"indomitable": 35,                   # ハイパーアクティブ
	"metal_form": 45,                    # メタルフォーム
	"magic_barrier": 40,                 # エナジーフィールド
	
	# 特殊
	"return_to_hand": 45,                # エグザイル, フィアー, ホーリーバニッシュ
	"swap_board_creatures": 50,          # リリーフ
	"swap_with_hand": 40,                # エクスチェンジ
	"steal_selected_card": 70,           # セフト
	"steal_item_conditional": 55,        # スニークハンド
	"place_creature": 50,                # ゴブリンズレア, スパルトイ
	"transform": 40,                     # ターンウォール
	"transform_to_card": 45,             # メタモルフォシス
	"discord_transform": 35,             # ディスコード
	"grant_mystic_arts": 50,             # シュリンクシジル, ドレインシジル, フロートシジル
	"use_target_mystic_art": 55,         # テンプテーション
	"check_hand_elements": 30,           # アセンブルカード
	"check_hand_synthesis": 35,          # フィロソフィー
	"secret_tiny_army": 45,              # タイニーアーミー
	
	# 通行料系
	"toll_multiplier": 50,               # グリード
	"toll_fixed": 40,                    # ユニフォーミティ
	"toll_disable": 55,                  # ブラックアウト
	"toll_share": 45,                    # ドリームトレイン
	"land_effect_disable": 40,           # ディスエレメント
	
	# 戦闘系
	"battle_disable": 50,                # ディラニー, バインドミスト
	"skill_nullify": 55,                 # ボーテックス
	"ap_nullify": 45,                    # デビリティ
	"peace": 30,                         # ピース
}

# スペル対象範囲の補正
const SPELL_TARGET_TYPE_BONUS = {
	"own_land": 0,           # アースシフト, ウォーターシフト, エアーシフト 等
	"land": 5,               # アステロイド, インフルエンス, クインテッセンス 等
	"creature": 10,          # アウトレイジ, エクスチェンジ, エグザイル 等
	"player": 20,            # エロージョン, クレアボヤンス, サブサイド 等
	"all_creatures": 30,     # イモビライズ, エレメンタルラス, クラスターバースト 等
	"all_players": 35,       # カオスパニック, クワイエチュード, バンフィズム
	"self": -10,             # アセンブルカード, アラーム, インシネレート 等
	"none": 0,               # エスケープ, スパルトイ, タイニーアーミー 等
	"world": 25,             # ウェイストワールド, ジョイントワールド, ソリッドワールド 等
	"unvisited_gate": 15,    # リミッション
}

# ===========================================
# アイテム効果補正値
# ===========================================

const ITEM_EFFECT_BONUS = {
	# スキル付与系
	"grant_skill": 40,                   # シャドウブレイズ, ストームシールド, マジックシールド 等
	"grant_first_strike": 50,            # アージェントキー, イーグルレイピア, サキュバスリング, スリング
	"grant_last_strike": 30,             # ダイヤアーマー
	"grant_double_attack": 60,           # トンファ
	
	# 無効化系
	"nullify_item_manipulation": 70,     # エンジェルケープ, ティアリングハロー, トゥームストーン
	"nullify_all_enemy_abilities": 100,  # ウォーロックディスク
	"nullify_reflect": 50,               # ムラサメ
	
	# 攻撃系
	"scroll_attack": 45,                 # オーラストライク, シャドウブレイズ, スパークボール 等
	"instant_death": 80,                 # バーニングハート
	"ap_drain": 40,                      # サキュバスリング
	
	# 防御系
	"reflect_damage": 50,                # アングリーマスク, スパイクシールド, ミラーホブロン, メイガスミラー
	"item_return": 35,                   # エターナルメイル, ソウルレイ, ブーメラン
	
	# ステータス変動
	"fixed_stat": 30,                    # ペトリフストーン
	"random_stat_bonus": 25,             # スペクターローブ
	"element_count_bonus": 35,           # ストームハルバード, マグマフレイル
	"owned_land_count_bonus": 40,        # ストームアーマー, マグマアーマー
	"chain_count_ap_bonus": 45,          # チェーンソー
	"hand_count_multiplier": 30,         # フォースアンクレット
	"same_element_as_enemy_count": 35,   # シェイドクロー
	"element_mismatch_bonus": 30,        # プリズムワンド
	
	# 特殊
	"transform": 40,                     # ツインスパイク, ドラゴンオーブ, ネクロプラズマ
	"change_element": 30,                # ニュートラルクローク
	"destroy_item": 45,                  # グレムリンアイ, リアクトアーマー
	"apply_curse": 40,                   # バインドウィップ, ムーンシミター
	"revive": 60,                        # ネクロスカラベ
	"legacy_magic": 35,                  # ゴールドグース
	"draw_cards_on_death": 40,           # トゥームストーン
	"level_up_on_win": 50,               # シルバープロウ
	"magic_on_enemy_survive": 25,        # ゴールドハンマー
	"magic_from_damage": 35,             # ゼラチンアーマー
	"revenge_mhp_damage": 45,            # ナパームアロー
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
		cost = cost.get("mp", 0)
	
	# ベース: (ST + HP) // 2
	var base = (st + hp) / 2
	
	# スキル補正
	var skill_bonus = _calculate_skill_bonus(card)
	
	# コスト補正（コストが高いほど減点）
	var cost_penalty = cost / 5
	
	return base + skill_bonus - cost_penalty


## スペルのレート計算
static func _calculate_spell_rate(card: Dictionary) -> int:
	var cost = card.get("cost", 0)
	if cost is Dictionary:
		cost = cost.get("mp", 0)
	
	# effect_parsedから効果タイプを取得
	var effect_parsed = card.get("effect_parsed", {})
	var effects = effect_parsed.get("effects", [])
	var target_type = effect_parsed.get("target_type", "none")
	
	# 効果タイプ補正（複数効果の場合は合算）
	var effect_bonus = 0
	for effect in effects:
		var effect_type = effect.get("effect_type", "")
		effect_bonus += SPELL_EFFECT_BONUS.get(effect_type, 20)
	
	# 効果がない場合のデフォルト
	if effect_bonus == 0:
		effect_bonus = 30
	
	# 対象範囲補正
	var target_bonus = SPELL_TARGET_TYPE_BONUS.get(target_type, 0)
	
	# コスト補正
	var cost_penalty = cost / 10
	
	return effect_bonus + target_bonus - cost_penalty


## アイテムのレート計算
static func _calculate_item_rate(card: Dictionary) -> int:
	# アイテムは基礎値+50（交換対象にならないため優先度を上げる）
	var base = 50
	
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
	
	for keyword in keywords:
		if SKILL_RATE_BONUS.has(keyword):
			bonus += SKILL_RATE_BONUS[keyword]
	
	return bonus
