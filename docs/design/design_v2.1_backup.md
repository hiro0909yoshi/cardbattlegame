# 🎮 カルドセプト風カードバトルゲーム - 設計書

## 📋 目次
1. [新システム詳細仕様](#新システム詳細仕様)
2. [領地コマンド詳細](#領地コマンド詳細)
3. [UI配置ガイドライン](#ui配置ガイドライン)
4. [将来計画](#将来計画)
5. [関連ドキュメント](#関連ドキュメント)

> **注**: 基本的なシステムアーキテクチャ、コーディング規約、バトルフローなどは各メモリファイルを参照してください。このドキュメントはdesign.md独自の詳細仕様のみを記載しています。

---

## 新システム詳細仕様

### 1. 種族システム

#### 概要
クリーチャーに`race`フィールドを追加し、種族ベースのスキル判定（応援スキルなど）を可能にするシステム。

#### 実装例
```json
{
  "id": 414,
  "race": "ゴブリン"
}
```

**実装済み**: ゴブリン種族（2体）で応援スキルの対象判定に使用
- ID: 414 - ゴブリン
- ID: 445 - レッドキャップ（ゴブリン全員にAP+20）

**将来拡張**: ドラゴン、アンデッド、デーモンなど他種族追加予定

---

### 2. 効果システム (EffectSystem)

#### 概要
クリーチャーのステータス変更効果を統一管理するシステム。

#### 効果の種類

**1. バトル中のみの効果**
- アイテム効果（AP+30、HP+40など）
- バトル終了時に自動削除

**2. 一時効果（移動で消える）**
- スペル「ブレッシング」（HP+10）
- 領地コマンドでクリーチャー移動時に削除

**3. 永続効果（移動で消えない）**
- マスグロース（全クリーチャーMHP+5）
- ドミナントグロース（特定属性MHP+10）
- 交換時やゲーム終了まで維持

**4. 土地数比例効果**
- アームドパラディン「火と土の土地数×10」
- バトル時に動的計算

#### データ構造
```gdscript
creature_data = {
	"base_up_hp": 0,           # 永続的な基礎HP上昇
	"base_up_ap": 0,           # 永続的な基礎AP上昇
	"permanent_effects": [],   # 永続効果配列
	"temporary_effects": [],   # 一時効果配列
	"map_lap_count": 0         # 周回カウント
}

# 効果オブジェクト
effect = {
	"type": "stat_bonus",
	"stat": "hp",              # または "ap"
	"value": 10,
	"source": "spell",
	"source_name": "ブレッシング",
	"removable": true,         # 打ち消し可能か
	"lost_on_move": true       # 移動で消えるか
}
```

#### 主要メソッド
```gdscript
# スペル効果
func add_spell_effect_to_creature(tile_index: int, effect: Dictionary)
func apply_mass_growth(player_id: int, bonus_hp: int = 5)
func apply_dominant_growth(player_id: int, element: String, bonus_hp: int = 10)

# 効果削除
func clear_temporary_effects_on_move(tile_index: int)
func remove_effects_from_creature(tile_index: int, removable_only: bool = true)
```

#### ability_parsedの拡張

**土地数比例効果の例**:
```json
{
  "effects": [
	{
	  "effect_type": "land_count_multiplier",
	  "stat": "ap",
	  "elements": ["fire", "earth"],
	  "multiplier": 10
	}
  ]
}
```

**アイテム効果の例**:
```json
{
  "effects": [
	{
	  "effect_type": "debuff_ap",
	  "value": 10
	},
	{
	  "effect_type": "buff_hp",
	  "value": 40
	}
  ]
}
```

詳細は `docs/design/effect_system.md` を参照。

---

### 5. ダウン状態システム

#### 概要
土地でアクション（召喚、レベルアップ、移動、交換）を実行すると、その土地は「ダウン状態」になり、次のターンまで再度選択できなくなる。

#### ダウン状態の設定タイミング
- 召喚実行後
- レベルアップ実行後
- クリーチャー移動実行後（移動先の土地）
- クリーチャー交換実行後

**例外: 不屈スキル**
- 不屈スキルを持つクリーチャーがいる土地は、アクション後もダウン状態にならない
- 何度でも領地コマンドを実行可能

#### ダウン状態の解除タイミング
- プレイヤーがスタートマスを通過したとき
- 全プレイヤーの全土地のダウン状態が一括解除される

#### 制約
- **ダウン状態の土地は領地コマンドで選択できない**
  - `get_player_owned_lands()`でダウン状態の土地を除外
  - UI上で選択肢として表示されない
- ダウン状態でもクリーチャーは通常通り機能する
  - バトルの防御側として機能
  - 通行料は発生する

#### 実装
```gdscript
# ダウン状態の設定
tile.set_down(true)

# ダウン状態の確認
if tile.is_down():
	# 選択不可

# ダウン状態の解除（スタート通過時）
movement_controller.clear_all_down_states_for_player(player_id)
```

#### 不屈スキルの実装
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

**不屈持ちクリーチャー一覧** (16体):
- 火: シールドメイデン(14), ショッカー(18), バードメイデン(28)
- 水: エキノダーム(113), カワヒメ(117), マカラ(141)
- 地: キャプテンコック(207), ヒーラー(234), ピクシー(235), ワーベア(249)
- 風: グレートニンバス(312), トレジャーレイダー(331), マーシャルモンク(341), マッドハーレクイン(342)
- 無: アーキビショップ(403), シャドウガイスト(418)

#### デバッグコマンド
- **Uキー**: 現在プレイヤーの全土地のダウン状態を即座に解除
- テスト用の機能（本番では無効化予定）

---

## 領地コマンド詳細

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

### レベルアップフロー
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

**レベルコスト（累計方式）**:
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

**実装クラス**:
- `LandCommandHandler`: 領地コマンドのロジック
- `UIManager`: アクションメニュー・レベル選択パネルのUI
- `GameFlowManager`: ターン終了処理

### クリーチャー移動フロー
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

**実装クラス**:
- `LandCommandHandler.execute_move_creature()`
- `LandCommandHandler.confirm_move()`

### クリーチャー交換フロー
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

**実装クラス**:
- `LandCommandHandler.execute_swap_creature()`
- `TileActionProcessor.execute_swap()`

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

## UI配置ガイドライン

### 全画面対応の原則
**すべてのUI要素は、画面解像度に依存しない相対的な配置を使用する。**

#### 推奨パターン
```gdscript
// ✅ GOOD: viewport_sizeを使用した相対配置
var viewport_size = get_viewport().get_visible_rect().size
var panel_x = viewport_size.x - panel_width - 20  # 右端から20px
var panel_y = (viewport_size.y - panel_height) / 2  # 画面中央
```

#### 非推奨パターン
```gdscript
// ❌ BAD: 絶対座標指定
panel.position = Vector2(1200, 100)  # 画面サイズが変わると破綻
```

### 配置ルール
1. **水平方向**
   - 左寄せ: `margin`
   - 中央揃え: `(viewport_size.x - width) / 2`
   - 右寄せ: `viewport_size.x - width - margin`

2. **垂直方向**
   - 上寄せ: `margin`
   - 中央揃え: `(viewport_size.y - height) / 2`
   - 下寄せ: `viewport_size.y - height - margin`

3. **マージン**
   - 画面端からの余白: 10-20px推奨
   - UI要素間の余白: 5-10px推奨

### UIコンポーネント配置例

#### ActionMenuPanel
```gdscript
# 画面右側中央に配置
var viewport_size = get_viewport().get_visible_rect().size
var panel_x = viewport_size.x - panel_width - 20
var panel_y = (viewport_size.y - panel_height) / 2
```
- **位置**: 画面右側中央
- **サイズ**: 200x320px

#### LevelSelectionPanel
```gdscript
# ActionMenuPanelと同じ位置
var viewport_size = get_viewport().get_visible_rect().size
var panel_x = viewport_size.x - panel_width - 20
var panel_y = (viewport_size.y - panel_height) / 2
```
- **位置**: 画面右側中央
- **サイズ**: 250x400px

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

#### TileNeighborSystemの拡張
- 十字路・T字路: 4方向以上の隣接にも対応済み
- 立体交差: Y軸も考慮可能（将来）
- 非ループ構造: 分岐のあるマップに対応可能

---

## 重要な設計上の注意点

### アクション処理フラグの管理

#### 問題: 二重管理
1. **BoardSystem3D.is_waiting_for_action**
2. **TileActionProcessor.is_action_processing**

#### 解決策（TECH-002で完了）
- TileActionProcessorに統一
- BoardSystem3Dはシグナル転送のみ
- LandCommandHandlerは`complete_action()`経由で通知

### ターン終了処理の管理

#### 責任クラス
`GameFlowManager` (scripts/game_flow_manager.gd)

#### 正常な呼び出しチェーン
```
TileActionProcessor (_complete_action)
  └─ emit_signal("action_completed")
	 │
	 ↓
BoardSystem3D (_on_action_completed)
  └─ emit_signal("tile_action_completed")
	 │
	 ↓
GameFlowManager (_on_tile_action_completed_3d)
  └─ end_turn()
	 └─ emit_signal("turn_ended")
```

#### 重複実行防止機構（3段階）
1. BoardSystem3D: `is_waiting_for_action`フラグチェック
2. GameFlowManager: フェーズチェック（END_TURN/SETUP時は無視）
3. end_turn(): 再入防止チェック

### システム初期化順序

#### 正しい初期化順序（game_3d.gd）
```gdscript
func _ready():
	# 1. システム作成
	
	# 2. UIManager設定
	ui_manager.board_system_ref = board_system_3d
	ui_manager.player_system_ref = player_system
	ui_manager.card_system_ref = card_system
	ui_manager.create_ui(self)  # ← CardSelectionUI等を初期化
	
	# 3. 手札UI初期化
	var ui_layer = get_node_or_null("UILayer")
	if ui_layer:
		ui_manager.initialize_hand_container(ui_layer)
		ui_manager.connect_card_system_signals()
	
	# 4. デバッグフラグ設定（重要！setup_systemsより前）
	game_flow_manager.debug_manual_control_all = debug_manual_control_all
	
	# 5. GameFlowManager設定
	game_flow_manager.setup_systems(player_system, card_system, board_system_3d, 
									skill_system, ui_manager, battle_system, special_tile_system)
	game_flow_manager.setup_3d_mode(board_system_3d, player_is_cpu)
	
	# 6. CardSelectionUIへの参照再設定（重要！）
	if ui_manager.card_selection_ui:
		ui_manager.card_selection_ui.game_flow_manager_ref = game_flow_manager
```

#### なぜ参照再設定が必要か
- `create_ui()`時点ではGameFlowManagerの参照がまだない
- `setup_systems()`でUIManagerに参照が設定される
- その後、子コンポーネントに明示的に再設定が必要

---

## 関連ドキュメント

このドキュメントはプロジェクト全体のアーキテクチャと詳細仕様を示すマスタードキュメントです。
各システムの基本仕様やコーディング規約については、メモリファイルを参照してください。

### システム設計ドキュメント

#### スキルシステム
- **[skills_design.md](skills_design.md)** - スキルシステム全体設計
  - 実装済みスキル一覧（18種類）
  - スキル適用順序とアーキテクチャ
  - 将来実装予定のスキル

#### 個別スキル仕様書（14ファイル）

**実装済みスキル:**
1. [assist_skill.md](skills/assist_skill.md) - 応援スキル
2. [double_attack_skill.md](skills/double_attack_skill.md) - 2回攻撃スキル
3. [first_strike_skill.md](skills/first_strike_skill.md) - 先制スキル
4. [indomitable_skill.md](skills/indomitable_skill.md) - 不屈スキル
5. [instant_death_skill.md](skills/instant_death_skill.md) - 即死スキル
6. [nullify_skill.md](skills/nullify_skill.md) - 無効化スキル
7. [penetration_skill.md](skills/penetration_skill.md) - 貫通スキル
8. [power_strike_skill.md](skills/power_strike_skill.md) - 強打スキル
9. [reflect_skill.md](skills/reflect_skill.md) - 反射スキル
10. [regeneration_skill.md](skills/regeneration_skill.md) - 再生スキル
11. [resonance_skill.md](skills/resonance_skill.md) - 感応スキル
12. [scroll_attack_skill.md](skills/scroll_attack_skill.md) - 巻物攻撃スキル
13. [support_skill.md](skills/support_skill.md) - 援護スキル
14. [item_destruction_theft_skill.md](skills/item_destruction_theft_skill.md) - アイテム破壊・盗みスキル
15. [transform_skill.md](skills/transform_skill.md) - 変身スキル
16. [revive_skill.md](skills/revive_skill.md) - 死者復活スキル

#### その他のシステム
- **[effect_system.md](effect_system.md)** - エフェクトシステム設計
- **[effect_system_design.md](effect_system_design.md)** - エフェクトシステム詳細設計
- **[battle_test_tool_design.md](battle_test_tool_design.md)** - バトルテストツール設計
- **[turn_end_flow.md](turn_end_flow.md)** - ターン終了フロー
- **[defensive_creature_design.md](defensive_creature_design.md)** - 防御型クリーチャー設計

### 実装・進捗管理ドキュメント

- **[docs/progress/](../progress/)** - 実装進捗と状態管理
- **[docs/implementation/](../implementation/)** - 実装仕様書
- **[docs/issues/](../issues/)** - タスク管理とバグトラッキング
- **[docs/refactoring/](../refactoring/)** - リファクタリング記録

---

## 変更履歴

| 日付 | バージョン | 変更内容 |
|------|-----------|---------|
| 2025/10/25 | 2.0 | 大幅リファクタリング: 重複削除、詳細仕様のみ記載 |
| 2025/10/25 | 2.1 | 実装済みスキル追加: アイテム破壊・盗み、変身、死者復活 |

---

**最終更新**: 2025年10月25日（v2.1 - スキル追加）  
**関連ドキュメント**: 
- [skills_design.md](skills_design.md) - スキルシステム詳細仕様
- メモリファイル - 基本アーキテクチャ・コーディング規約
