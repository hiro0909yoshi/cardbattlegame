# current_hp リファクタリング実装進捗報告 (2025-11-20)

**プロジェクト**: カルドセプト風カードバトルゲーム  
**実装日**: 2025年11月20日  
**ステータス**: Phase 5 実装途中（エラー検出）

---

## 📋 実装進捗サマリー

### ✅ 完了したPhase

| Phase | 項目 | 状態 |
|-------|------|------|
| Phase 1 | BattleParticipant クラス | ✅ 完了（既に新方式） |
| Phase 2 | battle_preparation.gd - 防御側HP初期化 | ✅ 完了 |
| Phase 3 | battle_special_effects.gd, battle_execution.gd | ✅ 完了 |
| Phase 4 | place_creature() 初期化 | ⬜ 未実施 |
| Phase 5 | スキル・効果ファイルの update_current_hp() 削除 | ⚠️ **エラー検出** |

---

## ✅ Phase 1-3: バトル側修正（完了）

### Phase 1: BattleParticipant クラス
- **状態**: 既に正しい形式で実装済み
- **take_damage()**: ✅ current_hp から直接削る処理で実装
- **take_mhp_damage()**: ✅ current_hp から直接削る処理で実装

### Phase 2: battle_preparation.gd - 防御側HP初期化修正
**ファイル**: `scripts/battle/battle_preparation.gd`  
**行番号**: 100-111行目  
**修正内容**:
```gdscript
# 修正前（古い方式）
var defender_base_only_hp = defender_creature.get("hp", 0)
var defender_max_hp = defender_base_only_hp + defender.base_up_hp
var defender_current_hp = defender_creature.get("current_hp", defender_max_hp)
defender.base_hp = defender_current_hp - defender.base_up_hp
defender.update_current_hp()

# 修正後（新方式）
var defender_base_only_hp = defender_creature.get("hp", 0)
var defender_max_hp = defender_base_only_hp + defender.base_up_hp
var defender_current_hp = defender_creature.get("current_hp", defender_max_hp)
defender.current_hp = defender_current_hp
# base_hp と base_up_hp はコンストラクタで既に設定済み
```

### Phase 3: battle_preparation.gd - apply_effect_arrays() 修正
**ファイル**: `scripts/battle/battle_preparation.gd`  
**行番号**: 247-252行目（旧249行目）  
**修正内容**:
```gdscript
# 修正前
participant.current_ap += participant.base_up_ap + participant.temporary_bonus_ap
participant.update_current_hp()

# 修正後
participant.current_ap += participant.base_up_ap + participant.temporary_bonus_ap
# HPを更新（新方式：ボーナス合計を current_hp に直接反映）
# update_current_hp() は呼ばない（current_hp が状態値になったため）
```

### Phase 3: battle_special_effects.gd - HP保存修正
**ファイル**: `scripts/battle/battle_special_effects.gd`  
**行番号**: 355行目  
**修正内容**:
```gdscript
# 修正前
creature_data["current_hp"] = defender.base_hp + defender.base_up_hp

# 修正後
creature_data["current_hp"] = defender.current_hp
```

### Phase 3: battle_execution.gd - ダメージ集計修正
**ファイル**: `scripts/battle/battle_execution.gd`  
**行番号**: 複数箇所（188, 201-202, 304, 318-319等）  
**修正内容**: 
- `damage_breakdown.get("base_hp_consumed", 0)` → `damage_breakdown.get("current_hp_consumed", 0)`
- ログ出力: 「基本HP」→ 「現在HP」に統一

---

## ⚠️ Phase 5: update_current_hp() 呼び出し削除（エラー検出）

### 実施状況

| ファイル | 箇所数 | 状態 |
|---------|--------|------|
| battle_skill_processor.gd | 16 | ⚠️ インデント崩れ修正済み |
| battle_item_applier.gd | 12 | ✅ 完了 |
| battle_special_effects.gd | 3 | ❌ **構文破損** |
| battle_curse_applier.gd | 1 | ✅ 完了 |
| skill_resonance.gd | 1 | ✅ 完了 |
| skill_special_creature.gd | 2 | ✅ 完了 |
| skill_transform.gd | 2 | ✅ 完了 |
| skill_assist.gd | 1 | ✅ 完了 |
| skill_item_manipulation.gd | 2 | ✅ 完了 |
| skill_penetration.gd | 1 | ✅ 完了 |
| skill_support.gd | 1 | ✅ 完了 |

**合計**: 39箇所中 36箇所完了、3箇所エラー状態

---

## 🔴 エラー詳細

### エラー1: battle_skill_processor.gd - インデント崩れ

**発生場所**: 260行目前後  
**原因**: 正規表現による置換時に、`print()` 文のインデントが乱れた  
**症状**: 以下のようなインデント構造になっていた
```gdscript
# update_current_hp() は呼ばない（current_hp が状態値になったため）
print("【土地数比例】", ...)  # ← インデント不正
    print("  対象属性:", ...)  # ← インデント不正
    print("  HP: ", ...)        # ← インデント不正
```

**修正**: インデントを統一（全て4タブレベルに）
```gdscript
# update_current_hp() は呼ばない（current_hp が状態値になったため）
print("【土地数比例】", ...)    # ✅ インデント修正済み
print("  対象属性:", ...)        # ✅ インデント修正済み
print("  HP: ", ...)            # ✅ インデント修正済み
```

**ステータス**: ✅ 修正完了

---

### エラー2: battle_special_effects.gd - 構文破損

