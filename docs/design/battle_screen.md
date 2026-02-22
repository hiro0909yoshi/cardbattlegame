# バトル画面設計書

## 概要

バトル開始時に専用のバトル画面（オーバーレイ）を表示し、クリーチャー同士の戦闘を視覚的に演出する。

## 画面構成

```
┌─────────────────────────────────────────────────────────────────┐
│                          バトル背景                              │
│                                                                  │
│  ┌─────────────────┐                  ┌─────────────────┐       │
│  │  ┌───────────┐  │                  │  ┌───────────┐  │       │
│  │  │           │  │                  │  │           │  │       │
│  │  │ 侵略側    │  │       VS        │  │ 防衛側    │  │       │
│  │  │ カード    │  │                  │  │ カード    │  │       │
│  │  │ (3.9倍)   │  │                  │  │ (3.9倍)   │  │       │
│  │  │           │  │                  │  │           │  │       │
│  │  └───────────┘  │                  │  └───────────┘  │       │
│  └─────────────────┘                  └─────────────────┘       │
│        ←───── 片側300px ─────→  ←───── 片側300px ─────→        │
│                        合計600px                                 │
│  ┌────────────────────┐              ┌────────────────────┐     │
│  │ HP ████████░░ 50/60│              │ HP ████████░░ 50/60│     │
│  │ AP ██████████ 30   │              │ AP ██████████ 25   │     │
│  └────────────────────┘              └────────────────────┘     │
│   中央から左に300px                      中央から右に300px       │
└─────────────────────────────────────────────────────────────────┘

カードサイズ: 220×293 × 3.9倍 = 858×1143
カード間隔: 片側300px（合計600px）
HP/APバー間隔: 中央から左右に300pxずつ（合計600px）
```

## レイヤー構造

```
※既存レイヤー: NotificationLayer = 100

CanvasLayer (layer = 110) - TransitionLayer（最前面）
└── ColorRect (黒、フェード用)
└── BattleStartLabel ("BATTLE!" テキスト)

CanvasLayer (layer = 90) - BattleScreen  
└── Background (背景)
├── AttackerDisplay (左・侵略側カード)
│   └── CardContainer (Card.tscnインスタンス、3.9倍スケール)
│   └── SkillLabel (スキル名表示、36pt)
├── DefenderDisplay (右・防衛側カード)
│   └── CardContainer (Card.tscnインスタンス、3.9倍スケール)
│   └── SkillLabel (スキル名表示、36pt)
├── AttackerHPBar (固定位置、中央から左に300px)
├── DefenderHPBar (固定位置、中央から右に300px)
├── VSLabel (中央)
├── EffectLayer (エフェクト用)
└── ClickArea (クリック待ち用、最前面)
```

## 画面遷移

### バトル開始時
```
1. フェードアウト（0.25秒）→ 画面が暗くなる
2. 暗転中（0.25秒）
   - "BATTLE!" テキスト表示（オプション）
   - バトル画面を準備（非表示状態で）
3. フェードイン（0.25秒）→ バトル画面が表示される
4. イントロ演出
   - 侵略側カードが左からスライドイン
   - 防衛側カードが右からスライドイン
   - VSが表示される
5. クリック待ち（ユーザーがクリックするまで停止）
6. スキル発動フェーズ → バトル開始
```

### バトル終了時
```
1. 結果演出（勝敗表示など） - show_battle_result()
2. 戦闘終了時能力の表示（再生、属性変化など）
   - この時点ではまだバトル画面が表示されている
   - スキル名表示やHP/APバーの更新が可能
3. バトル画面を閉じる - close_battle_screen()
   - フェードアウト（0.25秒）
   - バトル画面を削除
   - フェードイン（0.25秒）→ 元のゲーム画面
```

## バトル演出フロー

### 1. バトル準備フェーズ
```
- 侵略側/防衛側のクリーチャーデータ読み込み
- アイテム使用がある場合はアイテムデータも読み込み
- HPバー初期表示:
  - 緑セグメント: current_hp + item_bonus_hp
  - 土地ボーナス: 黄色
  - この時点ではバフ（水色）は無し
- APバー初期表示: 基本AP値
```

