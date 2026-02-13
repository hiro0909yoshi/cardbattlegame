# バトルテスト ビジュアルモード - 詳細実装計画

**最終更新**: 2026-02-13
**関連**: `docs/progress/refactoring_next_steps.md` フェーズ6

---

## 📊 システム理解サマリー

###

 1. 呪いシステムの全体像

**調査したシステム**:
- `SpellLand`: 土地呪い（属性変更、レベル操作、クリーチャー破壊）
- `SpellCurseStat`: クリーチャー呪い（恒久MHP/AP変更、条件付きAP変更、密命）
- `SpellWorldCurse`: プレイヤー呪い（ソリッドワールド、マーシフル、ウェイスト等7種類）
- `SpellCurseToll`: 通行料呪い（toll_share、toll_disable、toll_fixed等）
- `SpellCostModifier`: コスト呪い（ライフフォース、ウェイストワールド）

**テストで設定可能な呪いパラメータ**:
```gdscript
# クリーチャー呪い
curse_stat: {
    "duration": int,          # 持続ターン数
    "value": int,             # 変更値
    "mhp_threshold": int,     # MHP閾値（条件付き呪い用）
    "required_count": int     # 必要数（密命用）
}

# プレイヤー呪い（ワールド呪い）
world_curse: {
    "curse_type": String,     # "solid", "merciful", "waste", "mirror", etc.
    "duration": int,          # 持続ターン数
    "params": Dictionary      # 呪い毎に異なるパラメータ
}

# 通行料呪い
toll_curse: {
    "curse_type": String,     # "toll_share", "toll_disable", "toll_fixed", etc.
    "multiplier": float,      # 倍率（toll_multiplier用）
    "ratio": float,           # 獲得比率（toll_share用）
    "value": int              # 固定値（toll_fixed用）
}
```

### 2. バフシステムの全体像

**BattleParticipant のバフ/ボーナス構造**（HP消費優先度順）:
```
1. land_bonus_hp（土地ボーナス、戦闘毎に復活）→ 属性一致でレベル×10
2. resonance_bonus_hp（感応ボーナス）
3. temporary_bonus_hp（一時効果ボーナス）
4. spell_bonus_hp（スペルボーナス）
5. item_bonus_hp（アイテムボーナス）
6. base_hp（基本HP）
7. base_up_hp（永続基礎上昇）

AP計算:
current_ap = base_ap + base_up_ap + temporary_bonus_ap + item_bonus_ap
```

**効果配列**:
- `permanent_effects`: 移動で消えない効果（マスグロース等）
- `temporary_effects`: 移動で消える効果（スペルバフ等）
- 構造: `{source_name: String, stat: "hp"/"ap", value: int}`

**テストで設定可能なバフパラメータ**:
```gdscript
buff_config: {
    "base_up_hp": int,         # 永続HP上昇
    "base_up_ap": int,         # 永続AP上昇
    "item_bonus_hp": int,      # アイテムボーナスHP
    "item_bonus_ap": int,      # アイテムボーナスAP
    "spell_bonus_hp": int,     # スペルボーナスHP
    "spell_bonus_ap": int,     # スペルボーナスAP
    "permanent_effects": Array # 永続効果配列
    "temporary_effects": Array  # 一時効果配列
}
```

### 3. バトル条件の全体像

**戦闘土地設定**（防御側のみに適用）:
- 属性：fire, water, earth, wind, neutral
- レベル：1-5
- ボーナスHP = レベル × 10（属性一致時）

**隣接クリーチャー設定**:
- 味方隣接：応援スキル効果適用（BattleSkillProcessor）
- 敵隣接：将来拡張の余地

**保有土地数設定**:
- 属性別（fire/water/earth/wind）保有数（0-10）
- 感応スキル発動条件用

---

## 🎯 実装フェーズ

### Phase 1: BattleTestConfig の拡張（呪い・バフ設定追加）

**目的**: テスト設定に全ての呪い・バフパラメータを追加

**見積時間**: 1-2時間
**難易度**: 低

#### 実装内容

**対象ファイル**: `scripts/battle_test/battle_test_config.gd`

