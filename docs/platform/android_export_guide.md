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

## USB実機デバッグ（adb）

### 前提条件

1. Android端末の**開発者モード**をON（設定 → デバイスについて → ビルド番号を7回タップ）
2. **USBデバッグ**をON（設定 → 開発者オプション → USBデバッグ）
3. USB-Cケーブルで MacBook Air M4 と端末を接続（充電専用ケーブルは不可、データ通信対応が必要）
4. USBハブ経由でも基本OK（認識しない場合は直接接続を試す）

### adb セットアップ

```bash
# Android SDKのplatform-toolsにadbが含まれている
export PATH="$PATH:$HOME/Library/Android/sdk/platform-tools"

# 接続確認
adb devices
# → デバイスが表示されればOK（初回は端末側で「USBデバッグを許可」ダイアログが出る）
```

### APK直接インストール（Google Play不要）

```bash
# APKをエクスポートして直接インストール（ネット接続不要）
adb install path/to/arcana-conquest.apk
```

> **注意**: AABではなくAPK形式でエクスポートすること。adb installはAABに対応していない。
> エクスポート設定で「Export APK」を選択する。

### パフォーマンスモニタリング

game_3d.gd に組み込み済みのFPSカウンター（画面左上表示 + logcat出力）：

```bash
# Godotのログだけをフィルタして表示
adb logcat -s godot | grep "\[PERF\]"
```

出力例：
```
[PERF] FPS:30 OBJ:150 DRAW:80 VERT:50000
```

| 指標 | 意味 | 目安 |
|------|------|------|
| FPS | フレームレート | 30以上が目標 |
| OBJ | 描画オブジェクト数 | 200以下推奨 |
| DRAW | ドローコール数 | 100以下推奨 |
| VERT | 頂点数 | 少ないほど良い |

### 判断基準

- **FPSが常時低い（15-20）** → ベース描画負荷が高すぎる → ビューポート解像度削減 or シーン簡略化
- **OBJ/DRAWが高い（200+）** → ドローコール過多 → MultiMesh化やメッシュ結合が必要
- **静止時OKでアニメ時だけ落ちる** → 特定のアニメーション処理が重い → 該当コードを特定して最適化

## 現在のモバイル最適化状況（2026-03-29）

### 適用済み（未検証）

- ビューポート `scaling_3d/scale=0.5`（3Dのみ半解像度、2Dはフル）
- 城環境（castle_environment）をモバイルで無効化（`OS.has_feature("mobile")`）
- ワープタイルのパーティクル数 12→6、_process 2フレームスキップ
- BaseTile のブリンク処理 3フレームスキップ
- brick_wall.gdshader 簡略化（fbm削除、トライプラナー3→2方向、法線バンプ削除）
- 草パッチ数 120→30
- Tween リーク修正（target_marker_system, lap_system）
- FPSカウンター＋logcat出力追加（game_3d.gd）

### 次のステップ

1. **USB接続でAPKインストール → FPS数値取得**（最優先）
2. 数値に基づいてボトルネック特定（GPU負荷 or CPU負荷 or ドローコール）
3. 必要に応じてビューポート解像度削減（UI Anchor/Container移行が前提、大作業）
