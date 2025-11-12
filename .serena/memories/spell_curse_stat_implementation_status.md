# ステータス増減スペル実装状況 - 2025年11月13日

## 実装完了 ✅

### 1. SpellCurseStatクラス作成
- **ファイル**: `scripts/spells/spell_curse_stat.gd`
- **メソッド**:
  - `setup(curse, creature_mgr)` - 初期化
  - `apply_stat_boost(tile_index, effect)` - 能力値+20呪い付与
  - `apply_stat_reduce(tile_index, effect)` - 能力値-20呪い付与
  - `apply_to_creature_data(tile_index)` - temporary_effectsへの変換

### 2. GameFlowManager統合 ✅
- SpellCurseStatの初期化追加（_setup_spell_systems内）
- spell_curse_stat参照の設定完了

### 3. SpellPhaseHandler統合 ✅
- `_apply_single_effect()`メソッドに以下を追加:
  - "stat_boost" case: stat_boostの呪い付与処理
  - "stat_reduce" case: stat_reduceの呪い付与処理
  - どちらも target_type="land" 時に動作

### 4. BattlePreparation統合 ✅
- `prepare_participants()`に呪い適用呼び出し追加
- `_apply_creature_curses(tile_index)`メソッド実装
- temporary_effects → バトル時のHP/APボーナス適用

### 5. MovementController統合 ✅
- game_flow_manager参照の追加
- `move_along_path()`で移動時の呪い削除処理実装
- setup_systems()にgf_managerパラメータ追加

### 6. JSON修正
- **2054 (ディジーズ)**: effect_parsed追加完了 ✅
  - effect_type: "stat_reduce", value: -20, duration: -1
  - draw effect: count 1も追加
  
- **2066 (バイタリティ)**: effect_parsed追加予定
  - effect_type: "stat_boost", value: 20, duration: -1
  - draw effect: count 1も追加

## 次のステップ

### 緊急対応
- [ ] 2066のJSONに effect_parsedを手動追加
- [ ] ゲーム内でテスト（ディジーズ使用→呪い付与確認）

### テスト項目
1. スペル使用時に呪いが付与されるか
2. バトル時に呪い効果が適用されるか (HP/AP変動)
3. 移動時に呪いが消滅するか
4. 無期限呪い (-1) が正しく扱われるか

### 実装パターン注記
- 呪いは creature_data["curse"] に単一オブジェクトで保存
- duration: -1 = 無期限（上書き or 移動で消滅）
- temporary_effects → BattleParticipantの temporary_bonus_hp/ap へ
- 移動元から呪いが削除される（移動先ではない）

## コード参照
- SpellCurse: `scripts/spells/spell_curse.gd` (既存、完成)
- SpellCurseStat: `scripts/spells/spell_curse_stat.gd` (新規作成)
- 統合箇所:
  - GameFlowManager: line 155-158
  - SpellPhaseHandler: line 432-447
  - BattlePreparation: line 105-107, line 896-934
  - MovementController: line 35, line 43, line 115-118
