# current_hp 直接削るシステムへの移行計画 - ドキュメント作成完了 (2025-11-17)

## 作成されたドキュメント

### 1. hp_system_refactoring_plan.md
**目的**: リファクタリング全体計画書
**内容**:
- 現在のシステムと提案するシステムの比較
- データ構造の変更
- 実装の変更箇所（7項目）
- 修正手順（6ステップ）
- テスト項目（複数カテゴリ）
- ドキュメント更新項目
- 実装ステータストラッキング表
- 注意事項・リスク
**ファイルパス**: `docs/design/hp_system_refactoring_plan.md`

### 2. hp_system_refactoring_implementation_guide.md
**目的**: 実装時の詳細ガイド
**内容**:
- 各修正箇所の完全なコード例
- 実装時のチェックリスト
- トラブルシューティング
- 修正前後の比較
**ファイルパス**: `docs/design/hp_system_refactoring_implementation_guide.md`

## ドキュメントの主要内容

### hp_system_refactoring_plan.md の内容

#### 現在のシステム
```
base_hp（状態値）+ base_up_hp（定数） + ボーナス = current_hp（計算値）
↓
ダメージ時：base_hp を削る
↓
update_current_hp() で再計算
```

#### 提案するシステム
```
base_hp（定数）+ base_up_hp（定数）+ ボーナス = 表示用MHP参考値
↓
ダメージ時：current_hp を直接削る
↓
current_hp が状態値になる
```

### 実装の変更箇所（7項目）

1. **BattleParticipant コンストラクタ** 
   - update_current_hp() 呼び出し削除

2. **BattleParticipant.take_damage()**
   - base_hp -= → current_hp -= に変更
   - damage_breakdown キー変更
   - update_current_hp() 削除

3. **BattleParticipant.take_mhp_damage()**
   - base_hp -= → current_hp -= に変更
   - update_current_hp() 削除

4. **BattleParticipant.update_current_hp()**
   - メソッド全体を廃止

5. **battle_preparation.gd prepare_participants()**
   - base_hp 計算削除
   - current_hp 直接設定
   - update_current_hp() 削除

6. **バトル後HP保存処理**
   - base_hp + base_up_hp → current_hp に変更
   - 2ファイル（battle_special_effects.gd, battle_system.gd）

7. **ダメージ集計修正**
   - damage_breakdown キー参照更新
   - battle_execution.gd

### 修正手順（6ステップ）

1. BattleParticipant クラスの修正（30分）
2. battle_preparation.gd の修正（20分）
3. バトル後処理の修正（15分）
4. ダメージ集計の修正（15分）
5. 全スクリプトの確認（30分）
6. テスト実行（1時間）
**合計見積時間**: 約2.5時間

### テスト項目

4つのカテゴリで合計15項目以上のテスト項目を記載：
- 基本動作（4項目）
- HP管理（4項目）
- ダメージ処理（4項目）
- 戦闘終了処理（3項目）
- 特殊スキル（2項目）
- UI表示（2項目）

### ドキュメント更新項目

修正後に更新が必要なドキュメント：
1. hp_structure.md
2. effect_system_design.md
3. battle_system.md
4. on_death_effects.md
5. 新規完了報告書

## hp_system_refactoring_implementation_guide.md の内容

### 実装の詳細コード

各修正箇所について、完全な実装例を記載：
- コンストラクタ修正（確認項目付き）
- take_damage() 修正（完全なコード例）
- take_mhp_damage() 修正（完全なコード例）
- update_current_hp() 削除方法
- battle_preparation.gd 修正（完全なコード例）
- バトル後処理修正（2ファイル）
- ダメージ集計修正

### 修正時の確認チェックリスト

5つの Phase ごとにチェックリスト：
- Phase 1: BattleParticipant クラス修正（9項目）
- Phase 2: battle_preparation.gd 修正（6項目）
- Phase 3: バトル後処理修正（2項目）
- Phase 4: ダメージ集計修正（2項目）
- Phase 5: 全体確認（3項目）

### トラブルシューティング

5つの一般的な問題と解決方法：
1. コンパイルエラー「undefined reference」
2. HP が正しく減らない
3. 再生スキル等でHP回復がおかしい
4. MHP が計算されていない
5. バトル終了後に HP が勝手に変わる

### 参考：修正前後の比較

3つの観点での比較：
- ダメージフロー
- HP 初期化
- バトル後 HP 保存

## 利用方法

1. **計画段階**: `hp_system_refactoring_plan.md` を読んで全体像を把握
2. **実装段階**: `hp_system_refactoring_implementation_guide.md` を参照しながら修正
3. **チェックリスト**: 各 Phase のチェックリストで修正漏れを確認
4. **トラブルシューティング**: 問題が発生した場合は該当項目を参照

## 今後のアクション

1. ドキュメントをレビュー
2. 実装開始（手順1から順序立てて実行）
3. 各ステップでテスト実行
4. ドキュメント更新
5. 完了報告書作成
