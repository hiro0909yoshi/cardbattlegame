# カードドロー・手札操作スペル実装進捗

**最終更新**: 2025年11月26日

## 実装完了（4個）

| ID | 名前 | effect_type | 処理場所 |
|----|------|-------------|---------|
| 2095 | ホープ | `draw_cards` | SpellPhaseHandler → spell_draw.draw_cards() |
| 2020 | ギフト | `draw_by_rank`, `gain_magic_by_rank` | SpellPhaseHandler → 順位取得 + spell_draw/spell_magic |
| 2127 | リンカネーション | `discard_and_draw_plus` | SpellPhaseHandler内で直接処理 |
| 2004 | アセンブルカード | `check_hand_elements` | SpellPhaseHandler → 条件分岐 + gain_magic/draw_cards |

## 追加したeffect_type（SpellPhaseHandler._apply_single_effect内）

- `draw_cards`: 固定枚数ドロー
- `draw_by_rank`: 順位枚数ドロー
- `gain_magic`: 固定額魔力獲得
- `gain_magic_by_rank`: 順位×multiplierの魔力獲得
- `discard_and_draw_plus`: 手札全捨て＋元枚数分ドロー
- `check_hand_elements`: 手札属性チェック（密命用）

## 追加したヘルパーメソッド（SpellPhaseHandler）

- `_get_player_ranking(player_id)`: 順位取得（player_info_panel経由）
- `_get_hand_creature_elements(player_id)`: 手札クリーチャー属性収集

## 順位システム（PlayerInfoPanel）

- `get_player_ranking(player_id)`: 特定プレイヤーの順位
- `calculate_all_rankings()`: 全プレイヤー順位計算
- UIにも順位表示追加済み

## 次の実装候補（UI不要）

### 手札破壊系
- 2034: シャッター - 敵手札のアイテム/スペル破壊（UI必要）
- 2017: エロージョン - 重複カード破壊
- 2038: スクイーズ - 手札1枚破壊+G150付与
- 2128: レイオブパージ - 呪いカード全破壊
- 2129: レイオブロウ - G100以上カード全破壊

### UI必要（後回し）
- 2078: フォーサイト - デッキ上6枚選択UI
- 2090: プロフェシー - タイプ選択UI
- 2093: ポイズンマインド - デッキ破壊UI
- 2046: セフト - 敵手札選択UI

## 関連ドキュメント

- docs/design/spells/カードドロー.md (v2.2)
- docs/design/player_info_panel_redesign.md
- docs/design/spells_tasks.md
