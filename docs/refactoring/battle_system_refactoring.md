# BattleSystem リファクタリング記録

**日付**: 2025年1月  
**目的**: BattleSystem.gdの肥大化を解消し、保守性と可読性を向上

---

## 📊 リファクタリング前後の比較

| 項目 | リファクタリング前 | リファクタリング後 |
|------|-------------------|-------------------|
| **行数** | 1,087行 | 250行 (コア) + 800行 (サブシステム) |
| **メソッド数** | 34個 | 10個 (コア) + 28個 (サブシステム) |
| **責務** | すべて単一ファイル | 5つのモジュールに分離 |
| **テスト容易性** | 低 | 高 |

---

## 🏗️ 新しいアーキテクチャ

```
scripts/
├── battle_system.gd (250行)
│   └── コア機能のみ（システム統合、メインフロー制御）
│
└── battle/
	├── battle_preparation.gd (280行)
	│   └── バトル準備（Participant作成、アイテム効果、土地ボーナス、貫通判定）
	│
	├── battle_skill_processor.gd (200行)
	│   └── スキル処理（感応、強打、2回攻撃、巻物攻撃）
	│
	├── battle_execution.gd (180行)
	│   └── 戦闘実行（攻撃順決定、攻撃シーケンス、結果判定）
	│
	└── battle_special_effects.gd (340行)
		└── 特殊効果（即死、無効化、再生）
```

---

## 📦 モジュール詳細

### 1. BattleSystem (コア)

**責務**:
- システム統合（サブシステムの初期化と管理）
- メインフロー制御
- 結果処理とシグナル発行

**主要メソッド**:
```gdscript
func setup_systems()
func execute_3d_battle()
func execute_3d_battle_with_data()
func execute_invasion_3d()
func pay_toll_3d()
```

---

### 2. BattlePreparation

**責務**:
- BattleParticipant作成
- アイテム効果適用
- スキル付与
- 土地ボーナス計算
- 貫通スキル判定

**主要メソッド**:
```gdscript
func prepare_participants()
func apply_item_effects()
func grant_skill_to_participant()
func calculate_land_bonus()
func check_penetration_skill()
```

**依存関係**:
- BoardSystem (土地情報)
- CardSystem (カードデータ)
- PlayerSystem (プレイヤー情報)

---

### 3. BattleSkillProcessor

**責務**:
- バトル前スキル適用
- 感応スキル処理
- 強打スキル処理
- 巻物攻撃処理
- 2回攻撃判定

**主要メソッド**:
```gdscript
func apply_pre_battle_skills()
func apply_skills()
func apply_resonance_skill()
func apply_power_strike_skills()
func check_scroll_attack()
func check_double_attack()
```

**依存関係**:
- BoardSystem (プレイヤー土地情報)
- ConditionChecker (条件判定)
- EffectCombat (強打計算)

---

### 4. BattleExecution

**責務**:
- 攻撃順決定（先制・後手判定）
- 攻撃シーケンス実行
- ダメージ処理
- バトル結果判定

**主要メソッド**:
```gdscript
func determine_attack_order()
func execute_attack_sequence()
func resolve_battle_result()
```

**依存関係**:
- BattleSpecialEffects (無効化、即死判定)
- BattleParticipant (ステータス参照)

---

### 5. BattleSpecialEffects

**責務**:
- 無効化スキル処理
- 即死スキル処理
- 再生スキル処理
- 防御側HP更新

**主要メソッド**:
```gdscript
func check_nullify()
func check_instant_death()
func apply_regeneration()
func update_defender_hp()
```

**依存関係**:
- ConditionChecker (条件判定)
- BoardSystem (タイルデータ更新)

---

## 🔄 処理フロー

```
1. BattleSystem.execute_3d_battle()
   │
   ├─> 2. BattlePreparation.prepare_participants()
   │   ├─ BattleParticipant作成
   │   ├─ アイテム効果適用
   │   └─ 土地ボーナス計算
   │
   ├─> 3. BattleSkillProcessor.apply_pre_battle_skills()
   │   ├─ 感応スキル
   │   ├─ 強打スキル
   │   └─ 2回攻撃判定
   │
   ├─> 4. BattleExecution.determine_attack_order()
   │   └─ 先制・後手判定
   │
   ├─> 5. BattleExecution.execute_attack_sequence()
   │   ├─ 攻撃ループ
   │   ├─ BattleSpecialEffects.check_nullify()
   │   └─ BattleSpecialEffects.check_instant_death()
   │
   ├─> 6. BattleExecution.resolve_battle_result()
   │
   └─> 7. BattleSystem._apply_post_battle_effects()
	   ├─ BattleSpecialEffects.apply_regeneration()
	   └─ 土地奪取 or カード破壊 or 手札復帰
```

---

## ✅ メリット

### 1. **保守性向上**
- 各モジュールが単一責任を持つ
- 変更の影響範囲が明確
- バグの特定が容易

### 2. **テスト容易性**
- モジュール単位でテスト可能
- モックの作成が簡単
- 独立したテストケース作成が可能

### 3. **可読性向上**
- ファイルサイズが適切（200-350行）
- 責務が明確
- コードの意図が理解しやすい

### 4. **拡張性**
- 新しいスキル追加が容易
- モジュール単位での機能追加
- 他のモジュールへの影響を最小化

### 5. **並行開発**
- 複数人での開発が可能
- コンフリクトの発生を抑制
- レビューが容易

---

## 📝 今後の展開

### 次に分割推奨のファイル

#### 1. **land_command_handler.gd** (881行)
```
scripts/game_flow/land_command/
├── land_command_handler.gd (コア)
├── land_selection_handler.gd (土地選択)
├── level_up_handler.gd (レベルアップ)
├── creature_move_handler.gd (移動処理)
└── creature_swap_handler.gd (交換処理)
```

---

## 🔍 注意事項

### 互換性
- 外部からの呼び出しインターフェースは変更なし
- `execute_3d_battle()` / `execute_3d_battle_with_data()` は同じ
- シグナル `invasion_completed` も同じ

### 依存関係
- サブシステムは親の BattleSystem を通じて連携
- 直接の相互依存は避ける
- 必要な参照は setup_systems() で設定

### パフォーマンス
- サブシステム作成のオーバーヘッドは微小
- 実行時のパフォーマンスは変わらず
- メモリ使用量もほぼ同じ

---

## 📚 参考資料

- **設計パターン**: Strategy Pattern, Facade Pattern
- **原則**: Single Responsibility Principle (SRP)
- **参考書籍**: Clean Code, Refactoring

---

**作成者**: AI Assistant  
**レビュー**: 必要に応じて更新
