extends Resource
class_name GameConstants

# ゲーム定数管理ファイル
# バランス調整時はこのファイルを編集
# プリセット定義はJSONから参照される

# =============================================================================
# 固定値（全マップ・全ルール共通、変更不可）
# =============================================================================

# === プレイヤー関連 ===
const MAX_PLAYERS = 4             # 最大プレイヤー数

# === ボード関連 ===
const MAX_LEVEL = 5               # 土地の最大レベル

# 各レベルの累積価値（レベルアップコスト計算用）
const LEVEL_VALUES = {
	1: 0,
	2: 80,
	3: 260,   
	4: 620,   
	5: 1200   
}

# === カード関連 ===
const MAX_HAND_SIZE = 6           # 手札上限
const INITIAL_HAND_SIZE = 5       # 初期手札枚数
const CARD_COST_MULTIPLIER = 1    # カードコスト倍率（コスト×10EP）
const CARDS_PER_TYPE = 3          # 各カードの枚数

# === 土地価値関連 ===
const BASE_LAND_VALUE = 120       # 基礎土地価値

# 土地価値用レベル倍率
const LAND_VALUE_LEVEL_MULTIPLIER = {
	1: 1,
	2: 2,
	3: 4,
	4: 8,
	5: 16
}

# 土地価値用連鎖倍率
const LAND_VALUE_CHAIN_MULTIPLIER = {
	1: 1.0,
	2: 1.5,
	3: 1.8,
	4: 2.0,
	5: 2.2   # 5個以上
}

# 土地価値用属性係数
const LAND_VALUE_ELEMENT_MULTIPLIER = {
	"fire": 1.0,
	"water": 1.0,
	"wind": 1.0,
	"earth": 1.0,
	"neutral": 0.8
}

# === 通行料関連 ===
# 通行料用レベル倍率（土地価値に対する倍率）
const TOLL_LEVEL_MULTIPLIER = {
	1: 0.2,
	2: 0.3,
	3: 0.4,
	4: 0.6,
	5: 0.8
}

# === バトル関連 ===
const ELEMENT_ADVANTAGE = 20      # 属性相性ボーナス
const TERRAIN_BONUS_1 = 10        # 地形ボーナス（1個）
const TERRAIN_BONUS_2 = 20        # 地形ボーナス（2個）
const TERRAIN_BONUS_3 = 30        # 地形ボーナス（3個）
const TERRAIN_BONUS_4 = 40        # 地形ボーナス（4個以上）

# === CPU設定 ===
const CPU_SUMMON_RATE = 0.9       # CPU召喚確率
const CPU_INVASION_RATE = 0.8     # CPU侵略確率
const CPU_BATTLE_RATE = 0.7       # CPUバトル確率
const CPU_LEVELUP_RATE = 0.5      # CPUレベルアップ確率

# === カメラ関連 ===
const CAMERA_OFFSET = Vector3(11, 12, 11)  # カメラオフセット位置
const CAMERA_LOOK_OFFSET_Y = -8.0  # look_at対象のY補正（負でプレイヤーが画面上に移動）

# === アニメーション ===
const MOVE_SPEED = 0.3            # 移動アニメーション速度（秒）
const WARP_DELAY = 0.5            # ワープ演出待機時間（秒）
const TURN_END_DELAY = 0.3        # ターン終了待機時間（秒）

# === 周回ボーナス係数（固定） ===
const LAP_BONUS_CREATURE_RATE = 0.4   # 配置クリーチャー1体あたり40%
const LAP_BONUS_LAP_RATE = 0.4        # 1周あたり追加40%

# =============================================================================
# プリセット定義（JSONから名前で参照）
# =============================================================================