```gdscript
class_name BattleTestConfig

# ========== 既存の設定 ==========
var attacker_creatures: Array = []
var attacker_items: Array = []
var attacker_owned_lands: Dictionary = {
    "fire": 0, "water": 0, "earth": 0, "wind": 0
}
var attacker_battle_land: String = "neutral"
var attacker_battle_land_level: int = 1
var attacker_has_adjacent: bool = false

var defender_creatures: Array = []
var defender_items: Array = []
var defender_owned_lands: Dictionary = {
    "fire": 0, "water": 0, "earth": 0, "wind": 0
}
var defender_battle_land: String = "neutral"
var defender_battle_land_level: int = 1
var defender_has_adjacent: bool = false

# ========== 新規追加: 呪い設定 ==========

## 攻撃側呪い設定
var attacker_curse_stat: Dictionary = {}     # クリーチャー呪い
var attacker_world_curse: Dictionary = {}    # ワールド呪い
var attacker_toll_curse: Dictionary = {}     # 通行料呪い

## 防御側呪い設定
var defender_curse_stat: Dictionary = {}
var defender_world_curse: Dictionary = {}
var defender_toll_curse: Dictionary = {}

# ========== 新規追加: バフ設定 ==========

## 攻撃側バフ設定
var attacker_buff_config: Dictionary = {
    "base_up_hp": 0,
    "base_up_ap": 0,
    "item_bonus_hp": 0,
    "item_bonus_ap": 0,
    "spell_bonus_hp": 0,
    "spell_bonus_ap": 0,
    "permanent_effects": [],
    "temporary_effects": []
}

## 防御側バフ設定
var defender_buff_config: Dictionary = {
    "base_up_hp": 0,
    "base_up_ap": 0,
    "item_bonus_hp": 0,
    "item_bonus_ap": 0,
    "spell_bonus_hp": 0,
    "spell_bonus_ap": 0,
    "permanent_effects": [],
    "temporary_effects": []
}

## バリデーション拡張
func validate() -> bool:
    if attacker_creatures.is_empty():
        push_error("攻撃側クリーチャーが未選択")
        return false
    if defender_creatures.is_empty():
        push_error("防御側クリーチャーが未選択")
        return false
    return true
```

---

### Phase 2: BattleTestUI の拡張（呪い・バフ設定UI追加）

**目的**: UI からユーザーが呪い・バフを設定できるようにする

**見積時間**: 2-3時間
**難易度**: 中

#### 実装内容

**対象ファイル**:
- `scripts/battle_test/battle_test_ui.gd`
- `res://scenes/battle_test_tool.tscn`

**追加UI要素**:

```
[既存のUI]
  ├ 攻撃側クリーチャー選択
  ├ 攻撃側アイテム選択
  ├ 防御側クリーチャー選択
  ├ 防御側アイテム選択
  └ 土地設定

[新規: 呪い設定パネル]
  ├ 攻撃側呪い設定
  │  ├ クリーチャー呪い: HP/AP変更値（SpinBox）
  │  ├ ワールド呪い: タイプ選択（OptionButton）
  │  └ 通行料呪い: タイプ選択（OptionButton）
  └ 防御側呪い設定
     └ （同上）

[新規: バフ設定パネル]
  ├ 攻撃側バフ設定
  │  ├ base_up_hp/ap（SpinBox）
  │  ├ item_bonus_hp/ap（SpinBox）
  │  ├ spell_bonus_hp/ap（SpinBox）
  │  └ 効果配列（GridContainer + LineEdit）
  └ 防御側バフ設定
     └ （同上）

[新規: 実行モード設定]
  ├ ☑ ビジュアルモード（バトル画面表示）
  ├ ☑ 自動進行（クリック待ちなし）
  └ 速度: [━━━●━━━━] 1.0x
```

**実装例**:

