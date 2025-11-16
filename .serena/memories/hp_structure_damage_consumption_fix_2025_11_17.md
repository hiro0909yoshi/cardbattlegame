# HP構造ドキュメント修正 (2025-11-17)

## 修正内容

HPダメージ消費順序に関するドキュメント矛盾を解決

### 修正背景

ドキュメント（hp_structure.md）では「ダメージ時は current_hp が直接削られ、その後 update_current_hp() で再計算される」と記載されていたが、実装では：
- 各種ボーナスから順に消費
- 残ったダメージが base_hp から消費
- update_current_hp() で current_hp を再計算

current_hp は**計算値**（base_hp + base_up_hp + ボーナス群）のため、直接削られないことが正しい実装

### 修正内容（3箇所）

#### 修正1: HP計算式後の「重要な概念」セクション
**変更前**:
```
- ダメージ時は **current_hp が直接削られ**、その後 update_current_hp() で各ボーナスを反映して再計算される
```

**変更後**:
```
- ダメージ時は以下の順序で消費される：
  1. 各種一時的ボーナス（resonance_bonus_hp → land_bonus_hp → temporary_bonus_hp → item_bonus_hp → spell_bonus_hp）
  2. その後 base_hp から消費
  3. update_current_hp() を呼び出して、current_hp を現在の全ボーナスを含めて再計算
- current_hp は計算値（base_hp + base_up_hp + ボーナス群）のため、直接削られずに各要素から消費してから再計算される
```

#### 修正2: ダメージ消費順序のコードブロック
**変更前**:
```
1. resonance_bonus_hp（感応ボーナス）
2. land_bonus_hp（土地ボーナス）
3. temporary_bonus_hp（一時ボーナス）
4. item_bonus_hp（アイテムボーナス）
5. spell_bonus_hp（スペルボーナス）
6. current_hp（現在HP、最後に消費）
```

**変更後**:
```
1. resonance_bonus_hp（感応ボーナス）
2. land_bonus_hp（土地ボーナス）
3. temporary_bonus_hp（一時ボーナス）
4. item_bonus_hp（アイテムボーナス）
5. spell_bonus_hp（スペルボーナス）
6. base_hp（元のHPの現在値、最後に消費）

※ current_hp は計算値（base_hp + base_up_hp + ボーナス群）のため、直接削られません。
```

説明文:
**変更前**: 「base_hp と base_up_hp は消費されません」
**変更後**: 説明を厳密化 - base_hp は消費される（最後に）、base_up_hp のみ消費されない

#### 修正3: 理由説明セクションのタイトル・内容変更
**変更前**: 「base_hp と base_up_hp が消費されない理由」
**変更後**: 「base_up_hp が消費されない理由（base_hp は消費される）」

内容を修正して実装と合わせた

### 修正の正当性

1. **コード実装との一致**: battle_participant.gd の take_damage() メソッドで base_hp から直接消費している
2. **設計仕様との一致**: current_hp は計算式でのみ生成され、状態値ではない
3. **実装の効果**: 通路判定など他の処理との矛盾が解消される

## 影響範囲

- hp_structure.md のみ修正
- 他のドキュメント（effect_system_design.md など）でも同様の矛盾がある可能性がある
- コード実装に変更なし（既に正しく実装されている）