### 2. クリック待ち
```
- ユーザーがクリックするまで待機
- クリック後、スキル発動フェーズへ
```

### 3. スキル発動フェーズ（1つずつアニメーション）
```
発動順序に従って以下を繰り返す（各スキル1.5秒）:
1. スキル名をカード上部に表示
2. HP/APバーを変動させる（1.5秒かけて滑らかに）
   - 緑セグメント: current_hp + item_bonus_hp
   - バフ（水色）: 共鳴 + 一時 + スペル
   - 土地（黄）: 土地ボーナス
3. 次のスキルへ

適用されるスキル例:
- レリック効果
- ターン数ボーナス
- 共鳴スキル
- 土地数効果
- 強化
- 刺突（土地ボーナス無効化）
- 術攻撃
```

### 4. 攻撃フェーズ
```
攻撃順序に従って:
1. 攻撃側カードが前に移動（0.2秒）
2. 攻撃エフェクト再生
3. 被攻撃側カードが揺れる
4. ダメージ数値ポップアップ
5. HPバー減少（1.5秒かけて右側から消費）
   - 土地(黄) → バフ(水色) → 緑セグメント の順で減少
6. 攻撃側カードが元の位置に戻る（0.2秒）
7. 次の攻撃へ
```

### 5. 結果表示
```
- 勝敗に応じた演出
- 敗北側カードが消える/倒れるアニメーション
```

## HP/APバー仕様

### HPバー（複合セグメント構造）

HPバーは複数の色セグメントで構成され、HPの内訳を視覚的に表現する。
**右側から消費される**ため、表示順序は消費順序の逆になる。

```
HPバー構造（左から右）:
┌─────────────────────────────────────────────────┐
│ 緑セグメント    │ バフ(水色) │ 土地ボーナス(黄) │ 空(灰)
└─────────────────────────────────────────────────┘
  current_hp        共鳴+一時     最初に消費
  +item_bonus_hp    +スペル
  （最後に消費）

数値表示: 「65 / 90」(現在の合計HP / 合計最大HP)
※数値は実際の値を表示（100を超えることもある）
```

**バーの最大幅:**
- 常に100固定
- HP/APが100を超えてもバーは100%で止まる
- 数値ラベルは実際の値を正確に表示

**消費順序（battle_participant.gd準拠）:**
1. 土地ボーナス（land_bonus_hp）← 最初に消費
2. 共鳴ボーナス（resonance_bonus_hp）
3. 一時的ボーナス（temporary_bonus_hp）
4. スペルボーナス（spell_bonus_hp）
5. アイテムボーナス（item_bonus_hp）
6. current_hp ← 最後に消費

**色分け:**
- 緑 `#4CAF50`: current_hp + item_bonus_hp
- バフ（水色）`#03A9F4`: 共鳴 + 一時的 + スペルボーナスの合計
- 土地ボーナス（黄）`#FFC107`: 最初に消費
- 空（灰）`#424242`: 残りHP枠（最大100）
- ダメージ中（赤）`#F44336`: 減少演出用オーバーレイ

**アニメーション:**
- 変動時間: 1.5秒
- 消費順序を反映（右から順に減少: 黄→水色→緑）
- 回復時は全セグメント同時に増加

**サイズ（5.2倍スケール）:**
- 幅: 1040px
- 高さ: 125px
- 数値フォント: 72pt、太字、白色、アウトライン10px
- 枠線: 10px

**配置:**
- 固定位置（画面下部、y = 画面高さ - 280px）
- カードと連動せず独立配置
- 攻撃側: 中央から左に300px（バー右端）
- 防御側: 中央から右に300px（バー左端）

### APバー
- 色: 青系 `#2196F3`（単色）
- 最大幅: 100固定（APが100以上でもバーは100%で止まる）
- 幅: 1040px
- 高さ: 83px
- 数値フォント: 62pt
- スペーシング: 21px（HPバーとの間隔）
- 数値表示: 実際のAP値
- アニメーション: 1.5秒かけて滑らかに変動

## スキル名表示仕様

- 位置: カード上部（カードの中央揃え）
- 背景: 半透明の茶色プレート（300×60px）
- フォント: 36pt、太字、白色
- アウトライン: 4px、黒色
- 表示時間: 1.5秒
- アニメーション: フェードイン（0.15秒）→ 維持 → フェードアウト（0.15秒）

