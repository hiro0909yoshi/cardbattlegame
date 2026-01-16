# ターゲット選択システム設計

**ステータス**: 🔄 リファクタリング計画中  
**最終更新**: 2026年1月17日

---

## 概要

スペル、秘術、領地コマンドなどで使用するターゲット選択の統一システム。
土地、クリーチャー、プレイヤー、ゲートなど様々な対象の選択・フィルタリング・表示を担当。

---

## 現状のファイル構成

### メインファイル

| ファイル | 行数 | 役割 |
|---------|------|------|
| `scripts/game_flow/target_selection_helper.gd` | 1217 | ターゲット選択の汎用ヘルパー |

### 関連ファイル

| ファイル | 役割 |
|---------|------|
| `scripts/cpu_ai/cpu_target_resolver.gd` | CPUのターゲット条件判定 |
| `scripts/cpu_ai/cpu_spell_target_selector.gd` | CPUスペルターゲット選択 |
| `scripts/spells/spell_protection.gd` | 防魔フィルタ |
| `scripts/spells/spell_hp_immune.gd` | HP効果無効フィルタ |

---

## 現状の責務分析（target_selection_helper.gd）

### 1. タイル選択UI（インスタンスメソッド）〜150行
- `select_tile_from_list()` - await対応のタイル選択
- `_setup_tile_selection_navigation()` - ナビゲーション設定
- `_update_tile_selection_display()` - 表示更新
- `_select_next_tile()` / `_select_previous_tile()` - 切り替え
- `_confirm_tile_selection()` / `_cancel_tile_selection()` - 確定/キャンセル

### 2. マーカー管理（staticメソッド）〜150行
- `create_selection_marker()` - マーカー作成
- `show_selection_marker()` / `hide_selection_marker()` - 表示制御
- `rotate_selection_marker()` - 回転アニメーション
- `show_multiple_markers()` / `clear_confirmation_markers()` - 複数マーカー
- `_create_marker_mesh()` - メッシュ生成

### 3. カメラ制御（staticメソッド）〜50行
- `focus_camera_on_tile()` - タイルにフォーカス
- `focus_camera_on_player()` - プレイヤーにフォーカス

### 4. ハイライト制御（staticメソッド）〜100行
- `highlight_tile()` / `clear_all_highlights()` - 単一/全クリア
- `highlight_multiple_tiles()` - 複数ハイライト
- `show_confirmation_highlights()` - 確認フェーズ用
- `get_confirmation_text()` - 確認テキスト生成

### 5. ターゲット検索システム（staticメソッド）〜500行 ⭐最大
- `get_all_creatures()` - 全クリーチャー取得（条件付き）
- `get_valid_targets()` - ハンドラー経由
- `get_valid_targets_core()` - コア関数（CPU/プレイヤー共通）
- `_filter_by_most_common_element()` - 最多属性フィルタ
- `_check_has_adjacent_enemy()` - 隣接敵チェック
- `DummyHandler` - SpellProtection用ダミークラス

### 6. ターゲット操作（staticメソッド）〜100行
- `get_tile_index_from_target()` - ターゲットから座標取得
- `select_target_visually()` - 視覚的選択
- `clear_selection()` - 選択クリア
- `move_target_next()` / `move_target_previous()` - インデックス移動
- `select_target_by_index()` - 直接選択

### 7. UI表示ヘルパー（staticメソッド）〜100行
- `format_target_info()` - ターゲット情報テキスト
- `is_number_key()` / `get_number_from_key()` - 入力ヘルパー
- `_show_creature_info_panel()` / `_hide_creature_info_panel()` - 情報パネル

---

## リファクタリング計画

### 分割案

```
scripts/game_flow/
├── target_selection_helper.gd      # メイン（タイル選択、座標変換）〜250行
├── target_marker_system.gd         # マーカー管理（static）〜150行
├── target_finder.gd                # ターゲット検索（static）〜500行
└── target_ui_helper.gd             # UI表示ヘルパー（static）〜150行
```

### 各ファイルの責務

#### target_selection_helper.gd（メイン）
- タイル選択UI（インスタンスメソッド）
- ターゲット操作（座標変換、インデックス操作）
- 他モジュールへの委譲

