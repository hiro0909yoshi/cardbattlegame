# 📚 cardbattlegame ドキュメント

このディレクトリには、プロジェクトの設計・進捗・課題に関するすべてのドキュメントが含まれています。

## ⚠️ 重要：必ず確認すること

**チャット開始時・プロジェクト有効化時は、必ずこの`docs/`配下を確認してください。**

プロジェクトの現状把握、設計仕様、進行中の課題など、重要な情報がすべてここに集約されています。

---

## 📁 ディレクトリ構造

```
docs/
├── README.md              # このファイル（ドキュメント全体のインデックス）
├── quick_start/           # クイックスタートガイド ✨NEW
│   └── new_chat_guide.md  # チャット開始時の手順書
├── design/                # 設計ドキュメント
│   ├── design.md          # ゲーム全体の設計
│   ├── skills_design.md   # スキルシステムの詳細設計
│   ├── effect_system.md   # 効果システムの実装仕様
│   ├── defensive_creature_design.md  # 防御型クリーチャー設計 ✨NEW
│   └── turn_end_flow.md   # ターン終了フローの問題点と設計
├── progress/              # 進捗管理
│   ├── daily_log.md               # 日次作業ログ ✨NEW
│   ├── phase1a_progress.md        # Phase 1-A進捗状況
│   ├── phase1a_spec.md            # Phase 1-A仕様書
│   └── refactoring_progress.md    # リファクタリング進捗
├── implementation/        # 実装パターン集 ✨NEW
│   └── implementation_patterns.md # 実装テンプレート
├── refactoring/           # リファクタリング記録
│   ├── battle_system_refactoring.md
│   └── land_command_handler_refactoring.md
└── issues/                # 課題・タスク管理
    ├── issues.md          # 現在の課題（未対応・対応中のみ）
    ├── resolved_issues.md # 解決済み課題のアーカイブ
    ├── tasks.md           # タスク管理
    └── TURN_END_QUICK_FIX.md  # ターン終了処理のクイックフィックス
```

---

## 📖 各ドキュメントの概要

### 🚀 quick_start/ - クイックスタートガイド ✨NEW

#### [new_chat_guide.md](quick_start/new_chat_guide.md)
- **最重要**: チャット開始時に必ず確認
- チャット継続の定型手順
- よく使う情報の場所一覧
- 作業タイプ別のクイックスタート
- トラブルシューティング

**使い方**: 新しいチャットを開始したら、まずこのガイドを確認してください。

---

### 🎨 design/ - 設計ドキュメント

#### [design.md](design/design.md)
- ゲーム全体の基本設計
- ゲームルール、フェーズ、勝利条件
- システムアーキテクチャ

#### [skills_design.md](design/skills_design.md)
- スキルシステムの詳細仕様
- 各スキルの効果・発動条件
- スキル実装のガイドライン

#### [effect_system.md](design/effect_system.md)
- 効果システムの実装仕様
- スペル・アイテム・クリーチャー効果の統一管理
- 一時効果と永続効果の分離設計
- 土地数比例効果の実装例

#### [defensive_creature_design.md](design/defensive_creature_design.md) ✨NEW
- 防御型クリーチャーの詳細設計
- 全21体の実装一覧
- 召喚・移動・侵略制限の仕様
- バトル挙動とテスト方法

#### [turn_end_flow.md](design/turn_end_flow.md)
- ターン終了処理の問題点分析
- 新しいフロー設計
- 移行計画

---

### 📊 progress/ - 進捗管理

#### [daily_log.md](progress/daily_log.md) ✨NEW
- **日次の作業記録**（簡潔版）
- 完了した作業の一覧
- 次のステップの明記
- チャット間の継続性を保つための重要ファイル

**使い方**: 
- 作業終了時に記録
- 次回チャット開始時に確認

#### [phase1a_progress.md](progress/phase1a_progress.md)
- Phase 1-A（基盤整備）の進捗状況
- 完了したタスク
- 今後の予定

#### [phase1a_spec.md](progress/phase1a_spec.md)
- Phase 1-Aの詳細仕様書
- 実装する機能の詳細
- 技術的な実装方針

#### [refactoring_progress.md](progress/refactoring_progress.md)
- コードリファクタリングの進捗
- 分割されたファイルの一覧
- 使用した手法とベストプラクティス

---