## ダメージポップアップ仕様

- ダメージ: 赤色、「-30」形式
- 回復: 緑色、「+20」形式
- バフ: 青色、「AP+10」等
- アニメーション: 上に浮き上がりながらフェードアウト
- フォントサイズ: 大きめ（視認性重視）

## カード表示

バトル画面では実際のCard.tscnシーンをインスタンス化して表示する。

**仕様:**
- Card.tscn（res://scenes/Card.tscn）をインスタンス化
- スケール: 3.9倍（元サイズ 220×293 → 858×1143）
- `load_dynamic_creature_data()`でクリーチャーデータを設定
- マウスイベントは無効化（バトル画面では選択不要）

**配置:**
- 画面中央を基準に左右均等配置
- カード間スペース: 片側300px（合計600px）
- 攻撃側: 中央 - 300 - カード幅
- 防御側: 中央 + 300
- Y位置: 画面中央から550px上

## 実装ファイル構成

```
res://scripts/battle_screen/
├── battle_screen.gd            # メイン制御（CanvasLayer）
├── battle_creature_display.gd  # クリーチャー表示制御（Card.tscnインスタンス化）
├── hp_ap_bar.gd                # バー制御（固定位置、最大値100固定）
├── damage_popup.gd             # ポップアップ制御
├── skill_label.gd              # スキル名表示制御（36pt）
├── transition_layer.gd         # 画面遷移制御
└── battle_screen_manager.gd    # 既存システムとの連携

res://scripts/battle/
└── battle_skill_processor.gd   # スキル適用（1つずつアニメーション対応）
```

## 既存システムとの連携

### BattleScreenManager
```gdscript
class_name BattleScreenManager

signal intro_completed
signal skill_animation_completed
signal attack_animation_completed
signal battle_screen_closed

func start_battle(attacker_data, defender_data, item_data = null):
	# トランジション → バトル画面表示 → イントロ演出
	pass

func show_skill_activation(side: String, skill_name: String, effects: Dictionary):
	# スキル発動演出（1.5秒）
	# side: "attacker" or "defender"
	# effects: {hp_data, ap}
	pass

func show_attack(attacker_side: String, damage: int):
	# 攻撃演出
	pass

func show_damage(side: String, amount: int):
	# ダメージ表示
	pass

func update_hp(side: String, hp_data: Dictionary):
	# HPバー更新（1.5秒アニメーション）
	pass

func update_ap(side: String, value: int):
	# APバー更新（1.5秒アニメーション）
	pass

func show_battle_result(result: int):
	# 結果表示のみ（画面は閉じない）
	# 戦闘終了時能力の表示のため、結果表示後も画面を維持
	pass

func close_battle_screen():
	# バトル画面を閉じる
	# トランジション → 画面削除 → シグナル発火
	pass

func end_battle(result: int):
	# 後方互換性のため残す
	# show_battle_result() + close_battle_screen() を順番に呼ぶ
	pass
```

## 開発フェーズ

### Phase 1: 基本画面 ✅
- [x] TransitionLayer作成
- [x] BattleScreen基本レイアウト
- [x] カード表示（Card.tscnインスタンス化）
- [x] HP/APバー（固定位置配置）

### Phase 2: アニメーション ✅
- [x] 画面遷移（フェードイン/アウト）
- [x] カードスライドイン
- [x] HP/APバーのTweenアニメーション（1.5秒）
- [x] ダメージポップアップ
- [x] クリック待ち機能
- [x] 右から順にHP消費するアニメーション

### Phase 3: スキル演出 ✅
- [x] スキル名表示（36pt、1.5秒）
- [x] スキル1つずつアニメーション表示
- [x] 攻撃アニメーション
- [ ] 基本エフェクト

### Phase 4: 既存システム連携 ✅
- [x] BattleScreenManager実装
- [x] battle_system.gdとの統合
- [x] battle_skill_processor.gdのスキル別アニメーション対応
- [x] awaitによる演出待機

### Phase 5: サウンド・仕上げ
- [ ] 効果音追加
- [ ] BGM切り替え
- [ ] エフェクト追加・調整

