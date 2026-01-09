# 破産システム設計書

## 概要

プレイヤーの魔力がマイナスになった際に、所有土地を売却して支払いを行うシステム。

## 破産発生条件

以下の状況で魔力がマイナスになった場合に発生：

1. **通行料の支払い** - 敵の土地に止まった際（ターン終了時）
2. **スペル効果** - 魔力を奪うスペル（敵ターン中 → 自ターン開始時にチェック）
3. **スキル効果** - 魔力を奪うスキル（ターン終了時）

## 土地の価値計算

**土地の価値 = 通行料**

既存の通行料計算（`tile_data_manager.gd`の`calculate_toll()`）をそのまま使用：

```gdscript
var raw_toll = base * element_mult * level_mult * chain_bonus * map_mult
var final_toll = GameConstants.floor_toll(raw_toll)  # 10の位で切り捨て
```

**計算要素：**
- `base`: 基本通行料（GameConstants.BASE_TOLL）
- `element_mult`: 属性係数（GameConstants.TOLL_ELEMENT_MULTIPLIER）
- `level_mult`: レベル係数（GameConstants.TOLL_LEVEL_MULTIPLIER）
- `chain_bonus`: 連鎖ボーナス（同一属性土地の所有数による）
- `map_mult`: マップ係数（GameConstants.TOLL_MAP_MULTIPLIER）

**連鎖ボーナス（GameConstants）:**
- 2連鎖: CHAIN_BONUS_2
- 3連鎖: CHAIN_BONUS_3
- 4連鎖: CHAIN_BONUS_4
- 5連鎖以上: CHAIN_BONUS_5

**重要: 売却時の連鎖再計算**
- 1つの土地を売却すると、同一属性の残り土地の連鎖数が変わる
- 売却のたびに全土地の価値を再評価する必要がある
- 複数選択ではなく1枚ずつ売却する理由の1つ

**破産時の売却価格：**
- 計算式: `土地の価値 × 1.0`（100%返還）
- 既存の`calculate_toll()`を呼び出すだけでOK

**参考：ランドトランス（スペル）**
- 計算式: `土地の価値 × 0.7`（70%返還）
- 自発的な売却のため割引あり

## 処理フロー

### 1. 破産判定

```
魔力支払い発生
    ↓
現在の魔力 < 0 ?
    ↓ Yes
破産処理開始
```

### 2. 土地売却フロー

```
Case A: 土地売却で回復可能な場合
----------------------------------------
マイナス魔力を表示
    ↓
土地選択UI表示（プレイヤー）/ 自動選択（CPU）
    ↓
プレイヤーが売却する土地を選択
    ↓
土地売却（クリーチャー消滅、所有権解除）
    ↓
売却額を魔力に加算
    ↓
魔力 >= 0 になったら終了 → 通常続行（スタートに戻らない）
    ↓
まだマイナスなら土地選択に戻る


Case B: 全土地売却しても回復不可能な場合
----------------------------------------
マイナス魔力を表示
    ↓
全土地を自動売却
    ↓
プレイヤーをスタート地点（タイル0）に移動
    ↓
魔力を300Gにリセット
    ↓
プレイヤー呪いをクリア（世界呪いはそのまま）
    ↓
手札はそのまま維持
```

### 3. 判定タイミング

**A. ターン終了時（end_turn内）**
- 通行料支払い後
- バトル中のスキルで魔力を奪われた場合

**B. ターン開始時（start_turn内）**
- カードドロー後
- 敵のスペルで魔力を奪われた場合

## UI設計

### 土地売却UI

既存の土地選択UIをベースに拡張。

**画面構成：**
```
┌─────────────────────────────────────────────┐
│                  ボード表示                  │
│   （選択可能な自分の土地がハイライト）        │
├─────────────────────┬───────────────────────┤
│                     │   【破産処理】         │
│   クリーチャー       │                       │
│   情報パネル        │   現在の魔力: -150G    │
│   （選択中の土地）   │   不足額: 150G         │
│                     │                       │
│                     │   選択中の土地:        │
│                     │   タイル5 (Lv3) 300G   │
│                     │                       │
│                     │   [売却する]           │
└─────────────────────┴───────────────────────┘
```