### 🛠️ implementation/ - 実装パターン集 ✨NEW

#### [implementation_patterns.md](implementation/implementation_patterns.md)
- よく使う実装パターンのテンプレート集
- クリーチャー実装パターン
- スキル実装パターン
- JSONデータ追加パターン
- バグ修正パターン

**使い方**: 
- 新しい機能を実装する前に該当パターンを確認
- テンプレートをコピーして使用
- 効率的な実装をサポート

---

### 🔧 refactoring/ - リファクタリング記録

#### [battle_system_refactoring.md](refactoring/battle_system_refactoring.md)
- バトルシステムのリファクタリング記録

#### [land_command_handler_refactoring.md](refactoring/land_command_handler_refactoring.md)
- LandCommandHandlerの分割記録
- Static関数パターンの詳細
- 成功要因と教訓

---

### 🐛 issues/ - 課題・タスク管理

#### [issues.md](issues/issues.md)
- **現在の課題のみ**（未対応・対応中）
- 優先度別に整理（Critical/High/Medium/Low）
- 簡潔な記載、対応方法を明記

#### [resolved_issues.md](issues/resolved_issues.md)
- 解決済み課題のアーカイブ
- 詳細な解決方法・経緯を記録
- 過去の問題を参照する際に使用

#### [tasks.md](issues/tasks.md)
- 実装予定のタスク一覧
- タスクの優先順位
- 担当者・期限

#### [TURN_END_QUICK_FIX.md](issues/TURN_END_QUICK_FIX.md)
- ターン終了処理の緊急対応
- クイックフィックスの手順
- 暫定対応の記録

---

## 🔄 ワークフロー

### 新しいチャットを開始するとき ⭐️ 最重要
1. ✅ **`docs/quick_start/new_chat_guide.md`を確認** ← これが最重要！
2. ✅ `docs/progress/daily_log.md`で前回の作業と次のステップを確認
3. ✅ 前回のチャットを引き継ぐメッセージを送信
4. ✅ 必要に応じて`docs/design/`で設計仕様を参照

### チャット終了時
1. ✅ `docs/progress/daily_log.md`に作業内容を記録
2. ✅ 次のステップを明記
3. ✅ 課題があれば`docs/issues/issues.md`に追加

### 新しいissueを追加するとき
1. `docs/issues/issues.md`に追記
2. 必要に応じて個別のissueファイルを作成

### 進捗を更新するとき
1. `docs/progress/phase1a_progress.md`を更新
2. 完了したタスクをマーク

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

#### 更新例
```markdown
### BUG-001: ターン終了処理の重複
- **ステータス**: ~~調査中~~ → **解決済み**
- **修正日**: 2025年10月15日
- **修正内容**: PhaseManager導入により解決
```

---

### 📊 progress/ - 進捗更新
**進捗ドキュメントは、完了したタスクごとに更新してください。**

- ✅ タスク完了時にチェックマークを追加
- 📝 実装した内容を簡潔に記載
- 🐛 発生した問題があれば`issues/`にリンク

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

## 🎯 次のステップ

現在の開発状況：
- ✅ Phase 1-A Day 1-4: 完了
- ✅ コードリファクタリング: 2つの大規模ファイル分割完了
  - TileActionProcessor: 1,284行 → 5ファイル
  - LandCommandHandler: 881行 → 4ファイル
- ✅ 効果システム実装: Phase 1-2完了、Phase 3部分完了
  - スペル効果（マスグロース、ドミナントグロース）
  - アイテム効果（AP/HPバフ・デバフ）
  - 土地数比例効果（アームドパラディン実装）
- ✅ 防御型クリーチャー実装: 完了（全21体）
  - データ設定: `creature_type: "defensive"`
  - 召喚制限: 空き地にのみ配置可能
  - 移動制限: 移動コマンド使用不可
  - 侵略制限: バトルカードとして使用不可
- ✅ チャット継続性改善: 完了 ✨NEW
  - クイックスタートガイド作成
  - 日次作業ログシステム導入
  - 実装パターン集作成
- 🔄 Phase 1-A Day 5: 統合作業中
- 📋 次回: Phase 1-B（レベルアップ改善）

詳細は [phase1a_progress.md](progress/phase1a_progress.md) を参照してください。

---

**最終更新**: 2025年10月23日  
**管理者**: プロジェクトチーム
