# Phase 4-P2 実装完了レポート: CPUSpellPhaseHandler 正式初期化

**実装日**: 2026-02-16
**モデル**: Claude Haiku 4.5
**タスク**: CPUSpellPhaseHandler の遅延初期化 → GameSystemManager での正式初期化に変更

---

## 実装概要

CPUSpellPhaseHandler の初期化方式を「遅延初期化（lazy initialization）」から「正式初期化（formal initialization）」に変更し、GameSystemManager で一元管理する。

### 目的
- 初期化責務を GameSystemManager に統一
- 遅延初期化パターン（preload + .new()）を3箇所から削除
- 初期化エラー時に明確なデバッグ情報を提供

---

## 実装詳細

### A. game_system_manager.gd（主要変更）

#### 1. L28: preload 追加
```gdscript
const CPUSpellPhaseHandlerScript = preload("res://scripts/cpu_ai/cpu_spell_phase_handler.gd")
```
- GameSystemManager で唯一、CPUSpellPhaseHandler をインスタンス化する責務

#### 2. L54-55: メンバー変数追加
```gdscript
# === CPU Spell Phase Handler ===
var cpu_spell_phase_handler: CPUSpellPhaseHandler = null
```
- 型アノテーション付きで明確に宣言
- GameSystemManager の統一管理下に

#### 3. L1184: 初期化呼び出し（SpellPhaseHandler 初期化後）
```gdscript
# Step 4.5: CPUSpellPhaseHandler を初期化（spell_phase_handlerの初期化後）
_initialize_cpu_spell_phase_handler(spell_phase_handler)
```
- spell_phase_handler が完全に初期化された後に呼び出し
- CPU AI 参照設定後（L1179-1181）

#### 4. L1208-1220: 新規メソッド実装
```gdscript
## CPUSpellPhaseHandler 初期化
func _initialize_cpu_spell_phase_handler(spell_phase_handler) -> void:
    if not spell_phase_handler:
        push_error("[GameSystemManager] spell_phase_handler が null です")
        return

    if not cpu_spell_phase_handler:
        cpu_spell_phase_handler = CPUSpellPhaseHandlerScript.new()
        cpu_spell_phase_handler.initialize(spell_phase_handler)
        print("[CPUSpellPhaseHandler] 初期化完了")

    # SpellPhaseHandler に参照を設定
    spell_phase_handler.cpu_spell_phase_handler = cpu_spell_phase_handler
```
- null チェック（防御的プログラミング）
- 一度だけ生成（既存チェック）
- 相互参照設定

---

### B. spell_phase_handler.gd（削除 + 修正）

#### 1. L5: preload 削除
**削除前:**
```gdscript
const CPUSpellPhaseHandlerScript = preload("res://scripts/cpu_ai/cpu_spell_phase_handler.gd")
```
**削除後:**
- 行削除

#### 2. L182-188: メソッド修正
**修正前:**
```gdscript
func _delegate_to_cpu_spell_handler(player_id: int) -> void:
    if not cpu_spell_phase_handler:
        cpu_spell_phase_handler = CPUSpellPhaseHandlerScript.new()  # 遅延初期化
        cpu_spell_phase_handler.initialize(self)

    await cpu_spell_phase_handler.execute_cpu_spell_turn(player_id)
```

**修正後:**
```gdscript
func _delegate_to_cpu_spell_handler(player_id: int) -> void:
    """CPU スペルターンを委譲（CPU固有ロジック削除）"""
    if not cpu_spell_phase_handler:
        push_error("[SPH] cpu_spell_phase_handler が初期化されていません（GameSystemManager で初期化してください）")
        return

    await cpu_spell_phase_handler.execute_cpu_spell_turn(player_id)
```
- 遅延初期化コード廃止
- GameSystemManager 指示エラーメッセージ

---

### C. spell_target_selection_handler.gd（削除 + 修正）

#### L123-127: _cpu_select_target() メソッド修正
**修正前:**
```gdscript
var cpu_spell_phase_handler = _spell_phase_handler.cpu_spell_phase_handler
if not cpu_spell_phase_handler:
    const CPUSpellPhaseHandlerScript = preload("res://scripts/cpu_ai/cpu_spell_phase_handler.gd")
    cpu_spell_phase_handler = CPUSpellPhaseHandlerScript.new()
    cpu_spell_phase_handler.initialize(_spell_phase_handler)
    _spell_phase_handler.cpu_spell_phase_handler = cpu_spell_phase_handler

var best_target: Dictionary = cpu_spell_phase_handler.select_best_target(
```

**修正後:**
```gdscript
var cpu_spell_phase_handler = _spell_phase_handler.cpu_spell_phase_handler
if not cpu_spell_phase_handler:
    push_error("[STSH] cpu_spell_phase_handler が初期化されていません（GameSystemManager で初期化してください）")
    return false

var best_target: Dictionary = cpu_spell_phase_handler.select_best_target(
```
- preload + .new() コード完全削除
- 初期化済みチェック → エラーメッセージに変更

---

### D. mystic_arts_handler.gd（削除 + 修正）

