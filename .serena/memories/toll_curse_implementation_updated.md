# 通行料呪いシステム実装進捗（2025/11/23 更新）

## 実装完了項目

### Phase 1: SpellCurseToll基盤
✅ `scripts/spells/spell_curse_toll.gd` 実装完了
✅ apply_toll_share() - セプター呪い（通行料共有）
✅ apply_toll_disable() - セプター呪い（通行料無効）
✅ apply_toll_fixed() - セプター呪い（通行料固定）
✅ apply_toll_multiplier() - 領地呪い（通行料倍率）
✅ apply_peace() - 領地呪い（平和）

### Phase 2: SpellPhaseHandler統合
✅ _apply_single_effect() に全toll_*処理追加
✅ プレイヤーターゲット選択（self/enemy）
✅ クリーチャーターゲット選択（land + creature filter）

### Phase 3: GameFlowManager統合
✅ check_and_pay_toll_on_enemy_land() でセプター呪い判定
✅ toll_disable の支払い計算への反映
✅ toll_fixed の支払い計算への反映
✅ peace呪い時の支払い = 0G処理実装
❌ toll_share の配分処理（複数プレイヤー競合時の実装は保留）

### Phase 4: TileDataManager統合
✅ calculate_toll() で toll_multiplier 判定
✅ クリーチャー呪い確認して倍率適用

### Phase 5: BoardSystem3D統合
❌ _get_valid_moves() で peace 呪い判定（未実装）
❌ 移動候補から除外処理（未実装）
❌ _try_invade() で peace 呪い判定（未実装）
❌ 戦闘UI表示ブロック処理（未実装）

### Phase 6: テスト
❌ ドリームトレイン - 通行料50%獲得確認
❌ ブラックアウト - 通行料0確認
❌ ユニフォーミティ - 通行料200固定確認
❌ グリード - 通行料1.5倍確認
⚠️ ピース - 敵移動除外・戦闘不可は未実装、通行料0のみ実装

## 最近の修正（2025/11/23）

### 通行料0処理の実装
- `check_and_pay_toll_on_enemy_land()` に peace 呪い判定を追加
- peace 呪い時は通行料を0に設定
- `SpellCurseToll.has_peace_curse_on_land()` メソッド新規追加

### 初期化の統一
- GameSystemManager の Phase 4-2 で SpellCurseToll を初期化
- GameFlowManager._setup_spell_systems() では初期化しない（重複を避ける）

## 未実装項目（残作業）

### BoardSystem3D 連携（Phase 5）
peace呪いのピース以下が未実装：
1. 敵移動除外 - _get_valid_moves() の修正必要
2. 戦闘不可 - _try_invade() の修正必要

### セプター呪い（toll_share）
- 複数プレイヤー競合時の配分ロジック未実装
- 現在は get_receiver_toll() で返却のみ

## 重要な参照先
- ドキュメント: `docs/design/spells/通行料呪い_final.md`
- SpellCurseToll: `scripts/spells/spell_curse_toll.gd`
- GameFlowManager: `scripts/game_flow_manager.gd` (check_and_pay_toll_on_enemy_land)
- TileDataManager: `scripts/tile_data_manager.gd` (calculate_toll)
