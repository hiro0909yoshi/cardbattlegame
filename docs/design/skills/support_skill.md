# 応援スキル ✨NEW

**プロジェクト**: カルドセプト風カードバトルゲーム  
**バージョン**: 1.5  
**最終更新**: 2025年10月24日

---

## 📋 目次

1. [概要](#概要)
2. [基本仕様](#基本仕様)
3. [実装済みクリーチャー](#実装済みクリーチャー)
4. [条件システム](#条件システム)
5. [動的ボーナス](#動的ボーナス)
6. [実装詳細](#実装詳細)
7. [使用例](#使用例)

---

## 概要

盤面に配置されているクリーチャーが、**バトル参加者（侵略側・防御側）**に対してバフを与えるパッシブスキル。

---

## 基本仕様

### 発動タイミング
- バトル開始前（`apply_support_skills_to_all()`内）
- 最初に適用されるスキル（感応より前）

### 対象
- 侵略側クリーチャー
- 防御側クリーチャー

### 効果
- APボーナス
- HPボーナス

### スキル継承
応援スキルによるバフは対象クリーチャーのステータスを直接上昇させますが、スキルは継承されません。

---

## 実装済みクリーチャー

応援スキルを持つクリーチャーは全部で **9体** います。

| ID | 名前 | 属性 | 応援条件 | ボーナス |
|----|------|------|---------|---------|
| 401 | Boges | 火 | 火属性クリーチャー | AP+|AP-|AP&|AP 10 |
| 404 | Grimalkin | 火 | 風属性クリーチャー | AP+|AP-|AP&|AP 10 |
| 421 | Salamander | 火 | 攻撃側 | AP+|AP-|AP&|AP 10 |
| 424 | Naiad | 水 | 防御側 | HP+10 |
| 431 | Phantom Warrior | 地 | 地属性クリーチャー | AP+|AP-|AP&|AP 10 |
| 441 | Banshee | 水 | 水属性クリーチャー | AP+|AP-|AP&|AP 10 |
| 444 | Mad Harlequin | 風 | 自領地（動的） | AP+|AP-|AP&|AP +N×10 |
| 445 | Red Cap | 火 | ゴブリン種族 | AP+|AP-|AP&|AP 10、HP+10 |
| (追加予定) | - | - | - | - |

### 特殊なクリーチャー

#### Mad Harlequin (ID: 444)
- **動的ボーナス**: バトルタイルの隣接自領地数に応じてボーナスが変化
- **計算式**: `AP+|AP-|AP&|AP +N×10`（N = 隣接自領地数）
- **最大ボーナス**: AP+|AP-|AP&|AP 60（隣接6マス全て自領地の場合）

#### Red Cap (ID: 445)
- **種族条件**: ゴブリン種族のクリーチャーのみ対象
- **両方上昇**: AP+|AP-|AP&|AP 10 **および** HP+10

---

## 条件システム

### 条件タイプ

#### 1. 属性条件 (`element`)
特定属性のクリーチャーに対してバフを付与

```json
{
  "応援": {
	"condition": {
	  "type": "element",
	  "element": "fire"
	},
	"bonus": {
	  "ap": 10
	}
  }
}
```

#### 2. バトルロール条件 (`battle_role`)
攻撃側または防御側に対してバフを付与

```json
{
  "応援": {
	"condition": {
	  "type": "battle_role",
	  "role": "attacker"  // または "defender"
	},
	"bonus": {
	  "ap": 10
	}
  }
}
```

#### 3. 種族条件 (`race`)
特定種族のクリーチャーに対してバフを付与

```json
{
  "応援": {
	"condition": {
	  "type": "race",
	  "race": "Goblin"
	},
	"bonus": {
	  "ap": 10,
	  "hp": 10
	}
  }
}
```

#### 4. 所有者条件 (`owner_match`)
応援クリーチャーと同じ所有者のクリーチャーに対してバフを付与

```json
{
  "応援": {
	"condition": {
	  "type": "owner_match"
	},
	"bonus": {
	  "ap": 10
	}
  }
}
```

---

## 動的ボーナス

### 隣接自領地数ボーナス

Mad Harlequinのような特殊なクリーチャーは、**バトルタイル**の周囲の自領地数に応じてボーナスが変化します。

#### データ構造
```json
{
  "応援": {
	"condition": {
	  "type": "owner_match"
	},
	"bonus": {
	  "ap_per_adjacent": 10
	}
  }
}
```

#### 計算ロジック
```gdscript
# バトルタイルの隣接自領地数を取得
var adjacent_ally_count = _count_adjacent_ally_lands(battle_tile_index, owner_id)

# ボーナス計算
var dynamic_ap = bonus_data.get("ap_per_adjacent", 0) * adjacent_ally_count

# 適用
participant.current_ap += dynamic_ap
```

#### 例
```
バトルタイル = 45番
隣接タイル = [38, 44, 46, 52, 53, 54]

自領地数:
- 38番: プレイヤー1
- 44番: プレイヤー1  
- 46番: プレイヤー2
- 52番: 空き地
- 53番: プレイヤー1
- 54番: プレイヤー2

→ プレイヤー1の自領地数 = 3
→ Mad HarlequinのボーナスMad Harlequinのボーナス = 3 × 10 = AP+|AP-|AP&|AP 30
```

---

## 実装詳細

### クラス構成

#### SupportSkillSystem.gd
応援スキルの適用ロジックを管理

**主要メソッド**:
```gdscript
func apply_support_skills_to_all(
	attacker: BattleParticipant,
	defender: BattleParticipant,
	board_system: BoardSystem,
	battle_tile_index: int
) -> void

func apply_support_bonus(
	supporter_data: Dictionary,
	participant: BattleParticipant,
	battle_tile_index: int,
	board_system: BoardSystem
) -> void
```

### 処理フロー

```
1. BattleSystem.execute_3d_battle_with_data()
   ↓
2. apply_support_skills_to_all(attacker, defender)
   ↓
3. 盤面のクリーチャー全取得
   ↓
4. 各クリーチャーの応援スキルチェック
   ↓
5. 条件評価（属性、ロール、種族など）
   ↓
6. ボーナス適用
   - 静的ボーナス（ap, hp）
   - 動的ボーナス（ap_per_adjacent）
   ↓
7. 感応スキル適用へ
```

### 重要な注意点

#### バトルタイルの使用
- 応援スキルの条件評価や動的ボーナス計算は、**応援クリーチャーの配置タイル**ではなく**バトルタイル**を基準に行います
- これにより、Mad Harlequinの隣接自領地判定が正しく動作します

#### スキルインデックス
現在の実装では、応援スキルは複数持てる設計になっていますが、実装済みクリーチャーは全て1つのみです。

---

## 使用例

### シナリオ1: 基本的な応援

```
盤面:
- タイル10: Boges（応援[火]、AP+|AP-|AP&|AP 10）
- タイル45: バトル発生（Phoenix vs Salamander）

結果:
1. Phoenixは火属性 → Bogesの応援対象
2. Phoenix: AP+|AP-|AP&|AP 30 → 40 に上昇
3. バトル実行
```

### シナリオ2: 複数の応援

```
盤面:
- タイル10: Boges（応援[火]、AP+|AP-|AP&|AP 10）
- タイル20: Salamander（応援[攻撃側]、AP+|AP-|AP&|AP 10）  
- タイル45: バトル発生（Phoenix（火・攻撃側） vs Odontotyrannus）

結果:
1. PhoenixはBogesの条件（火属性）を満たす → AP+|AP-|AP&|AP 10
2. Phoenixは Salamanderの条件（攻撃側）を満たす → AP+|AP-|AP&|AP 10
3. Phoenix: AP+|AP-|AP&|AP 30 → 50 に上昇
4. バトル実行
```

### シナリオ3: 動的ボーナス（Mad Harlequin）

```
盤面:
- タイル30: Mad Harlequin（応援[自領地]、AP+|AP-|AP&|AP +N×10）
- タイル45: バトル発生
- タイル45の隣接: プレイヤー1の土地が4つ

結果:
1. バトルタイル45の隣接自領地数 = 4
2. 動的ボーナス = 4 × 10 = 40
3. バトル参加クリーチャー: AP+|AP-|AP&|AP +40
4. バトル実行
```

---

## 変更履歴

| バージョン | 日付 | 変更内容 |
|-----------|------|---------|
| 1.0 | 2025/10/23 | 初版作成 - 応援スキル実装完了（9体） |
| 1.1 | 2025/10/23 | Mad Harlequinのバグ修正（隣接判定をバトルタイル基準に変更） |
| 1.5 | 2025/10/24 | 個別ドキュメントとして分離 |
