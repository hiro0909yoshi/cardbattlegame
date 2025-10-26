# 土地システム統合仕様

## 📋 目次
1. [隣接判定システム（TileNeighborSystem）](#隣接判定システムtileneighborsystem)
2. [土地ボーナスシステム](#土地ボーナスシステム)
3. [ダウン状態システム](#ダウン状態システム)
4. [領地コマンド詳細](#領地コマンド詳細)

---

## 隣接判定システム（TileNeighborSystem）

### 概要
タイルの物理的な隣接関係を座標ベースで判定するシステム。

### 判定方法
```gdscript
# XZ平面での距離計算
const TILE_SIZE = 4.0
const NEIGHBOR_THRESHOLD = 4.5  # タイルサイズより10%大きい

var dx = abs(my_pos.x - other_pos.x)
var dz = abs(my_pos.z - other_pos.z)
var distance_xz = sqrt(dx * dx + dz * dz)

if distance_xz < NEIGHBOR_THRESHOLD:
	# 隣接と判定
```

### 使用例
```gdscript
# スキル条件: 「隣接した自領地なら強打」
var neighbors = board_system.tile_neighbor_system.get_spatial_neighbors(tile_index)
# → [5, 7]  # タイル6の隣接タイル

var has_ally = board_system.tile_neighbor_system.has_adjacent_ally_land(
	tile_index, player_id, board_system
)
# → true/false
```

### キャッシュ機構
- 初回起動時に全タイルの隣接関係を計算
- 結果をキャッシュして高速化（O(1)で取得）
- マップ変更時は再計算可能

### 拡張性
- 十字路・T字路: 4方向以上の隣接にも対応
- 立体交差: Y軸も考慮可能（将来）

### 主要メソッド
```gdscript
# 初期化
func setup(tiles: Dictionary)

# 隣接取得
func get_spatial_neighbors(tile_index: int) -> Array
func get_sequential_neighbors(tile_index: int) -> Array

# 条件判定
func has_adjacent_ally_land(tile_index: int, player_id: int, board_system) -> bool
```

### アルゴリズム
1. 全タイルペアの距離を計算（XZ平面）
2. 閾値4.5以内を隣接と判定
3. 結果を`spatial_neighbors_cache`にキャッシュ

### パフォーマンス
- 初回構築: O(N²) - 20タイルで400回計算、<10ms
- 実行時取得: O(1) - キャッシュから即座に取得

---

## 土地ボーナスシステム

### 概要
クリーチャーと土地の属性が一致すると、土地レベルに応じたHPボーナスが得られる。

### 計算式
```
土地ボーナスHP = 土地レベル × 10

例:
- レベル1の火属性土地 + 火属性クリーチャー → +10HP
- レベル3の水属性土地 + 水属性クリーチャー → +30HP
- レベル5の風属性土地 + 風属性クリーチャー → +50HP (最大)
```

### 実装場所
- 召喚時: `BaseTile.place_creature()` → `_apply_land_bonus()`
- バトル時: `BattleSystem._apply_attacker_land_bonus()`

### データ構造
```gdscript
creature_data = {
	"name": "フェニックス",
	"element": "火",
	"hp": 30,              # 基本HP
	"land_bonus_hp": 20,   # 土地ボーナス（別管理）
	# 表示HP = 30 + 20 = 50
}
```

### 特徴
- `hp`とは別フィールドで管理
- 「貫通」「巻物」スキルで無視される（将来実装）
- 常時適用（召喚時・バトル時）

---

## ダウン状態システム

### 概要
土地でアクション（召喚、レベルアップ、移動、交換）を実行すると、その土地は「ダウン状態」になり、次のターンまで再度選択できなくなる。

### ダウン状態の設定タイミング
- 召喚実行後
- レベルアップ実行後
- クリーチャー移動実行後（移動先の土地）
- クリーチャー交換実行後

### 例外: 不屈スキル
- 不屈スキルを持つクリーチャーがいる土地は、アクション後もダウン状態にならない
- 何度でも領地コマンドを実行可能

### ダウン状態の解除タイミング
- プレイヤーがスタートマスを通過したとき
- 全プレイヤーの全土地のダウン状態が一括解除される

### 制約
- **ダウン状態の土地は領地コマンドで選択できない**
  - `get_player_owned_lands()`でダウン状態の土地を除外
  - UI上で選択肢として表示されない
- ダウン状態でもクリーチャーは通常通り機能する
  - バトルの防御側として機能
  - 通行料は発生する

### 実装
```gdscript
# ダウン状態の設定
tile.set_down(true)

# ダウン状態の確認
if tile.is_down():
	# 選択不可

# ダウン状態の解除（スタート通過時）
movement_controller.clear_all_down_states_for_player(player_id)
```

### 不屈スキルの実装
```gdscript
# SkillSystem.gd
static func has_unyielding(creature_data: Dictionary) -> bool:
	if creature_data.is_empty():
		return false
	var ability_detail = creature_data.get("ability_detail", "")
	return "不屈" in ability_detail

# ダウン状態設定時の不屈チェック（各アクション処理）
if tile.has_method("set_down_state"):
	var creature = tile.creature_data if tile.has("creature_data") else {}
	if not SkillSystem.has_unyielding(creature):
		tile.set_down_state(true)
	else:
		print("不屈によりダウンしません")
```

### 不屈持ちクリーチャー一覧（16体）
- 火: シールドメイデン(14), ショッカー(18), バードメイデン(28)
- 水: エキノダーム(113), カワヒメ(117), マカラ(141)
- 地: キャプテンコック(207), ヒーラー(234), ピクシー(235), ワーベア(249)
- 風: グレートニンバス(312), トレジャーレイダー(331), マーシャルモンク(341), マッドハーレクイン(342)
- 無: アーキビショップ(403), シャドウガイスト(418)

### デバッグコマンド
- **Uキー**: 現在プレイヤーの全土地のダウン状態を即座に解除
- テスト用の機能（本番では無効化予定）

---

## 領地コマンド詳細

### UIフラグ管理

**重要なフラグ**: `card_selection_ui.is_active`
- `true`: カード選択可能（召喚フェーズ）
- `false`: カード選択不可（領地コマンド中・その他のフェーズ）

**実装**:
```gdscript
// 領地コマンドを開く時
ui_manager.card_selection_ui.is_active = false  // カード選択を無効化

// 領地コマンドを閉じる時
_reinitialize_card_selection.call_deferred()   // 次フレームで再初期化
ui_manager.hide_card_selection_ui()             // 一度非表示
ui_manager.show_card_selection_ui(player)       // 再表示（is_active=trueになる）
```

### 基本制約
1. **1ターンに1回のみ実行可能**
   - レベルアップ、移動、交換のいずれか1つのみ
   - 実行後は自動的にターン終了
   
2. **召喚と領地コマンドは排他的**
   - 召喚を実行した場合、領地コマンドは実行できない
   - 領地コマンドを実行した場合、召喚は実行できない
   - どちらか一方のみ選択可能

3. **ダウン状態の土地は選択不可**
   - アクション実行済みの土地は次のターンまで使用不可
   - 選択肢として表示されない
   - **例外**: 不屈スキル持ちのクリーチャーがいる土地はダウンしないため、何度でも使用可能

### 土地選択の操作方法
- **矢印キー（↑↓←→）**: 土地を切り替え（プレビュー）
- **Enterキー**: 選択を確定してアクションメニューへ
- **数字キー（1-0）**: 該当する土地を即座に確定
- **C/Escapeキー**: キャンセル

### アクション選択
- **Lキー**: レベルアップ
- **Mキー**: クリーチャー移動
- **Sキー**: クリーチャー交換
- **C/Escapeキー**: 前画面に戻る

---

## 1. レベルアップ

### フロー
```
移動完了
  ↓
領地コマンドボタン表示（人間プレイヤーのみ）
  ↓
土地選択（数字キー1-0）
  ├─ ダウン状態の土地は選択不可
  └─ 所有している土地のみ選択可能
  ↓
アクションメニュー表示（右側中央パネル）
  ├─ [L] レベルアップ
  ├─ [M] 移動
  ├─ [S] 交換
  └─ [C] 戻る（土地選択に戻る）
  ↓
レベルアップ選択（Lキー）
  ↓
レベル選択画面表示
  ├─ 現在レベル表示
  ├─ Lv2-5選択ボタン
  │   ├─ 累計コスト表示
  │   │   Lv1→2: 80G
  │   │   Lv1→3: 240G
  │   │   Lv1→4: 620G
  │   │   Lv1→5: 1200G
  │   └─ 魔力不足のボタンは無効化
  └─ [C] 戻る（アクションメニューに戻る）
  ↓
レベル選択（Lv2-5いずれか）
  ↓
レベルアップ実行
  ├─ 魔力消費（累計コスト）
  ├─ 土地レベル更新
  ├─ ダウン状態設定
  └─ UI更新
  ↓
ターン終了
```

### レベルコスト（累計方式）
```gdscript
const LEVEL_COSTS = {
	0: 0,
	1: 0,
	2: 80,      // Lv1→2: 80G
	3: 240,     // Lv1→3: 240G (80 + 160)
	4: 620,     // Lv1→4: 620G (80 + 160 + 380)
	5: 1200     // Lv1→5: 1200G (80 + 160 + 380 + 580)
}

// コスト計算
var cost = LEVEL_COSTS[target_level] - LEVEL_COSTS[current_level]
```

### 実装クラス
- `LandCommandHandler`: 領地コマンドのロジック
- `UIManager`: アクションメニュー・レベル選択パネルのUI
- `GameFlowManager`: ターン終了処理

---

## 2. クリーチャー移動

### フロー
```
領地コマンド → 移動を選択
  ↓
移動元の土地を選択（ダウン状態除外）
  ↓
隣接する移動先を表示
  ├─ 空き地
  ├─ 自分の土地（移動不可）
  └─ 敵の土地
  ↓
移動先を選択（↑↓キーで切り替え）
  ↓
【空き地への移動】
  - 移動元が空き地になる
  - 移動先に土地獲得
  - クリーチャー配置
  - ダウン状態設定
  - ターン終了
  
【敵地への移動】
  - 移動元が空き地になる
  - バトル実行
  - 勝利: 土地獲得 + ダウン設定
  - 敗北: クリーチャー消滅
  - ターン終了
```

### 実装クラス
- `LandCommandHandler.execute_move_creature()`
- `LandCommandHandler.confirm_move()`

---

## 3. クリーチャー交換

### フロー
```
領地コマンド → 交換を選択
  ↓
交換対象の土地を選択（ダウン状態除外）
  ↓
手札にクリーチャーカードがあるか確認
  ├─ なし → エラーメッセージ
  └─ あり → 次へ
  ↓
新しいクリーチャーカードを選択
  ↓
元のクリーチャーを手札に戻す
  ↓
新しいクリーチャーを召喚
  - コスト支払い（mp × 10G）
  - 土地ボーナス適用
  - 土地レベル継承
  - ダウン状態設定
  ↓
ターン終了
```

### 実装クラス
- `LandCommandHandler.execute_swap_creature()`
- `TileActionProcessor.execute_swap()`

---

## 将来計画

### 分岐路システム設計案

#### マップ設計の進化
```
現在（菱形1周）        将来（自由分岐）
	 ◇                      ◇
	◇ ◇                    ╱ ╲
   ◇   ◇                  ◇   ◇
  ◇     ◇      →         │   │
   ◇   ◇                  ◇═══◇
	◇ ◇                    ╲ ╱
	 ◇                      ◇
```

#### タイルの接続情報
```gdscript
# タイルの接続情報
{
  "index": 5,
  "connections": [4, 6, 12],  # 3方向に分岐
  "junction_type": "T-junction"  # 十字路・T字路
}
```

#### TileNeighborSystemの対応
- 十字路・T字路: 4方向以上の隣接にも対応済み
- 立体交差: Y軸も考慮可能（将来）
- 非ループ構造: 分岐のあるマップに対応可能

---

## 変更履歴

| 日付 | バージョン | 変更内容 |
|------|-----------|---------|
| 2025/10/25 | 1.0 | 初版作成: design.mdから土地関連システムを統合 |
| 2025/10/25 | 1.1 | 将来計画（分岐路システム）を追加 |

---

**最終更新**: 2025年10月25日（v1.1 - 将来計画追加）  
**関連ドキュメント**: [design.md](design.md) - プロジェクト設計書
