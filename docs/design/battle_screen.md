# バトル画面設計書

## 概要

バトル開始時に専用のバトル画面（オーバーレイ）を表示し、クリーチャー同士の戦闘を視覚的に演出する。

## 画面構成

```
┌─────────────────────────────────────────────────────────────────┐
│                          バトル背景                              │
│  ┌───────────────────┐              ┌───────────────────┐       │
│  │   [スキル名]       │              │   [スキル名]       │       │
│  │  ┌─────────────┐  │              │  ┌─────────────┐  │       │
│  │  │             │  │              │  │             │  │       │
│  │  │  侵略側     │  │     VS      │  │  防衛側     │  │       │
│  │  │  カード     │  │              │  │  カード     │  │       │
│  │  │  (大)       │  │              │  │  (大)       │  │       │
│  │  │             │  │              │  │             │  │       │
│  │  └─────────────┘  │              │  └─────────────┘  │       │
│  │  [名前]            │              │  [名前]            │       │
│  │  HP ████████░░ 50/60             │  HP ████████░░ 40/50│       │
│  │  AP ██████████ 30                │  AP ██████████ 25   │       │
│  └───────────────────┘              └───────────────────┘       │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ [アイテム表示エリア]                                      │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

## レイヤー構造

```
※既存レイヤー: NotificationLayer = 100

CanvasLayer (layer = 110) - TransitionLayer（最前面）
└── ColorRect (黒、フェード用)
└── BattleStartLabel ("BATTLE!" テキスト)

CanvasLayer (layer = 90) - BattleScreenLayer  
└── BattleScreen (メインコンテナ)
    ├── Background (背景)
    ├── AttackerSide (左・侵略側)
    │   ├── SkillLabel (スキル名表示)
    │   ├── CardDisplay (カード表示)
    │   ├── NameLabel (クリーチャー名)
    │   ├── HPBar (複合バー)
    │   ├── APBar + APLabel
    │   └── DamagePopup (ダメージ数字)
    ├── CenterArea (中央)
    │   └── VSLabel
    ├── DefenderSide (右・防衛側)
    │   ├── SkillLabel
    │   ├── CardDisplay
    │   ├── NameLabel
    │   ├── HPBar (複合バー)
    │   ├── APBar + APLabel
    │   └── DamagePopup
    ├── ItemDisplay (使用アイテム表示)
    └── EffectLayer (エフェクト用)
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
```

### バトル終了時
```
1. 結果演出（勝敗表示など）
2. フェードアウト（0.25秒）
3. バトル画面を非表示に
4. フェードイン（0.25秒）→ 元のゲーム画面
```

## バトル演出フロー

### 1. バトル準備フェーズ
```
- 侵略側/防衛側のクリーチャーデータ読み込み
- アイテム使用がある場合はアイテムデータも読み込み
- HPバー初期表示:
  - 緑セグメント（base_hp + base_up_hp）: 緑色
  - 土地ボーナス: 黄色（防御側のみ）
  - この時点ではバフ（水色）は無し
- APバー初期表示: 基本AP値
```

### 2. アイテム使用フェーズ（該当時のみ）
```
- アイテムカードを画面下部に表示
- アイテム効果発動アニメーション
- HP/APバーを更新:
  - アイテムボーナスHP: 緑セグメントに加算（表示上）
  - base_up_hp上昇: 緑セグメントを伸ばす
  - AP変動: APバーを更新
- アイテムフェーズ完了後、戦闘フェーズへ
```

### 3. スキル発動フェーズ（戦闘前）
```
発動順序に従って以下を繰り返す:
1. スキル名をカード上部に表示（0.5秒）
2. スキルエフェクト再生
3. HP/APバーを変動させる（Tweenで滑らかに）
   - base_up_hp/item_bonus_hp上昇: 緑セグメントを伸ばす
   - バフHP上昇（感応/一時/スペル）: 水色セグメントを追加/延長
   - HP減少: 右側から減少（土地→バフ→緑セグメント順、赤い演出）
   - AP変動: APバーを更新
4. ダメージ/回復/バフ数値をポップアップ表示
5. 次のスキルへ（0.3秒待機）
```

### 4. 攻撃フェーズ
```
攻撃順序に従って:
1. 攻撃側カードが前に移動（0.2秒）
2. 攻撃エフェクト再生
3. 被攻撃側カードが揺れる
4. ダメージ数値ポップアップ
5. HPバー減少（右側から消費、Tweenで滑らかに）
   - 土地(黄) → バフ(水色) → 緑セグメント の順で減少
