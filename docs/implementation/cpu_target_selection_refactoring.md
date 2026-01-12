# CPUターゲット選択ロジックのリファクタリング

## 概要

CPUのスペル/秘術ターゲット選択ロジックを、プレイヤーと同じ`TargetSelectionHelper`を使用するようにリファクタリングしました。

## 背景・問題点

従来、ターゲット選択ロジックが二重管理されていました：

- **プレイヤー**: `TargetSelectionHelper.get_valid_targets()` → 防魔・HP効果無効等のチェック込み
- **CPU**: `cpu_target_resolver.check_target_condition()` → 独自実装

この結果、防魔やHP効果無効を持つクリーチャーに対して、プレイヤーは使用できないのにCPUは使用できてしまう問題がありました。

## 解決策

### 1. TargetSelectionHelperのリファクタリング

`get_valid_targets_core`という新しい静的関数を追加し、`handler`なしで呼び出せるようにしました。

```gdscript
# 従来（handlerが必要）
static func get_valid_targets(handler, target_type: String, target_info: Dictionary) -> Array:
    # handlerから情報を抽出してコア関数を呼び出す
    var systems = {
        "board_system": handler.board_system,
        "player_system": handler.player_system,
        "current_player_id": handler.current_player_id,
        "game_flow_manager": handler.game_flow_manager
    }
    return get_valid_targets_core(systems, target_type, target_info)

# 新規追加（CPU等から直接呼び出し可能）
static func get_valid_targets_core(systems: Dictionary, target_type: String, target_info: Dictionary) -> Array:
```

### 2. CPU側の修正

`cpu_spell_target_selector.gd`と`cpu_mystic_arts_ai.gd`の`get_default_targets`を修正し、`TargetSelectionHelper.get_valid_targets_core`を使用するようにしました。

```gdscript
## デフォルトターゲット取得（TargetSelectionHelper共通ロジック使用）
func get_default_targets(spell: Dictionary, context: Dictionary) -> Array:
    var systems = {
        "board_system": board_system,
        "player_system": player_system,
        "current_player_id": context.get("player_id", 0),
        "game_flow_manager": game_flow_manager
    }
    
    # TargetSelectionHelperの共通ロジックを使用
    var targets = TargetSelectionHelper.get_valid_targets_core(systems, target_type, target_info)
    # ...
```

### 3. DummyHandlerクラスの追加

`SpellProtection.filter_protected_targets()`が`handler`オブジェクトを期待するため、`systems`辞書から`handler`ライクなオブジェクトを作成する`DummyHandler`クラスを追加しました。

```gdscript
class DummyHandler:
    var board_system
    var player_system
    var current_player_id: int
    var game_flow_manager
    
    func _init(systems: Dictionary):
        board_system = systems.get("board_system")
        player_system = systems.get("player_system")
        current_player_id = systems.get("current_player_id", 0)
        game_flow_manager = systems.get("game_flow_manager")
```

## 共通化されたチェック項目

以下のチェックがプレイヤー/CPU両方で統一されました：

### 防魔チェック（SpellProtection）
- パッシブスキル「防魔」
- クリーチャー呪い（spell_protection, protection_wall）
- 世界呪い「呪い防魔化」（呪い付きクリーチャーが防魔になる）
- プレイヤー呪い（spell_protection）

### HP効果無効チェック（SpellHpImmune）
- パッシブスキル「HP効果無効」
- 呪い（hp_effect_immune）

### その他のフィルタ
- owner_filter（own/enemy/any）
- 属性制限
- レベル制限
- 呪い有無チェック
- ダウン状態チェック
- 等

## ファイル変更一覧

| ファイル | 変更内容 |
|---------|---------|
| `scripts/game_flow/target_selection_helper.gd` | `get_valid_targets_core`追加、`DummyHandler`クラス追加 |
| `scripts/cpu_ai/cpu_spell_target_selector.gd` | `get_default_targets`を共通ロジック使用に変更 |
| `scripts/cpu_ai/cpu_mystic_arts_ai.gd` | `_get_default_targets`を共通ロジック使用に変更 |

## 今後の保守

新しいターゲット条件を追加する場合は、`TargetSelectionHelper.get_valid_targets_core`に追加するだけで、プレイヤーとCPU両方に適用されます。

CPU固有の追加フィルタリング（例：移動系呪いの場合の防御型除外）は、`get_default_targets`内で`get_valid_targets_core`呼び出し後に適用します。
