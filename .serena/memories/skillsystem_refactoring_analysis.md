# SkillSystem リファクタリング分析

## 現状の使用パターン

### SkillSystem の実装
- **バフ構造**: player_buffs[player_id] = 辞書（8つのフィールド）
- **バフ適用**: apply_buff() メソッド（match文で個別に対応）
- **バフ参照**: modify_* メソッド内で player_buffs[player_id].フィールド名で直接アクセス

### バフの種類（8種類）
1. card_cost_reduction
2. dice_bonus
3. toll_multiplier
4. draw_bonus
5. magic_income_bonus
6. battle_st_bonus
7. battle_hp_bonus

### 外部呼び出し状況
- apply_buff() の外部呼び出し: **ゼロ**（SkillSystem内部でのみ使用）
- modify_card_cost(): cpu_ai_handler.gd で呼び出し
- modify_dice_roll(): game_flow_manager.gd で呼び出し
- 他の modify_* メソッド: 呼び出しなし（未使用）

## 重要な気付き

**SkillSystem は現在ほぼ未使用** の機能が多い
- apply_buff() が呼ばれていない（バトル/スキルシステムから呼ばれる形跡なし）
- modify_creature_stats() が呼ばれていない
- modify_toll() が呼ばれていない
- modify_draw_count() が呼ばれていない

つまり、実際に使用されているのは：
- modify_card_cost()
- modify_dice_roll()

のみ。

## 実際の利用状況の詳細

### バトルシステムでの使用
- scripts/battle/**/*.gd: player_buffs や apply_buff の参照なし
- バトルはバフシステムを**使用していない**

### スキルシステムでの使用
- scripts/skills/**/*.gd: player_buffs や apply_buff の参照なし
- スキル処理はバフシステムを**使用していない**

### ゲームフローでの使用
- game_flow_manager.gd:
  - skill_system.modify_dice_roll() を呼び出し（ダイス処理で）
  - skill_system.end_turn_cleanup() を呼び出し（ターン終了時に）

### CPU AI での使用
- cpu_ai_handler.gd:
  - skill_system.modify_card_cost() を呼び出し（カードコスト計算で）

## スペルシステムの確認結果

スペル系スクリプト（12ファイル）を調査：
- spell_magic.gd: 魔力管理（player_buffs 参照なし）
- spell_curse.gd: 呪いシステム（player_buffs 参照なし）
- spell_land_new.gd: 土地操作（player_buffs 参照なし）
- spell_dice.gd: ダイス操作（SkillSystem 参照なし）
- spell_draw.gd: ドロー操作（SkillSystem 参照なし）
- その他スペル: player_buffs 参照なし

**結論**: スペルシステムも SkillSystem の player_buffs を使用していない

## 最終結論

**SkillSystem のバフシステムは設計された機能だが、実装側では完全に未使用**

- バトルシステム（20+ファイル）: 使用なし
- スキルシステム（scripts/skills/）: 使用なし
- スペルシステム（12ファイル）: 使用なし
- ゲームフロー: modify_card_cost(), modify_dice_roll() のみ使用
- CPU AI: modify_card_cost() のみ使用

つまり、apply_buff() で追加したバフは、コード内では全く活用されていない設計段階のコード。

## リファクタリングの目的

Gemini の指摘：
> 新しいバフを追加するたびに、initialize_player_buffs、apply_buff、apply_debuffなど、
> 全てのメソッドに新しいmatch文または辞書キーを追加しなければなりません。

つまり、**将来のバフ追加時の拡張性を向上させる**ことが主眼。

## 提案するリファクタリング方針

### 案1: 動的バフ配列方式（Gemini推奨）
```gdscript
player_buffs[player_id] = [
    {"type": "card_cost_reduction", "value": 10, "duration": -1},
    {"type": "dice_bonus", "value": 2, "duration": 3},
    ...
]
```

**メリット**:
- 新バフ追加時は配列に追加するだけ
- match文が不要
- 動的なバフ管理が可能

**デメリット**:
- 計算メソッドをループで実装（わずかな性能低下）
- 既存コード修正が少ない（modify_* メソッドのみ）

### 案2: 現状のままで細かく対応
新バフ追加時は initialize_player_buffs と apply_buff を修正

**メリット**:
- 実装シンプル

**デメリット**:
- 将来、毎回複数ファイル修正必要
- 拡張性低い

## 修正対象ファイル（案1実装時）

**必須修正**:
1. scripts/skill_system.gd（メインリファクタリング）

**影響確認**:
- scripts/flow_handlers/cpu_ai_handler.gd（modify_card_cost 呼び出し）
- scripts/game_flow_manager.gd（modify_dice_roll 呼び出し）

推定修正行数: 60-80行

## 結論

修正行数は**極めて少ない**。リファクタリングの価値が高い。

Gemini の指摘は「将来のバフ追加時の保守性」に関する指摘で、
今はバフ数が少ないから目立たないが、
数十種類に増えたときに効果が出る。

やる価値あり。