**表示要素：**
- 現在の魔力（マイナス表示）
- 選択中の土地の売却価格
- 売却ボタン

## 実装箇所

### 呼び出しタイミング

**A. ターン終了時 `end_turn()`（game_flow_manager.gd）**

```gdscript
func end_turn():
    # ...
    await check_and_discard_excess_cards()  # 手札調整
    await check_and_pay_toll_on_enemy_land() # 通行料支払い
    await check_and_handle_bankruptcy()      # ← 破産チェック（新規追加）
    # ...
```

**B. ターン開始時 `start_turn()`（game_flow_manager.gd）**

```gdscript
func start_turn():
    var current_player = player_system.get_current_player()
    emit_signal("turn_started", current_player.id)
    
    # カードドロー
    var drawn = spell_draw.draw_one(current_player.id)
    
    # ★ターン開始時の破産チェック（敵スペル等で魔力マイナスの場合）
    await check_and_handle_bankruptcy()
    
    # スペルフェーズ開始...
```

### 新規作成

**BankruptcyHandler** (`scripts/game_flow/bankruptcy_handler.gd`)

```gdscript
class_name BankruptcyHandler

# 定数
const START_TILE_INDEX = 0
const RESET_MAGIC = 300

# 主要メソッド
func check_bankruptcy(player_id: int) -> bool          # 魔力 < 0 か判定
func get_land_value(tile_index: int) -> int            # 土地価値取得（calculate_toll流用）
func sell_land(tile_index: int) -> int                 # 土地売却、売却額を返す
func get_player_lands(player_id: int) -> Array         # プレイヤーの所有土地一覧
func can_recover_by_selling(player_id: int) -> bool    # 売却で回復可能か判定
func force_sell_all_and_reset(player_id: int)          # 全売却＆スタートリセット

# プレイヤー/CPU分岐
func process_bankruptcy(player_id: int, is_cpu: bool)  # メイン処理
func process_player_bankruptcy(player_id: int)         # プレイヤー用（UI表示）
func process_cpu_bankruptcy(player_id: int)            # CPU用（自動選択）
```

**BankruptcySellUI** (`scripts/ui_components/bankruptcy_sell_ui.gd`)
- 土地選択UI
- 魔力表示（マイナス対応）
- 売却ボタン
- 売却完了シグナル

### 既存修正

1. **PlayerSystem** (`scripts/player_system.gd`)
   - `add_magic()`: マイナス値を許容するように変更

2. **GameFlowManager** (`scripts/game_flow_manager.gd`)
   - `end_turn()`: 破産チェック呼び出しを追加
   - `start_turn()`: カードドロー後に破産チェック呼び出しを追加

## リセット時の状態

全土地売却しても回復不可能な場合：

| 項目 | 状態 |
|------|------|
| 魔力 | 300G |
| 手札 | そのまま |
| 土地 | 全て失う |
| プレイヤー呪い | クリア |
| 世界呪い | そのまま |
| 位置 | タイル0（スタート地点） |

## CPU対応

BankruptcyHandler内で `process_cpu_bankruptcy()` として実装。

**CPU土地選択ロジック（簡易版）：**
1. 低価値の土地から売却
2. 連鎖への影響が少ない土地を優先

後で `cpu_bankruptcy_ai.gd` に分離してリファクタリング可能。

## 関連システム

- **ランドトランス** (`spell_land_new.gd`): 70%価格での自発的売却
- **通行料計算** (`tile_data_manager.gd`): `calculate_toll()`
- **土地放棄** (`spell_land_new.gd`): `abandon_land()`関数を参考

## 定数

```gdscript
# game_constants.gd または BankruptcyHandler内
const START_TILE_INDEX = 0       # スタート地点
const BANKRUPTCY_RESET_MAGIC = 300  # 破産リセット後の初期魔力
```

## TODO

- [ ] Phase 1: BankruptcyHandler基本実装
- [ ] Phase 2: BankruptcySellUI実装
- [ ] Phase 3: GameFlowManager統合（end_turn, start_turn）
- [ ] Phase 4: PlayerSystem修正（マイナス魔力許容）
- [ ] Phase 5: CPU自動選択ロジック
- [ ] Phase 6: テスト・調整