class_name CPUAIConstants
extends RefCounted
## CPU AI 共通定数
##
## 各CPU AIモジュールで使用する評価スコアや優先度の定数を一元管理

# ============================================================
# 優先度値（スペル・秘術評価用）
# ============================================================

const PRIORITY_VALUES = {
	"highest": 4.0,
	"high": 3.0,
	"medium_high": 2.5,
	"medium": 2.0,
	"low": 1.0,
	"very_low": 0.5
}

# ============================================================
# 移動評価スコア（CPUMovementEvaluator用）
# ============================================================

## 敵領地（倒せない）: -通行料 × 係数
const SCORE_STOP_ENEMY_CANT_WIN_MULTIPLIER = -1

## 敵領地（倒せる）: +通行料 × 係数
const SCORE_STOP_ENEMY_CAN_WIN_MULTIPLIER = 2

## 空き地（属性一致・召喚可能）
const SCORE_STOP_EMPTY_ELEMENT_MATCH = 200

## 空き地（属性不一致・召喚可能）
const SCORE_STOP_EMPTY_ELEMENT_MISMATCH = 50

## 空き地（召喚不可）
const SCORE_STOP_EMPTY_NO_SUMMON = 0

## 自分の領地
const SCORE_STOP_OWN_LAND = 0

## 特殊タイル（城、魔法石等）
const SCORE_STOP_SPECIAL_TILE = 50

## チェックポイント停止で1周達成
const SCORE_STOP_CHECKPOINT_LAP = 1500

## 経路上でチェックポイント通過
const SCORE_PATH_CHECKPOINT_PASS = 0

## 経路スコアの除数（1/10にする）
const SCORE_PATH_DIVISOR = 10

## 未訪問ゲート方向ボーナス
const SCORE_DIRECTION_UNVISITED_GATE = 1200

## 最短CP方向ボーナス
const SCORE_CHECKPOINT_DIRECTION_BONUS = 900

## 足止めペナルティ基礎値
const SCORE_FORCED_STOP_PENALTY = -200

## 経路評価の最大距離
const PATH_EVALUATION_DISTANCE = 10

# ============================================================
# 領地コマンド評価スコア（CPUTerritoryAI用）
# ============================================================

## 基準スコア: 空き地に属性一致召喚
const SUMMON_BASE_SCORE = 290

## 基準スコア: 空き地に属性不一致召喚
const SUMMON_MISMATCH_SCORE = 100

## 移動侵略（空き地）: 属性一致ボーナス
const MOVE_ELEMENT_MATCH_BONUS = 150

## 移動侵略（空き地）: 連鎖数係数
const MOVE_CHAIN_MULTIPLIER = 50

## 移動侵略/侵略: 属性一致ボーナス
const INVASION_ELEMENT_MATCH_BONUS = 50

## 侵略: 敵資産減少倍率（自分の増加 + 敵の減少）
const INVASION_ASSET_MULTIPLIER = 2

## クリーチャー交換: レート差係数
const SWAP_RATE_MULTIPLIER = 2

## クリーチャー交換: 属性一致ボーナス
const SWAP_ELEMENT_MATCH_BONUS = 150

## クリーチャー交換: 属性不一致ペナルティ
const SWAP_ELEMENT_MISMATCH_PENALTY = -500

## クリーチャー交換: 土地レベル係数
const SWAP_LEVEL_MULTIPLIER = 20

## クリーチャー交換: 最低スコア閾値
const SWAP_MIN_SCORE_THRESHOLD = 25

## 属性変更: 基本スコア
const ELEMENT_CHANGE_BASE_SCORE = 100

## 属性変更: 無属性ボーナス
const ELEMENT_CHANGE_NEUTRAL_BONUS = 100

## 属性変更: コスト係数
const ELEMENT_CHANGE_COST_MULTIPLIER = 0.3

# ============================================================
# 危機モード・EP管理（CPUTerritoryAI用）
# ============================================================

## 危機モード: 残りEP閾値
const CRISIS_MODE_THRESHOLD = 100

## 危機モード: スコア（最優先）
const CRISIS_MODE_SCORE = 9999

## EP温存: 残す割合（30%）
const MAGIC_RESERVE_RATIO = 0.3

## EP温存: 最低残高
const MAGIC_RESERVE_MINIMUM = 100

# ============================================================
# その他共通定数
# ============================================================

## 無限ループ防止用: 最大判断試行回数
const MAX_DECISION_ATTEMPTS = 3

## CPU思考ディレイ（秒）
const CPU_THINKING_DELAY = 0.5