## 実装メモ

### 2024年12月実装
- BattleCreatureDisplayでCard.tscnをインスタンス化
- HPバーを固定位置に配置（カードと連動しない）
- バトル開始後のクリック待ち機能
- カード間隔: 片側300px（合計600px）
- HPバー間隔: 中央から左右に300pxずつ
- HP/APバー最大値100固定（100以上でもバーは100%で止まる）
- スキル1つずつアニメーション表示（1.5秒）
- スキル名表示を大きく（36pt、背景300×60px）
- HP消費アニメーション: 右から順（黄→水色→緑）

---

## スキル追加ガイド

新しいスキルを追加する際のバトル画面表示・アニメーション実装ガイド。

### スキルの種類と処理タイミング

| タイミング | 処理場所 | 例 |
|-----------|---------|-----|
| 戦闘開始前（クリック後） | `battle_skill_processor.gd` | 共鳴、強化、刺突、ブルガサリ |
| 攻撃成功時 | `battle_execution.gd` | APドレイン、刻印付与、ダウン付与 |

### 共通関数: `_show_skill_change_if_any`

スキル適用後のHP/APバー更新とスキル名表示を自動で行う共通関数。

```gdscript
func _show_skill_change_if_any(
	participant: BattleParticipant,  # 変化をチェックする対象
	before: Dictionary,              # スキル適用前のスナップショット
	skill_name: String,              # 表示するスキル名
	skill_owner: BattleParticipant = null  # スキル名を表示する側（省略時はparticipant）
) -> void
```

**動作:**
1. `participant`のステータスが`before`から変化したかチェック
2. 変化があれば`skill_owner`側にスキル名表示
3. `participant`側のHP/APバーをアニメーション更新

### 使い方

#### 1. 自己バフ系スキル（自分のステータスが変化）

```gdscript
# 例: 共鳴、強化、ターン数ボーナス
var before = _snapshot_stats(attacker)
ResonanceSkill.apply_resonance(attacker, board_system_ref)
await _show_skill_change_if_any(attacker, before, "共鳴")
```

#### 2. 敵対象スキル（敵のステータスを変化させる）

第4引数`skill_owner`でスキル所持者を指定。

```gdscript
# 例: 刺突（attackerのスキルでdefenderの土地ボーナスを無効化）
var before = _snapshot_stats(defender)
PenetrationSkill.apply_penetration(attacker, defender)
await _show_skill_change_if_any(defender, before, "刺突", attacker)
# → attackerカード側に「刺突」表示、defenderのHPバーが減少
```

#### 3. 両者チェックするスキル

```gdscript
# 例: ブルガサリ（どちらかがアイテム使用時に発動）
attacker_before = _snapshot_stats(attacker)
defender_before = _snapshot_stats(defender)
SkillPermanentBuff.apply_bulgasari_battle_bonus(attacker, ...)
SkillPermanentBuff.apply_bulgasari_battle_bonus(defender, ...)
await _show_skill_change_if_any(attacker, attacker_before, "ブルガサリ")
await _show_skill_change_if_any(defender, defender_before, "ブルガサリ")
```

### 攻撃成功時スキルの追加（battle_execution.gd）

攻撃成功時に発動するスキルは`execute_attack_sequence()`内の攻撃成功ブロックで処理。

```gdscript
# 攻撃成功時効果ブロック内（約460行目付近）
if defender_p.is_alive() and attacker_p.current_ap > 0:
	# 既存: 刻印付与、ダウン付与
	# 新しいスキル追加例:
	var drained = _apply_ap_drain_on_attack_success(attacker_p, defender_p)
	if drained and battle_screen_manager:
		var skill_owner_side = "attacker" if attacker_p.is_attacker else "defender"
		var target_side = "attacker" if defender_p.is_attacker else "defender"
		await battle_screen_manager.show_skill_activation(skill_owner_side, "APドレイン", {})
		await battle_screen_manager.update_ap(target_side, defender_p.current_ap)
```

### スナップショットで検出される変化

