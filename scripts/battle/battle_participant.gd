class_name BattleParticipant

# バトル参加者の情報を管理するクラス
# 侵略側・防御側の両方に使用

# スキルモジュール
var _skill_magic_gain = preload("res://scripts/battle/skills/skill_magic_gain.gd")
var _skill_magic_steal = preload("res://scripts/battle/skills/skill_magic_steal.gd")

# クリーチャーデータ
var creature_data: Dictionary

# HP管理（消費順序付き）
var base_hp: int              # クリーチャーの基本HP（最後に消費）
var base_up_hp: int = 0       # 永続的な基礎HP上昇（合成・マスグロース等）
var resonance_bonus_hp: int = 0  # 共鳴ボーナス（土地ボーナスの後に消費）
var land_bonus_hp: int        # 土地ボーナス（先に消費、戦闘ごとに復活）
var temporary_bonus_hp: int = 0  # 一時的なHPボーナス（効果配列からの合計）
var item_bonus_hp: int = 0    # アイテムボーナス
var spell_bonus_hp: int = 0   # スペルボーナス
var current_hp: int           # 現在のHP

# 攻撃力
var current_ap: int           # 現在のAP（スキル適用後）
var base_up_ap: int = 0       # 永続的な基礎AP上昇（合成・マスグロース等）
var temporary_bonus_ap: int = 0  # 一時的なAPボーナス（効果配列からの合計）
var item_bonus_ap: int = 0    # アイテムボーナスAP

# 効果配列の参照（打ち消し効果判定用）
var permanent_effects: Array = []  # 永続効果（移動で消えない）
var temporary_effects: Array = []  # 一時効果（移動で消える）

# スキル・状態
var has_first_strike: bool    # 先制攻撃を持つか
var has_last_strike: bool     # 後手（相手が先攻）
var has_item_first_strike: bool = false  # アイテムによる先制付与
var attack_count: int = 1     # 攻撃回数（2回攻撃なら2）
var is_attacker: bool         # 侵略側かどうか
var player_id: int            # プレイヤーID
var instant_death_flag: bool = false  # 即死されたフラグ
var is_using_scroll: bool = false  # 術攻撃フラグ（刺突とは別）
var was_attacked_by_enemy: bool = false  # 敵から攻撃を受けたフラグ（バイロマンサー用）
var enemy_used_item: bool = false  # 敵がアイテムを使用したフラグ（ブルガサリ用）
var has_ogre_bonus: bool = false  # オーガボーナスが適用されたフラグ（オーガロード用）
var has_squid_mantle: bool = false  # スクイドマントル効果（敵の特殊攻撃無効化）

# システム参照
var spell_magic_ref = null  # SpellMagicの参照（蓄魔系アイテム用）

# 初期化
func _init(
	p_creature_data: Dictionary,
	p_base_hp: int,
	p_land_bonus_hp: int,
	p_ap: int,
	p_is_attacker: bool,
	p_player_id: int
):
	creature_data = p_creature_data
	base_hp = p_base_hp
	land_bonus_hp = p_land_bonus_hp
	current_ap = p_ap
	is_attacker = p_is_attacker
	player_id = p_player_id
	
	# 先制・後手判定
	has_first_strike = _check_first_strike()
	has_last_strike = _check_last_strike()
	
	# current_hp は battle_preparation.gd で直接設定されるため、ここでは初期化しない

# 先制攻撃を持つかチェック
func _check_first_strike() -> bool:
	var keywords = creature_data.get("ability_parsed", {}).get("keywords", [])
	return "先制" in keywords

# 後手を持つかチェック
func _check_last_strike() -> bool:
	var keywords = creature_data.get("ability_parsed", {}).get("keywords", [])
	return "後手" in keywords

# アイテムで先制を付与（後手を上書き）
func apply_item_first_strike():
	has_item_first_strike = true
	has_last_strike = false  # 後手を無効化
	print("【アイテム先制】", creature_data.get("name", "?"), " アイテムにより先制付与（後手無効化）")

# update_current_hp() は削除済み（current_hp が状態値になったため）

