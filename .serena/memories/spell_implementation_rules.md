# スペル実装ルール

## 原則
SpellPhaseHandlerには個別スペルのロジックを書かない。
各スペル種別の専用スクリプトに機能を実装し、SpellPhaseHandlerは委譲のみ行う。

## 実装場所

| カテゴリ | 実装先スクリプト | 担当効果 |
|---------|-----------------|---------|
| ドロー・手札操作 | spell_draw.gd | draw, draw_cards, draw_by_type, destroy系, steal系 |
| 魔力操作 | spell_magic.gd | add_magic, transfer_magic, drain_magic |
| 土地操作 | spell_land.gd | change_element, change_level, destroy_creature |
| 呪い（通行料） | spell_curse_toll.gd | curse_toll_*, toll manipulation |
| 呪い（ステータス） | spell_curse_stat.gd | curse_stat_*, battle restrictions |
| ダイス操作 | spell_dice.gd | dice_*, movement manipulation |
| 秘術 | spell_mystic_arts.gd | 秘術固有効果（既存効果はspell_id参照） |

## SpellPhaseHandlerの役割
1. effect_typeを見て適切なスクリプトに委譲
2. ターゲット選択UIの制御
3. スペルフェーズの状態管理
4. **個別効果のロジックは書かない**

## 新規effect_type追加時の手順
1. 該当カテゴリのスクリプトにメソッド追加
2. そのスクリプトのapply_effect()にcase追加
3. SpellPhaseHandlerの委譲リストに追加（必要な場合のみ）
