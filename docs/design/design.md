# 🎮 カルドセプト風カードバトルゲーム - 設計書

> **完全な目次は [README.md](../README.md) を参照してください**

このドキュメントには以下の詳細仕様が含まれています：
- 新システム詳細仕様（種族、効果システム）
- UI配置ガイドライン
- 開発・テストツール

> **注**: 基本的なシステムアーキテクチャ、コーディング規約、バトルフローなどは`.serena/memories/`のメモリファイルを参照してください。  
> **重要な実装ルール**: `.serena/memories/coding_standards_and_architecture.md`を必ず参照してください。

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

#### 設計ドキュメント
- **[effect_system_design.md](effect_system_design.md)** - 設計思想と検討事項
  - 効果の種類13パターンの詳細設計
  - データ構造設計（creature_data、effectオブジェクト）
  - HP/AP管理構造（BattleParticipant）
  - 効果の適用順序・ダメージ消費順序
  - 未決定事項・今後の検討事項
  - 変身・死者復活効果の設計

- **[effect_system.md](effect_system.md)** - 実装仕様と進捗
  - 実装完了状況（Phase 1-3の進捗）
  - 実装されたカード例（アームドパラディン、アーメット）
  - コード使用例（スペル追加、マスグロース等）
  - 実装フェーズ計画

#### 簡易概要
- **4種類の効果**: バトル中のみ／一時効果（移動で消える）／永続効果／土地数比例
- **データ管理**: `base_up_hp/ap`, `permanent_effects`, `temporary_effects`
- **計算順序**: 基礎値 → 永続 → 一時 → 土地 → アイテム → 感応 → 強打

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
---

## 開発・テストツール

### バトルテストツール

> **詳細**: [battle_test_tool_design.md](battle_test_tool_design.md) - バトルテストツール完全仕様

#### 概要
スペル・アイテム・スキルの効果を網羅的にテストし、バランス調整・バグ検出を行うツール。

#### 主要機能
- **大規模テスト**: 最大40,000バトルの自動実行（約6-7分）
- **柔軟な設定**: ID入力式選択、プリセット機能（属性別・スキル別）
- **条件設定**: 土地レベル、隣接判定、所有者設定
- **結果表示**: 勝率テーブル、統計情報、詳細ログウィンドウ
- **スキル記録**: 発動スキル・付与スキルの追跡

#### 使用場所
`scenes/test/battle_test_ui.tscn`

#### 典型的な使用例
1. 新スキル実装後の動作確認
2. アイテムバランス調整
3. クリーチャーの勝率分析
4. バグの再現と検証

---

**最終更新**: 2025年10月25日  
**完全な目次・関連ドキュメント**: [README.md](../README.md)を参照
**重要な実装ルール**: `.serena/memories/coding_standards_and_architecture.md`を参照
