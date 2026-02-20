class_name CpuCurseEvaluator
extends RefCounted

## 呪い効果の有利/不利を判定するクラス
## CPU AIが呪いの上書き判断を行うために使用

# =============================================================================
# 定数定義
# =============================================================================

## クリーチャーにとって有利な呪い（所有者視点）
const BENEFICIAL_CREATURE_CURSES: Array[String] = [
	"stat_boost",           # 能力値+20
	"mystic_grant",         # アルカナアーツ付与
	"command_growth",       # コマンド成長
	"forced_stop",          # 強制停止（敵を足止め）
	"indomitable",          # 不屈
	"land_effect_grant",    # 地形効果付与
	"metal_form",           # メタルフォーム
	"magic_barrier",        # マジックバリア
	"toll_multiplier",      # 通行料倍率
	"remote_move",          # 遠隔移動
	"spell_protection",     # 防魔
	"protection_wall",      # 防魔壁
	"hp_effect_immune",     # HP効果無効
	"blast_trap",           # 爆発罠
	"peace",                # 平和（侵略不可＝防御）
]

## クリーチャーにとって不利な呪い（所有者視点）
const HARMFUL_CREATURE_CURSES: Array[String] = [
	"curse_toll_half",      # 通行料半減
	"stat_reduce",          # 能力値-20
	"skill_nullify",        # 戦闘能力不可
	"battle_disable",       # 戦闘行動不可
	"ap_nullify",           # AP=0
	"random_stat",          # 能力値不定
	"plague",               # 衰弱
	"bounty",               # 賞金首
	"destroy_after_battle", # 戦闘後破壊
	"land_effect_disable",  # 地形効果無効
	"move_disable",         # 移動不可
	"creature_toll_disable", # クリーチャー通行料無効
]

## プレイヤーにとって有利な呪い
const BENEFICIAL_PLAYER_CURSES: Array[String] = [
	"dice_fixed",           # ダイス固定
	"dice_range",           # ダイス範囲
	"protection",           # 防魔
	"life_force",           # 生命力
	"toll_share",           # 通行料共有
]

## プレイヤーにとって不利な呪い
const HARMFUL_PLAYER_CURSES: Array[String] = [
	"dice_range_magic",     # 範囲+EP（制限付き）
	"toll_disable",         # 通行料無効
	"toll_fixed",           # 通行料固定
	"spell_disable",        # スペル不可
	"movement_reverse",     # 歩行逆転
]

# =============================================================================
# クリーチャー呪い判定
# =============================================================================

## クリーチャーの呪いが所有者にとって有利かどうか判定
## 戻り値: 1=有利, -1=不利, 0=呪いなし/不明
static func get_creature_curse_benefit(creature: Dictionary) -> int:
	var curse = creature.get("curse", {})
	if curse.is_empty():
		return 0
	
	var curse_type = curse.get("curse_type", "")
	
	if curse_type in BENEFICIAL_CREATURE_CURSES:
		return 1
	elif curse_type in HARMFUL_CREATURE_CURSES:
		return -1
	
	return 0  # 不明な呪いタイプ


## CPUから見てクリーチャーの呪い状態が望ましいかどうか判定
## 戻り値: true=望ましい状態（上書きすべきでない）, false=上書きしてよい
static func is_curse_state_desirable_for_cpu(cpu_id: int, creature_owner_id: int, creature: Dictionary, player_system = null) -> bool:
	var benefit = get_creature_curse_benefit(creature)
	if benefit == 0:
		return false

	var is_own_creature = _is_ally(cpu_id, creature_owner_id, player_system)
	if is_own_creature:
		return benefit > 0
	else:
		return benefit < 0


## 不利な呪いのターゲットとして適切か判定
## 戻り値: true=ターゲットとして適切
static func is_valid_harmful_curse_target(cpu_id: int, creature_owner_id: int, creature: Dictionary, player_system = null) -> bool:
	if _is_ally(cpu_id, creature_owner_id, player_system):
		return false
	var benefit = get_creature_curse_benefit(creature)
	if benefit < 0:
		return false
	return true


## 有利な呪いのターゲットとして適切か判定
## 戻り値: true=ターゲットとして適切
static func is_valid_beneficial_curse_target(cpu_id: int, creature_owner_id: int, creature: Dictionary, player_system = null) -> bool:
	if not _is_ally(cpu_id, creature_owner_id, player_system):
		return false
	var benefit = get_creature_curse_benefit(creature)
	if benefit > 0:
		return false
	return true

# =============================================================================
# プレイヤー呪い判定
# =============================================================================

## プレイヤーの呪いが有利かどうか判定
## 戻り値: 1=有利, -1=不利, 0=呪いなし/不明
static func get_player_curse_benefit(player_curse: Dictionary) -> int:
	if player_curse.is_empty():
		return 0
	
	var curse_type = player_curse.get("curse_type", "")
	
	if curse_type in BENEFICIAL_PLAYER_CURSES:
		return 1
	elif curse_type in HARMFUL_PLAYER_CURSES:
		return -1
	
	return 0


## CPUから見てプレイヤーの呪い状態が望ましいかどうか判定
## cpu_id: CPUのプレイヤーID
## target_player_id: ターゲットプレイヤーID
## player_curse: プレイヤー呪いデータ
## player_system: PlayerSystemオブジェクト（チーム判定用、デフォルト: null）
static func is_player_curse_desirable_for_cpu(cpu_id: int, target_player_id: int, player_curse: Dictionary, player_system = null) -> bool:
	var benefit = get_player_curse_benefit(player_curse)

	if benefit == 0:
		return false

	var is_self = _is_ally(cpu_id, target_player_id, player_system)

	if is_self:
		return benefit > 0  # 自分/同盟に有利な呪い → 望ましい
	else:
		return benefit < 0  # 敵に不利な呪い → 望ましい

# =============================================================================
# 呪い解除スペル用判定
# =============================================================================

## 自クリーチャーに不利な呪いがあるかチェック
## cpu_id: CPUのプレイヤーID
## creatures: クリーチャー情報の配列
## player_system: PlayerSystemオブジェクト（チーム判定用、デフォルト: null）
static func has_harmful_curse_on_own_creatures(cpu_id: int, creatures: Array[Dictionary], player_system = null) -> bool:
	for creature_info in creatures:
		var owner_id = creature_info.get("owner_id", -1)
		var is_own = false

		# チームシステムが利用可能な場合はチーム判定を使用
		if player_system:
			is_own = player_system.is_same_team(cpu_id, owner_id)
		else:
			is_own = (owner_id == cpu_id)

		if not is_own:
			continue

		var creature = creature_info.get("creature", {})
		if get_creature_curse_benefit(creature) < 0:
			return true

	return false


## CPUプレイヤー自身に不利な呪いがあるかチェック
static func has_harmful_curse_on_self(player_curse: Dictionary) -> bool:
	return get_player_curse_benefit(player_curse) < 0


# =============================================================================
# 内部ヘルパー
# =============================================================================

## チーム判定ヘルパー（player_systemがあればis_same_team、なければID一致）
static func _is_ally(cpu_id: int, other_id: int, player_system = null) -> bool:
	if player_system and player_system.has_method("is_same_team"):
		return player_system.is_same_team(cpu_id, other_id)
	return cpu_id == other_id
