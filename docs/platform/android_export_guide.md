# Android エクスポート設定ガイド

## 環境構成

### 必要なツール

| ツール | バージョン | インストール方法 | パス |
|--------|-----------|---------------|------|
| JDK | OpenJDK 17 | `brew install openjdk@17` | `/opt/homebrew/opt/openjdk@17` |
| Android SDK | latest | Android Studio経由 | `~/Library/Android/sdk` |
| Android Studio | latest | `brew install --cask android-studio` | アプリケーション |

### Godot エディター設定

**エディター → エディター設定 → エクスポート → Android**

| 設定項目 | 値 |
|---------|---|
| Java SDK Path | `/opt/homebrew/opt/openjdk@17` |
| Android SDK Path | `/Users/andouhiroyuki/Library/Android/sdk` |
| Debug Keystore | デフォルト（自動生成） |

## エクスポートプリセット設定

**プロジェクト → エクスポート → Android**

| 設定項目 | 値 |
|---------|---|
| Gradleビルドを使用 | オン |
| エクスポート形式 | Export AAB |
| 最小SDK | 24 (default) |
| ターゲットSDK | 35 (default) |
| アーキテクチャ | arm64-v8a のみ |

### パッケージ

| 設定項目 | 値 |
|---------|---|
| 固有名 | `com.katsurastudio.arcanaconquest` |
| 名前 | `Arcana Conquest` |
| App Category | Game |

### Keystore（リリース署名）

| 設定項目 | 値 |
|---------|---|
| リリース | `/Users/andouhiroyuki/arcana-conquest-release.keystore` |
| Release User | `arcana-conquest` |
| Release Password | ※別途管理 |

> **重要**: キーストアファイルとパスワードは絶対に紛失しないこと。紛失するとアプリの更新ができなくなる。

### Androidビルドテンプレート

- **プロジェクト → Androidビルドテンプレートのインストール** を事前に実行する必要がある
- プロジェクト内に `android/` ディレクトリが生成される

## エクスポート手順

1. **プロジェクト → エクスポート** を開く
2. Android プリセットを選択
3. **プロジェクトのエクスポート** をクリック
4. 保存先を指定（例: `~/arcana-conquest.aab`）
5. モード: **リリース** を選択
6. Gradle ビルドが実行される（初回はダウンロードあり）
7. 完了後 `.aab` ファイルが生成される

## トラブルシューティング

### 「AABのエクスポートはGradleビルドが有効な場合のみ」
→ Gradleビルドを使用をオンにする

### 「Androidビルドテンプレートがインストールされていません」
→ プロジェクト → Androidビルドテンプレートのインストール

### keytoolが見つからない
→ フルパスで実行: `/opt/homebrew/opt/openjdk@17/bin/keytool`

### Java Runtime が見つからない
→ brew版はPATHに自動追加されない。Godotのエディター設定でJava SDK Pathを指定する
