# 📋 次のリファクタリング作業

**最終更新**: 2026-02-13
**目的**: セッション間で作業計画が失われないよう、次にやることを明確に記録

---

## 現在のフェーズ

**フェーズ3-D: SpellSystemContainer導入**（完了：ステップ1-6すべて完了）

### Context（背景・目的）

GameFlowManager(GFM)が10+2個のspellシステム変数を個別保持しており、冗長な変換チェーンが発生している：

```
GSM: ローカル辞書構築 → GFM.set_spell_systems(): 辞書→個別変数展開
  → GSM._initialize_phase1a_handlers(): 個別変数→再度辞書詰め直し
	→ SpellEffectExecutor: 辞書→個別変数展開
```

**課題**:
- 当初見積もり: 389箇所のspell_*参照
- 実際の調査結果: **約100箇所**（大幅に少ない）
- 辞書⇔個別変数の変換が3回発生

**解決策**:
- CPUAIContext（RefCountedコンテナ）パターンを参考
- SpellSystemContainerを導入して変換チェーンを解消
- GFMのspell変数12個を集約

### 実装進捗（6ステップ）

#### ✅ ステップ1: SpellSystemContainerクラス作成（完了）

**新規作成**: `scripts/spells/spell_system_container.gd`

```gdscript
class_name SpellSystemContainer
extends RefCounted
```

- CPUAIContextパターン準拠（個別変数 + setup(dict) + is_valid() + debug_print_status()）
- コア8変数: spell_draw, spell_magic, spell_land, spell_curse, spell_dice, spell_curse_stat, spell_world_curse, spell_player_move
- 派生2変数: spell_curse_toll, spell_cost_modifier（set_xxx()で後から追加）
- `to_dictionary()`: 既存のdict展開メソッドとの互換性用
- `is_valid()` / `is_fully_valid()`: バリデーション

**影響**: ゼロ（新規ファイル）

#### ✅ ステップ2: GSM→GFMのコンテナ注入（後方互換あり）（完了）

**修正ファイル**:
1. `scripts/system_manager/game_system_manager.gd`
   - `_setup_spell_systems()`: ローカル辞書の代わりにSpellSystemContainerを構築
   - spell_curse_toll/spell_cost_modifier（行347-385）もコンテナ経由で設定
   - `_initialize_phase1a_handlers()`内の辞書再構築（行672-683）を `container.to_dictionary()` に簡素化

2. `scripts/game_flow_manager.gd`
   - `var spell_container: SpellSystemContainer` 追加
   - `set_spell_container()` 新メソッド追加
   - **後方互換**: 既存の個別変数（行71-80）にも展開（段階的に削除予定）
   - Node型システム（spell_curse_stat, spell_world_curse）のadd_child()はGFMで継続

**影響**: 既存コードは個別変数を使い続けるため、動作不変

#### ✅ ステップ3: GFM内部のspell_*をcontainer経由に置換（完了）

**修正ファイル**: `scripts/game_flow_manager.gd`

GFM内部で`self.spell_draw`等を使っている箇所を`spell_container.spell_draw`に変更：
- 行277: `spell_draw.draw_one()` → `spell_container.spell_draw.draw_one()`
- 行447-448: `spell_curse.update_player_curse()` → container経由
- 行471-472: `spell_world_curse.on_round_start()` → container経由
- 行554-555: `spell_magic.trigger_land_curse()` → container経由
- 行584-587, 594-595: spell_curse_stat, spell_magic初期化処理 → container経由

**影響**: GFM内部のみ変更、外部からの参照は個別変数が残っているため影響なし

#### ✅ ステップ4: GFM経由アクセス残存ファイルの直接参照化（完了）

**修正完了**:
- ✅ `scripts/game_flow/movement_helper.gd` - `board_system.get_meta("spell_world_curse")` パターン適用
- ✅ `scripts/game_flow/target_finder.gd` - systems辞書にspell_player_moveキー追加
- ✅ `scripts/system_manager/game_system_manager.gd` - 全箇所をcontainer経由に変更
  - 595-622行: spell_cost_modifier, spell_world_curse, spell_curse
  - 347-396行: SpellCurseToll/SpellCostModifier初期化
  - 676-739行: 各ハンドラーへのspell参照設定
- ✅ `scripts/battle_system.gd` (setup_systems)
  - spell_draw, spell_magic をcontainer経由で取得
- ✅ `scripts/game_flow/dice_phase_handler.gd`
  - setup()でcontainer.spell_diceを受け取り
- ✅ `scripts/game_flow/dominio_command_handler.gd`
  - set_spell_systems_direct()でcontainer経由のspell参照を受け取り
- ✅ `scripts/game_flow/land_action_helper.gd`
  - handlerパラメータ経由でspell_landにアクセス（handlerはDominioCommandHandler）

**影響**: 外部からのGFM個別変数アクセスを解消、全てcontainer経由に統一

#### ✅ ステップ5: GFMの個別変数削除と旧メソッド廃止（完了）

**修正ファイル**: `scripts/game_flow_manager.gd`, `scripts/system_manager/game_system_manager.gd`

**削除完了**:
- ✅ 個別spell変数10個を削除（spell_draw, spell_magic, spell_land, spell_curse, spell_dice, spell_curse_stat, spell_world_curse, spell_player_move, spell_curse_toll, spell_cost_modifier）
- ✅ `set_spell_systems()` メソッド削除（旧初期化メソッド）
- ✅ `set_spell_container()`内の後方互換ブリッジ削除（226-235行の個別変数展開コード）
- ✅ Spell系preload定数削除（24-33行の10個、GSMでpreload済みのため不要）
- ✅ GSMでの後方互換用代入削除（spell_curse_toll, spell_cost_modifier）
- ✅ `set_spell_container()`のNode型add_child処理をcontainer経由に変更

