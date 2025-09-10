extends Resource

# ゲーム定数管理ファイル
# バランス調整時はこのファイルを編集

# === プレイヤー関連 ===
const INITIAL_MAGIC = 3000        # 初期魔力
const TARGET_MAGIC = 8000         # 勝利条件の魔力
const MAX_PLAYERS = 4             # 最大プレイヤー数

# === ボード関連 ===
const TOTAL_TILES = 20            # マスの総数
const MAX_LEVEL = 5               # 土地の最大レベル
const LEVEL_UP_COST_RATE = 100   # レベルアップコスト（レベル×この値）

# === カード関連 ===
const MAX_HAND_SIZE = 6           # 手札上限
const INITIAL_HAND_SIZE = 5       # 初期手札枚数
const CARD_COST_MULTIPLIER = 10  # カードコスト倍率（コスト×10G）
const CARDS_PER_TYPE = 3          # 各カードの枚数

# === 報酬関連 ===
const START_BONUS = 100           # スタート地点通過ボーナス
const CHECKPOINT_BONUS = 100      # チェックポイントボーナス
const PASS_BONUS = 200            # スタート通過ボーナス

# === 通行料関連 ===
const BASE_TOLL = 100            # 基礎通行料
const CHAIN_BONUS_2 = 1.5        # 2個連鎖倍率
const CHAIN_BONUS_3 = 2.5        # 3個連鎖倍率
const CHAIN_BONUS_4 = 4.0        # 4個以上連鎖倍率（上限）

# === バトル関連 ===
const ELEMENT_ADVANTAGE = 20      # 属性相性ボーナス
const TERRAIN_BONUS_1 = 10       # 地形ボーナス（1個）
const TERRAIN_BONUS_2 = 20       # 地形ボーナス（2個）
const TERRAIN_BONUS_3 = 30       # 地形ボーナス（3個）
const TERRAIN_BONUS_4 = 40       # 地形ボーナス（4個以上）

# === CPU設定 ===
const CPU_SUMMON_RATE = 0.9      # CPU召喚確率
const CPU_INVASION_RATE = 0.8    # CPU侵略確率
const CPU_BATTLE_RATE = 0.7      # CPUバトル確率
const CPU_LEVELUP_RATE = 0.5     # CPUレベルアップ確率

# === アニメーション ===
const MOVE_SPEED = 0.3            # 移動アニメーション速度（秒）
const WARP_DELAY = 0.5            # ワープ演出待機時間（秒）
const TURN_END_DELAY = 1.0        # ターン終了待機時間（秒）

# === 色定義 ===
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

# === 特殊マス色 ===
const SPECIAL_TILE_COLORS = {
	"WARP_GATE": Color(1.0, 0.5, 0.0),    # オレンジ
	"WARP_POINT": Color(0.8, 0.3, 0.8),   # 紫
	"CARD": Color(0.3, 0.8, 0.8),         # シアン
	"NEUTRAL": Color(0.5, 0.5, 0.5),      # グレー
	"START": Color(1.0, 0.9, 0.3),        # 金
	"CHECKPOINT": Color(0.3, 0.8, 0.3)    # 緑
}