# === ルールプリセット ===
# 初期EPと勝利条件のセット
const RULE_PRESETS = {
	"standard": {
		"initial_magic": 1000,
		"win_conditions": {
			"mode": "all",
			"conditions": [
				{"type": "magic", "target": 8000, "timing": "checkpoint"}
			]
		}
	},
	"quick": {
		"initial_magic": 2000,
		"win_conditions": {
			"mode": "all",
			"conditions": [
				{"type": "magic", "target": 4000, "timing": "checkpoint"}
			]
		}
	},
	"elimination": {
		"initial_magic": 1000,
		"win_conditions": {
			"mode": "any",
			"conditions": [
				{"type": "bankrupt_enemy", "timing": "immediate"}
			]
		}
	},
	"territory": {
		"initial_magic": 1000,
		"win_conditions": {
			"mode": "all",
			"conditions": [
				{"type": "territories", "target": 10, "timing": "checkpoint"}
			]
		}
	}
}

# === 周回ボーナスプリセット ===
# 周回完了時とチェックポイント通過時のボーナス
const LAP_BONUS_PRESETS = {
	"low": {
		"lap_bonus": 80,
		"checkpoint_bonus": 50
	},
	"standard": {
		"lap_bonus": 150,
		"checkpoint_bonus": 150
	},
	"high": {
		"lap_bonus": 200,
		"checkpoint_bonus": 150
	},
	"very_high": {
		"lap_bonus": 300,
		"checkpoint_bonus": 200
	}
}

# === チェックポイントプリセット ===
# 周回完了に必要なチェックポイント
const CHECKPOINT_PRESETS = {
	"standard": ["N", "S"],
	"three_way": ["N", "S", "W"],
	"three_way_alt": ["N", "E", "W"],
	"four_way": ["N", "S", "W", "E"]
}

# =============================================================================
# デフォルト値（JSONで指定がない場合のフォールバック）
# =============================================================================

const DEFAULT_INITIAL_MAGIC = 1000
const DEFAULT_TARGET_MAGIC = 8000
const DEFAULT_LAP_BONUS_PRESET = "standard"
const DEFAULT_CHECKPOINT_PRESET = "standard"
const DEFAULT_RULE_PRESET = "standard"

# ランクボーナスプリセット
const RANK_BONUS_PRESETS = {
	"default": {
		"SS": 500,
		"S": 200,
		"A": 100,
		"B": 50,
		"C": 0
	}
}

const DEFAULT_RANK_BONUS_PRESET = "default"

# プリセット名からランクボーナステーブルを取得
static func get_rank_bonus_table(preset_name: String) -> Dictionary:
	if RANK_BONUS_PRESETS.has(preset_name):
		return RANK_BONUS_PRESETS[preset_name]
	return RANK_BONUS_PRESETS[DEFAULT_RANK_BONUS_PRESET]

# =============================================================================
# ユーティリティ関数
# =============================================================================

# 1の位で切り捨て（通行料・土地価値用）
static func floor_toll(amount: float) -> int:
	return int(floor(amount))

# ルールプリセットから初期EPを取得
static func get_initial_magic(preset_name: String) -> int:
	if RULE_PRESETS.has(preset_name):
		return RULE_PRESETS[preset_name].get("initial_magic", DEFAULT_INITIAL_MAGIC)
	return DEFAULT_INITIAL_MAGIC

# ルールプリセットから勝利条件を取得
static func get_win_conditions(preset_name: String) -> Dictionary:
	if RULE_PRESETS.has(preset_name):
		return RULE_PRESETS[preset_name].get("win_conditions", {})
	return RULE_PRESETS["standard"].get("win_conditions", {})

# 周回ボーナスプリセットから値を取得
static func get_lap_bonus(preset_name: String) -> int:
	if LAP_BONUS_PRESETS.has(preset_name):
		return LAP_BONUS_PRESETS[preset_name].get("lap_bonus", 120)
	return LAP_BONUS_PRESETS["standard"].get("lap_bonus", 120)

# チェックポイントボーナスプリセットから値を取得
static func get_checkpoint_bonus(preset_name: String) -> int:
	if LAP_BONUS_PRESETS.has(preset_name):
		return LAP_BONUS_PRESETS[preset_name].get("checkpoint_bonus", 100)
	return LAP_BONUS_PRESETS["standard"].get("checkpoint_bonus", 100)

