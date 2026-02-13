# 📚 cardbattlegame ドキュメント

**最終更新**: 2026年2月13日

---

## 🚀 新しいチャットを開始したら

1. ✅ **`quick_start/new_chat_guide.md`を確認**
2. ✅ **`progress/daily_log.md`で前回の作業を確認**
3. ✅ このREADMEで必要なドキュメントの場所を確認

---

## 📁 ディレクトリ構造

```
docs/
├── README.md              # このファイル（完全な目次）
├── quick_start/           # クイックスタートガイド
│   └── new_chat_guide.md  # チャット開始時の手順書
├── design/                # 設計ドキュメント
│   ├── skills/            # 個別スキル仕様書（29ファイル）
│   └── spells/            # 個別スペル効果仕様書（20ファイル）
├── implementation/        # 実装リファレンス
│   ├── implementation_patterns.md   # 実装パターン
│   ├── delegation_method_catalog.md # 委譲メソッドカタログ
│   └── signal_catalog.md            # シグナルカタログ
├── progress/              # 進捗管理
│   └── daily_log.md       # 日次作業ログ
└── issues/                # 課題・タスク管理
	├── issues.md          # 現在の課題
	├── resolved_issues.md # 解決済み課題
	└── tasks.md           # タスク管理
```

---

## 📖 設計ドキュメント一覧

### コアシステム

| ドキュメント | 内容 |
|-------------|------|
| [design.md](design/design.md) | 種族システム・効果システム・開発ツール |
| [tile_system.md](design/tile_system.md) | タイルタイプ・TileHelper・地形効果・レベルシステム |
| [tile_creature_separation_plan.md](design/tile_creature_separation_plan.md) | タイル・クリーチャー分離設計 |
| [land_system.md](design/land_system.md) | 隣接判定・土地ボーナス・ダウン状態・ドミニオオーダー |
| [toll_system.md](design/toll_system.md) | 通行料計算・呪い効果 |
| [map_system.md](design/map_system.md) | マップシステム設計 |

### バトルシステム

| ドキュメント | 内容 |
|-------------|------|
| [battle_system.md](design/battle_system.md) | BattleParticipant・戦闘フロー |
| [hp_structure.md](design/hp_structure.md) | HP管理構造・MHP計算・current_hp仕様 |
| [battle_test_tool_design.md](design/battle_test_tool_design.md) | バトルテストツール仕様 |

### スキル・スペル・アイテム

| ドキュメント | 内容 |
|-------------|------|
| [skills_design.md](design/skills_design.md) | スキルシステム全体設計 |
| [spells_design.md](design/spells_design.md) | スペル効果システム全体設計 |
| [mystic_arts.md](design/mystic_arts.md) | アルカナアーツシステム（3方式対応） |
| [item_system.md](design/item_system.md) | アイテムシステム |
| [合成.md](design/合成.md) | 合成システム |

### 効果システム

| ドキュメント | 内容 |
|-------------|------|
| [effect_system.md](design/effect_system.md) | 実装仕様・Phase進捗 |
| [effect_system_design.md](design/effect_system_design.md) | 設計思想・データ構造 |
| [conditional_stat_buff_system.md](design/conditional_stat_buff_system.md) | 条件付きバフシステム（実装完了） |
| [condition_patterns_catalog.md](design/condition_patterns_catalog.md) | 条件分岐パターンカタログ |

### ゲームフロー

| ドキュメント | 内容 |
|-------------|------|
| [turn_end_flow.md](design/turn_end_flow.md) | ターン終了処理フロー |
| [lap_system.md](design/lap_system.md) | 周回システム・チェックポイント |
| [turn_number_system.md](design/turn_number_system.md) | ラウンド数カウンター |
| [destroy_counter_correction.md](design/destroy_counter_correction.md) | 破壊数カウンター（LapSystem内） |

### UI・操作

| ドキュメント | 内容 |
|-------------|------|
| [global_navigation_buttons.md](design/global_navigation_buttons.md) | GlobalActionButtons統合方式 |
| [info_panel.md](design/info_panel.md) | 情報パネル |
| [player_info_panel.md](design/player_info_panel.md) | プレイヤー情報パネル |
| [card_info_panels.md](design/card_info_panels.md) | カード情報パネル |

### カード・デッキ

| ドキュメント | 内容 |
|-------------|------|
| [card_system_multi_deck.md](design/card_system_multi_deck.md) | マルチデッキシステム |
| [cpu_deck_system.md](design/cpu_deck_system.md) | CPUデッキシステム |

### CPU・クエスト

