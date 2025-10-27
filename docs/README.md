# 📚 cardbattlegame ドキュメント

**このファイルの役割**: プロジェクト全体の完全な目次・インデックス

---

## 🚀 新しいチャットを開始したら

1. ✅ **`quick_start/new_chat_guide.md`を確認** ← 最重要！
2. ✅ **`progress/daily_log.md`で前回の作業を確認**
3. ✅ このREADMEで必要なドキュメントの場所を確認
4. ✅ 必要に応じて`.serena/memories/`と`design/`で仕様を確認

---

## 📁 ディレクトリ構造

```
docs/
├── README.md              # このファイル（完全な目次）
├── quick_start/           # クイックスタートガイド
│   └── new_chat_guide.md  # チャット開始時の手順書
├── design/                # 設計ドキュメント
│   ├── design.md          # 詳細仕様（種族、効果システム、UI配置）
│   ├── land_system.md     # 土地システム統合仕様
│   ├── skills_design.md   # スキルシステム全体設計
│   ├── skills/            # 個別スキル仕様書（16ファイル）
│   ├── effect_system.md   # 効果システム実装仕様
│   ├── effect_system_design.md  # 効果システム詳細設計
│   ├── battle_test_tool_design.md  # バトルテストツール
│   ├── turn_end_flow.md   # ターン終了フロー
│   └── defensive_creature_design.md  # 防御型クリーチャー
├── progress/              # 進捗管理
│   └── daily_log.md       # 日次作業ログ（直近のみ）
├── implementation/        # 実装パターン集
│   └── implementation_patterns.md
├── refactoring/           # リファクタリング記録
└── issues/                # 課題・タスク管理
	├── issues.md          # 現在の課題
	├── resolved_issues.md # 解決済み課題
	└── tasks.md           # タスク管理
```

---

## 📖 ドキュメント完全ガイド

### 🧠 メモリファイル（基礎知識）

**場所**: `.serena/memories/`

| ファイル | 内容 | 重要度 |
|---------|------|--------|
| **project_overview.md** | プロジェクト全体像・UIアーキテクチャ・システム分離・完成度 | ⭐️⭐️⭐️ |
| **coding_standards_and_architecture.md** | コーディング規約・命名規則・エラーハンドリング | ⭐️⭐️⭐️ |
| **spell_and_item_implementation_details.md** | スペル・アイテムの実装パターン・データ構造 | ⭐️⭐️ |
| **project_structure_and_docs.md** | ディレクトリ構造・ドキュメント体系 | ⭐️ |

**注**: メモリファイルは自動的に読み込まれます

---

### 🚀 quick_start/ - クイックスタートガイド

#### [new_chat_guide.md](quick_start/new_chat_guide.md) ⭐️ 最重要
- チャット開始時の定型手順
- 必読ドキュメント一覧（メモリファイル含む）
- よく使う情報の場所
- 作業タイプ別のクイックスタート例
- チャット終了時のチェックリスト

---

### 🎨 design/ - 設計ドキュメント

#### コアシステム

| ドキュメント | 内容 |
|-------------|------|
| **[design.md](design/design.md)** | 種族システム・効果システム・開発ツール |
| **[land_system.md](design/land_system.md)** | 隣接判定・土地ボーナス・ダウン状態・領地コマンド・将来計画 |
| **[skills_design.md](design/skills_design.md)** | スキルシステム全体設計・実装済み16種類・適用順序・将来予定 |
| **[item_system.md](design/item_system.md)** | アイテムシステム・アイテムフェーズ・効果タイプ・UI統合 |
| **[battle_system.md](design/battle_system.md)** | BattleParticipant・HP管理・ダメージ消費順序 |

#### 効果システム

| ドキュメント | 内容 |
|-------------|------|
| **[effect_system_design.md](design/effect_system_design.md)** | 設計思想・13パターン・データ構造・適用順序・未決定事項 |
| **[effect_system.md](design/effect_system.md)** | 実装仕様・Phase進捗・実装カード例・コード使用例 |

#### 個別スキル仕様書（17種類）

**場所**: `design/skills/`

