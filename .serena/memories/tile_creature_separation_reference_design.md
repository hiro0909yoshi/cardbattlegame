# クリーチャー管理システム - 完全実装済み (2025年11月5日)

## ⚠️ 重要: "タイル"という名称について

**実装上の注意点**:
- クリーチャーは**タイルに配置されている**が、データは**CreatureManagerが管理**
- `tile.creature_data` という記法は残っているが、実体はCreatureManagerにある
- 「タイルがクリーチャーを持っている」という理解は誤り
- 正しくは「CreatureManagerがタイル番号をキーにクリーチャーを管理している」

## 実装完了状態 ✅

### Phase 1-3 すべて完了

**Phase 1**: CreatureManager実装 ✅
- `scripts/creature_manager.gd` - 230行の完全実装
- 基本機能: get_data_ref(), set_data(), has_creature(), clear_data()
- 拡張機能: find_by_player(), find_by_element(), validate_integrity()
- セーブ/ロード: get_save_data(), load_from_save_data()
- 3D管理: set_visual_node(), update_all_visuals()

**Phase 2**: BaseTile統合 ✅
- `scripts/tiles/base_tiles.gd` 変更
- creature_dataをプロパティ化（get/set）
- 透過的なリダイレクト実装
- `scripts/board_system_3d.gd` で初期化

**Phase 3**: 完全移行 ✅
- フォールバック機構(_local_creature_data)を削除
- CreatureManagerへの完全依存
- 実ゲームで動作確認完了

## アーキテクチャ

### データの流れ
```
tile.creature_data = {...}
  ↓ (プロパティset)
BaseTile.creature_data.set(value)
  ↓
CreatureManager.set_data(tile_index, value)
  ↓
creatures[tile_index] = value  ← 実際の保存場所
```

### 参照による変更
```gdscript
// これが動作する理由
var ref = tile.creature_data  // get_data_ref()で参照取得
ref["hp"] = 100  // CreatureManager内の辞書を直接変更
```

### 重要な実装コード

**BaseTile (scripts/tiles/base_tiles.gd)**:
```gdscript
static var creature_manager: CreatureManager = null

var creature_data: Dictionary:
    get:
        if creature_manager:
            return creature_manager.get_data_ref(tile_index)
        else:
            push_error("[BaseTile] CreatureManager未初期化")
            return {}
    set(value):
        if creature_manager:
            creature_manager.set_data(tile_index, value)
        else:
            push_error("[BaseTile] CreatureManager未初期化")
```

**BoardSystem3D 初期化**:
```gdscript
func _ready():
    create_creature_manager()  # 最初に実行
    create_subsystems()

func create_creature_manager():
    var cm = CreatureManager.new()
    cm.board_system = self
    add_child(cm)
    BaseTile.creature_manager = cm
```

## データ構造

### CreatureManagerが管理するデータ
```gdscript
creatures: Dictionary = {
    tile_index: {
        "name": "ドラゴン",
        "hp": 100,
        "max_hp": 100,
        "ap": 50,
        "element": "fire",
        "ability_parsed": {...},
        "base_up_hp": 10,
        "permanent_effects": [],
        "temporary_effects": [],
        "items": [],
        ...全フィールド
    }
}
```

## 既存コードへの影響

### 変更不要 ✅
- 約800箇所の `tile.creature_data["key"]` は変更不要
- place_creature(), remove_creature() も変更不要
- BattleParticipant も変更不要
- すべて透過的にCreatureManager経由になる

### 変更したファイル（2ファイルのみ）
1. `scripts/tiles/base_tiles.gd` - プロパティ追加
2. `scripts/board_system_3d.gd` - 初期化追加

## 利点

### 開発面
- データの一元管理が可能
- デバッグが容易（debug_print()で一覧表示）
- 検索・集計機能が簡単に追加できる

### パフォーマンス
- セーブ/ロードの簡素化
- 将来的なキャッシュ最適化が可能

### 保守性
- 責任の分離が明確
- テストが書きやすい
- 拡張が容易

## 使用例

### 検索機能
```gdscript
# プレイヤー0のクリーチャー取得
var creatures = creature_manager.find_by_player(0)

# 火属性のクリーチャー取得
var fire_creatures = creature_manager.find_by_element("fire")

# すべてのクリーチャー数
var count = creature_manager.get_creature_count()
```

### デバッグ
```gdscript
creature_manager.debug_print()
# → コンソールに全クリーチャーの状態を出力
```

### 整合性チェック
```gdscript
if not creature_manager.validate_integrity():
    print("データに問題があります")
```

## 注意事項

### CreatureManagerの初期化タイミング
- BoardSystem3D._ready()で自動的に初期化される
- BaseTile.creature_managerはstaticなので全タイルで共有
- 初期化前にアクセスするとエラー（push_error）

### データの所有権
- クリーチャーデータの「実体」はCreatureManagerにある
- タイルはあくまで「配置場所」を示すだけ
- データの移動はコピー→削除→再配置の流れ

## テスト結果
- 単体テスト: 10/10成功 ✅
- 統合テスト: 6/6成功 ✅
- 実ゲーム: すべて正常動作 ✅