| ドキュメント | 内容 |
|-------------|------|
| [cpu_ai_design.md](design/cpu_ai_design.md) | CPU AI設計（概念） |
| [cpu_ai_understanding.md](design/cpu_ai_understanding.md) | CPU AI理解メモ |
| [cpu_spell_ai_spec.md](specs/cpu_spell_ai_spec.md) | CPU スペル/アルカナアーツAI仕様 |
| [cpu_battle_ai_spec.md](specs/cpu_battle_ai_spec.md) | CPU バトル判断仕様 |
| [quest_system_design.md](design/quest_system_design.md) | クエストシステム設計 |

### クリーチャー管理

| ドキュメント | 内容 |
|-------------|------|
| [creatures_tasks.md](design/creatures_tasks.md) | クリーチャー実装タスク |
| [creatures_unimplemented.md](design/creatures_unimplemented.md) | 未実装クリーチャー |
| [defensive_creature_design.md](design/defensive_creature_design.md) | 防御型クリーチャー設計 |
| [spells_tasks.md](design/spells_tasks.md) | スペル実装タスク |

### リファクタリング設計

| ドキュメント | 内容 |
|-------------|------|
| [game_system_manager_design.md](design/refactoring/game_system_manager_design.md) | GameSystemManager設計 |
| [initialization_consolidation_plan.md](design/refactoring/initialization_consolidation_plan.md) | 初期化統合計画（Phase 1-3） |

### 実装リファレンス

| ドキュメント | 内容 |
|-------------|------|
| [implementation_patterns.md](implementation/implementation_patterns.md) | 実装パターン・テンプレート |
| [delegation_method_catalog.md](implementation/delegation_method_catalog.md) | 委譲メソッドカタログ |
| [signal_catalog.md](implementation/signal_catalog.md) | シグナルカタログ（192シグナル） |

---

## 📂 個別スキル仕様書（29ファイル）

**場所**: `design/skills/`

| スキル | ファイル |
|--------|---------|
| 応援 | [assist_skill.md](design/skills/assist_skill.md) |
| 戦闘終了時効果 | [battle_end_effects_skill.md](design/skills/battle_end_effects_skill.md) |
| クリーチャー召喚 | [creature_spawn_skill.md](design/skills/creature_spawn_skill.md) |
| 呪い拡散 | [curse_spread_skill.md](design/skills/curse_spread_skill.md) |
| 2回攻撃 | [double_attack_skill.md](design/skills/double_attack_skill.md) |
| 先制 | [first_strike_skill.md](design/skills/first_strike_skill.md) |
| 不屈 | [indomitable_skill.md](design/skills/indomitable_skill.md) |
| 即死 | [instant_death_skill.md](design/skills/instant_death_skill.md) |
| アイテムクリーチャー | [item_creature_skill.md](design/skills/item_creature_skill.md) |
| アイテム破壊・盗み | [item_destruction_theft_skill.md](design/skills/item_destruction_theft_skill.md) |
| アイテム復帰 | [item_return_skill.md](design/skills/item_return_skill.md) |
| 地形効果 | [land_effects_skill.md](design/skills/land_effects_skill.md) |
| 合体 | [merge_skill.md](design/skills/merge_skill.md) |
| 無効化 | [nullify_skill.md](design/skills/nullify_skill.md) |
| 死亡時効果 | [on_death_effects.md](design/skills/on_death_effects.md) |
| 貫通 | [penetration_skill.md](design/skills/penetration_skill.md) |
| 強打 | [power_strike_skill.md](design/skills/power_strike_skill.md) |
| 反射 | [reflect_skill.md](design/skills/reflect_skill.md) |
| 再生 | [regeneration_skill.md](design/skills/regeneration_skill.md) |
| 感応 | [resonance_skill.md](design/skills/resonance_skill.md) |
| 死者復活 | [revive_skill.md](design/skills/revive_skill.md) |
| 巻物攻撃 | [scroll_attack_skill.md](design/skills/scroll_attack_skill.md) |
| 援護 | [support_skill.md](design/skills/support_skill.md) |
| 変身 | [transform_skill.md](design/skills/transform_skill.md) |
| 空地移動・敵地移動 | [vacant_move_skill.md](design/skills/vacant_move_skill.md) |
| 遺産 | [遺産.md](design/skills/遺産.md) |
| EP獲得・奪取 | [EP獲得奪取.md](design/skills/EP獲得奪取.md) |
| 密命カード | [密命カード.md](design/skills/密命カード.md) |
| 通行料操作 | [通行料操作.md](design/skills/通行料操作.md) |

---

## 📂 個別スペル効果仕様書（20ファイル）

**場所**: `design/spells/`

