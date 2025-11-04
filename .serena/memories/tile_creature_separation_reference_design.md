# 参照方式による最小限変更の設計 (2025年11月5日)

## 調査結果

### creature_data の性質
1. **完全に独立したDictionary** - タイルは単なる入れ物
2. **コピーして移動可能** - duplicate() で別タイルに移動できる
3. **参照で操作される** - participant.creature_data["key"] = value

### 既存コードの制約
- 約800箇所で `creature_data["key"]` 形式の直接変更
- BattleParticipant が辞書への参照を保持
- 既存コード変更は現実的でない

## 新設計: 参照透過的なCreatureManager

### コンセプト
**「既存コードを一切変更せず、データだけを集約する」**

### 実装方法

#### CreatureManager
```gdscript
class_name CreatureManager
var creatures: Dictionary = {}  # {tile_index: creature_data}

func get_data_ref(tile_index: int) -> Dictionary:
    if not creatures.has(tile_index):
        creatures[tile_index] = {}
    return creatures[tile_index]  # 参照を返す！
```

#### BaseTile
```gdscript
static var creature_manager: CreatureManager = null

var creature_data: Dictionary:
    get: return creature_manager.get_data_ref(tile_index)
    set(value): creature_manager.set_data(tile_index, value)
```

### 利点
✅ 既存コード800箇所を変更不要
✅ データはCreatureManagerに集約
✅ 段階的移行が可能
✅ 3D表示との統合が容易

### 実装ステップ
1. ✅ CreatureManager作成（完了）
2. ⬜ BaseTileにプロパティget/set追加
3. ⬜ BoardSystemでの初期化
4. ⬜ テスト

### 削除処理の3シナリオ
- **移動**: データコピー→削除→再配置
- **手札復帰**: データコピー→削除→CardSystemへ
- **完全削除**: 削除のみ（GC回収）

## Phase 2以降は不要
参照方式により、API統一（Phase 2-3）はスキップ可能
