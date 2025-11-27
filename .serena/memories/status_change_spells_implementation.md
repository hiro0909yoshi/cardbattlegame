# ステータス増減スペル実装 引き継ぎ

## 設計ドキュメント
`docs/design/spells/ステータス増減.md`

## 実装フェーズ

### フェーズ1: 恒久変更方式スペル（優先）
- **対象**: グロースボディ(2026)、ファットボディ(2075)、マスグロース(2107)
- **effect_type**: `permanent_hp_change`, `permanent_ap_change`
- **処理**: `base_up_hp`, `base_up_ap` を直接変更
- **注意**: `EffectManager.apply_max_hp_effect()` で current_hp も同時更新

### フェーズ2: デビリティ（AP=0呪い）
- **対象**: デビリティ(2058)
- **curse_type**: `ap_nullify`
- **処理**: BattlePreparation._apply_creature_curses() でAP=0固定

### フェーズ3: タイニーアーミー（密命）
- **対象**: タイニーアーミー(2050)
- **条件**: MHP30以下のクリーチャー5体以上
- **成功時**: 対象全員 base_up_hp +10、G500獲得
- **失敗時**: ブック復帰
- **UI**: 1体ずつカメラ→通知→クリック待ち

### フェーズ4: クリーチャー秘術（MHP増減）+ シュリンクシジル
- **新規スペルID**: MHP+10、MHP-10 を定義
- **リチェノイド(244)**: 秘術 G30・MHP+10（敵味方問わず）
- **エアロダッチェス(303)**: 秘術 G50・MHP-10（敵のみ）
- **シュリンクシジル(2035)**: 呪いで秘術を付与する特殊ケース

## シュリンクシジル設計

### 構造
```
スペル「シュリンクシジル」→ 呪い「縮小術」→ 秘術「縮小」(G50・敵MHP-10)
```

### 対象制約
- `has_no_curse`: 呪いを持っていない
- `has_no_mystic_arts`: 秘術を持っていない

### 実装箇所
1. **SpellMysticArts**: `get_mystic_arts_for_creature()` で呪いの `mystic_arts` も取得
2. **TargetSelectionHelper**: `has_no_mystic_arts` フィルタ追加
3. **呪いタイプ**: `mystic_grant`（mystic_artsフィールド付き）

### 呪いデータ構造
```gdscript
creature_data["curse"] = {
    "curse_type": "mystic_grant",
    "name": "縮小術",
    "duration": -1,
    "lost_on_move": true,
    "mystic_arts": [{
        "name": "縮小",
        "cost": 50,
        "spell_id": XXXX,  # MHP-10スペル
        "target_filter": "enemy_creature"
    }]
}
```

## 既存実装（参照用）
- **バイタリティ/ディジーズ**: `SpellCurseStat` + `BattlePreparation._apply_creature_curses()`
- **秘術システム**: `SpellMysticArts` (spell_id参照方式)
- **戦闘制限呪い**: `SpellCurseBattle`