```gdscript
# _snapshot_stats()が記録するフィールド
- current_hp
- current_ap
- resonance_bonus_hp    # 共鳴ボーナス
- temporary_bonus_hp    # 一時的ボーナス
- spell_bonus_hp        # スペルボーナス
- land_bonus_hp         # 土地ボーナス
- item_bonus_hp         # アイテムボーナス
```

これらのフィールドが変化した場合のみアニメーションが実行される。

### チェックリスト（新スキル追加時）

- [ ] スキルの処理タイミングを決定（戦闘開始前 or 攻撃成功時）
- [ ] 自己バフか敵対象かを確認
- [ ] `_snapshot_stats()`でスキル適用前の状態を保存
- [ ] スキルロジックを実行
- [ ] `_show_skill_change_if_any()`を呼び出し
  - 自己バフ: 第4引数省略
  - 敵対象: 第4引数にスキル所持者を指定
- [ ] 攻撃成功時スキルの場合は`battle_execution.gd`で直接`battle_screen_manager`を使用

---

## スキル表示システム（SkillDisplayConfig）

### 概要

スキル発動時の表示（スキル名、エフェクト、SE）を一元管理するシステム。
マッピングテーブル方式により、JSONの変更なしでスキル表示を制御できる。

### ファイル構成

```
res://scripts/battle_screen/
└── skill_display_config.gd    # スキル表示設定（マッピングテーブル）
```

### 設計思想

| 項目 | 方針 |
|------|------|
| スキル名 | マッピングテーブルで`effect_type`→日本語名 |
| エフェクト | マッピングテーブルで指定（未実装なら空文字） |
| SE | マッピングテーブルで指定（未実装なら空文字） |
| パラメータ分岐 | JSONの値（element等）を渡して動的にエフェクト決定 |

### マッピングテーブル構造

```gdscript
# skill_display_config.gd
class_name SkillDisplayConfig

const CONFIG = {
	# 固定エフェクトのスキル
	"power_strike": {
		"name": "強化",
		"effect": "impact_fire",
		"sound": "se_power"
	},
	"ap_drain": {
		"name": "APドレイン",
		"effect": "drain_purple",
		"sound": "se_drain"
	},
	"penetration": {
		"name": "刺突",
		"effect": "shield_break",
		"sound": "se_break"
	},
	
	# パラメータで分岐するスキル
	"change_tile_element": {
		"name": "属性変化",
		"effect_by_element": {
			"water": "element_change_water",
			"fire": "element_change_fire",
			"wind": "element_change_wind",
			"earth": "element_change_earth"
		},
		"sound": "se_element_change"
	},
	
	# エフェクト未実装のスキル（名前のみ表示）
	"resonance": {
		"name": "共鳴",
		"effect": "",
		"sound": ""
	}
}
```

### パラメータ分岐の仕組み

同じ`effect_type`でも、JSONのパラメータに応じて異なるエフェクトを再生できる。

**対応パターン:**

| パターン | テーブルのキー | 渡すパラメータ |
|---------|--------------|---------------|
| 属性分岐 | `effect_by_element` | `{"element": "water"}` |
| 条件分岐 | `effect_by_condition` | `{"condition": "enemy_no_item"}` |
| 対象分岐 | `effect_by_target` | `{"target": "enemy"}` |

**例: 属性変化（バハムート）**

```json
// JSONデータ
{
  "effect_type": "change_tile_element",
  "element": "water"
}
```

```gdscript
// 呼び出し
var params = {"element": effect.get("element", "")}
var config = SkillDisplayConfig.get_config("change_tile_element", params)
// → {"name": "属性変化", "effect": "element_change_water", "sound": "se_element_change"}
```

### 公開API

```gdscript
## 設定を取得
## @param effect_type: スキルのeffect_type
## @param params: 分岐用パラメータ（省略可）
## @return: {name, effect, sound}
static func get_config(effect_type: String, params: Dictionary = {}) -> Dictionary

## スキル表示を実行（名前 + エフェクト + SE）
## @param battle_screen_manager: バトル画面マネージャー
## @param effect_type: スキルのeffect_type
## @param side: "attacker" or "defender"
## @param params: 分岐用パラメータ（省略可）
static func show(battle_screen_manager, effect_type: String, side: String, params: Dictionary = {}) -> void
```

### 使用例