6. 攻撃側カードが元の位置に戻る（0.2秒）
7. 次の攻撃へ（0.3秒待機）
```

### 5. スキル発動フェーズ（戦闘後）
```
- 死亡時スキル、勝利/敗北時スキル等
- フェーズ3と同様の演出
```

### 6. 結果表示
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
  base_hp           感応+一時     最初に消費
  +base_up_hp       +スペル
  +アイテム(表示上)
  （最後に消費）

数値表示: 「65 / 100」(現在の合計HP / 表示上の最大値)
```

**消費順序（battle_participant.gd準拠）:**
1. 土地ボーナス（land_bonus_hp）← 最初に消費
2. 感応ボーナス（resonance_bonus_hp）
3. 一時的ボーナス（temporary_bonus_hp）
4. スペルボーナス（spell_bonus_hp）
5. アイテムボーナス（item_bonus_hp）
6. current_hp ← 最後に消費

**色分け:**
- 緑 `#4CAF50`: base_hp + base_up_hp + アイテムボーナス（表示上、緑セグメントに含める）
- バフ（水色）`#03A9F4`: 感応 + 一時的 + スペルボーナスの合計
- 土地ボーナス（黄）`#FFC107`: 防御側のみ、戦闘ごとに復活、最初に消費
- 空（灰）`#424242`: 残りHP枠
- ダメージ中（赤）`#F44336`: 減少演出用オーバーレイ

**表示タイミング:**
1. バトル開始時: 緑セグメント + 土地ボーナスを表示（防御側のみ土地ボーナスあり）
2. アイテム使用後: アイテムボーナスHPは緑セグメントに加算（表示上）
3. スキル発動後: 該当セグメントを変動
4. ダメージ時: 右側から減少（土地→バフ→緑の順）

**緑セグメントに含めるもの（表示上）:**
- base_hp: クリーチャーの基礎HP
- base_up_hp: 永続的なHP上昇（レベルアップ等）
- item_bonus_hp: アイテムによるHP上昇（※MHP定義には含まれないが、表示上は緑に含める）

**バフに含めるもの（水色セグメント）:**
- resonance_bonus_hp: 感応スキルによるボーナス
- temporary_bonus_hp: 一時的なHP上昇
- spell_bonus_hp: スペルによるHP上昇

**注意: MHP定義について**
- MHP = base_hp + base_up_hp（ゲーム全体で使用される定義）
- item_bonus_hpは戦闘中のみ有効で、MHP定義には含まれない
- バトル画面では表示上の都合でitem_bonus_hpを緑セグメントに含めるが、これはMHP定義の変更ではない

**サイズ:**
- 幅: 200px
- 高さ: 24px
- 数値フォント: 太字、白色、影付き

### APバー
- 色: 青系 `#2196F3`（単色、色分け不要）
- 幅: 200px
- 高さ: 16px
- 数値表示: 「現在AP」
- バフ/デバフ時に数値とバー長が変動

### HPバーのデータ構造
```gdscript
# HPバーに渡すデータ（BattleParticipantから取得）
var hp_data = {
    # 緑セグメント: base_hp + base_up_hp + item_bonus_hp（表示上）
    "base_hp": 40,              # クリーチャーの基礎HP
    "base_up_hp": 10,           # 永続的なHP上昇（レベルアップ等）
    "item_bonus_hp": 10,        # アイテムによるHP上昇（表示上は緑に含める）
    # → MHP = 40 + 10 + 10 = 60
    
    # バフ（水色）: 感応 + 一時 + スペル
    "resonance_bonus_hp": 5,    # 感応スキルによるボーナス
    "temporary_bonus_hp": 0,    # 一時的なHP上昇
    "spell_bonus_hp": 5,        # スペルによるHP上昇
    # → バフ合計 = 10
    
    # 土地ボーナス（黄）: 防御側のみ、最初に消費
    "land_bonus_hp": 20,        # 土地レベルに応じたボーナス
    
    # 現在HP（ダメージを受けると減少）
    "current_hp": 90,           # 現在の実HP値
    
    # 表示用最大値
    "display_max": 100          # バー全体幅の基準値
}

# 合計HP = MHP(60) + バフ(10) + 土地(20) = 90
# ダメージ消費順: 土地(黄) → バフ(水色) → MHP(緑)
```

## ダメージポップアップ仕様

- ダメージ: 赤色、「-30」形式
- 回復: 緑色、「+20」形式
- バフ: 青色、「AP+10」等
- アニメーション: 上に浮き上がりながらフェードアウト
- フォントサイズ: 大きめ（視認性重視）

