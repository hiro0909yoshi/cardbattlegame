# 通行料システム実装完了

**バージョン**: 1.0  
**完成日**: 2025年11月23日  
**ステータス**: 実装完了

---

## 概要

通行料システムの完全実装。敵地判定・支払い処理をend_turn()に一本化し、レベルアップコストを動的計算化。

---

## 実装内容

### 1. GameConstants.gd - 通行料係数定義
```
TOLL_ELEMENT_MULTIPLIER: fire/water/wind/earth=1.0, none=0.8
TOLL_LEVEL_MULTIPLIER: Lv1~5: 1.0, 1.2, 1.5, 2.0, 2.5
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
   - 敵地なら支払い、自領地・スタートなら支払いなし
5. ターン終了処理・次ターン
```

### 4. tile_action_processor.gd - パス処理修正
- `on_action_pass()`: 支払い処理削除
- シグナル発火で end_turn() へ自動遷移

### 5. battle_system.gd - pay_toll_3d()削除
- 関数定義・呼び出し（3箇所）完全削除
- invasion_completed シグナルで処理継続

### 6. land_command_ui.gd - レベルアップコスト動的計算
- ハードコード値（80, 240, 620, 1200）削除
- board_system_ref.tile_data_manager.calculate_level_up_cost()で動的計算
- show_level_selection()・_calculate_level_up_cost()実装

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
| 戦闘勝利（ATTACKER_WIN） | ❌ | 土地奪取→自領地に |
| 相打ち（BOTH_DEFEATED） | ❌ | 土地無所有に |

---

**最終更新**: 2025年11月23日