# 現在APを更新
func update_current_ap():
	var base_ap = creature_data.get("ap", 0)
	current_ap = base_ap + base_up_ap + temporary_bonus_ap + item_bonus_ap

# base_up_hpを増加し、current_hpも同時に更新
func add_base_up_hp(value: int) -> void:
	base_up_hp += value
	current_hp += value
	# creature_dataにも反映（戦闘後の永続化用）
	creature_data["base_up_hp"] = base_up_hp

# ダメージを受ける（消費順序に従う）
func take_damage(damage: int) -> Dictionary:
	# 敵から攻撃を受けたフラグを設定（バイロマンサー用）
	was_attacked_by_enemy = true
	
	var remaining_damage = damage
	var damage_breakdown = {
		"resonance_bonus_consumed": 0,
		"land_bonus_consumed": 0,
		"temporary_bonus_consumed": 0,
		"item_bonus_consumed": 0,
		"spell_bonus_consumed": 0,
		"base_hp_consumed": 0,
		"current_hp_consumed": 0
	}
	
	# 1. 土地ボーナスから消費（最初に消費）
	if land_bonus_hp > 0 and remaining_damage > 0:
		var consumed = min(land_bonus_hp, remaining_damage)
		land_bonus_hp -= consumed
		remaining_damage -= consumed
		damage_breakdown["land_bonus_consumed"] = consumed
	
	# 2. 共鳴ボーナスから消費
	if resonance_bonus_hp > 0 and remaining_damage > 0:
		var consumed = min(resonance_bonus_hp, remaining_damage)
		resonance_bonus_hp -= consumed
		remaining_damage -= consumed
		damage_breakdown["resonance_bonus_consumed"] = consumed
	
	# 3. 一時的なボーナスから消費
	if temporary_bonus_hp > 0 and remaining_damage > 0:
		var consumed = min(temporary_bonus_hp, remaining_damage)
		temporary_bonus_hp -= consumed
		remaining_damage -= consumed
		damage_breakdown["temporary_bonus_consumed"] = consumed
	
	# 4. スペルボーナスから消費
	if spell_bonus_hp > 0 and remaining_damage > 0:
		var consumed = min(spell_bonus_hp, remaining_damage)
		spell_bonus_hp -= consumed
		remaining_damage -= consumed
		damage_breakdown["spell_bonus_consumed"] = consumed
	
	# 5. アイテムボーナスから消費
	if item_bonus_hp > 0 and remaining_damage > 0:
		var consumed = min(item_bonus_hp, remaining_damage)
		item_bonus_hp -= consumed
		remaining_damage -= consumed
		damage_breakdown["item_bonus_consumed"] = consumed
	
	# 6. current_hp から直接消費（MHP = base_hp + base_up_hp + item_bonus_hp）
	if remaining_damage > 0:
		current_hp -= remaining_damage
		damage_breakdown["current_hp_consumed"] = remaining_damage
	
	# update_current_hp() は呼ばない
	# current_hp が状態値になったため、計算値ではなくなる
	
	# 💰 蓄魔処理（ゼラチンアーマー: 受けたダメージから蓄魔）
	_trigger_magic_from_damage(damage)
	
	return damage_breakdown

# 生存しているか
func is_alive() -> bool:
	return current_hp > 0

# 真のMHP（最大HP）を取得
# MHP = base_hp + base_up_hp（戦闘ボーナスは含まない）
func get_max_hp() -> int:
	return base_hp + base_up_hp

# 戦闘中の有効最大HP（刻印等の一時効果を反映）
# 土地ボーナスは別枠なので含めない
func get_effective_max_hp() -> int:
	return base_hp + base_up_hp + item_bonus_hp + resonance_bonus_hp + \
		   temporary_bonus_hp + spell_bonus_hp

# ダメージを負っているかチェック
# 現在HPが真のMHPより低い場合にtrue
func is_damaged() -> bool:
	return current_hp < get_max_hp()

# 残りHP割合を取得（0.0 ~ 1.0）
func get_hp_ratio() -> float:
	var max_hp = get_max_hp()
	if max_hp == 0:
		return 0.0
	return float(current_hp) / float(max_hp)