## スキル名表示仕様

- 位置: カード上部（カードの中央揃え）
- 背景: 半透明の黒または茶色のプレート
- フォント: 太字、白色
- 表示時間: 0.5〜1秒
- アニメーション: フェードイン → 維持 → フェードアウト

## エフェクト

### 攻撃エフェクト
- 斬撃/打撃系: 白い線のスラッシュ
- 魔法系: 属性に応じた色のパーティクル

### スキルエフェクト（例）
- 先制: 黄色いスピードライン
- 強打: 赤い衝撃波
- 防御: 青いバリア
- 回復: 緑の光の粒子
- 毒: 紫の泡

## サウンド

### 効果音
- バトル開始: 重厚な音
- 攻撃ヒット: 斬撃/打撃音
- スキル発動: スキル種類に応じた音
- ダメージ: 軽い衝撃音
- 勝利: ファンファーレ
- 敗北: 悲しい音

### BGM
- バトル専用BGMに切り替え
- バトル終了後に元のBGMに戻す

## 実装ファイル構成

```
res://scenes/battle/
├── battle_screen.tscn          # メインシーン
├── battle_creature_display.tscn # クリーチャー表示コンポーネント
├── hp_ap_bar.tscn              # HP/APバーコンポーネント
├── damage_popup.tscn           # ダメージポップアップ
├── skill_label.tscn            # スキル名表示
└── transition_layer.tscn       # 画面遷移用レイヤー

res://scripts/battle_screen/
├── battle_screen.gd            # メイン制御
├── battle_creature_display.gd  # クリーチャー表示制御
├── hp_ap_bar.gd                # バー制御
├── damage_popup.gd             # ポップアップ制御
├── skill_label.gd              # スキル名表示制御
├── transition_layer.gd         # 画面遷移制御
└── battle_screen_manager.gd    # 既存システムとの連携

res://assets/battle/
├── effects/                    # エフェクト素材
├── sounds/                     # 効果音
└── backgrounds/                # 背景画像
```

## 既存システムとの連携

### BattleScreenManager（新規）
```gdscript
# 既存のbattle_system.gdから呼び出される
class_name BattleScreenManager

signal intro_completed
signal skill_animation_completed
signal attack_animation_completed
signal battle_screen_closed

func start_battle(attacker_data, defender_data, item_data = null):
    # トランジション → バトル画面表示 → イントロ演出
    pass

func show_skill_activation(side: String, skill_name: String, effects: Dictionary):
    # スキル発動演出
    # side: "attacker" or "defender"
    # effects: {hp_change, ap_change, etc}
    pass

func show_attack(attacker_side: String, damage: int):
    # 攻撃演出
    pass

func show_damage(side: String, amount: int):
    # ダメージ表示
    pass

func update_hp(side: String, current: int, max: int):
    # HPバー更新
    pass

func update_ap(side: String, value: int):
    # APバー更新
    pass

func end_battle(result: int):
    # 結果表示 → トランジション → 閉じる
    pass
```

### 呼び出し例（battle_system.gdから）
```gdscript
# バトル開始
await battle_screen_manager.start_battle(attacker, defender, item)

# スキル発動時
await battle_screen_manager.show_skill_activation("attacker", "先制", {})

# 攻撃時
await battle_screen_manager.show_attack("attacker", damage)
await battle_screen_manager.show_damage("defender", damage)
await battle_screen_manager.update_hp("defender", new_hp, max_hp)

# バトル終了
await battle_screen_manager.end_battle(RESULT_ATTACKER_WIN)
```

## 開発フェーズ

### Phase 1: 基本画面
- [ ] TransitionLayer作成
- [ ] BattleScreen基本レイアウト
- [ ] カード表示（静的）
- [ ] HP/APバー（静的）

### Phase 2: アニメーション
- [ ] 画面遷移（フェードイン/アウト）
- [ ] カードスライドイン
- [ ] HP/APバーのTweenアニメーション
- [ ] ダメージポップアップ

### Phase 3: スキル演出
- [ ] スキル名表示
- [ ] 攻撃アニメーション
- [ ] 基本エフェクト

### Phase 4: 既存システム連携
- [ ] BattleScreenManager実装
- [ ] battle_system.gdとの統合
- [ ] awaitによる演出待機

### Phase 5: サウンド・仕上げ
- [ ] 効果音追加
- [ ] BGM切り替え
- [ ] エフェクト追加・調整
