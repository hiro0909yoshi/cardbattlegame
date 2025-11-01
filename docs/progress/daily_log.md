# 📅 日次作業ログ

**目的**: チャット間の継続性を保つため、各日の作業内容を簡潔に記録

**ルール**: 
- 各作業は1〜3行で簡潔に
- 完了したタスクに ✅
- 次のステップを必ず明記
- 詳細は該当ドキュメントにリンク
- **前日以前のログは削除し、直近の作業のみ記録**
- **⚠️ ログ更新時は必ず残りトークン数を報告すること**

---

## 2025年11月1日

### 完了した作業

- ✅ **ID1024, 1025の欠番を復元**
  - 1024: スパークボール（巻物）
  - 1025: スパイクシールド（防具）- 反射[1/2]

- ✅ **アイテム実装（防具2個完了）**
  - 1002: アングリーマスク - HP+30；追加ダメージ[自分が受けたダメージ]
	- 反射[全・自傷]: 100%反射、自分もダメージ受ける
  - 1017: スクイドマントル - HP+40；敵の攻撃成功時能力無効
	- 防御時のみ、敵の特殊攻撃スキル（強打・2回攻撃・即死・貫通）を無効化

- ✅ **スクイドマントルの実装**
  - BattleParticipantに`has_squid_mantle`フラグ追加
  - battle_preparation.gdで効果付与
  - battle_skill_processor.gdで強打・2回攻撃・貫通をチェック
  - battle_special_effects.gdで即死をチェック
  - condition_checker.gdの`build_battle_context()`に`opponent`と`is_defender`を追加

- ✅ **バグ修正**
  - contextに`opponent`が渡されない問題を修正
  - `build_battle_context()`が`opponent`を返すように修正

- ✅ **テスト確認**
  - スクイドマントルで強打が無効化されることを確認
  - 貫通・即死も正しく無効化されることを確認

- ✅ **進捗ドキュメント更新**
  - 防具: 17/20 → 19/20（95%）
  - 全体: 48/75 → 50/75（67%）

- ✅ **ニュートラルクローク実装完了**
  - 1045: ニュートラルクローク - HP+40；属性変化[⬜]
  - `change_element`効果を実装
  - battle_preparation.gdで属性を無属性（neutral）に変更

### 🎉 防具カテゴリ完成！

**防具**: 20/20（100%）✅  
**全体**: 51/75（68%）

- ✅ **1036: ツインスパイク実装完了**
  - ST+20；強制変化[使用クリーチャー]
  - 効果: 攻撃時、防御側を倒せなかった場合、防御側が攻撃側のクリーチャーに変身
  - 変身は永続的、HPはフルHPにリセット
  - base_up_hp（永続ボーナス）とアイテムは維持
  - `forced_copy_attacker`変身タイプを実装
  - `skill_transform.gd`で変身時にbase_up_hpを保持するよう修正
  - `battle_preparation.gd`で変身効果をability_parsedに追加
  - 死者復活はbase_up_hpを引き継がないよう修正

- ✅ **進捗ドキュメント更新**
  - アクセサリ: 13/20 → 14/20（70%）
  - 全体: 51/75 → 52/75（69%）

- ✅ **クリーチャー交換・地形変化後のターンエンド問題を修正**
  - 地形変化で`is_action_processing`が設定されていなかった
  - `execute_terrain_change_with_element()`の開始時に`is_action_processing = true`を設定
  - これにより`complete_action()`が正しく実行され、ターンエンドが呼ばれるようになった

- ✅ **領地コマンドでターンエンド時に「召喚しない」ボタンが残る問題を修正**
  - **根本原因**: `end_turn()`でカード選択UIを非表示にしていなかった
  - 通常の召喚では`execute_summon()`内で`hide_card_selection_ui()`を呼ぶため問題なし
  - 領地コマンド経由のターンエンドでは呼ばれないため、ボタンが残っていた
  - **修正**: `end_turn()`の開始時に`hide_card_selection_ui()`を追加
  - 追加修正: `_on_land_command_closed()`でターンエンド中は再初期化をスキップ
  - これで全てのターンエンドパターンでUIが正しくクリアされる

### 次のステップ