```gdscript
# battle_test_ui.gd に追加

## 呪い設定UI
@onready var attacker_curse_stat_hp: SpinBox = $CursePanel/AttackerCurseStatHP
@onready var attacker_curse_stat_ap: SpinBox = $CursePanel/AttackerCurseStatAP
@onready var attacker_world_curse_option: OptionButton = $CursePanel/AttackerWorldCurseOption

## バフ設定UI
@onready var attacker_base_up_hp: SpinBox = $BuffPanel/AttackerBaseUpHP
@onready var attacker_base_up_ap: SpinBox = $BuffPanel/AttackerBaseUpAP
@onready var attacker_spell_bonus_hp: SpinBox = $BuffPanel/AttackerSpellBonusHP

## ビジュアルモードUI
@onready var visual_mode_check: CheckBox = $ModePanel/VisualModeCheck
@onready var auto_advance_check: CheckBox = $ModePanel/AutoAdvanceCheck

func _setup_curse_ui():
    # ワールド呪いの選択肢追加
    attacker_world_curse_option.add_item("なし", -1)
    attacker_world_curse_option.add_item("ソリッドワールド", 0)
    attacker_world_curse_option.add_item("マーシフルワールド", 1)
    attacker_world_curse_option.add_item("ウェイストワールド", 2)
    # ...

func _on_execute_button_pressed():
    # 設定をconfigに反映
    config.attacker_curse_stat = {
        "hp": attacker_curse_stat_hp.value,
        "ap": attacker_curse_stat_ap.value
    }
    config.attacker_buff_config["base_up_hp"] = attacker_base_up_hp.value
    # ...

    # 実行モードに応じて分岐
    if visual_mode_check.button_pressed:
        await _execute_visual_mode()
    else:
        _execute_logic_mode()
```

---

### Phase 3: BattleTestExecutor の拡張（呪い・バフ適用）

**目的**: バトル実行時に設定した呪い・バフを自動適用

**見積時間**: 2-3時間
**難易度**: 中

#### 実装内容

**対象ファイル**: `scripts/battle_test/battle_test_executor.gd`

**修正箇所**:

```gdscript
# _execute_single_battle() 内に追加

func _execute_single_battle(...) -> BattleTestResult:
    # ... 既存のBattleParticipant作成 ...

    # ========== 新規追加: 呪い適用 ==========
    _apply_curse_effects(attacker, config.attacker_curse_stat, config.attacker_world_curse, config.attacker_toll_curse)
    _apply_curse_effects(defender, config.defender_curse_stat, config.defender_world_curse, config.defender_toll_curse)

    # ========== 新規追加: バフ適用 ==========
    _apply_buff_config(attacker, config.attacker_buff_config)
    _apply_buff_config(defender, config.defender_buff_config)

    # ... 既存のバトル実行 ...

## 呪い効果適用
static func _apply_curse_effects(participant, curse_stat, world_curse, toll_curse):
    # クリーチャー呪い
    if curse_stat.has("hp") and curse_stat.hp != 0:
        participant.base_hp += curse_stat.hp
        participant.current_hp += curse_stat.hp

    if curse_stat.has("ap") and curse_stat.ap != 0:
        participant.current_ap += curse_stat.ap

    # ワールド呪いは記録のみ（バトル結果に含める）
    participant.creature_data["world_curse"] = world_curse

    # 通行料呪いは記録のみ
    participant.creature_data["toll_curse"] = toll_curse

## バフ適用
static func _apply_buff_config(participant, buff_config):
    participant.base_up_hp = buff_config.get("base_up_hp", 0)
    participant.base_up_ap = buff_config.get("base_up_ap", 0)
    participant.item_bonus_hp = buff_config.get("item_bonus_hp", 0)
    participant.item_bonus_ap = buff_config.get("item_bonus_ap", 0)
    participant.spell_bonus_hp = buff_config.get("spell_bonus_hp", 0)
    participant.spell_bonus_ap = buff_config.get("spell_bonus_ap", 0)

    # 効果配列
    participant.permanent_effects = buff_config.get("permanent_effects", []).duplicate(true)
    participant.temporary_effects = buff_config.get("temporary_effects", []).duplicate(true)

    # current_hpとcurrent_apを更新
    participant.current_hp += participant.base_up_hp
    participant.update_current_ap()
```

---

### Phase 4: BattleScreenManager 統合（ビジュアルモード基盤）

**目的**: BattleScreen をテスト実行中に表示可能にする

