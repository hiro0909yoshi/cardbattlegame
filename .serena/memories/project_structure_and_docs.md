# cardbattlegame プロジェクト構造とドキュメント管理

## ⚠️ 重要：必須確認事項

**チャット開始時・プロジェクト有効化時は、必ず以下を実行してください：**

```bash
# 1. ドキュメントディレクトリ確認
ls -la docs/

# 2. ドキュメントインデックス確認
cat docs/README.md

# 3. 進捗状況確認
cat docs/progress/phase1a_progress.md

# 4. 既知の課題確認（現在対応中のもののみ）
cat docs/issues/issues.md
```

---

## 📁 プロジェクト構造

```
cardbattlegame/
├── README.md              # プロジェクト全体の概要
├── docs/                  # 📚 全ドキュメント（必ず確認！）
│   ├── README.md          # ドキュメント全体のインデックス
│   ├── design/            # 🎨 設計ドキュメント（読み取り専用！）
│   │   ├── design.md          # ゲーム全体設計
│   │   ├── skills_design.md   # スキルシステム詳細
│   │   └── turn_end_flow.md   # ターン終了フロー設計
│   ├── progress/          # 📊 進捗管理（適時更新）
│   │   ├── phase1a_progress.md  # Phase 1-A進捗
│   │   └── phase1a_spec.md      # Phase 1-A仕様書
│   └── issues/            # 🐛 課題・タスク管理（適時更新！）
│       ├── issues.md            # 現在の課題（未対応・対応中のみ）
│       ├── resolved_issues.md   # 解決済み課題のアーカイブ
│       ├── tasks.md             # タスク管理
│       └── TURN_END_QUICK_FIX.md # 緊急対応記録
├── scripts/               # GDScriptファイル
│   ├── game_flow/         # ゲームフロー管理
│   │   ├── land_command_handler.gd       # 領地コマンド統合（352行）
│   │   ├── land_selection_helper.gd      # 土地選択処理（177行）
│   │   ├── land_action_helper.gd         # アクション実行（333行）
│   │   ├── land_input_helper.gd          # 入力処理（126行）
│   │   ├── tile_action_processor.gd      # タイルアクション統合管理（404行）
│   │   ├── summon_action_executor.gd     # 召喚アクション（287行）
│   │   ├── level_action_executor.gd      # レベルアップアクション（153行）
│   │   ├── exchange_action_executor.gd   # 交換アクション（217行）
│   │   └── tile_input_handler.gd         # タイル入力処理（223行）
│   ├── skills/            # スキルシステム
│   ├── tiles/             # タイル関連
│   └── ui_components/     # UIコンポーネント
├── scenes/                # Godotシーン
├── assets/                # アセット
├── data/                  # ゲームデータ（JSON）
└── models/                # 3Dモデル
```

---

## 🔧 コードアーキテクチャ

### 大規模ファイルの分割パターン

#### 成功例1: TileActionProcessor（2025年10月15日）

元：1,284行 → 分割後合計：1,284行（増加0%）

- **tile_action_processor.gd**: 統合管理（404行）
- **summon_action_executor.gd**: 召喚処理（287行）
- **level_action_executor.gd**: レベルアップ処理（153行）
- **exchange_action_executor.gd**: 交換処理（217行）
- **tile_input_handler.gd**: 入力処理（223行）

#### 成功例2: LandCommandHandler（2025年10月21日）

元：881行 → 分割後合計：988行（**増加12%のみ！**）

- **land_command_handler.gd**: 統合管理（352行）
- **land_selection_helper.gd**: 土地選択処理（177行）
- **land_action_helper.gd**: アクション実行（333行）
- **land_input_helper.gd**: 入力処理（126行）

**成功の要因：**
1. **Static関数パターン**: ヘルパークラスをstatic関数の集まりとして実装
2. **インスタンス不要**: `new()`や`add_child()`不要
3. **シグナル接続不要**: コールバック地獄を回避
4. **状態の一元管理**: 全ての状態は`handler`経由でアクセス
5. **余計なコードゼロ**: 後方互換性メソッドや不要なシグナルなし

**増加した107行の内訳：**
- クラス定義: 3行
- ラッパー関数: 約100行（`func xxx(): return Helper.xxx(self)`形式）
- コメント: 4行

**バックアップ：**
- `tile_action_processor_old.gd`（元ファイル保存済み）
- `land_command_handler_old.gd.disabled`（元ファイル保存済み）

**分割の原則：**
1. **責任の分離**: 選択・実行・入力を明確に分離
2. **Static関数**: インスタンス生成不要、シグナル接続不要
3. **最小限の増加**: 機能そのまま、必要最小限のコードのみ追加
4. **後方互換性**: 外部インターフェースは完全に維持

---

## 🚨 ドキュメント更新ルール（超重要）

### 🚫 design/ - 勝手に更新しないこと
**設計ドキュメントは、ユーザーの明示的な指示なしに変更してはいけません。**

- ❌ **絶対禁止**: AIが独自判断で設計を変更・追記
- ✅ **OK**: ユーザーから「設計を変更してください」と明示的に指示があった場合のみ
- 📖 **用途**: 実装時の参照用（読み取り専用）