#### target_marker_system.gd（新規）
- マーカー作成・表示・非表示
- マーカー回転アニメーション
- 複数マーカー管理
- カメラ制御
- ハイライト制御

#### target_finder.gd（新規）
- `get_valid_targets_core()` - メイン検索ロジック
- `get_all_creatures()` - 全クリーチャー取得
- 各ターゲットタイプ別フィルタリング
  - creature: 属性、呪い、MHP、ダウン状態など
  - player: own/enemy/any
  - land: レベル、属性、距離
  - gate: 未訪問ゲート
- `DummyHandler` クラス
- 防魔フィルタ適用

#### target_ui_helper.gd（新規）
- `format_target_info()` - テキストフォーマット
- `get_confirmation_text()` - 確認テキスト
- 入力ヘルパー（数字キー判定）
- クリーチャー情報パネル表示

---

## ターゲットタイプ一覧

### creature
クリーチャーを対象とするスペル/秘術用

| フィルタ | 説明 | 例 |
|---------|------|-----|
| `owner_filter` | own/enemy/any | 自/敵/全クリーチャー |
| `creature_elements` | 属性制限 | ["fire", "water"] |
| `has_curse` | 呪い付き | エグザイル |
| `has_no_curse` | 呪いなし | - |
| `has_summon_condition` | 召喚条件あり | サンダークラップ |
| `no_summon_condition` | 召喚条件なし | エグザイル |
| `hp_reduced` | HP減少中 | スウォーム |
| `is_down` | ダウン状態 | ディザスター |
| `has_adjacent_enemy` | 隣接敵あり | アウトレイジ |
| `mhp_check` | MHP条件 | {operator: "<=", value: 30} |
| `element_mismatch` | 属性不一致 | エレメンタルラス |
| `can_move` | 移動可能 | チャリオット |
| `require_mystic_arts` | 秘術持ち | テンプテーション |
| `require_not_down` | ダウンしていない | テンプテーション |
| `affects_hp` | HP効果 | HP効果無効チェック |

### player
プレイヤーを対象とするスペル用

| フィルタ | 説明 | 例 |
|---------|------|-----|
| `target_filter` | own/enemy/any | 自/敵/全プレイヤー |

### land / own_land / enemy_land
土地を対象とするスペル用

| フィルタ | 説明 | 例 |
|---------|------|-----|
| `owner_filter` | own/enemy/any | 自/敵/全領地 |
| `target_filter` | creature/empty | クリーチャーあり/空地 |
| `max_level` / `min_level` | レベル制限 | Lv1-4 |
| `required_level` | 特定レベル | Lv4のみ |
| `required_elements` | 属性制限 | ["fire", "earth"] |
| `distance_min` / `distance_max` | 距離制限 | マジカルリープ |

### unvisited_gate
未訪問ゲートを対象とするスペル用（リミッション）

---

## 防魔・HP効果無効フィルタ

### 自動適用
`get_valid_targets_core()` は最後に自動的に防魔フィルタを適用。

```gdscript
# 防魔フィルター（ignore_protection: true でスキップ可能）
if not target_info.get("ignore_protection", false):
    targets = SpellProtection.filter_protected_targets(targets, dummy_handler)
```

### 防魔チェック対象（SpellProtection）
- パッシブスキル「防魔」
- クリーチャー呪い（spell_protection, protection_wall）
- プレイヤー呪い（spell_protection）
- 世界呪い「呪い防魔化」
- 世界呪い「防魔」

### HP効果無効チェック（SpellHpImmune）
- `target_info.affects_hp = true` のスペルのみ適用
- パッシブスキル「HP効果無効」
- 呪い（hp_effect_immune）

---

## 使用例

### プレイヤー側（SpellPhaseHandler経由）
```gdscript
var targets = TargetSelectionHelper.get_valid_targets(self, "creature", {
    "owner_filter": "enemy",
    "affects_hp": true
})
```

### CPU側（systems辞書経由）
```gdscript
var systems = {
    "board_system": board_system,
    "player_system": player_system,
    "current_player_id": player_id,
    "game_flow_manager": game_flow_manager
}
var targets = TargetSelectionHelper.get_valid_targets_core(systems, "creature", {
    "owner_filter": "enemy",
    "mhp_check": {"operator": "<=", "value": 30}
})
```

---

## 呼び出し元一覧（調査結果）

### メソッド別使用頻度