# MHP条件チェック（無効化スキル等で使用）
# @param operator: 比較演算子（"<", "<=", ">", ">=", "=="）
# @param threshold: 閾値
func check_mhp_condition(operator: String, threshold: int) -> bool:
	var mhp = get_max_hp()
	
	match operator:
		"<":
			return mhp < threshold
		"<=":
			return mhp <= threshold
		">":
			return mhp > threshold
		">=":
			return mhp >= threshold
		"==":
			return mhp == threshold
		_:
			GameLogger.error("Battle", "未知の演算子 '%s'（BattleParticipant.check_mhp_condition）" % operator)
			return false

# MHP以下かチェック（簡易版）
func is_mhp_below_or_equal(threshold: int) -> bool:
	return check_mhp_condition("<=", threshold)

# MHP以上かチェック（簡易版）
func is_mhp_above_or_equal(threshold: int) -> bool:
	return check_mhp_condition(">=", threshold)

# MHPが特定範囲内かチェック
func is_mhp_in_range(min_threshold: int, max_threshold: int) -> bool:
	var mhp = get_max_hp()
	return mhp >= min_threshold and mhp <= max_threshold

# デバッグ用：MHP情報を文字列で取得
# MHP範囲に直接ダメージ（報復効果用）
# ボーナスを無視してMHP（base_hp + base_up_hp）を直接削る
# MHPが0以下になった場合は即死扱い
func take_mhp_damage(damage: int) -> void:
	print("【MHPダメージ】", creature_data.get("name", "?"), " MHPに-", damage)
	
	# MHPを計算
	var current_mhp = base_hp + base_up_hp
	var new_mhp = current_mhp - damage
	
	# 削られたダメージ分を current_hp から消費
	if damage > 0:
		current_hp -= damage
		print("  current_hp: -", damage, " (残り:", current_hp, ")")
	
	# MHPが0以下になった場合は即死
	if new_mhp <= 0:
		print("  → MHP=", new_mhp, " 即死発動")
		current_hp = 0
		print("  → 現在HP:", current_hp, " / MHP: 0")
	else:
		print("  → 現在HP:", current_hp, " / MHP:", new_mhp)

## 💰 ダメージを受けた時の蓄魔処理（ゼラチンアーマー用）
func _trigger_magic_from_damage(damage: int) -> void:
	"""
	ダメージを受けた直後に蓄魔効果をチェック
	
	Args:
		damage: 受けたダメージ量
	"""
	if not spell_magic_ref:
		return
	
	if damage <= 0:
		return
	
	var items = creature_data.get("items", [])
	for item in items:
		var effect_parsed = item.get("effect_parsed", {})
		var effects = effect_parsed.get("effects", [])
		
		for effect in effects:
			var effect_type = effect.get("effect_type", "")
			
			# magic_from_damage効果をチェック
			if effect_type == "magic_from_damage":
				var multiplier = effect.get("multiplier", 5)
				var amount = damage * multiplier
				
				print("【蓄魔(ダメージ)】", creature_data.get("name", "?"), "の", item.get("name", "?"), 
					  " → プレイヤー", player_id + 1, "が", amount, "蓄魔（ダメージ", damage, "×", multiplier, "）")
				
				spell_magic_ref.add_magic(player_id, amount)
	
	# 💰 クリーチャースキル: ダメージ時蓄魔（ゼラチンウォールなど）
	_skill_magic_gain.apply_damage_magic_gain(self, damage, spell_magic_ref)

## 💰 吸魔効果をチェック（攻撃側が呼ぶ）
func trigger_magic_steal_on_damage(defender, damage: int, spell_magic) -> void:
	"""
	敵にダメージを与えた時に吸魔効果をチェック
	
	Args:
		defender: ダメージを受けた敵
		damage: 与えたダメージ量
		spell_magic: SpellMagicインスタンス
	"""
	if not spell_magic:
		return
	
	if damage <= 0:
		return
	
	# クリーチャースキル: ダメージベース吸魔（バンディットなど）
	_skill_magic_steal.apply_damage_based_steal(self, defender, damage, spell_magic)
