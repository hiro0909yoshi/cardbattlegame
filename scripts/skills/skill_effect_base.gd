extends Node
class_name SkillEffectBase

# スキル効果の基底クラス
'''スキル効果の基底クラス
全効果タイプ、対象タイプ、条件タイプをenumで定義
条件チェックや計算式評価の基本機能
強打を含む全キーワード能力の定義'''


# 全ての効果タイプの共通インターフェースを定義

# 効果タイプ定義
enum EffectType {
	# ステータス変更系
	MODIFY_STATS,      # AP/HPを変更
	SET_STATS,         # AP/HPを特定値に設定  
	SWAP_STATS,        # AP/HPを入れ替え
	
	# キーワード能力系
	ADD_KEYWORD,       # キーワード能力を付与
	REMOVE_KEYWORD,    # キーワード能力を除去
	
	# 戦闘系
	DAMAGE,            # ダメージを与える
	HEAL,              # 回復する
	DESTROY,           # 破壊する
	
	# 特殊系
	CARD_SYNTHESIS,    # カード合成
	FORCED_MOVE,       # 強制移動
	MARK_DISTRIBUTION, # マーク配布
	DOWN_STATUS,       # ダウン状態付与
	COMMAND_UNLOCK,    # コマンド解放
	
	# 土地系
	CHANGE_ELEMENT,    # 土地属性を変更
	LEVEL_UP,          # 土地レベルアップ
	CAPTURE_LAND,      # 土地を奪取
	
	# 移動制御系
	MOVEMENT_LOCK,     # 移動不可
	REVERSE_DIRECTION, # 歩行逆転
	FORCED_STOP,       # 強制停止
	DICE_MANIPULATION, # ダイス操作
	
	# 制限・条件系
	REMOVE_RESTRICTIONS, # 配置条件無視/制限解除
	STRATEGY_LIMIT,      # 下位戦略不可
	TOLL_MULTIPLY,       # 通行料倍率変更
	
	# 世界効果系
	WORLD_SPELL         # 世界呪（全体永続効果）
}

# 対象タイプ定義
enum TargetType {
	# 単体
	SELF,              # 自身
	ENEMY,             # 敵単体
	ALLY,              # 味方単体
	CREATURE,          # 任意のクリーチャー
	LAND,              # 任意の土地
	
	# 複数
	ALL_ENEMIES,       # 敵全体
	ALL_ALLIES,        # 味方全体
	ALL_CREATURES,     # 全クリーチャー
	ALL_LANDS,         # 全土地
	ADJACENT           # 隣接
}

# 条件タイプ定義
enum ConditionType {
	# 位置条件
	ON_ELEMENT_LAND,     # 特定属性の土地にいる
	ADJACENT_TO,         # 隣接している
	
	# 所持条件
	HAS_ITEM_TYPE,       # アイテム装備中
	HAS_KEYWORD,         # キーワード能力を持つ
	TOTAL_LAND_COUNT,    # 総土地数
	LAND_LEVEL_CHECK,    # 土地レベル条件
	ELEMENT_LAND_COUNT,  # 属性土地数
	CONSECUTIVE_LANDS,   # 連続領地条件
	
	# 状態条件
	HP_BELOW,            # HP以下
	HP_ABOVE,            # HP以上
	MHP_BELOW,           # MHP以下
	MHP_ABOVE,           # MHP以上
	IS_ATTACKING,        # 攻撃時
	IS_DEFENDING,        # 防御時
	HAS_MARK,            # 特定マーク付与時
	
	# タイミング条件
	ON_SUMMON,           # 召喚時
	ON_DESTROY,          # 破壊時
	ON_BATTLE_WIN,       # 戦闘勝利時
	TURN_START,          # ターン開始時
	TURN_DURATION,       # Xターン間
	
	# レベル・順位条件
	LAND_LEVEL_LIMIT,    # 土地レベル制限
	PLAYER_RANK          # プレイヤー順位条件
}

# キーワード能力定義
enum Keywords {
	# 戦闘能力
	FIRST_STRIKE,        # 先制
	POWER_STRIKE,        # 強打
	PENETRATE,           # 貫通
	REGENERATE,          # 再生
	DOUBLE_ATTACK,       # 2回攻撃
	
