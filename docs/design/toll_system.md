# 通行料システム実装完了

**バージョン**: 1.1  
**完成日**: 2025年11月23日  
**最終更新**: 2025年12月16日  
**ステータス**: 実装完了

---

## 概要

通行料システムの完全実装。敵地判定・支払い処理をend_turn()に一本化し、レベルアップコストを動的計算化。

---

## 実装内容

### 1. GameConstants.gd - 通行料係数定義
```
TOLL_ELEMENT_MULTIPLIER: fire/water/wind/earth=1.0, none=0.8
TOLL_LEVEL_MULTIPLIER: Lv1~5: 0.3, 0.6, 2.0, 4.0, 8.0
TOLL_MAP_MULTIPLIER: map_1=1.0（拡張可能）
floor_toll(amount): 10の位で切り捨て関数
```

### 2. tile_data_manager.gd - 通行料計算
- `calculate_toll(tile_index, map_id)`: 通行料計算（要素×レベル×連鎖×マップ）
- `calculate_chain_bonus()`: 日本語→英語属性名修正
- `calculate_level_up_cost(tile_index, target_level, map_id)`: レベルアップコスト（連鎖固定1.5）

### 3. game_flow_manager.gd - 敵地支払い一本化
```
end_turn()内の処理順:
1. 初期チェック
2. UI/ランド処理
3. ★手札調整実行
4. ★敵地判定・支払い実行 ← ここで統一
   - check_and_pay_toll_on_enemy_land()
   - 敵地なら支払い、自ドミニオ・スタートなら支払いなし
   ★通行料呪いを判定・計算
	 - SpellCurseToll.calculate_final_toll()で呪い判定
	 - セプター呪い（toll_disable, toll_fixed, toll_share）
	 - ドミニオ呪い（toll_multiplier, peace）を適用
	 - 主通行料 + 副収入を支払い
5. ターン終了処理・次ターン
```

### 4. tile_action_processor.gd - パス処理修正
- `on_action_pass()`: 支払い処理削除
- シグナル発火で end_turn() へ自動遷移

### 5. battle_system.gd - pay_toll_3d()削除
- 関数定義・呼び出し（3箇所）完全削除
- invasion_completed シグナルで処理継続

### 6. dominio_order_ui.gd - レベルアップコスト動的計算
- ハードコード値（80, 240, 620, 1200）削除
- board_system_ref.tile_data_manager.calculate_level_up_cost()で動的計算
- show_level_selection()・_calculate_level_up_cost()実装

### 7. spell_curse_toll.gd - 通行料呪いシステム
**通行料計算に呪いを適用**
- `apply_toll_share()`: 敵の通行料50%獲得（ドリームトレイン）
- `apply_toll_disable()`: 支払わない（ブラックアウト）
- `apply_toll_fixed()`: 支払い固定値（ユニフォーミティ）
- `apply_toll_multiplier()`: クリーチャーの通行料倍率（グリード）
- `apply_peace()`: 敵移動除外＋戦闘不可＋通行料0（ピース）
- `apply_invasion_disable()`: 侵略無効化（セプター呪い）
- `apply_toll_half_curse()`: 通行料半減（ドミニオ呪い）
- `apply_creature_toll_disable()`: クリーチャーの通行料無効化
- `apply_curse_from_effect()`: 効果辞書からの呪い適用（汎用）

**統合的な計算メソッド**
```
calculate_final_toll(tile_index, payer_id, receiver_id, base_toll)
  ↓
1. ドミニオ呪いチェック（peace, toll_multiplier）
   ├─ peace → 通行料=0
   └─ toll_multiplier → 倍率適用
2. セプター呪いチェック（支払い側）
   ├─ toll_disable → 支払い=0
   └─ その他
3. セプター呪いチェック（受取側）
   ├─ toll_fixed → 固定値
   ├─ toll_share → 副収入計算
   └─ その他
  ↓
戻り値: {main_toll, bonus_toll, bonus_receiver_id}
```

---

## 計算式

### 通行料
```
通行料 = 100 × 要素係数 × レベル係数 × 連鎖ボーナス × マップ係数
	  → floor_toll()で10の位切り捨て
```

### レベルアップコスト
```
コスト = 100 × 要素係数 × レベル係数 × 1.5（固定連鎖2個） × マップ係数
	  → floor_toll()で10の位切り捨て
```

---

## 支払いシーン

| シーン | 支払い | 理由 |
|--------|--------|------|
| パスボタン選択後 | ✅ | 敵地に留まる |
| 戦闘敗北（DEFENDER_WIN） | ✅ | 敵地に留まる |
| 敵地生き残り（ATTACKER_SURVIVED） | ✅ | 敵地に留まる |
| 戦闘勝利（ATTACKER_WIN） | ❌ | 土地奪取→自ドミニオに |
| 相打ち（BOTH_DEFEATED） | ❌ | 土地無所有に |

---

## 補足：通行料呪いとの統合

通行料呪い（`docs/design/spells/通行料呪い.md`）は本システムの **上位レイヤー** として機能：

| 処理段階 | 役割 |
|---------|------|
| **基本計算** | tile_data_manager.calculate_toll() → base_toll |
| **呪い適用** ← **新規** | spell_curse_toll.calculate_final_toll() → 最終通行料 + 副収入 |
| **支払い実行** | player_system.pay_toll() |

**詳細は `docs/design/spells/通行料呪い.md` を参照**

---

## 補足：侵略判定との統合（2025/12/05追加）

SpellCurseTollは本来「通行料」システムだが、以下の理由で**侵略判定**の一部機能も担当：

### 統合の理由

1. **既存のpeace呪い**: 「敵の移動侵略を防ぐ」効果が既にSpellCurseTollで実装済み
2. **チェック箇所の一元化**: 侵略可否の判定は複数箇所（通常移動、スペル移動、移動先候補算出）で必要
3. **参照の容易さ**: SpellCurseTollは board_system のメタデータとして各所から参照可能

### 追加された侵略関連機能

| メソッド | 対象 | 効果 |
|---------|------|------|
| `has_peace_curse()` | 土地 | その土地への侵略を防ぐ |
| `has_peace_curse_on_land()` | 土地 | 土地のピース呪いをチェック |
| `is_invasion_disabled()` | 土地 | その土地への侵略が無効か |
| `is_player_invasion_disabled()` | プレイヤー | そのプレイヤーが侵略不可 |
| `is_creature_invasion_immune()` | クリーチャー | そのクリーチャーが移動侵略無効 |
| `can_move_to_land()` | 土地+プレイヤー | 移動可能かの総合判定 |

### チェック箇所

| ファイル | 用途 |
|---------|------|
| `movement_helper.gd` | 移動先候補から除外 |
| `land_action_helper.gd` | 通常移動確定時のチェック |
| `spell_creature_move.gd` | スペル移動先候補から除外 |

### 設計上の注意

- 通行料と直接関係のない侵略判定がSpellCurseTollに含まれる
- 将来的にリファクタリングする場合は「InvasionChecker」等への分離を検討
- 現状は既存のpeace呪い実装との一貫性を優先

---

---

## Note: Phase 1 での統合（2026-02-20追加）

SpellCurseToll は Phase 1 で SpellSystemContainer に統合されました。
アクセス方法:
```gdscript
game_flow_manager.spell_container.spell_curse_toll
```

詳細は `docs/progress/refactoring_next_steps.md` の Phase 1 セクションを参照。

---

**最終更新**: 2025年12月16日（v1.1 - レベル係数修正、メソッド追記）
**統合完了**: 2026年2月20日（Phase 1 - SpellSystemContainer化）
