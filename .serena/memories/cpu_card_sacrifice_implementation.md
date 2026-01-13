# CPUカード犠牲システム実装 - 完了

## 実装内容

### 1. CPUSacrificeSelector クラス
`scripts/cpu_ai/cpu_sacrifice_selector.gd`
- **既存の`SpellSynthesis.check_condition()`と`CreatureSynthesis.check_condition()`を使用**
- 合成条件でフィルタリング後、レート最低カードを選択
- イド専用処理（土地属性に合うクリーチャーでレート最高を選択）

### 2. CPUSpellAI - スペル使用時のカード犠牲
`scripts/cpu_ai/cpu_spell_ai.gd`
- `sacrifice_selector`参照追加
- `set_spell_synthesis()`メソッド追加
- `decide_spell()`戻り値: `sacrifice_card`, `should_synthesize`
- 合成判断ロジック（シャイニングガイザー、デビリティ、マスグロース）

### 3. CPUTerritoryAI - クリーチャー召喚時のカード犠牲
`scripts/cpu_ai/cpu_territory_ai.gd`
- `sacrifice_selector`, `creature_synthesis`参照追加
- `set_creature_synthesis()`メソッド追加
- `_can_place_creature()`: 犠牲カードがある場合のみ許可

### 4. SpellPhaseHandler - CPU実行フロー
`scripts/game_flow/spell_phase_handler.gd`
- `_execute_cpu_spell()`: 犠牲カード処理追加
- `initialize()`でcpu_spell_aiにspell_synthesisを設定

### 5. TileActionProcessor - CPU召喚/バトル
`scripts/tile_action_processor.gd`
- `sacrifice_selector`参照追加
- `_process_card_sacrifice()`: CPU判定追加
- `_process_card_sacrifice_cpu()`: CPUSacrificeSelector使用
- `_auto_select_sacrifice_card_for_cpu()`: CPUSacrificeSelector使用
- `_is_cpu_player()`: CPU判定メソッド追加

### 6. CPUAIHandler - 初期化
`scripts/cpu_ai/cpu_ai_handler.gd`
- `territory_ai`に`creature_synthesis`を設定

### 7. データ変更
`data/spell_1.json`
- シャイニングガイザー: `can_kill_target` → `can_kill_with_40_damage`

`scripts/cpu_ai/cpu_target_resolver.gd`
- `can_kill_with_40_damage`条件追加

## 設計ポイント
- **プレイヤー側と同じロジックを使用**: `SpellSynthesis`/`CreatureSynthesis`の`check_condition()`
- CPUSacrificeSelectorは「どのカードを選ぶか」のみ担当
- 破棄・合成適用は既存の`CardSacrificeHelper`と`SpellSynthesis`/`CreatureSynthesis`を使用

## デバッグフラグ
```gdscript
tile_action_processor.debug_disable_card_sacrifice = true  # 現在無効化中
```

テスト後に`false`に変更してプレイヤー側も有効化