	# 防御能力
	NULLIFY,             # 無効化
	SUPPORT,             # 援護
	REFLECT,             # 反射
	REFLECT_SCROLL,      # 反射[巻物]
	DEFENDER,            # 防御型
	
	# 特殊能力
	RETURN_TO,           # 復帰[ブック/手札]
	TRANSFORM,           # 変身
	REVIVE_DEAD,         # 死者復活
	MUTUAL_DESTRUCTION,  # 道連れ
	DRAW,                # ドロー
	ADDITIONAL_DAMAGE,   # 追加ダメージ
	REVIVE,              # 復活
	SYNTHESIS,           # 合成
	AFFINITY,            # 感応
	SECRET,              # 密命
	INSTANT_DEATH,       # 即死
	
	# 移動能力
	FLYING,              # 飛行
	TELEPORT            # 瞬間移動
}

# 効果データ
@export var effect_type: EffectType
@export var target: TargetType
@export var conditions: Array = []  # 条件配列
@export var value: int = 0          # 固定値
@export var formula: String = ""    # 計算式
@export var keyword: Keywords       # キーワード（ADD/REMOVE_KEYWORD用）
@export var element: String = ""    # 属性（土地系用）
@export var duration: int = -1       # 持続時間（-1は永続）

# 条件評価
func check_conditions(context: Dictionary) -> bool:
	if conditions.is_empty():
		return true
		
	for condition in conditions:
		if not _check_single_condition(condition, context):
			return false
	return true

# 単一条件チェック（派生クラスでオーバーライド可能）
func _check_single_condition(condition: Dictionary, context: Dictionary) -> bool:
	var cond_type = condition.get("condition_type", "")
	var cond_value = condition.get("value", 0)
	
	match cond_type:
		"mhp_below":
			return context.get("mhp", 100) <= cond_value
		"mhp_above":
			return context.get("mhp", 0) >= cond_value
		"hp_below":
			return context.get("hp", 100) <= cond_value
		"hp_above":
			return context.get("hp", 0) >= cond_value
		"on_element_land":
			var land_element = condition.get("element", "")
			return context.get("land_element", "") == land_element
		"has_item_type":
			var item_type = condition.get("item_type", "")
			var items = context.get("equipped_items", [])
			for item in items:
				if item.get("item_type", "") == item_type:
					return true
			return false
		"is_attacking":
			return context.get("is_attacker", false)
		"is_defending":
			return not context.get("is_attacker", true)
		"element_land_count":
			var cond_element = condition.get("element", "")
			var count = condition.get("count", 0)
			var player_lands = context.get("player_lands", {})
			return player_lands.get(cond_element, 0) >= count
		_:
			# 未実装の条件はtrueとして扱う（後で実装）
			push_warning("未実装の条件タイプ: " + cond_type)
			return true

# 値の計算（固定値またはformula）
func calculate_value(context: Dictionary) -> int:
	if formula.is_empty():
		return value
	return _evaluate_formula(formula, context)

# 計算式評価
func _evaluate_formula(formula_str: String, context: Dictionary) -> int:
	var expr = Expression.new()
	
	# 変数名を定義
	var variable_names = [
		"fire_lands", "water_lands", "earth_lands", "wind_lands",
		"total_lands", "tile_level", 
		"hand_count", "creatures_in_play",
		"damage_dealt", "damage_taken"
	]
	
	# 変数値を取得
	var variable_values = []
	for var_name in variable_names:
		variable_values.append(context.get(var_name, 0))
	
	# 式をパース
	var error = expr.parse(formula_str, variable_names)
	if error != OK:
		push_error("計算式パースエラー: " + formula_str)
		return 0
		
	# 実行
	var result = expr.execute(variable_values, null, true)
	if expr.has_execute_failed():
		push_error("計算式実行エラー: " + formula_str)
		return 0
		
	return int(result)

# 効果を適用（派生クラスで実装）
func apply_effect(_target_node, _context: Dictionary) -> void:
	push_error("apply_effect()は派生クラスで実装してください")
	pass

# デバッグ用文字列
func _to_string() -> String:
	var result = "SkillEffect[type=%s, target=%s" % [
		EffectType.keys()[effect_type],
		TargetType.keys()[target]
	]
	if not conditions.is_empty():
		result += ", conditions=%d" % conditions.size()
	if value != 0:
		result += ", value=%d" % value
	if not formula.is_empty():
		result += ", formula=%s" % formula
	result += "]"
	return result