**理由**: 設計はプロジェクトの根幹であり、勝手な変更はシステム全体に影響します。

---

### ✅ issues/ - 適時更新すること
**課題・タスクは、作業の進捗に応じて積極的に更新してください。**

#### issues.mdの構成（2025/10/15改善）
- **issues.md**: 現在対応中・未対応の課題のみ（シンプル・簡潔）
- **resolved_issues.md**: 解決済み課題のアーカイブ（詳細記録）

#### 更新すべきタイミング
1. **バグ発見時**: `issues.md`に新しいBUG-XXXを追加
2. **バグ修正時**: 
   - `issues.md`から該当バグを削除
   - `resolved_issues.md`に移動（解決日・対応方法を追記）
   - `issues.md`の「最近解決した課題」セクションに簡潔に追記
3. **タスク完了時**: `tasks.md`で該当タスクにチェックマーク
4. **新しい課題発見時**: TECH-XXXとして`issues.md`に追記
5. **実装中の気づき**: 注意事項・備考を追記

#### issues.mdの記載方針
- **簡潔に**: 症状・原因・対応方法を各1-2行で
- **優先度明確に**: Critical/High/Medium/Lowで分類
- **ステータス明確に**: 🚧調査中 / ⚠️要対応 / 📋計画中 / ✅解決済み
- **詳細は不要**: 詳しい経緯はresolved_issues.mdに記録

---

### 📊 progress/ - 進捗更新
**進捗ドキュメントは、完了したタスクごとに更新してください。**

- ✅ タスク完了時にチェックマークを追加
- 📝 実装した内容を簡潔に記載
- 🐛 発生した問題があれば`issues/`にリンク

---

## 🔄 ワークフロー

### 新規チャット開始時
1. ✅ プロジェクト有効化: `serena:activate_project cardbattlegame`
2. ✅ `docs/README.md`確認
3. ✅ `docs/progress/`で現在の進捗把握
4. ✅ `docs/issues/issues.md`で現在対応中の問題確認（シンプルになった！）
5. ✅ `docs/design/`で必要な設計仕様参照（読み取りのみ）

### 実装前
- 必ず該当する`docs/design/`のドキュメントを確認
- 既存の課題を`docs/issues/issues.md`で確認（見やすくなった！）

### 実装中
- バグ発見 → すぐに`docs/issues/issues.md`に簡潔に追記
- 新しい気づき → `docs/issues/issues.md`に備考追加

### 実装後
- `docs/progress/`を更新（完了したタスクをマーク）
- `docs/issues/issues.md`を更新：
  - 解決した課題を削除
  - `resolved_issues.md`に移動（詳細記録）
  - 「最近解決した課題」セクションに簡潔に追記
- **design/は更新しない**（ユーザー指示がない限り）

---

## 📝 重要なドキュメント

| ファイル | 内容 | 確認頻度 | 更新権限 |
|---------|------|----------|----------|
| `docs/README.md` | ドキュメント全体のガイド | 毎回 | 読み取りのみ |
| `docs/progress/phase1a_progress.md` | 現在の進捗 | 毎回 | 適時更新 |
| `docs/issues/issues.md` | **現在の課題のみ** | 実装前/後 | **適時更新** |
| `docs/issues/resolved_issues.md` | 解決済みアーカイブ | 参照時 | 解決時に追記 |
| `docs/design/design.md` | ゲーム全体設計 | 仕様確認時 | **更新禁止** |
| `docs/design/skills_design.md` | スキルシステム | スキル実装時 | **更新禁止** |

---

## 🎯 現在の開発状況（2025年10月21日時点）

- ✅ Phase 1-A Day 1-4: 基盤整備完了
  - PhaseManager作成
  - ダウン状態システム実装
  - 領地コマンドUI基盤実装
- ✅ コード品質改善: Godot警告解決
- ✅ ドキュメント整理: docs/構造化、issues.md簡潔化
- ✅ **コードリファクタリング**:
  - TileActionProcessor分割完了（1,284行 → 5ファイル、増加0%）
  - LandCommandHandler分割完了（881行 → 4ファイル、増加12%）
- 🔄 Phase 1-A Day 5: システム統合作業中
- 📋 次回: Phase 1-B レベルアップ改善

詳細: `docs/progress/phase1a_progress.md`

---

## ⚠️ 注意事項

### 絶対に忘れないこと
1. **チャット開始時**: `docs/`を必ず確認
2. **実装前**: 設計ドキュメント参照（読み取りのみ）
3. **バグ発見時**: `docs/issues/issues.md`に即座に**簡潔に**追記
4. **タスク完了時**: `docs/progress/`と`docs/issues/`を更新
5. **設計変更**: ユーザーの明示的指示がない限り`docs/design/`を変更しない

### ドキュメント更新の基本ルール
- 古い情報は削除せず「~~取り消し線~~」
- 更新日時を記載
- **issues.mdは簡潔に**、詳細はresolved_issues.mdへ
- **design/は読み取り専用、issues/は積極的に更新**

---

**作成日**: 2025年10月15日  
**最終更新**: 2025年10月21日（LandCommandHandler分割成功）
