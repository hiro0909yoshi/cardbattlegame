# ドキュメント矛盾修正一覧（2025-11-17）

## 修正完了ドキュメント

### 1. effect_system_design.md（3箇所修正）

#### 修正1: HP計算式に spell_bonus_hp を追加
```gdscript
# 変更前
current_hp = base_hp + base_up_hp + temporary_bonus_hp + 
             land_bonus_hp + resonance_bonus_hp + item_bonus_hp

# 変更後
current_hp = base_hp + base_up_hp + temporary_bonus_hp + 
             land_bonus_hp + resonance_bonus_hp + item_bonus_hp + spell_bonus_hp
```

#### 修正2: ダメージ消費順序から base_up_hp 削除
```
6. current_hp（残りHP） ← base_hp の現在値
↓
6. base_hp（元のHPの現在値、最後に消費）
※ current_hp は計算値のため直接削られません
```

#### 修正3: BattleParticipant説明を明確化
- base_hp: 「元のHPの現在値（ダメージで削られる）」に変更
- base_up_hp: 「バトル後も creature_data に保存」を追記

### 2. battle_system.md（1箇所修正）

#### ダメージ消費順序から base_up_hp を削除
```
6. 永続基礎HP (base_up_hp)
7. 基本HP (base_hp - 最後に消費)
↓
6. 基本HP (base_hp - 最後に消費)
※ 永続基礎HP (base_up_hp) は消費されません
```

設計思想も更新：base_up_hp はダメージで削られない点を明記

### 3. on_death_effects.md（1箇所修正）

#### ダメージ消費順序コードブロック更新
```
6. current_hp（残りHP） ← base_hp の現在値
↓
6. base_hp（元のHPの現在値、最後に消費）
```

雪辱の特徴を更新：「base_hp のみ消費される」を追記

## 修正が必要な他のドキュメント

### 確認済み・矛盾なし
- condition_patterns_catalog.md: ダメージ関連記載なし
- effect_system.md: 前フェーズドキュメント、更新予定あり

### 未確認・追加調査推奨
- item_system.md: 1059（ペトリフストーン）関連の HP 処理記載の有無
- spells/ 配下: 各スペル仕様ドキュメント
- skills_design.md, skills/*.md: スキル個別ドキュメント

## 修正方針

実装（battle_participant.gd）に合わせてドキュメントを統一：
- ダメージは各要素から消費、最後に base_hp から消費
- current_hp は計算値で直接削られない
- base_up_hp は永続的なMHPボーナスで削られない
- ただし base_hp は通常ダメージで削られる

## 検証項目

✅ hp_structure.md との整合性
✅ effect_system_design.md との整合性
✅ battle_system.md との整合性
✅ on_death_effects.md との整合性
⚠️ item_system.md の詳細確認推奨
⚠️ その他スキルドキュメントの細部確認推奨