**見積時間**: 3-4時間
**難易度**: 中～高

#### 実装内容

**対象ファイル**:
- `scripts/battle_test/battle_test_ui.gd`
- `scripts/battle_screen/battle_screen_manager.gd`

**ビジュアルモード実行ロジック**:

```gdscript
# battle_test_ui.gd に追加

var _battle_screen_manager: BattleScreenManager = null

func _ready():
    # BattleScreenManagerを作成
    _battle_screen_manager = BattleScreenManager.new()
    _battle_screen_manager.name = "BattleScreenManager_Test"
    add_child(_battle_screen_manager)

## ビジュアルモード実行
func _execute_visual_mode():
    # テストケース生成
    var test_cases = _generate_test_cases()

    print("[ビジュアルモード] ", test_cases.size(), "バトル実行")

    for i in range(test_cases.size()):
        var test_case = test_cases[i]

        # プログレス表示
        _update_progress(i + 1, test_cases.size())

        # バトル情報パネル表示
        _show_battle_info_panel(test_case)

        # バトル実行（BattleScreen表示）
        await _execute_single_visual_battle(test_case)

        # 自動進行がOFFなら、ユーザーのクリック待ち
        if not auto_advance_check.button_pressed:
            await _wait_for_user_input()

    print("[ビジュアルモード] 完了")

## 単一バトルを視覚的に実行
func _execute_single_visual_battle(test_case: Dictionary):
    # 攻撃側/防御側データ準備
    var attacker_data = _prepare_creature_data_with_curses_and_buffs(
        test_case.attacker_creature_id,
        test_case.attacker_item_id,
        config.attacker_curse_stat,
        config.attacker_buff_config
    )

    var defender_data = _prepare_creature_data_with_curses_and_buffs(
        test_case.defender_creature_id,
        test_case.defender_item_id,
        config.defender_curse_stat,
        config.defender_buff_config,
        config.defender_battle_land,
        config.defender_battle_land_level
    )

    # バトル画面を開く
    await _battle_screen_manager.start_battle(attacker_data, defender_data)

    # イントロ完了待ち
    await _battle_screen_manager.intro_completed

    # スキル発動を視覚化
    await _show_skills_visual(attacker_data, defender_data)

    # バトル実行（BattleSystemを使用）
    var battle_system = BattleSystem.new()
    # ... バトル実行 ...

    # HP/AP変化を視覚化
    await _battle_screen_manager.update_hp("attacker", attacker_hp_data)
    await _battle_screen_manager.update_hp("defender", defender_hp_data)

    # 結果表示
    var result = _determine_winner(attacker_data, defender_data)
    await _battle_screen_manager.show_battle_result(result)

    # 結果パネル更新
    _update_result_panel(test_case, attacker_data, defender_data, result)

    # バトル画面を閉じる
    await _battle_screen_manager.close_battle_screen()
```

---

### Phase 5: テストケース・ドキュメント作成

**目的**: 実装完了後の機能確認とユーザー向けドキュメント

**見積時間**: 1-2時間
**難易度**: 低

#### 実装内容

**新規作成ドキュメント**:
1. `docs/design/battle_test_coverage.md` - カバー範囲一覧
2. `docs/usage/battle_test_visual_mode_guide.md` - 使用方法ガイド

**プリセットテストケース**:

```gdscript
# battle_test_ui.gd に追加

func _create_preset_tests():
    # プリセット1: 呪い効果テスト
    var preset_curse = BattleTestConfig.new()
    preset_curse.attacker_creatures = [100]  # 基本クリーチャー
    preset_curse.defender_creatures = [200]
    preset_curse.defender_curse_stat = {"hp": -20, "ap": -10}  # HP-20, AP-10呪い

    # プリセット2: バフ効果テスト
    var preset_buff = BattleTestConfig.new()
    preset_buff.attacker_creatures = [101]
    preset_buff.defender_creatures = [201]
    preset_buff.attacker_buff_config = {
        "base_up_hp": 30,
        "base_up_ap": 10,
        "permanent_effects": [
            {"source_name": "テスト効果", "stat": "hp", "value": 20}
        ]
    }

    # プリセット3: 土地レベル・感応テスト
    var preset_land = BattleTestConfig.new()
    preset_land.attacker_creatures = [102]  # 感応持ち
    preset_land.attacker_owned_lands = {"fire": 5, "water": 3}
    preset_land.defender_creatures = [202]
    preset_land.defender_battle_land = "fire"
    preset_land.defender_battle_land_level = 5  # Lv5 → +50HP
```