#### 基本的な使い方（発動箇所で1行追加）

```gdscript
# 強化発動時
PowerStrikeSkill.apply(participant, context)
await SkillDisplayConfig.show(battle_screen_manager, "power_strike", side)

# 属性変化発動時（パラメータ渡し）
var element = effect.get("element", "")
apply_tile_element_change(tile, element)
await SkillDisplayConfig.show(battle_screen_manager, "change_tile_element", side, {"element": element})
```

#### ステータス変動スキルとの併用

ステータス変動があるスキルは既存の`_show_skill_change_if_any`を使用。
SkillDisplayConfigはステータス変動がないスキル向け。

```gdscript
# ステータス変動あり → 既存方式（自動検出）
var before = _snapshot_stats(participant)
ResonanceSkill.apply(participant, context)
await _show_skill_change_if_any(participant, before, "共鳴")

# ステータス変動なし → SkillDisplayConfig
if has_first_strike:
	await SkillDisplayConfig.show(battle_screen_manager, "first_strike", side)
```

### keywords系スキルの扱い

keywords系（先制、奮闘など）はそのまま日本語名なので、特別な処理で対応。

```gdscript
const KEYWORD_CONFIG = {
	"先制": {"effect": "speed_up", "sound": "se_speed"},
	"後手": {"effect": "", "sound": ""},
	"奮闘": {"effect": "endure", "sound": "se_endure"},
	"再生": {"effect": "regenerate", "sound": "se_heal"},
	# ...
}

static func show_keyword(battle_screen_manager, keyword: String, side: String) -> void:
	var config = KEYWORD_CONFIG.get(keyword, {})
	await battle_screen_manager.show_skill_activation(side, keyword, {})
	if config.get("effect", ""):
		await battle_screen_manager.play_effect(side, config["effect"])
	if config.get("sound", ""):
		AudioManager.play_se(config["sound"])
```

### スキル発動箇所の対応状況

| カテゴリ | スキル例 | 表示方式 | 対応状況 |
|---------|---------|---------|---------|
| ステータス変動あり | 共鳴、強化、刺突、APドレイン | `_show_skill_change_if_any` | ✅ 対応済 |
| ステータス変動なし（effect_type） | 先制、アイテム破壊、崩壊付与 | `SkillDisplayConfig.show()` | ❌ 未対応 |
| ステータス変動なし（keyword） | 奮闘、再生 | `SkillDisplayConfig.show_keyword()` | ❌ 未対応 |

### 新スキル追加時のチェックリスト

#### ステータス変動があるスキル
- [ ] 処理ロジックを実装
- [ ] `_show_skill_change_if_any`で表示（自動検出）
- [ ] SkillDisplayConfigへの追加は不要

#### ステータス変動がないスキル
- [ ] 処理ロジックを実装
- [ ] SkillDisplayConfig.CONFIGに追加
  ```gdscript
  "new_skill": {
	  "name": "新スキル",
	  "effect": "",  # 後から追加可
	  "sound": ""    # 後から追加可
  }
  ```
- [ ] 発動箇所に1行追加
  ```gdscript
  await SkillDisplayConfig.show(battle_screen_manager, "new_skill", side)
  ```

### エフェクト追加時の手順

1. エフェクトリソースを作成（`res://effects/`など）
2. BattleScreenManagerに`play_effect()`を実装
3. SkillDisplayConfigのCONFIGにエフェクト名を追加

```gdscript
# 変更前
"power_strike": {"name": "強化", "effect": "", "sound": ""}

# 変更後（エフェクト追加）
"power_strike": {"name": "強化", "effect": "impact_fire", "sound": "se_power"}
```

### バトル系クラスとの関係

```
battle_system.gd
	↓
battle_preparation.gd
	↓
battle_item_applier.gd ──→ SkillDisplayConfig.show()
	↓
battle_skill_processor.gd ──→ _show_skill_change_if_any() / SkillDisplayConfig.show()
	↓
battle_execution.gd ──→ SkillDisplayConfig.show()
	↓
battle_special_effects.gd ──→ SkillDisplayConfig.show()
```

各バトルクラスから`SkillDisplayConfig`を呼び出すことで、スキル表示を一元管理。