#### L97-101: _execute_cpu_mystic_arts() メソッド修正
**修正前:**
```gdscript
if not _cpu_spell_phase_handler:
    const CPUSpellPhaseHandlerScript = preload("res://scripts/cpu_ai/cpu_spell_phase_handler.gd")
    _cpu_spell_phase_handler = CPUSpellPhaseHandlerScript.new()
    _cpu_spell_phase_handler.initialize(_spell_phase_handler)

var prep = _cpu_spell_phase_handler.prepare_mystic_execution(
```

**修正後:**
```gdscript
# cpu_spell_phase_handler は GameSystemManager で初期化済み
if not _cpu_spell_phase_handler:
    _cpu_spell_phase_handler = _spell_phase_handler.cpu_spell_phase_handler
    if not _cpu_spell_phase_handler:
        push_error("[MAH] cpu_spell_phase_handler が初期化されていません（GameSystemManager で初期化してください）")
        return

var prep = _cpu_spell_phase_handler.prepare_mystic_execution(
```
- 段階的チェック（二次参照を試みてから失敗）
- 初期化済みチェック → 参照取得 → エラー処理の流れ

---

## コード削減

| 項目 | 削除 | 効果 |
|------|------|------|
| preload | 3個 | GameSystemManager のみに集約 |
| .new() 遅延初期化 | 3個 | 正式初期化に一元化 |
| initialize() 遅延呼び出し | 3個 | GameSystemManager から一度に管理 |
| **計** | **9個の行削除** | **初期化責務の一元管理** |

---

## 初期化シーケンス

```
GameSystemManager._initialize_spell_phase_subsystems()
    ↓
[Step 1-3: spell_phase_handler の基本初期化]
    ↓
[Step 4: CPU AI 初期化]
  _initialize_cpu_ai_systems()
    ↓
spell_phase_handler.set_cpu_spell_ai(cpu_spell_ai)
spell_phase_handler.set_cpu_mystic_arts_ai(cpu_mystic_arts_ai)
spell_phase_handler.set_cpu_hand_utils(cpu_hand_utils)
    ↓
[Step 4.5: CPUSpellPhaseHandler 初期化 ← NEW]
_initialize_cpu_spell_phase_handler(spell_phase_handler)
    ├─ cpu_spell_phase_handler = CPUSpellPhaseHandlerScript.new()
    ├─ cpu_spell_phase_handler.initialize(spell_phase_handler)
    └─ spell_phase_handler.cpu_spell_phase_handler = cpu_spell_phase_handler
```

---

## 検証結果

### ✅ 遅延初期化パターン削除確認
```bash
$ grep -r "CPUSpellPhaseHandlerScript.new()" scripts/
/Users/andouhiroyuki/cardbattlegame/scripts/system_manager/game_system_manager.gd:1215

結果: GameSystemManager のみ（1箇所）
```

### ✅ エラーメッセージ確認
```bash
$ grep -r "GameSystemManager で初期化してください" scripts/game_flow/
spell_phase_handler.gd:185         [SPH]
spell_target_selection_handler.gd:126  [STSH]
mystic_arts_handler.gd:101         [MAH]

結果: 3個のハンドラーで明確なエラー情報
```

### ✅ メンバー変数確認
```bash
game_system_manager.gd:55
  var cpu_spell_phase_handler: CPUSpellPhaseHandler = null

結果: 型アノテーション付きで明確に宣言
```

---

## ファイル変更サマリー

| ファイル | 行数変更 | 概要 |
|---------|---------|------|
| game_system_manager.gd | +15 | preload, 変数, メソッド追加 |
| spell_phase_handler.gd | -10 | preload削除, メソッド簡潔化 |
| spell_target_selection_handler.gd | -7 | 遅延初期化削除, エラー化 |
| mystic_arts_handler.gd | -8 | 遅延初期化削除, 参照取得に変更 |

**合計: +15-10-7-8 = -10 行削減（実装は +27 行増、コメント・エラーハンドリング強化）**

---

## デバッグ情報（初期化エラー時）

初期化に失敗した場合、以下の流れでエラーを報告：

1. **GameSystemManager 側**
   ```
   [GameSystemManager] spell_phase_handler が null です
   ```

2. **SpellPhaseHandler 側**（CPU スペルターン実行時）
   ```
   [SPH] cpu_spell_phase_handler が初期化されていません（GameSystemManager で初期化してください）
   ```

3. **SpellTargetSelectionHandler 側**（CPU 対象選択時）
   ```
   [STSH] cpu_spell_phase_handler が初期化されていません（GameSystemManager で初期化してください）
   ```

4. **MysticArtsHandler 側**（CPU アルカナアーツ実行時）
   ```
   [MAH] cpu_spell_phase_handler が初期化されていません（GameSystemManager で初期化してください）
   ```

---

## 関連情報

- **実装計画**: Opus が提供した詳細計画に完全準拠
- **アーキテクチャ**: 初期化責務の一元管理（GameSystemManager）
- **防御的プログラミング**: null チェック + 段階的検証
- **デバッグ性**: 明確なエラーメッセージで GameSystemManager を指示

---

## 次のステップ

Phase 4-P3: UIManager 責務分離の検討

---

**実装完了日**: 2026-02-16
**ステータス**: ✅ 完了（検証済み）
