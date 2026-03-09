# バトルテストツール機能仕様書

**プロジェクト**: カルドセプト風カードバトルゲーム
**作成日**: 2025年10月18日
**最終更新**: 2026年3月8日
**対象ユーザー**: 開発者・テスター
**ステータス**: バトルシステム完全統合版（刻印・アイテム・スキル・ビジュアルモード対応）

---

## 📋 目次

1. [概要](#概要)
2. [機能一覧](#機能一覧)
3. [画面仕様](#画面仕様)
4. [操作フロー](#操作フロー)
5. [入力値仕様](#入力値仕様)
6. [出力仕様](#出力仕様)
7. [バトル実行の仕組み](#バトル実行の仕組み)
8. [刻印スペル対応](#刻印スペル対応)
9. [スキル付与機能](#スキル付与機能)
10. [エラーハンドリング](#エラーハンドリング)
11. [制限事項](#制限事項)

---

## 概要

### 目的
スペル・アイテム・スキル・刻印の効果を網羅的にテストし、バランス調整とバグ検出を支援する。

### 利用シーン
1. **新スキル実装後**: 正しく動作するか確認
2. **新アイテム実装後**: スキル付与・ステータスボーナスが正しいか確認
3. **刻印スペル実装後**: 刻印効果がバトルに反映されるか確認
4. **バランス調整前**: 各クリーチャーの強さを数値化
5. **リファクタリング後**: 既存機能が壊れていないか確認
6. **バグ報告時**: 再現条件を特定

### テストモード

| モード | 説明 | 用途 |
|---|---|---|
| **通常モード** | 高速で全組み合わせを実行 | 大量テスト・統計分析 |
| **ビジュアルモード** | バトル画面でアニメーション付き実行 | スキル発動確認・演出確認 |

---

## 機能一覧

### F1. クリーチャー選択
- ID入力でクリーチャーを選択
- 最大10体まで
- フォントサイズ36pt、入力欄200x50

### F2. アイテム選択
- ID入力でアイテムを選択
- 「なし」指定可能
- アイテム効果は `item_applier.apply_item_effects()` で適用

### F3. 刻印スペル選択
- 攻撃側・防御側それぞれに刻印スペルIDを設定可能
- スペルの `effect_parsed.effects` から刻印データを構築
- `effect_type` → `curse_type` 変換マップで正しい刻印タイプに変換

### F4. 土地条件設定
- 保有土地数（火水地風 各0-10）
- バトル発生土地の属性
- 土地レベル

### F5. 隣接条件設定
- 隣接味方ドミニオンの有無

### F6. プリセット選択
- 属性別・スキル別の事前定義セット

### F7. 攻撃⇔防御入れ替え

### F8. ID参照パネル
- 全カードのID一覧（フォント36pt、ウィンドウ1500x1000）
- ×ボタンで閉じる（`close_requested`シグナル対応）

### F9. バトル実行（通常モード）
- 全組み合わせを高速実行
- `BattleTestExecutor` 使用

### F9b. バトル実行（ビジュアルモード）
- `BattleScreenManager` でアニメーション付き実行
- スキル発動演出・攻撃演出・結果演出を表示

### F10. 結果表示（テーブル）
- フォントサイズ36pt
- 勝者: `attacker`, `defender`, `attacker_survived`, `both_defeated`

### F11. 結果表示（詳細ウィンドウ）
- Window型（独立テーマスコープ）
- 800x800、フォント32pt
- ×ボタンで閉じる

### F12. 統計サマリー
- フォントサイズ36pt

---

## 画面仕様

### UI仕様

| 要素 | サイズ/設定 | 備考 |
|---|---|---|
| グローバルテーマ | `default_font_size = 24` | assets/ui/default_theme.tres |
| テストツールフォント | 36pt (1.5倍) | 24以下は無効 |
| ID入力欄 | 200x50 | expand有効 |
| クリーチャーリスト | 高さ100 | |
| DetailWindow | 800x800 | Window型で独立テーマ |
| カード一覧ウィンドウ | 1500x1000 | close_requested対応 |

---

## 操作フロー

### 通常モード
```
1. クリーチャーID入力（攻撃側・防御側）
2. アイテムID入力（オプション）
3. 刻印スペルID入力（オプション）
4. 土地条件設定
5. [テスト実行]ボタン
6. 結果確認（テーブル・統計・詳細）
```

### ビジュアルモード
```
1. クリーチャーID入力（攻撃側・防御側）
2. アイテム・刻印設定（オプション）
3. [ビジュアル実行]ボタン
4. バトル画面が開く
5. スキル発動演出 → 攻撃演出 → 結果表示
6. バトル画面が閉じる
```

---

## 入力値仕様

（前バージョンと同様。省略）

---

## 出力仕様

### 勝者判定

| winner値 | 意味 |
|---|---|
| `"attacker"` | 攻撃側勝利 |
| `"defender"` | 防御側勝利 |
| `"attacker_survived"` | 攻撃側生存（防御側も生存） |
| `"both_defeated"` | 相打ち（両方死亡） |

---

## バトル実行の仕組み

### 処理順序（通常モード・ビジュアルモード共通）

```
1. カードデータ取得（CardLoader.get_card_by_id + duplicate(true)）
2. BattleSystem作成 → シーンツリーに追加
3. モックシステム作成（BoardSystem3D, MockCardSystem, MockPlayerSystem）
4. SpellMagic/SpellDraw作成・セットアップ
5. BattleSystem.setup_systems()
6. サブシステムのsetup_systems()（★ビジュアルモードではBattleScreenManagerを渡す）
7. BattleParticipant作成
8. ★ current_hp 手動設定（attacker.current_hp = hp, defender.current_hp = hp + land_bonus）
9. apply_effect_arrays()（効果配列適用）
10. item_applier.apply_item_effects()（アイテム効果適用）
11. _apply_curse_spell()（刻印データをcreature_data["curse"]にセット）
12. apply_pre_battle_skills()（スキル適用 + apply_creature_curses()で刻印効果を実際に反映）
13. determine_attack_order()（攻撃順決定）
14. execute_attack_sequence()（攻撃実行）
15. resolve_battle_result()（結果判定）
16. BattleSystemクリーンアップ
```

### メインゲームとの違い

| 項目 | メインゲーム | テストツール |
|---|---|---|
| BattleParticipant作成 | `prepare_participants()` | 直接 `new()` + 手動 `current_hp` 設定 |
| アイテム適用 | `apply_remaining_item_effects()` | `item_applier.apply_item_effects()` 直接 |
| 刻印適用 | `spell_curse.curse_creature()` | `_apply_curse_spell()` で同等のDict構築 |
| PlayerSystem | 実際のプレイヤーデータ | MockPlayerSystem（ダミー2人） |
| BattleScreenManager | 常にあり | 通常モード: null、ビジュアルモード: あり |

---

## 刻印スペル対応

### effect_type → curse_type 変換マップ

スペルデータの `effect_type` と `battle_curse_applier` の `curse_type` は名前が異なる場合がある：

| スペル effect_type | battle_curse_applier の curse_type | 変換必要 |
|---|---|---|
| `stat_boost` | `stat_boost` | 不要 |
| `stat_reduce` | `stat_reduce` | 不要 |
| `ap_nullify` | `ap_nullify` | 不要 |
| `metal_form` | `metal_form` | 不要 |
| `magic_barrier` | `magic_barrier` | 不要 |
| `battle_disable` | `battle_disable` | 不要 |
| `skill_nullify` | `skill_nullify` | 不要 |
| `random_stat_curse` | `random_stat` | **必要** |
| `command_growth_curse` | `command_growth` | **必要** |
| `plague_curse` | `plague` | **必要** |
| `bounty_curse` | `bounty` | **必要** |

### 新しい刻印タイプを追加する場合

1. `spell_curse.gd` の `match effect_type:` で変換があるか確認
2. 変換がある場合、テストツールの `_curse_type_map` に追加
3. 変換がない場合（`effect_type` = `curse_type`）、追加不要（自動対応）

### 非刻印effect_type

以下はスペルカードの付随効果であり、刻印ではないためスキップする：
- `draw` - カードドロー
- `magic_gain` - EP獲得
- その他 `""` (空文字)

---

## スキル付与機能

### 付与可能なスキル（実装済み）

| スキル名 | 効果 | 付与方法 |
|---------|------|---------|
| 先制攻撃 | 先に攻撃する | アイテム |
| 後手 | 後に攻撃する | アイテム |
| 強化 | APが2倍になる | アイテム |

### アイテムスキル適用の流れ

```gdscript
# item_applier経由で適用（battle_preparationに直接メソッドはない）
battle_system.battle_preparation.item_applier.apply_item_effects(
	participant, item_data, enemy_participant
)
```

`apply_item_effects` 内部で:
- `stat_bonus` → `item_bonus_hp`, `item_bonus_ap` に加算（current_hpには加算しない）
- `effects` → スキル付与、特殊効果等

---

## エラーハンドリング

### よくあるエラーと対処

| エラー | 原因 | 対処 |
|---|---|---|
| `SpellMagic: 無効なプレイヤーID` | MockPlayerSystemにプレイヤーがいない | ダミープレイヤー2人追加（解決済み） |
| `Invalid call to 'get' in base 'Array'` | curse をArrayで設定している | Dictionary形式で設定 |
| HP:0 vs 0（全て相打ち） | current_hp 未初期化 | new()後に手動設定 |
| ビジュアルモード即終了 | BattleScreenManagerが null | setup_systems()に渡す |
| 刻印が効かない | effect_type → curse_type 変換漏れ | 変換マップに追加 |

---

## 制限事項

### 機能制限

1. **1対1バトルのみ** - 複数クリーチャーの同時戦闘は非対応
2. **アイテム1個まで** - 複数装備は非対応
3. **刻印1個まで** - `creature_data["curse"]` は1つのDictionaryのみ
4. **バフ設定** - 通常モードのExecutorのみ対応（ビジュアルモード未対応）

### UI制限

1. **フォントオーバーライド**: グローバルテーマの `default_font_size=24` 以下の値は効果なし
2. **DetailWindow**: Window型で独立テーマスコープ（グローバルテーマの影響を受けない）

### 修正時の鉄則

**メインロジックは絶対に変更しない。テストクラス内での修正のみ。**

修正対象ファイル:
- `scripts/battle_test/battle_test_executor.gd`
- `scripts/battle_test/battle_test_ui.gd`
- `scripts/battle_test/battle_test_statistics.gd`
- `scenes/battle_test_tool.tscn`

---

## 更新履歴

| 日付 | 内容 | 更新者 |
|------|------|--------|
| 2025/10/18 | 初版作成 | AI |
| 2025/10/18 | アイテム・スペルによるスキル付与機能を追加 | AI |
| 2026/03/08 | 大規模改修: current_hp初期化修正、ビジュアルモードBattleScreenManager連携、アイテム適用をitem_applier経由に修正、刻印スペル全タイプ対応（effect_type→curse_type変換マップ追加）、MockPlayerSystemダミープレイヤー追加、UI拡大（フォント36pt）、DetailWindow/カード一覧の×ボタン対応 | AI |

---

**最終更新**: 2026年3月8日
