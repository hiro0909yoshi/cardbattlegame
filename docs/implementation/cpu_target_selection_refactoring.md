# CPUターゲット選択ロジックのリファクタリング

## 概要

CPUのスペル/秘術ターゲット選択ロジックを、プレイヤーと同じフィルタリングが適用されるようにリファクタリングしました。

## 背景・問題点

従来、ターゲット選択ロジックが二重管理されていました：

- **プレイヤー**: `TargetSelectionHelper.get_valid_targets()` → 防魔・HP効果無効等のチェック込み
- **CPU**: `cpu_target_resolver.check_target_condition()` → 独自実装（フィルタなし）

この結果、防魔やHP効果無効を持つクリーチャーに対して、プレイヤーは使用できないのにCPUは使用できてしまう問題がありました。

## 解決策

### 1. TargetSelectionHelper.get_valid_targets_core

`get_valid_targets_core`という静的関数で、`handler`なしで呼び出せるようにしました。
**関数の最後で`SpellProtection.filter_protected_targets()`を自動適用**します。

```gdscript
static func get_valid_targets_core(systems: Dictionary, target_type: String, target_info: Dictionary) -> Array:
	# ... ターゲット取得処理 ...
	
	# 防魔フィルター（ignore_protection: true でスキップ可能）
	if not target_info.get("ignore_protection", false):
		var dummy_handler = _create_dummy_handler(systems)
		targets = SpellProtection.filter_protected_targets(targets, dummy_handler)
	
	return targets
```

### 2. CPUTargetResolver.check_target_condition

`cpu_rule.target_condition`経由のターゲット取得にも**防魔フィルタを自動適用**するようにしました。

```gdscript
func check_target_condition(target_condition: String, context: Dictionary) -> Array:
	var results = _check_target_condition_internal(target_condition, context)
	
	# 全ての結果に防魔フィルタを適用
	results = _apply_protection_filter(results, context)
	
	return results

func _apply_protection_filter(targets: Array, context: Dictionary) -> Array:
	# SpellProtection.is_creature_protected / is_player_protected を使用
	# ...
```

### 3. DummyHandlerクラス

`SpellProtection.filter_protected_targets()`が`handler`オブジェクトを期待するため、`systems`辞書から`handler`ライクなオブジェクトを作成する`DummyHandler`クラスを追加しました。

```gdscript
class DummyHandler:
	var board_system
	var player_system
	var current_player_id: int
	var game_flow_manager
	
	func _init(systems: Dictionary):
		# ...
```

## フィルタ適用の全体像

```
┌─────────────────────────────────────────────────────────────┐
│                    ターゲット取得経路                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  【プレイヤー】                  【CPU】                     │
│       │                           │                         │
│       ▼                           ▼                         │
│  spell_phase_handler         cpu_spell_ai                   │
│       │                      ┌────┴────┐                    │
│       ▼                      ▼         ▼                    │
│  TargetSelectionHelper    get_default  check_target         │
│  .get_valid_targets()     _targets()   _condition()         │
│       │                      │              │               │
│       ▼                      ▼              ▼               │
│  get_valid_targets_core   get_valid_   _check_target_       │
│       │                   targets_core condition_internal   │
│       │                      │              │               │
│       ▼                      ▼              ▼               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │         SpellProtection.filter_protected_targets     │   │
│  │         または _apply_protection_filter              │   │
│  └─────────────────────────────────────────────────────┘   │
│                           │                                 │
│                           ▼                                 │
│                    防魔持ちが除外された                      │
│                    ターゲットリスト                          │
└─────────────────────────────────────────────────────────────┘
```

## 共通化されたチェック項目

以下のチェックがプレイヤー/CPU両方で統一されました：

### 防魔チェック（SpellProtection）
- パッシブスキル「防魔」（keywords）
- パッシブスキル「防魔」（ability文字列）
- クリーチャー呪い（spell_protection, protection_wall）
- プレイヤー呪い（spell_protection）
- 世界呪い「呪い防魔化」（呪い付きクリーチャーが防魔になる）
- 世界呪い「防魔」（全セプター対象）

### HP効果無効チェック（SpellHpImmune）
- パッシブスキル「HP効果無効」（keywords）
- 呪い（hp_effect_immune）
- ※ `target_info.affects_hp = true` のスペルのみ適用

### その他のフィルタ（get_valid_targets_core内）
- owner_filter（own/enemy/any）
- 属性制限（creature_elements, required_elements）
- レベル制限（min_level, max_level, required_level）
- 呪い有無チェック（has_curse, has_no_curse）
- ダウン状態チェック（is_down, require_not_down）
- 秘術有無チェック（has_no_mystic_arts, require_mystic_arts）
- 移動可否チェック（can_move）
- 等

## ファイル変更一覧

| ファイル | 変更内容 |
|---------|---------|
| `scripts/game_flow/target_selection_helper.gd` | `get_valid_targets_core`に防魔フィルタを組み込み、`DummyHandler`クラス追加 |
| `scripts/cpu_ai/cpu_spell_target_selector.gd` | `get_default_targets`を共通ロジック使用に変更 |
| `scripts/cpu_ai/cpu_target_resolver.gd` | `check_target_condition`に防魔フィルタを追加、`game_flow_manager`参照を追加 |
| `scripts/cpu_ai/cpu_spell_condition_checker.gd` | `CPUTargetResolver`初期化時に`game_flow_manager`を渡すよう変更 |
| `scripts/cpu_ai/cpu_mystic_arts_ai.gd` | `CPUTargetResolver`初期化時に`game_flow_manager`を渡すよう変更 |

## 今後の保守

### 新しいターゲット条件を追加する場合

1. `TargetSelectionHelper.get_valid_targets_core`に条件を追加
2. または`CPUTargetResolver._check_target_condition_internal`にmatchケースを追加

いずれの場合も、防魔フィルタは**自動的に適用**されるため、個別に追加する必要はありません。

### 防魔を無視したい場合

`target_info.ignore_protection = true`を設定（ディスペルマジック等）