# 🎮 cardbattlegame

Godot 4.3で開発中の3Dカードバトルゲーム

## ⚠️ 重要：開発者へ

**このプロジェクトで作業を開始する前に、必ず [`docs/README.md`](docs/README.md) を確認してください。**

すべての設計ドキュメント、進捗状況、既知の課題が`docs/`ディレクトリに集約されています。

---

## 🚀 クイックスタート

### プロジェクトを開く
```bash
# Godot 4.3で開く
godot project.godot
```

### ドキュメントを確認
```bash
# ドキュメント一覧
ls -la docs/

# ドキュメントインデックス
cat docs/README.md
```

---

## 📚 ドキュメント

| カテゴリ | 説明 | リンク |
|---------|------|--------|
| 📖 **全体ガイド** | ドキュメント全体のインデックス | [`docs/README.md`](docs/README.md) |
| 🎨 **設計** | ゲーム設計・システム仕様 | [`docs/design/`](docs/design/) |
| 📊 **進捗** | 開発進捗・フェーズ管理 | [`docs/progress/`](docs/progress/) |
| 🐛 **課題** | バグ・タスク管理 | [`docs/issues/`](docs/issues/) |

---

## 🛠️ 技術スタック

- **Engine**: Godot 4.3
- **Language**: GDScript
- **Platform**: Windows / macOS / Linux

---

## 📂 プロジェクト構造

```
cardbattlegame/
├── docs/              # 📚 ドキュメント（必ず確認！）
│   ├── README.md      # ドキュメントインデックス
│   ├── design/        # 設計ドキュメント
│   ├── progress/      # 進捗管理
│   └── issues/        # 課題管理
├── scripts/           # GDScriptファイル
│   ├── game_flow/     # ゲームフロー管理
│   ├── skills/        # スキルシステム
│   ├── tiles/         # タイル関連
│   └── ui_components/ # UIコンポーネント
├── scenes/            # Godotシーン
├── assets/            # アセット（画像・音声等）
├── data/              # ゲームデータ（JSON等）
└── models/            # 3Dモデル
```

---

## 🎯 現在の開発状況

- ✅ **Phase 1-A 完全完了**: 領地コマンドシステム実装済み
  - ✅ レベルアップ機能
  - ✅ クリーチャー移動機能
  - ✅ クリーチャー交換機能
- ✅ **TECH-002 完了**: アクション処理フラグ統一
- 📋 **次回**: Phase 1-B以降の機能実装

詳細は [`docs/progress/phase1a_progress.md`](docs/progress/phase1a_progress.md) を確認してください。

---

## 🤝 開発フロー

### 新しい機能を追加する
1. 📖 `docs/design/`で設計を確認
2. 📝 `docs/issues/tasks.md`にタスク追加
3. 💻 実装
4. ✅ テスト
5. 📊 `docs/progress/`を更新

### バグを修正する
1. 🐛 `docs/issues/issues.md`で既知のバグを確認
2. 🔍 問題を特定
3. 🛠️ 修正
4. ✅ テスト
5. ✓ `docs/issues/issues.md`を更新（ステータス: 解決済み）

---

## 📌 重要なリマインダー

- 🔔 **チャット開始時**: `docs/`を必ず確認
- 🔔 **プロジェクト有効化時**: `docs/README.md`を読む
- 🔔 **実装前**: 設計ドキュメントを参照
- 🔔 **進捗更新**: `docs/progress/`を更新

---

## 📄 ライセンス

（ライセンス情報をここに記載）

---

**最終更新**: 2025年10月16日