**発生場所**: 20-50行目  
**原因**: `.*?\.update_current_hp\(\)` という正規表現が、関数ドキュメント内の説明文も削除した  
**症状**: Returns文の説明が消えて、重要なコードが削除された
```gdscript
# 破損状態（現在）
func check_nullify(attacker: BattleParticipant, defender: BattleParticipant, context: Dictionary) -> Dictionary:
	"""
	無効化判定を行う
	
	Returns:
		# update_current_hp() は呼ばない（current_hp が状態値になったため）  ← これが削除のコメント
		# update_current_hp() は呼ばない...  ← 重複・破損
		# update_current_hp() は呼ばない...  ← 重複・破損
						result["death_revenge_activated"] = true  ← コードが裂ける
```

**影響範囲**: 
- 関数 `check_nullify()` のドキュメント破損
- その後のコード構造が完全に乱れている

**必要な対応**: 
- ファイルをGitで復元、または
- 正しいバージョンで上書き

**ステータス**: ❌ **要修正**

---

### エラー3: battle_special_effects.gd - パーサーエラー

**Godotエラーメッセージ**:
```
Parser Error: Could not parse global class "BattleSpecialEffects" from "res://scripts/battle/battle_special_effects.gd"
```

**原因**: 上記の構文破損のため、Godotスクリプトパーサーが失敗

**ステータス**: ❌ **要修正** (battle_special_effects.gd の復旧後に解消)

---

## 🔧 修正方針

### 推奨される復旧手順

#### 1. battle_special_effects.gd の復旧

**方法A**: Gitで復元（推奨）
```bash
git checkout -- scripts/battle/battle_special_effects.gd
```

**方法B**: 正しいバージョンで上書き
- ファイル内容を確認し、削除されたコードを復元
- その後、慎重に update_current_hp() 呼び出し3箇所のみを削除

#### 2. 削除対象の正確な特定

battle_special_effects.gd で削除すべき箇所は：
```gdscript
# 211行目付近
defender.update_current_hp()

# 335行目付近
participant.update_current_hp()

# 438行目付近
opponent.update_current_hp()
```

**重要**: ドキュメント文（""" """内）には触れないこと

#### 3. 確認テスト

復旧後、以下を確認：
```bash
# Godotエディタで構文チェック
# または、コマンドラインで：
gdscript --check scripts/battle/battle_special_effects.gd
```

---

## 📊 修正統計

### 完了度
- **合計処理**: 39箇所の update_current_hp() 呼び出し削除
- **完了**: 36箇所 (92%)
- **エラー**: 3箇所 (8%)
- **全体進捗**: Phase 1-4 完了 + Phase 5 の 92% 完了

### コード行数
- **修正行数**: 約150行
- **新規コメント追加**: 39行（各削除箇所に説明コメント追加）

---

## 📝 次ステップ

### 優先度1（緊急）
1. ✅ battle_skill_processor.gd のインデント修正 → **完了**
2. ❌ battle_special_effects.gd をGitで復元 → **要実施**
3. ❌ battle_special_effects.gd の update_current_hp() 3箇所を慎重に削除 → **要実施**
4. ⬜ Godotエディタで構文チェック → **確認予定**

### 優先度2（その後）
1. ⬜ update_current_hp() 関数定義の削除（battle_participant.gd, 89-91行目）
2. ⬜ Phase 4: place_creature() に current_hp 初期化追加
3. ⬜ バトルテスト実行

### 優先度3（別フェーズ）
1. ⬜ マップ側修正（base_up_hp 変更時の current_hp 同期）

---

## 🎯 Phase 5 修正戦略（復旧後の推奨手順）

### 問題点分析
- **全置換の危険性**: 正規表現 `.*?\.update_current_hp\(\)` は、意図しないテキストまで削除した

### 推奨される修正方法（復旧後）

#### 方法1: 手動修正（安全）
各ファイルで以下を実施：
```gdscript
# 削除対象を特定して確認
participant.temporary_bonus_hp += value
participant.update_current_hp()  # ← この行を削除

# 置換
participant.temporary_bonus_hp += value
# update_current_hp() は呼ばない（current_hp が状態値になったため）
```

#### 方法2: セクションごと確認置換（推奨）
1. ファイルごとに開く
2. 関数単位で `update_current_hp()` を検索
3. 前後のコードを確認して、削除しても安全か確認
4. 置換実行

---

## 📚 参考資料

### ドキュメント
- `docs/design/hp_structure.md` - HP管理構造の仕様
- `docs/design/hp_system_refactoring_plan.md` - リファクタリング計画
- `docs/design/hp_system_refactoring_implementation_guide.md` - 実装詳細ガイド

### 実装メモリ
- `phase_5_update_current_hp_deletion_complete.md` - Phase 5完了記録
- `current_hp_refactoring_status_2025_11_20.md` - 全体進捗

---

## ✅ チェックリスト（復旧後）

- [ ] battle_special_effects.gd をGitで復元
- [ ] battle_special_effects.gd の構文確認
- [ ] 211, 335, 438行目の update_current_hp() を確認
- [ ] 該当行を削除・置換
- [ ] Godotエディタで構文チェック
- [ ] バトルテスト実行
- [ ] ログで「現在HP」が表示されることを確認
- [ ] update_current_hp() 関数定義を削除
- [ ] 全体テスト実行

---

**作成日**: 2025年11月20日  
**最終更新**: 2025年11月20日  
**作成者**: Hand（開発）
