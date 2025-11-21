# GameSystemManager 実装前確認事項

## 質問1: UIManager.create_ui() の親ノード

**UIManager.create_ui(parent: Node) の挙動**:
- parent を受け取り、parent.add_child(ui_layer) でUILayerを作成
- UILayerはparentの直下に追加される
- Phase 4-1 Step 10で呼ぶ際、parent = game_3d シーンノードであることを確認

**実装時のパラメータ**:
```gdscript
# GameSystemManager内
if parent_node:
    ui_manager.create_ui(parent_node)  # parent_node = game_3d.tscn のルート
```

**ドキュメントの修正**: parent_nodeはgame_3dシーンのルートノード

---

## 質問2: SkillSystem → PlayerBuffSystem リネーム

**現状**:
- ファイル: scripts/skill_system.gd （クラス名: SkillSystem）
- メモリ: skillsystem_rename_completed に完全なリネーム計画がある
- 対象: 9ファイル、29箇所

**ドキュメントの記述**:
- GameSystemManager設計書 Phase 1で「SkillSystem」と書かれているが
- 実際は「PlayerBuffSystem」に統一する予定

**GameSystemManager実装時の対応**:
1. Phase 1で「PlayerBuffSystem」として作成・登録
2. 全SetupメソッドのパラメータをPlayerBuffSystemに統一
3. ファイルリネーム（skill_system.gd → player_buff_system.gd）は別途タスク

**今回の実装方針**:
- GameSystemManagerの実装時点では「skill_system」変数名を使用しつつも
- コメントで「PlayerBuffSystem (旧SkillSystem)」と記載
- または、既にリネームを完了してからGameSystemManager実装を開始

---

## 質問3: GameFlowManager の初期化順序

**GameFlowManager.setup_systems() シグネチャ**:
```gdscript
func setup_systems(p_system, c_system, b_system, s_system, ui_system, 
                   bt_system = null, st_system = null):
    player_system = p_system         # (1)
    card_system = c_system           # (2)
    skill_system = s_system          # (3) ← s_system
    ui_manager = ui_system           # (4)
    battle_system = bt_system        # (5)
    special_tile_system = st_system  # (6)
    
    _setup_spell_systems(b_system)   # (7) ← ここでSpellDraw/Magic/Land等が初期化される
```

**重要な依存関係**:
- _setup_spell_systems(b_system) は「board_system」（b_system）を受け取る
- setup_systems()の第3パラメータ（b_system）は board_system_3d
- Phase 4-1 Step 1で「board_system_3d」を渡す必要がある

**Phase 4-1 Step 1 の正確な呼び出し**:
```gdscript
game_flow_manager.setup_systems(
    player_system,        # p_system
    card_system,          # c_system
    board_system_3d,      # b_system ← 重要：3番目パラメータ
    player_buff_system,   # s_system
    ui_manager,           # ui_system
    battle_system,        # bt_system
    special_tile_system   # st_system
)
```

**ドキュメントの確認事項**:
- ドキュメントではsetup_systems(player_system, card_system, board_system_3d, skill_system, ...)と記載
- 実装コードでは(p_system, c_system, b_system, s_system, ui_system, ...)
- 順序は「player, card, board, skill, ui, battle, special_tile」

---

## 実装時の明確な手順

### 1. 変数名を統一（game_system_manager.gd）
```gdscript
# Phase 1
var player_buff_system: PlayerBuffSystem  # ← PlayerBuffSystemとして定義
# または
var skill_system: SkillSystem  # ← 既存コードとの互換性維持
```

### 2. Phase 4-1 Step 1のパラメータ順序
```gdscript
game_flow_manager.setup_systems(
    player_system,          # 1番目
    card_system,            # 2番目
    board_system_3d,        # 3番目 ← 重要
    player_buff_system,     # 4番目
    ui_manager,             # 5番目
    battle_system,          # 6番目
    special_tile_system     # 7番目
)
```

### 3. UIManager.create_ui() の呼び出しタイミング
```gdscript
# Phase 4-1 Step 5: UIManagerに参照を設定
ui_manager.board_system_ref = board_system_3d
ui_manager.player_system_ref = player_system
ui_manager.card_system_ref = card_system
ui_manager.game_flow_manager_ref = game_flow_manager

# Phase 4-1 Step 10: 全参照設定後にcreate_ui()を呼ぶ
if parent_node:
    ui_manager.create_ui(parent_node)
```