| メソッド | 呼出数 | カテゴリ |
|---------|-------|---------|
| `focus_camera_on_tile()` | 19 | カメラ制御 |
| `show_selection_marker()` | 8 | マーカー管理 |
| `get_valid_targets()` | 8 | ターゲット検索 |
| `hide_selection_marker()` | 6 | マーカー管理 |
| `clear_selection()` | 6 | ターゲット操作 |
| `clear_all_highlights()` | 5 | ハイライト制御 |
| `clear_confirmation_markers()` | 4 | マーカー管理 |
| `rotate_selection_marker()` | 3 | マーカー管理 |
| `get_valid_targets_core()` | 3 | ターゲット検索 |
| `show_confirmation_highlights()` | 2 | ハイライト制御 |
| `get_confirmation_text()` | 2 | UI表示 |
| その他 | 11 | 各種 |

### 呼び出し元ファイル一覧

#### スペル関連（5ファイル）
| ファイル | 使用メソッド |
|---------|-------------|
| `spell_phase_handler.gd` | rotate_marker, get_valid_targets, select_visually, format_info, move_target, clear_*, show_confirmation |
| `spell_effect_executor.gd` | get_valid_targets |
| `spell_mystic_arts.gd` | get_valid_targets, clear_*, show_confirmation, get_confirmation_text |
| `spell_damage.gd` | focus_camera, get_valid_targets |
| `spell_curse_stat.gd` | focus_camera |
| `spell_curse.gd` | get_all_creatures |
| `spell_borrow.gd` | clear_selection |

#### 領地コマンド関連（4ファイル）
| ファイル | 使用メソッド |
|---------|-------------|
| `land_command_handler.gd` | create/show/hide/rotate_marker, focus_camera |
| `land_selection_helper.gd` | clear_highlights, show_marker, focus_camera, highlight_tile |
| `land_action_helper.gd` | show_marker, focus_camera |
| `land_input_helper.gd` | show_marker, focus_camera |

#### CPU AI関連（3ファイル）
| ファイル | 使用メソッド |
|---------|-------------|
| `cpu_spell_target_selector.gd` | get_valid_targets_core |
| `cpu_mystic_arts_ai.gd` | get_valid_targets_core |
| `cpu_special_tile_ai.gd` | get_valid_targets_core |

### 初期化・参照設定

| ファイル | 内容 |
|---------|------|
| `game_system_manager.gd` | インスタンス作成（preload + new） |
| `game_flow_manager.gd` | `target_selection_helper` プロパティとして保持 |

---

## 分割時の影響範囲

### 高影響（多くのファイルが使用）
- `focus_camera_on_tile()` - 19箇所 → `target_marker_system.gd`へ移動
- `show_selection_marker()` / `hide_selection_marker()` - 14箇所 → `target_marker_system.gd`へ移動

### 中影響（複数ファイルが使用）
- `get_valid_targets()` / `get_valid_targets_core()` - 11箇所 → `target_finder.gd`へ移動
- `clear_selection()` / `clear_all_highlights()` - 11箇所 → `target_marker_system.gd`へ移動

### 低影響（少数ファイルが使用）
- `format_target_info()` / `get_confirmation_text()` - 4箇所 → `target_ui_helper.gd`へ移動
- 入力ヘルパー - 3箇所 → `target_ui_helper.gd`へ移動

---

## リファクタリング戦略

### Phase 1: 新ファイル作成（既存コードに影響なし）
1. `target_marker_system.gd` 作成
2. `target_finder.gd` 作成
3. `target_ui_helper.gd` 作成
4. 各ファイルに関数をコピー（まだ移動しない）

### Phase 2: TargetSelectionHelperを委譲パターンに変更
1. `TargetSelectionHelper`のメソッドを新クラスへの委譲に変更
2. 既存の呼び出し元は変更不要（互換性維持）
3. 動作確認

### Phase 3: 段階的に呼び出し元を更新（任意）
1. 新クラスを直接呼び出すように変更
2. `TargetSelectionHelper`の委譲メソッドを非推奨化

---

## 変更履歴

| 日付 | 内容 |
|------|------|
| 2026/01/17 | 初版作成、リファクタリング計画策定 |
| 2026/01/17 | 呼び出し元調査結果追加、影響範囲分析 |