**武器の実装を進める**
- 🎯 簡単な候補:
  1. 1012: ゴールドハンマー - ST+40；攻撃で敵非破壊時、魔力獲得[G200]（★☆☆）
  2. 1034: チェーンソー - ST+戦闘地の連鎖数×20（★☆☆）
  3. 1044: ナパームアロー - ST+30；HP+20；雪辱[敵のMHP-40]（★★☆）

**残りトークン: 79,342 / 190,000**

---

## 2025年10月30日

### 完了した作業

- ✅ **MHP計算の完全統一化完了**
  - BattleParticipant存在時: `participant.get_max_hp()` を使用
  - 修正箇所（5箇所）:
	- `battle_preparation.gd`: 42行目（攻撃側）、78行目（防御側）、242行目（ブラッドプリン）
	- `battle_skill_processor.gd`: 292行目（土地数比例）、1317行目（ランダムHP）
  - JSON操作時は従来通り `hp + base_up_hp` を直接計算

- ✅ **MHPとダメージ計算の完全仕様ドキュメント作成**
  - ファイル: `docs/design/mhp_damage_calculation.md`
  - 全7種類のHPボーナスを定義（base_hp, base_up_hp, resonance_bonus_hp等）
  - ダメージ消費順序の完全定義
  - 各ボーナスの設定箇所・タイミング・用途を詳細記載
  
- ✅ **HPCalculator削除完了**
  - `scripts/utils/hp_calculator.gd` を削除
  - 理由: 不完全な計算式（戦闘ボーナスを含まない）
  - BattleParticipantに統合する方が正しい設計

- ✅ **BattleParticipantにMHPヘルパーメソッド追加**
  - `get_max_hp()` - 真のMHP取得（base_hp + base_up_hp）
  - `is_damaged()` - ダメージ判定
  - `get_hp_ratio()` - 残りHP割合
  - `check_mhp_condition()` - MHP条件チェック
  - `is_mhp_below_or_equal()` - MHP以下判定
  - `is_mhp_above_or_equal()` - MHP以上判定
  - `is_mhp_in_range()` - MHP範囲判定
  - `get_hp_debug_string()` - デバッグ文字列

### 設計の明確化

**MHP（最大HP）の定義**:
```gdscript
MHP = base_hp + base_up_hp  // 真の最大HP（永続）
```

**戦闘中のHP**:
```gdscript
current_hp = base_hp + base_up_hp + temporary_bonus_hp + 
			 resonance_bonus_hp + land_bonus_hp + item_bonus_hp + spell_bonus_hp
```

**使い分け**:
- 戦闘中: `participant.get_max_hp()` を使用
- JSON操作時: `hp + base_up_hp` を直接計算

### 次のステップ

**MHP計算統一完了！次の候補:**
1. 戦闘中スキル（残りスキル）の実装
2. 新しい機能の実装
3. バグ修正・リファクタリング
4. テストとデバッグ

**残りトークン: 122,481 / 190,000**

---


## テンプレート（コピー用）

```markdown
## YYYY年MM月DD日

### 完了した作業
- ✅ **[作業内容]**
  - [詳細1]
  - [詳細2]
  - 詳細: `[関連ドキュメントへのリンク]`

### 次のステップ
- 📋 **[次の作業]**
  - [詳細]

### 課題・メモ
- [気づいた点、今後の懸念事項など]
```

---

## 📝 記録のガイドライン

### ✅ 良い記録の例
```markdown
- ✅ **防御型クリーチャー実装完了**（全21体）
  - 属性別: 火3、水5、地6、風1、無6
  - 詳細: docs/design/defensive_creature_design.md
```
→ 数値・結果が明確、詳細へのリンクあり

### ❌ 悪い記録の例
```markdown
- ✅ いろいろやった
```
→ 具体性なし、次回のチャットで役に立たない

---

## 🎯 記録すべき内容

### 必須
- 実装した機能・修正したバグ
- 影響を受けたファイル
- 次のステップ

### 推奨
- 数値データ（クリーチャー数、ファイル行数など）
- 関連ドキュメントへのリンク
- 重要な設計判断

### 不要
- 細かいコード変更の説明（それはGitコミットログへ）
- 試行錯誤の過程（それはチャット内で完結）

---

**最終更新**: 2025年10月25日