| No | スキル | ファイル |
|----|--------|---------|
| 1 | 応援 | [assist_skill.md](design/skills/assist_skill.md) |
| 2 | 2回攻撃 | [double_attack_skill.md](design/skills/double_attack_skill.md) |
| 3 | 先制 | [first_strike_skill.md](design/skills/first_strike_skill.md) |
| 4 | 不屈 | [indomitable_skill.md](design/skills/indomitable_skill.md) |
| 5 | 即死 | [instant_death_skill.md](design/skills/instant_death_skill.md) |
| 6 | 無効化 | [nullify_skill.md](design/skills/nullify_skill.md) |
| 7 | 貫通 | [penetration_skill.md](design/skills/penetration_skill.md) |
| 8 | 強打 | [power_strike_skill.md](design/skills/power_strike_skill.md) |
| 9 | 反射 | [reflect_skill.md](design/skills/reflect_skill.md) |
| 10 | 再生 | [regeneration_skill.md](design/skills/regeneration_skill.md) |
| 11 | 感応 | [resonance_skill.md](design/skills/resonance_skill.md) |
| 12 | 巻物攻撃 | [scroll_attack_skill.md](design/skills/scroll_attack_skill.md) |
| 13 | 援護 | [support_skill.md](design/skills/support_skill.md) |
| 14 | アイテム破壊・盗み | [item_destruction_theft_skill.md](design/skills/item_destruction_theft_skill.md) |
| 15 | 変身 | [transform_skill.md](design/skills/transform_skill.md) |
| 16 | 死者復活 | [revive_skill.md](design/skills/revive_skill.md) |
| 17 | 空地移動・敵地移動 | [vacant_move_skill.md](design/skills/vacant_move_skill.md) |

#### その他システム

| ドキュメント | 内容 |
|-------------|------|
| **[battle_test_tool_design.md](design/battle_test_tool_design.md)** | バトルテストツール完全仕様・大規模テスト・結果表示 |
| **[turn_end_flow.md](design/turn_end_flow.md)** | ターン終了処理フロー・問題点・重複防止機構 |
| **[defensive_creature_design.md](design/defensive_creature_design.md)** | 防御型クリーチャー21体・召喚/移動/侵略制限 |
| **[lap_system.md](design/lap_system.md)** | 周回システム・チェックポイント・ボーナス適用 ✅ |
| **[turn_number_system.md](design/turn_number_system.md)** | ラウンド数カウンター・ラーバキン ✅ |
| **[conditional_stat_buff_system.md](design/conditional_stat_buff_system.md)** | 条件付きバフ38体・永続/一時バフ・実装状況 |
| **[hp_structure.md](design/hp_structure.md)** | HP管理構造・MHP計算・current_hp仕様 ⭐️ |

---

### 📊 progress/ - 進捗管理

| ドキュメント | 内容 |
|-------------|------|
| **[daily_log.md](progress/daily_log.md)** | 日次作業ログ（直近のみ記録、前日以前は削除） |
| **[skill_implementation_status.md](progress/skill_implementation_status.md)** | スキル実装状況一覧 |
| **[battle_test_tool_progress.md](progress/battle_test_tool_progress.md)** | バトルテストツール開発進捗 |

---

### 🛠️ implementation/ - 実装パターン集

| ドキュメント | 内容 |
|-------------|------|
| **[implementation_patterns.md](implementation/implementation_patterns.md)** | クリーチャー・スキル・JSON追加パターン・バグ修正パターン |
| **[land_level_check_implementation.md](implementation/land_level_check_implementation.md)** | 土地レベルチェック実装 |

---

### 🔧 refactoring/ - リファクタリング記録

| ドキュメント | 内容 |
|-------------|------|
| **[battle_system_refactoring.md](refactoring/battle_system_refactoring.md)** | バトルシステムリファクタリング記録 |
| **[land_command_handler_refactoring.md](refactoring/land_command_handler_refactoring.md)** | LandCommandHandler分割・Static関数パターン |

---

### 🐛 issues/ - 課題・タスク管理

| ドキュメント | 内容 |
|-------------|------|
| **[issues.md](issues/issues.md)** | 現在の課題のみ（未対応・対応中）、優先度別 |
| **[resolved_issues.md](issues/resolved_issues.md)** | 解決済み課題のアーカイブ |
| **[tasks.md](issues/tasks.md)** | 実装予定タスク一覧・優先順位 |

