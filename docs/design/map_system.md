# マップシステム仕様

**バージョン**: 1.1  
**最終更新**: 2025年12月16日

---

## 📐 マップ構造

### 基本仕様
- **形状**: ダイヤモンド型
- **タイル数**: 20マス
- **移動方向**: 時計回り（0 → 1 → 2 ... → 19 → 0）
- **座標系**: 3D空間（XZ平面）

### タイル配置
```
タイル番号は時計回りに0〜19
	  
	  15  14  13  12  11  10
	16                      9
  17                          8
	18                      7
	  19  0   1   2   3   4   5   6
```

---

## 🎯 特殊タイルの種類

### 1. CheckpointTile（チェックポイントタイル）

**配置場所**:
- **タイル0** - タイプN（スタート地点）
- **タイル10** - タイプS（対角線上）

**役割**: 周回検出
- プレイヤーが通過するとシグナル発行（N または S）
- N + S のセット = 1周完了

**視覚的特徴**: 黒色のオーバーレイメッシュ

**詳細**: [周回システム](#-周回システム) を参照

---

### 2. WarpTile（ワープタイル）

**配置場所**:
- **タイル4** ↔ **タイル5** （ワープペア）
- **タイル15** ↔ **タイル16** （ワープペア）

**動作**: 通過型ワープ（歩数消費なし）
- タイル4を通過 → タイル5へ瞬間移動（歩数を消費せず移動継続）
- タイル5を通過 → タイル4へ瞬間移動（歩数を消費せず移動継続）
- タイル15を通過 → タイル16へ瞬間移動（歩数を消費せず移動継続）
- タイル16を通過 → タイル15へ瞬間移動（歩数を消費せず移動継続）

**視覚的特徴**: 紫色のオーバーレイメッシュ

**ワープペア設定**: マップJSONの`warp_pair`フィールドで定義（動的読み込み）

**実装**:
- `MovementController.check_and_handle_warp()` - ワープ判定・歩数戻し
- `SpecialTileSystem.register_warp_pair()` - ペア登録
- `StageLoader.register_warp_pairs_to_system()` - JSONから読み込み
- フェードアウト/フェードインアニメーション

---

### 3. 通常タイル（属性タイル）

**種類**:
- FireTile（火）
- WaterTile（水）
- EarthTile（土）
- WindTile（風）
- NeutralTile（無）

**機能**:
- クリーチャー配置可能
- 属性一致でHP土地ボーナス: `HP + (レベル × 10)`
- レベル1〜5まで成長可能

---

## 🔄 周回システム

### 仕組み

**周回完了の条件**:
1. プレイヤーがタイル0（N）を通過 → **Nシグナル**
2. プレイヤーがタイル10（S）を通過 → **Sシグナル**
3. **N + S 両方揃う** → **周回完了**

**特殊ルール**:
- ゲーム開始時のタイル0通過はカウントしない
- 2回目以降の通過からNシグナル発行
- 順序は問わない（N→S でも S→N でもOK）

---

### 周回完了時の効果

#### 永続バフ対象クリーチャー

| ID | 名前 | 効果 |
|----|------|------|
| 7 | キメラ | 周回ごとにAP+10（累積、上限なし） |
| 240 | モスタイタン | 周回ごとにMHP+10（MHP≧80で30にリセット） |

**データ保存**:
```gdscript
creature_data["map_lap_count"] = 0      # 周回数カウンター
creature_data["base_up_ap"] += 10       # キメラ用
creature_data["base_up_hp"] += 10       # モスタイタン用
```

**リセット条件**: 手札に戻った時

---

## 🎁 スタート通過ボーナス

### タイル0通過時の効果

プレイヤーがタイル0を通過するたび、以下の3つの効果が発動：

#### 1. 💰 魔力ボーナス
- `GameConstants.PASS_BONUS`分の魔力を獲得
- 現在値: 500G

#### 2. 🔓 ダウン状態クリア
- プレイヤーの**全領地**のダウン状態を解除
- 次のターンで領地コマンド（レベルアップ/移動/交換）が再び可能に

#### 3. 💚 クリーチャーHP回復
- プレイヤーの**全クリーチャー**のHPを**+10回復**
- MHP（最大HP）を超えない
- 計算式: `new_HP = min(current_HP + 10, MHP)`

**例**:
```
MHP 50, 現在HP 30 → 40に回復
MHP 50, 現在HP 45 → 50に回復（上限）
```

---

## 🚶 移動方向システム

### 基本概念

プレイヤーの移動は以下の方向が存在する：

| 方向 | 値 | 説明 |
|------|-----|------|
| 順方向（時計回り） | +1 | タイル番号が増加する方向（0→1→2...） |
| 逆方向（反時計回り） | -1 | タイル番号が減少する方向（...2→1→0→19） |

---

### プレイヤーが持つ移動情報

```gdscript
class PlayerData:
	var current_direction: int = 1   # 現在の移動方向（+1 or -1）
	var came_from: int = -1          # 前にいたタイル（分岐判定用）
	var buffs: Dictionary = {}       # buffs["direction_choice_pending"] = true で方向選択権
```

---

### タイル構造

#### ループタイルと分岐タイル

| タイプ | タイル番号 | connections | 説明 |
|--------|-----------|-------------|------|
| ループタイル | 1〜19 | `[]`（空） | 通常の円形ループ |
| 分岐点 | 0 | `[1, 19, 20]` | 3方向に分岐 |
| 中継点 | 20 | `[0, 21]` | 2方向に接続 |
| 行き止まり | 21 | `[20]` | 1方向のみ |

#### ループサイズの動的計算

```gdscript
# connectionsが空のタイル（ループタイル）の最大インデックス + 1
func _get_loop_size() -> int:
	var max_normal_tile = -1
	for tile_index in tile_nodes.keys():
		var tile = tile_nodes[tile_index]
		if tile.connections.is_empty():
			max_normal_tile = max(max_normal_tile, tile_index)
	if max_normal_tile >= 0:
		return max_normal_tile + 1  # 例: 最大19 → ループサイズ20
	else:
		return tile_nodes.size()
```

**計算例**:
- タイル1〜19: connections空 → 最大19 → ループサイズ = 20
- タイル0, 20, 21: connectionsあり → 除外

---

### 方向選択権（direction_choice_pending）

#### 付与タイミング

| タイミング | 処理場所 |
|-----------|---------|
| ゲームスタート時 | `GameFlowManager.start_game()` |
| スペルワープ後 | `SpellPlayerMove._warp_player()` |

#### 実装

```gdscript
# ゲームスタート時
func start_game():
	for player in player_system.players:
		player.buffs["direction_choice_pending"] = true

# スペルワープ後
func _warp_player(player_id: int, target_tile: int):
	# ...ワープ処理...
	player_system.players[player_id].buffs["direction_choice_pending"] = true
```

---

### 分岐選択のロジック

#### 基本フロー

```
現在タイルにconnectionsがある？
├─ NO → ループ内移動: (current + direction) % loop_size
└─ YES → came_fromを除外して選択肢を作成
		  ├─ 選択肢 0個 → 来た方向に戻る（行き止まり）
		  ├─ 選択肢 1個 → 自動選択
		  └─ 選択肢 2個以上 → UI表示
```

#### 実装（_get_next_tile_with_branch）

```gdscript
func _get_next_tile_with_branch(current_tile: int, came_from: int, player_id: int) -> int:
	var tile = tile_nodes.get(current_tile)
	
	# connectionsがなければループ内移動
	if not tile or tile.connections.is_empty():
		var direction = _get_player_current_direction(player_id)
		var loop_size = _get_loop_size()
		return (current_tile + direction + loop_size) % loop_size
	
	# connectionsからcame_fromを除外
	var choices = []
	for conn in tile.connections:
		if conn != came_from:
			choices.append(conn)
	
	# 選択肢なし → 来た方向に戻る
	if choices.is_empty():
		return came_from
	
	# 選択肢1つ → 自動選択
	if choices.size() == 1:
		return choices[0]
	
	# 選択肢2つ以上 → UI表示
	return await _show_branch_tile_selection(choices)
```

---

### 方向の推測

選んだタイルから移動方向（+1/-1）を推測する：

```gdscript
func _infer_direction_from_choice(current_tile: int, chosen_tile: int, player_id: int) -> int:
	var loop_size = _get_loop_size()
	
	# 選んだタイルがループ外なら現在の方向を維持
	if chosen_tile >= loop_size:
		return _get_player_current_direction(player_id)
	
	# ループ内なら方向を判定
	var next_plus = (current_tile + 1) % loop_size
	var next_minus = (current_tile - 1 + loop_size) % loop_size
	
	if chosen_tile == next_plus:
		return 1   # 順方向
	elif chosen_tile == next_minus:
		return -1  # 逆方向
	else:
		return _get_player_current_direction(player_id)
```

**例**:
- タイル0で「タイル1」選択 → +1（順方向）
- タイル0で「タイル19」選択 → -1（逆方向）
- タイル0で「タイル20」選択 → 現在の方向を維持

---

### 移動の実例

#### 例1: ループ内移動

```
現在: タイル5, direction=+1, came_from=4
→ connectionsなし → ループ計算
→ (5 + 1) % 20 = 6
→ タイル6へ移動
```

#### 例2: 分岐点での選択

```
現在: タイル0, came_from=19
→ connections=[1, 19, 20]
→ 19を除外 → 選択肢=[1, 20]
→ UI表示 → 「タイル1」選択
→ direction=+1 を設定
→ タイル1へ移動
```

#### 例3: 行き止まりからの戻り

```
現在: タイル21, came_from=20
→ connections=[20]
→ 20を除外 → 選択肢=[]（空）
→ came_fromに戻る → タイル20へ
```

#### 例4: 分岐タイル20の通過

```
現在: タイル20, came_from=0
→ connections=[0, 21]
→ 0を除外 → 選択肢=[21]
→ 自動選択 → タイル21へ
```

---

### UI操作

#### 入力方法

| 選択タイプ | キーボード | ボタン | 説明 |
|-----------|-----------|--------|------|
| 分岐タイル選択 | ←→ + Enter | - | タイル番号から選択 |
| 方向選択（+1/-1） | ↑↓ + Enter | ▲▼ + ✓ | 順方向/逆方向を選択 |

#### グローバルナビゲーションボタン（方向選択時）

方向選択フェーズではグローバルナビゲーションボタンが表示されます。

| ボタン | アイコン | 動作 |
|--------|----------|------|
| 決定 | ✓ | 選択確定 |
| 上 | ▲ | 方向切り替え |
| 下 | ▼ | 方向切り替え |

※戻るボタン（✕）は非表示

#### 実装詳細

```gdscript
# 方向選択開始時
func _setup_direction_selection_navigation():
	ui_manager.enable_navigation(
		func(): _confirm_direction_selection(),  # 決定
		Callable(),                               # 戻るなし
		func(): _cycle_direction_selection(),    # 上
		func(): _cycle_direction_selection()     # 下
	)

# 方向選択終了時
func _clear_direction_selection_navigation():
	ui_manager.disable_navigation()
```

**表示例**:
```
移動方向を選択: 順方向 →
```

---

### 歩行逆転呪い（カオスパニック）

**付与方法**: カオスパニック（ID: 2019）

**効果**:
- 付与されたプレイヤーは移動方向が反転
- direction=+1 で移動開始 → 実際は-1方向に移動

**持続**: 1ターン

**実装**:
```gdscript
# calculate_path内で方向を反転
if _has_movement_reverse_curse(player_id):
	final_direction = -direction
```

---

### 移動フェーズの流れ

```
1. ターン開始
   ↓
2. スペルフェーズ（省略）
   ↓
3. ダイスロール
   ↓
4. 方向選択権チェック
   ├─ direction_choice_pending == true
   │   ├─ 分岐点にいる → タイル選択UI
   │   └─ 通常タイル → +1/-1選択UI
   └─ false → 前回のdirectionを使用
   ↓
5. 1歩ずつ移動（_move_steps_with_branch）
   各ステップで:
   │
   ├─ 次タイル判定（_get_next_tile_with_branch）
   │   ├─ connectionsあり → 選択肢作成 → UI or 自動選択
   │   └─ connectionsなし → ループ計算
   │
   ├─ 移動実行（move_to_tile）
   ├─ came_from更新
   ├─ ワープチェック
   ├─ チェックポイントチェック
   └─ 足どめチェック
   ↓
6. 最終位置に到着
   ↓
7. タイルアクション
```

---

## 📊 実装状況

### ✅ 実装済み

#### 基本システム
- [x] 20マスのダイヤモンド型マップ（ループタイル0-19）
- [x] CheckpointTile（N/S）と周回検出
- [x] 周回完了時の永続バフ（キメラ、モスタイタン）
- [x] スタート通過ボーナス（魔力、ダウンクリア、HP回復）
- [x] WarpTile（4↔5、15↔16）通過型ワープ（歩数消費なし、JSONから動的読み込み）
- [x] 属性タイル（火/水/土/風/無）
- [x] 土地ボーナスシステム

#### 分岐・方向選択システム
- [x] タイル接続システム（connections: Array[int]）
- [x] ループサイズの動的計算（_get_loop_size）
- [x] 分岐タイル（タイル0: [1, 19, 20]）
- [x] 中継タイル（タイル20: [0, 21]）
- [x] 行き止まりタイル（タイル21: [20]）
- [x] came_from追跡による戻り方向除外
- [x] 方向選択権（direction_choice_pending）
  - [x] ゲームスタート時の付与
  - [x] スペルワープ後の付与
- [x] 分岐タイル選択UI（←→キー）
- [x] 方向選択UI（↑↓キー + グローバルナビゲーションボタン）
- [x] 方向の推測（_infer_direction_from_choice）
- [x] current_directionの記憶と継続
- [x] 歩行逆転呪い（カオスパニック）

#### 修正済みハードコード
- [x] movement_controller.gd: ループサイズを動的計算
- [x] spell_curse.gd: tile_nodes.keys()でループ
- [x] debug_controller.gd: tile_nodes.has()でチェック
- [x] spell_land_new.gd: tile_nodes.has()でチェック

### 🚧 未実装
- [ ] 追加のワープゲート
- [ ] 停止型ワープタイル
- [ ] 停止型特殊マス（宿屋、店など）
- [ ] マップ選択システム
- [ ] ランダムマップ生成
- [ ] 複数マップ対応

---

## 🔧 技術詳細

### 周回状態管理

**GameFlowManager.player_lap_state**:
```gdscript
{
  player_id: {
	"game_started": bool,  # ゲーム開始フラグ
	"N": bool,             # Nシグナル受信フラグ
	"S": bool              # Sシグナル受信フラグ
  }
}
```

### シグナルフロー

```
CheckpointTile
  └─ checkpoint_passed(player_id, "N"|"S")
	   ↓
  GameFlowManager._on_checkpoint_passed()
	   ↓
  両方のフラグが立つ？
	   ├─ YES → _complete_lap()
	   │          ├─ フラグリセット
	   │          ├─ 永続バフ適用
	   │          └─ lap_completed シグナル
	   │
	   └─ NO → 待機
```

---

## 📝 関連ドキュメント

- [周回システム実装ノート](../implementation_notes/lap_system_implementation.md)
- [条件付きステータスバフシステム](conditional_stat_buff_system.md)
- [スキルシステム設計](skills_design.md)
- [グローバルナビゲーションボタン設計ガイド](global_navigation_buttons.md)

---

## 🎮 プレイヤー向けヒント

### 周回を効率よく回るコツ
1. **ワープゲートを活用**: タイル5→6でショートカット
2. **チェックポイントの位置を把握**: タイル0とタイル10
3. **周回ボーナスを狙う**: キメラ、モスタイタンを配置すれば強力

### スタート通過を意識した戦略
- ダウン状態の土地が多い時は早めにスタートを目指す
- 瀕死のクリーチャーはスタート通過で+10回復
- 魔力が不足している時は周回で補充

---

**最終更新**: 2025年12月16日  
**作成者**: Development Team