---

## 📋 対象ファイル一覧

| ファイル | 操作 | Phase | 理由 |
|---------|------|-------|------|
| `scripts/battle_test/battle_test_config.gd` | 修正 | 1 | 呪い・バフ設定フィールド追加 |
| `scripts/battle_test/battle_test_ui.gd` | 修正 | 2, 4 | 呪い・バフ設定UI、ビジュアルモード実行 |
| `res://scenes/battle_test_tool.tscn` | 修正 | 2 | UI要素追加 |
| `scripts/battle_test/battle_test_executor.gd` | 修正 | 3 | 呪い・バフ適用ロジック |
| `scripts/battle_screen/battle_screen_manager.gd` | 参照 | 4 | ビジュアルモード表示用（修正不要） |
| `docs/design/battle_test_coverage.md` | 新規 | 5 | カバー範囲ドキュメント |
| `docs/usage/battle_test_visual_mode_guide.md` | 新規 | 5 | 使用方法ガイド |

---

## ⚠️ リスク と 対策

| リスク | 深刻度 | 対策 |
|-------|--------|------|
| 呪い効果の不正確な適用 | 中 | SpellCurse系クラスの実装を参照、既存ロジックを再利用 |
| バフ効果配列の不整合 | 中 | BattlePreparation の apply_effect_arrays() を参照 |
| ビジュアルモードの非同期処理エラー | 高 | await を適切に使用、BattleScreenManager のシグナル待ち |
| UI レイアウト崩れ | 低 | ScrollContainer を使用、動的サイズ調整 |
| パフォーマンス低下（大量バトル実行時） | 低 | ビジュアルモードは1バトルずつ実行、ロジックモードは高速 |

---

## ✅ 期待される成果

### エフェクト開発支援
- ✅ スキル発動エフェクトを即座に確認
- ✅ ダメージポップアップの調整
- ✅ HP/APバーアニメーションの調整
- ✅ タイミング調整が容易

### デバッグ支援
- ✅ バグの視覚的発見（「あれ、スキル発動してない？」）
- ✅ アイテム効果の確認（「ちゃんとHP増えてる？」）
- ✅ 呪い効果の確認（「ちゃんとAP減ってる？」）
- ✅ 複数バトルの比較（「なぜこのバトルだけ勝つ？」）

### 設計検証
- ✅ バランス調整（「このアイテム強すぎ？」）
- ✅ スキルの視覚的インパクト確認
- ✅ デザイナーでも理解しやすい

### テストカバレッジ向上
- ✅ 呪い効果テスト（土地呪い、クリーチャー呪い、ワールド呪い）
- ✅ バフ効果テスト（永続効果、一時効果）
- ✅ 複雑なバトル条件テスト（隣接クリーチャー、土地レベル）

---

## 📊 見積り時間サマリー

| Phase | 内容 | 見積時間 | 難易度 |
|-------|------|---------|--------|
| Phase 1 | BattleTestConfig 拡張 | 1-2時間 | 低 |
| Phase 2 | BattleTestUI 拡張 | 2-3時間 | 中 |
| Phase 3 | BattleTestExecutor 拡張 | 2-3時間 | 中 |
| Phase 4 | BattleScreenManager 統合 | 3-4時間 | 中～高 |
| Phase 5 | テストケース・ドキュメント | 1-2時間 | 低 |
| **合計** | | **9-14時間** | 中～高 |

---

## 次のステップ

1. ユーザーにこの計画を確認してもらう
2. 承認後、Phase 1 から実装開始
3. 各Phase完了後、動作確認
4. 全Phase完了後、総合テスト

---

**注意**: このドキュメントは `docs/progress/refactoring_next_steps.md` のフェーズ6の詳細版です。