**検証結果**:
- ✅ grep確認: 個別変数への外部参照ゼロ
- ✅ Godotエディタでのコンパイルチェック: エラー/警告なし

**影響**:
- GFMの個別変数を完全削除、全てcontainer経由に統一
- 後方互換性喪失（意図通り）
- コード削減: 約30行削減（変数宣言10行 + メソッド18行 + preload定数10行 - Node追加処理2行）

#### ✅ ステップ6（オプション）: SpellEffectExecutorのコンテナ直接参照化（完了）

**修正ファイル**:
1. `scripts/game_flow/spell_effect_executor.gd`
2. `scripts/game_flow/spell_phase_handler.gd`
3. `scripts/system_manager/game_system_manager.gd`

**変更内容**:
- ✅ `set_spell_systems(dict)` → `set_spell_container(container)` に変更
- ✅ 内部の個別変数10個（spell_magic, spell_dice等）を削除
- ✅ `var spell_container: SpellSystemContainer` を追加
- ✅ 全メソッド内の個別変数参照を `spell_container.spell_xxx` に置換（15箇所以上）
- ✅ SpellPhaseHandlerの `set_spell_effect_executor_systems(dict)` → `set_spell_effect_executor_container(container)` に変更
- ✅ GSMの `spell_container.to_dictionary()` 呼び出しを削除、containerを直接渡すように変更

**メリット**: 辞書展開処理が完全に不要になり、最後の変換チェーンを解消

**検証結果**:
- ✅ grep確認: `set_spell_systems()` / `to_dictionary()` の呼び出しゼロ
- ✅ コード削減: SpellEffectExecutor約12行削減（個別変数10個 + set_spell_systemsメソッド）

---

## リスクと対策

| リスク | 深刻度 | 対策 |
|-------|--------|------|
| GFM個別変数参照の見落とし | 高 | ステップ2で後方互換ブリッジ設置済み、ステップ5前にgrep再確認 |
| 初期化順序崩壊（spell_curse先行） | 高 | GSMの作成順序は変えない、container.is_valid()でバリデーション |
| Node型spell_*のadd_child管理 | 中 | コンテナはRefCounted（データのみ）、add_childはGFMで継続 |
| staticメソッド内アクセス | 中 | 引数追加 or get_meta()パターン（既存実績あり） |

---

## テスト・検証手順

**各ステップ後の確認**:
1. Godotエディタでコンパイルエラーなし
2. ゲーム起動→ターン進行→スペル使用→バトル→ドミニオコマンドの一連動作確認
3. `spell_container.debug_print_status()`で全12システム設定確認

**重点テスト項目**:
- スペルフェーズ: 各種スペル使用
- アルカナアーツ: stat_boost系（spell_curse_stat経由）
- バトル: ミラーワールド判定（spell_world_curse）
- ドミニオ: 土地属性変更（spell_land + ソリッドワールドチェック）
- ターン終了: 呪いduration更新、通行料支払い
- CPU AI: スペル使用判断

---

## 主要ファイル一覧

**新規作成**:
- `scripts/spells/spell_system_container.gd`

**修正ファイル**:
- `scripts/system_manager/game_system_manager.gd` - コンテナ生成・注入の中核
- `scripts/game_flow_manager.gd` - spell変数集約、個別変数の段階的削除
- `scripts/game_flow/spell_effect_executor.gd` - 辞書展開の置換（ステップ6）
- `scripts/game_flow/movement_helper.gd` - get_meta()パターン適用
- `scripts/game_flow/target_finder.gd` - systems辞書にspell_player_move追加

**参照のみ**:
- `scripts/cpu_ai/cpu_ai_context.gd` - 設計パターンの先行事例

---

## ドキュメント更新（必須）

各ステップ完了後に以下を更新：
- [ ] `docs/implementation/delegation_method_catalog.md` - SpellSystemContainer関連パターン追加
- [ ] `docs/progress/refactoring_next_steps.md` - 進捗更新（本ファイル）
- [ ] `docs/progress/daily_log.md` - 作業記録
- [ ] `CLAUDE.md` の Spell System Architecture セクション - コンテナパターンの記載

---

## 保留中のフェーズ

### フェーズ3-C: UI座標ハードコード解消
- 推定: ~28箇所
- 優先度: 中（大工事のため後回し）
- 内容: ハードコードされたUI座標をviewport相対に変更

---

## 完了したフェーズ（参考）

### ✅ フェーズ1: 残存チェーンアクセス解消
- 32箇所のチェーンアクセスを解消
- 4段チェーン3箇所、3段チェーン15箇所、get_parent()逆走5箇所など

### ✅ フェーズ2: GFM巨大メソッド分離
- GameFlowManager: 982行 → 724行（258行削減、26%削減）
- DicePhaseHandler, TollPaymentHandler, DiscardHandler 新規作成

### ✅ フェーズ3-A: game_stats分離
- 10ファイル、28箇所のチェーンアクセス解消
- 直接参照パターン適用

### ✅ フェーズ3-B: debug_manual_control_all集約
- 14ファイル修正
- DebugSettings Autoload 作成

---

## メモ・議論ポイント

（前回のセッションで詰めた内容をここに記録）

---

**注意**: このファイルは常に最新状態に保つこと。作業計画を詰めたら即座に更新する。