# 必要チェックポイントを取得
static func get_required_checkpoints(preset_name: String) -> Array:
	if CHECKPOINT_PRESETS.has(preset_name):
		return CHECKPOINT_PRESETS[preset_name].duplicate()
	return CHECKPOINT_PRESETS["standard"].duplicate()

# =============================================================================
# 色定義
# =============================================================================

const ELEMENT_COLORS = {
	"火": Color(1.0, 0.4, 0.4),
	"水": Color(0.4, 0.6, 1.0),
	"風": Color(0.4, 1.0, 0.6),
	"土": Color(0.8, 0.6, 0.3)
}

const PLAYER_COLORS = [
	Color(1, 0, 0),      # プレイヤー1: 赤
	Color(0, 0, 1),      # プレイヤー2: 青
	Color(0, 1, 0),      # プレイヤー3: 緑
	Color(1, 1, 0)       # プレイヤー4: 黄
]

const LEVEL_COLORS = [
	Color(0.7, 0.7, 0.7),  # レベル1: 灰色
	Color(0.4, 0.8, 0.4),  # レベル2: 緑
	Color(0.4, 0.6, 1.0),  # レベル3: 青
	Color(0.8, 0.4, 0.8),  # レベル4: 紫
	Color(1.0, 0.8, 0.0)   # レベル5: 金
]

const SPECIAL_TILE_COLORS = {
	"WARP_GATE": Color(1.0, 0.5, 0.0),    # オレンジ
	"WARP_POINT": Color(0.8, 0.3, 0.8),   # 紫
	"CARD": Color(0.3, 0.8, 0.8),         # シアン
	"NEUTRAL": Color(0.5, 0.5, 0.5),      # グレー
	"START": Color(1.0, 0.9, 0.3),        # 金
	"CHECKPOINT": Color(0.3, 0.8, 0.3)    # 緑
}

# =============================================================================
# フォントサイズ定義
# =============================================================================

# 基本サイズ
const FONT_SIZE_XS = 14      # 極小（補足テキスト）
const FONT_SIZE_S = 16       # 小（ラベル）
const FONT_SIZE_M = 28       # 中（説明文）
const FONT_SIZE_L = 36       # 大（ボタン、タイトル）
const FONT_SIZE_XL = 48      # 特大（強調）
const FONT_SIZE_XXL = 64     # 超大（アクション指示）
const FONT_SIZE_XXXL = 96    # 最大（メニュー）
const FONT_SIZE_ICON = 120   # アイコン用（グローバルボタン）

# UI別サイズ
const FONT_SIZE_BUTTON = 36          # 通常ボタン
const FONT_SIZE_BUTTON_LARGE = 48    # 大きいボタン
const FONT_SIZE_MENU_BUTTON = 96     # メニューボタン
const FONT_SIZE_TOAST = 60           # トースト通知
const FONT_SIZE_COMMENT = 60         # コメント表示
const FONT_SIZE_COMMENT_LARGE = 120  # 大きいコメント
const FONT_SIZE_DICE = 64            # ダイス表示
const FONT_SIZE_ACTION_PROMPT = 64   # アクション指示

# =============================================================================
# UI色定義
# =============================================================================

const COLOR_GRAYOUT = Color(0.5, 0.5, 0.5, 1.0)           # グレーアウト
const COLOR_GRAYOUT_MODULATE = Color(0.5, 0.5, 0.5, 1.0)  # グレーアウト（modulate用）
const COLOR_NORMAL_MODULATE = Color(1.0, 1.0, 1.0, 1.0)   # 通常（modulate用）
const COLOR_HIGHLIGHT = Color(1, 1, 0, 0.3)               # ハイライト
const COLOR_RESTRICTION_ICON = Color(1.0, 0.3, 0.3, 1.0)  # 制限アイコン（赤）
const COLOR_WHITE = Color(1.0, 1.0, 1.0, 1.0)             # 白
const COLOR_BLACK = Color(0, 0, 0, 1.0)                   # 黒（アウトライン用）