| スペル効果 | ファイル |
|-----------|---------|
| クリーチャー交換 | [クリーチャー交換.md](design/spells/クリーチャー交換.md) |
| クリーチャー操作 | [クリーチャー操作.md](design/spells/クリーチャー操作.md) |
| クリーチャー手札戻し | [クリーチャー手札戻し.md](design/spells/クリーチャー手札戻し.md) |
| クリーチャー配置 | [クリーチャー配置.md](design/spells/クリーチャー配置.md) |
| ステータス増減 | [ステータス増減.md](design/spells/ステータス増減.md) |
| スペル借用 | [スペル借用.md](design/spells/スペル借用.md) |
| ダイス操作 | [ダイス操作.md](design/spells/ダイス操作.md) |
| ダメージ操作 | [ダメージ操作.md](design/spells/ダメージ操作.md) |
| プレイヤー移動 | [プレイヤー移動.md](design/spells/プレイヤー移動.md) |
| 世界呪い | [世界呪い.md](design/spells/世界呪い.md) |
| 呪い効果 | [呪い効果.md](design/spells/呪い効果.md) |
| 呪い除去 | [呪い除去.md](design/spells/呪い除去.md) |
| 変身 | [変身.md](design/spells/変身.md) |
| 手札操作 | [手札操作.md](design/spells/手札操作.md) |
| 戦闘制限呪い | [戦闘制限呪い.md](design/spells/戦闘制限呪い.md) |
| 通行料呪い | [通行料呪い.md](design/spells/通行料呪い.md) |
| 防魔 | [防魔.md](design/spells/防魔.md) |
| ドミニオ変更 | [ドミニオ変更.md](design/spells/ドミニオ変更.md) |
| EP増減 | [EP増減.md](design/spells/EP増減.md) |
| 行動制限 | [行動制限.md](design/spells/行動制限.md) |

---

## 🧠 メモリファイル

**場所**: `.serena/memories/`

| ファイル | 内容 |
|---------|------|
| project_overview.md | プロジェクト全体像・システム構成 |
| coding_standards_and_architecture.md | コーディング規約・命名規則 |
| scripts_directory_structure.md | scriptsディレクトリ構造 |
| creatures_tasks_document.md | クリーチャータスク管理 |
| efficient_code_search_methods.md | コード検索方法 |

---

## 🎯 実装完了状況

### ✅ 完了済み

- **スキルシステム**: 29種類のスキル仕様書完成、実装完了
- **スペルシステム**: 20カテゴリのスペル効果仕様書完成、大部分実装完了
- **アルカナアーツシステム**: 3方式対応（既存スペル参照/アルカナアーツ専用スペル/直接effects）
- **呪いシステム**: クリーチャー/プレイヤー/世界呪の3種類実装完了
- **効果システム**: Phase 1-3実装完了
- **条件付きバフ**: 全クリーチャー実装完了
- **防御型クリーチャー**: 全21体実装完了
- **バトルテストツール**: 基本機能完成
- **土地システム**: 隣接判定・ダウン状態・ドミニオオーダー実装完了
- **通行料システム**: 計算・呪い効果実装完了
- **周回システム**: チェックポイント・ボーナス適用実装完了
- **ラウンド数カウンター**: 実装完了
- **破壊数カウンター**: LapSystem内で実装完了
- **HP管理構造**: current_hp状態値方式で実装完了
- **マルチデッキ**: プレイヤー別デッキ管理実装完了
- **GlobalActionButtons**: UI統合方式実装完了

### 📋 進行中・計画中

- クエストシステムの拡張
- CPU AI の高度化
- 一部未実装クリーチャーの対応

詳細は [progress/daily_log.md](progress/daily_log.md) を参照。

---

## 🐛 課題・タスク管理

| ドキュメント | 内容 |
|-------------|------|
| [issues.md](issues/issues.md) | 現在の課題（未対応・対応中） |
| [resolved_issues.md](issues/resolved_issues.md) | 解決済み課題アーカイブ |
| [tasks.md](issues/tasks.md) | 実装予定タスク一覧 |

---

## ⚠️ ドキュメント更新ルール

### design/ - 設計ドキュメント
- ❌ **禁止**: AIが独自判断で設計を変更
- ✅ **OK**: ユーザーから明示的に指示があった場合のみ変更

### issues/ - 課題・タスク
- ✅ バグ発見時・修正時に積極的に更新
- ✅ タスク完了時にチェックマーク追加

### progress/ - 進捗
- ✅ 作業完了ごとに更新

---

## 📝 命名規則

- **設計ドキュメント**: `機能名_design.md` または `機能名.md`
- **スキル仕様書**: `スキル名_skill.md` または日本語名
- **スペル仕様書**: 日本語カテゴリ名

---

**管理者**: プロジェクトチーム
