class_name BattleParticipant

# バトル参加者の情報を管理するクラス
# 侵略側・防御側の両方に使用

# クリーチャーデータ
var creature_data: Dictionary

# HP管理（消費順序付き）
var base_hp: int              # クリーチャーの基本HP（最後に消費）
var base_up_hp: int = 0       # 永続的な基礎HP上昇（合成・マスグロース等）
var resonance_bonus_hp: int = 0  # 感応ボーナス（土地ボーナスの後に消費）
var land_bonus_hp: int        # 土地ボーナス（先に消費、戦闘ごとに復活）
var temporary_bonus_hp: int = 0  # 一時的なHPボーナス（効果配列からの合計）
var item_bonus_hp: int = 0    # アイテムボーナス
var spell_bonus_hp: int = 0   # スペルボーナス
var current_hp: int           # 現在のHP

# 攻撃力
var current_ap: int           # 現在のAP（スキル適用後）
var base_up_ap: int = 0       # 永続的な基礎AP上昇（合成・マスグロース等）
var temporary_bonus_ap: int = 0  # 一時的なAPボーナス（効果配列からの合計）

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
var is_using_scroll: bool = false  # 巻物攻撃フラグ（貫通とは別）

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
	
	# 現在HPを計算
	update_current_hp()

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

# 現在HPを更新
func update_current_hp():
	current_hp = base_hp + base_up_hp + temporary_bonus_hp + \
				 resonance_bonus_hp + land_bonus_hp + item_bonus_hp + spell_bonus_hp

# ダメージを受ける（消費順序に従う）
func take_damage(damage: int) -> Dictionary:
	var remaining_damage = damage
	var damage_breakdown = {
		"resonance_bonus_consumed": 0,
		"land_bonus_consumed": 0,
		"temporary_bonus_consumed": 0,
		"item_bonus_consumed": 0,
		"spell_bonus_consumed": 0,
		"base_up_hp_consumed": 0,
		"base_hp_consumed": 0
	}
	
	# 1. 感応ボーナスから消費
	if resonance_bonus_hp > 0 and remaining_damage > 0:
		var consumed = min(resonance_bonus_hp, remaining_damage)
		resonance_bonus_hp -= consumed
		remaining_damage -= consumed
		damage_breakdown["resonance_bonus_consumed"] = consumed
	
	# 2. 土地ボーナスから消費
	if land_bonus_hp > 0 and remaining_damage > 0:
		var consumed = min(land_bonus_hp, remaining_damage)
		land_bonus_hp -= consumed
		remaining_damage -= consumed
		damage_breakdown["land_bonus_consumed"] = consumed
	
	# 3. 一時的なボーナスから消費
	if temporary_bonus_hp > 0 and remaining_damage > 0:
		var consumed = min(temporary_bonus_hp, remaining_damage)
		temporary_bonus_hp -= consumed
		remaining_damage -= consumed
		damage_breakdown["temporary_bonus_consumed"] = consumed
	
	# 4. アイテムボーナスから消費
	if item_bonus_hp > 0 and remaining_damage > 0:
		var consumed = min(item_bonus_hp, remaining_damage)
		item_bonus_hp -= consumed
		remaining_damage -= consumed
		damage_breakdown["item_bonus_consumed"] = consumed
	
	# 5. スペルボーナスから消費
	if spell_bonus_hp > 0 and remaining_damage > 0:
		var consumed = min(spell_bonus_hp, remaining_damage)
		spell_bonus_hp -= consumed
		remaining_damage -= consumed
		damage_breakdown["spell_bonus_consumed"] = consumed
	
	# 6. 永続的な基礎HP上昇から消費
	if base_up_hp > 0 and remaining_damage > 0:
		var consumed = min(base_up_hp, remaining_damage)
		base_up_hp -= consumed
		remaining_damage -= consumed
		damage_breakdown["base_up_hp_consumed"] = consumed
	
	# 7. 基本HPから消費
	if remaining_damage > 0:
		base_hp -= remaining_damage
		damage_breakdown["base_hp_consumed"] = remaining_damage
	
	# 現在HPを更新
	update_current_hp()
	
	return damage_breakdown

# 生存しているか
func is_alive() -> bool:
	return current_hp > 0

# デバッグ用の情報出力
func get_status_string() -> String:
	return "%s (HP:%d/%d, AP:%d)" % [
		creature_data.get("name", "不明"),
		current_hp,
		base_hp + land_bonus_hp + item_bonus_hp + spell_bonus_hp,
		current_ap
	]