---

## 🔄 ワークフロー

### 新しいチャットを開始するとき ⭐️ 最重要
1. ✅ **`docs/quick_start/new_chat_guide.md`を確認** ← これが最重要！
2. ✅ `docs/progress/daily_log.md`で前回の作業と次のステップを確認
3. ✅ 前回のチャットを引き継ぐメッセージを送信
4. ✅ 必要に応じて`docs/design/`で設計仕様を参照

### 新しい機能を追加する
1. 📖 **設計を確認**
   - `docs/design/` - 詳細仕様
   - `.serena/memories/` - 基礎知識・コーディング規約
2. 📝 `docs/issues/tasks.md`にタスク追加
3. 💻 実装
4. ✅ テスト
5. 📊 `docs/progress/daily_log.md`を更新

### チャット終了時
1. ✅ `docs/progress/daily_log.md`に作業内容を記録
2. ✅ 次のステップを明記
3. ✅ 課題があれば`docs/issues/issues.md`に追加

### 新しいissueを追加するとき
1. `docs/issues/issues.md`に追記
2. 必要に応じて個別のissueファイルを作成

---

## ⚠️ 重要：ドキュメント更新ルール

### 🚫 design/ - 勝手に更新しないこと
**設計ドキュメントは、ユーザーの明示的な指示なしに変更してはいけません。**

- ❌ **禁止**: AIが独自判断で設計を変更・追記
- ✅ **OK**: ユーザーから「設計を変更してください」と明示的に指示があった場合のみ
- 📖 **用途**: 実装時の参照用（読み取り専用）

**理由**: 設計はプロジェクトの根幹であり、勝手な変更はシステム全体に影響します。

---

### ✅ issues/ - 適時更新すること
**課題・タスクは、作業の進捗に応じて積極的に更新してください。**

#### 更新すべきタイミング
1. **バグ発見時**: `issues.md`に新しいBUG-XXXを追加
2. **バグ修正時**: ステータスを「解決済み」に更新、修正内容を記載
3. **タスク完了時**: `tasks.md`で該当タスクにチェックマーク
4. **新しい課題発見時**: TECH-XXXとして追記
5. **実装中の気づき**: 注意事項・備考を追記

---

### 📊 progress/ - 進捗更新
**進捗ドキュメントは、完了したタスクごとに更新してください。**

- ✅ タスク完了時にチェックマークを追加
- 📝 実装した内容を簡潔に記載
- 🐛 発生した問題があれば`issues/`にリンク

---

## 🎯 現在の開発状況

### 実装完了
- ✅ スキルシステム: **17種類実装完了**（空地移動・敵地移動追加）
- ✅ 効果システム: Phase 1-3実装完了
- ✅ 防御型クリーチャー: 全21体実装完了
- ✅ バトルテストツール: 基本機能完成
- ✅ 土地システム: 隣接判定・ダウン状態・領地コマンド実装完了
- ✅ 周回システム: 実装完了
- ✅ ラウンド数カウンター: 実装完了
- ✅ HP管理構造: 実装完了

### 次のステップ
- 📋 手札数取得実装（リリス対応）
- 📋 破壊数カウンター実装（ソウルコレクター対応）
- 📋 条件付きバフクリーチャー38体の実装

詳細は [progress/daily_log.md](progress/daily_log.md) を参照してください。

---

## 📝 ドキュメント作成ガイドライン

### 命名規則
- **設計ドキュメント**: `機能名_design.md`
- **進捗ドキュメント**: `フェーズ名_progress.md`
- **課題ドキュメント**: `BUG-XXX.md` または `TECH-XXX.md`

### フォーマット
- Markdown形式
- 見出しは階層構造を明確に
- コードブロックには言語指定
- 更新日時を記載

### 更新時の注意
- 古い情報は削除せず、「~~取り消し線~~」でマーク
- 変更履歴を「## 更新履歴」セクションに記載
- 重要な変更は太字で強調

---

**最終更新**: 2025年10月25日  
**管理者**: プロジェクトチーム
