# マップシステム仕様

**バージョン**: 1.2  
**最終更新**: 2025年1月19日

---

## 📐 マップ構造

### 基本仕様
- **形状**: マップごとに異なる（ダイヤモンド型、十字型など）
- **タイル数**: マップJSONの`tile_count`で定義
- **移動方向**: 時計回り（0 → 1 → 2 ... → N → 0）
- **座標系**: 3D空間（XZ平面）

### タイル配置例（ダイヤモンド型20マス）
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

**役割**: 周回検出
- プレイヤーが通過するとシグナル発行（N, S, E, W）
- 必要なシグナルがすべて揃う = 1周完了
- 必要シグナルはマップJSONの`checkpoint_preset`で指定

**視覚的特徴**: 黒色のオーバーレイメッシュ

**詳細**: [周回システム](#-周回システム) を参照

---

### 2. WarpTile（ワープタイル）

**種類**:
- `Warp` - 通過型（歩数消費なし）
- `WarpStop` - 停止型（そのマスで止まる）

**動作**:
- 通過型: 瞬間移動後も移動継続
- 停止型: 瞬間移動後にそのマスで停止

**視覚的特徴**: 紫色のオーバーレイメッシュ

**ワープペア設定**: マップJSONの`warp_pair`フィールドで定義

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

### 4. その他の特殊タイル

| タイル | 説明 |
|--------|------|
| BranchTile | 分岐点（複数方向への接続） |
| CardBuyTile | カード購入マス |
| CardGiveTile | カード獲得マス |
| MagicStoneTile | 魔法石マス |
| MagicTile | 魔力マス |

---

## 🔄 周回システム

### 仕組み

**周回完了の条件**:
1. マップで指定された全チェックポイントを通過
2. チェックポイントプリセットで必要シグナルが決まる

**チェックポイントプリセット**: [オンラインルール設計書](online_rules_design.md#checkpoint_presetsチェックポイントプリセット) を参照

**特殊ルール**:
- ゲーム開始時のスタート地点通過はカウントしない
- 2回目以降の通過からシグナル発行
- 順序は問わない

---

### 周回完了時の効果

#### 1. 魔力ボーナス

マップの`lap_bonus_preset`で指定されたボーナスを獲得。
プリセット詳細: [オンラインルール設計書](online_rules_design.md#lap_bonus_presets周回ボーナスプリセット) を参照

#### 2. ダウン状態クリア
- プレイヤーの**全領地**のダウン状態を解除
- 次のターンで領地コマンド（レベルアップ/移動/交換）が再び可能に

#### 3. クリーチャーHP回復
- プレイヤーの**全クリーチャー**のHPを**+10回復**
- MHP（最大HP）を超えない
- 計算式: `new_HP = min(current_HP + 10, MHP)`

#### 4. 永続バフ対象クリーチャー

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

## 🚶 移動方向システム

### 基本概念

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

| タイプ | connections | 説明 |
|--------|-------------|------|
| ループタイル | `[]`（空） | 通常の円形ループ |
| 分岐点 | `[1, 19, 20]` | 複数方向に分岐 |
| 中継点 | `[0, 21]` | 2方向に接続 |
| 行き止まり | `[20]` | 1方向のみ |

#### ループサイズの動的計算

```gdscript
func _get_loop_size() -> int:
	var max_normal_tile = -1
	for tile_index in tile_nodes.keys():
		var tile = tile_nodes[tile_index]
		if tile.connections.is_empty():
			max_normal_tile = max(max_normal_tile, tile_index)
	if max_normal_tile >= 0:
		return max_normal_tile + 1
	else:
		return tile_nodes.size()
```

---

### 方向選択権（direction_choice_pending）

#### 付与タイミング

| タイミング | 処理場所 |
|-----------|---------|
| ゲームスタート時 | `GameFlowManager.start_game()` |
| スペルワープ後 | `SpellPlayerMove._warp_player()` |

---

### 分岐選択のロジック

```
現在タイルにconnectionsがある？
├─ NO → ループ内移動: (current + direction) % loop_size
└─ YES → came_fromを除外して選択肢を作成
		  ├─ 選択肢 0個 → 来た方向に戻る（行き止まり）
		  ├─ 選択肢 1個 → 自動選択
		  └─ 選択肢 2個以上 → UI表示
```

---

### 歩行逆転呪い（カオスパニック）

**付与方法**: カオスパニック（ID: 2019）

**効果**:
- 付与されたプレイヤーは移動方向が反転
- direction=+1 で移動開始 → 実際は-1方向に移動

**持続**: 1ターン

---

### 移動フェーズの流れ

```
1. ターン開始
   ↓
2. スペルフェーズ
   ↓
3. ダイスロール
   ↓
4. 方向選択権チェック
   ├─ direction_choice_pending == true
   │   ├─ 分岐点にいる → タイル選択UI
   │   └─ 通常タイル → +1/-1選択UI
   └─ false → 前回のdirectionを使用
   ↓
5. 1歩ずつ移動
   各ステップで:
   ├─ 次タイル判定
   ├─ 移動実行
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

## 📄 マップJSONスキーマ

```json
{
	"id": "map_diamond_20",
	"name": "ダイヤモンド型",
	"description": "基本の20マスマップ",
	"tile_count": 20,
	"loop_size": 20,
	"tiles": [
		{"index": 0, "type": "Checkpoint", "x": 0, "z": 0, "checkpoint_type": "N"},
		{"index": 1, "type": "Neutral", "x": 4, "z": 0},
		{"index": 4, "type": "Warp", "x": 16, "z": 0, "warp_pair": 5}
	],
	"connections": {
		"0": [1, 19, 20]
	},
	"lap_bonus_preset": "standard",
	"checkpoint_preset": "standard"
}
```

### フィールド説明

| フィールド | 説明 |
|-----------|------|
| `id` | マップ識別子 |
| `tile_count` | タイル総数 |
| `loop_size` | メインループのタイル数 |
| `tiles` | タイル配置データ |
| `connections` | 分岐タイルの接続情報 |
| `lap_bonus_preset` | 周回ボーナスプリセット名 |
| `checkpoint_preset` | チェックポイントプリセット名 |

プリセットの詳細: [オンラインルール設計書](online_rules_design.md) を参照

---

## 📊 実装状況

### ✅ 実装済み

- [x] 動的マップ生成（JSONから）
- [x] CheckpointTile（N/S/E/W）と周回検出
- [x] 周回完了時の永続バフ
- [x] 周回ボーナス（プリセット対応）
- [x] WarpTile（通過型・停止型）
- [x] 属性タイル（火/水/土/風/無）
- [x] 土地ボーナスシステム
- [x] 分岐・方向選択システム
- [x] 歩行逆転呪い

### 🚧 未実装

- [ ] 追加のワープゲート
- [ ] 停止型特殊マス（宿屋、店など）
- [ ] マップ選択システム
- [ ] ランダムマップ生成

---

## 📝 関連ドキュメント

- [オンラインルール設計書](online_rules_design.md) - プリセット、勝利条件、カード制限
- [クエストシステム設計](quest_system_design.md) - ソロクエスト専用の仕様
- [条件付きステータスバフシステム](conditional_stat_buff_system.md)
- [スキルシステム設計](skills_design.md)

---

**最終更新**: 2025年1月19日
