# システムアーキテクチャ リファクタリング計画

## 概要
Gemini による設計レビューで指摘されたシステムアーキテクチャの問題に対処するための計画書。主に以下の3つの大型リファクタリングを段階的に実施。

---

## 1. TileDataManager / CreatureManager の SSoT 統一 【優先度: 高】

### 現在の問題
- **データの二重管理**: TileDataManager が `tile.creature_data` を参照、CreatureManager が独立した辞書で管理
- **"誰がマスターか不明確"** → HP や AP 更新時に片方だけが更新される整合性バグ

### 根本原因
```
TileDataManager側: get_tile_info() → tile.creature_data を参照
CreatureManager側: creatures: Dictionary = {tile_index: creature_data辞書}
```
この二つが共存し、更新時に同期が取られない。

### 推奨解決方針
**CreatureManager を SSoT（単一情報源）にする**

#### 実装ステップ
1. **BaseTile からクリーチャーデータを削除**
   - `creature_data` プロパティを削除
   - クリーチャー ID / 参照キーのみを保持

2. **CreatureManager をマスターに統一**
   - `creatures: Dictionary = {tile_index: creature_data}`を唯一の真実の源に
   - 全てのクリーチャー情報アクセスは CreatureManager.get_creature_data() 経由

3. **TileDataManager の責務を明確化**
   - タイルの基本属性管理（land_type, effect など）
   - クリーチャーデータへはアクセス窓口のみ（CreatureManager.get_creature_data() を呼び出す）

#### 影響範囲
- `TileDataManager.gd`: `get_tile_info()` の修正
- `BaseTile.gd`: `creature_data` プロパティ削除
- `BoardSystem3D.gd`: クリーチャーアクセス箇所の修正
- 各種ビジュアル更新メソッド

---

## 2. TileDataManager からビジュアル処理を分離 【優先度: 中】

### 現在の問題
- TileDataManager にビジュアル更新メソッドが含まれている
  - `update_all_displays()`
  - `_update_display(tile_index: int)`
- **責務混在**: データ管理 + 表示更新が同じクラスに

### 問題の影響
- 3D表示を変更する際、データ管理ファイルまで修正が必要
- テスト時にビジュアル依存が混入
- 保守性低下

### 推奨解決方針
ビジュアル層を分離

#### 実装ステップ
1. **ビジュアル更新メソッドを TileDataManager から削除**
   - `update_all_displays()`
   - `_update_display()`

2. **新規クラス TileVisualUpdater を作成** （または既存ビジュアルシステムに統合）
   - TileDataManager が更新したデータを監視
   - データ変更時に自動的にビジュアルを更新

3. **イベント駆動で結合**
   - TileDataManager: `data_changed` シグナル発火
   - TileVisualUpdater: シグナル受信 → ビジュアル更新

#### 影響範囲
- `TileDataManager.gd`: ビジュアルメソッド削除
- 新規ファイル: `TileVisualUpdater.gd` （または既存ビジュアルシステムに統合）
- ビジュアル更新呼び出し元の修正

---

## 3. SkillSystem の拡張性向上 【優先度: 中】

### 現在の問題
- バフをハードコードで管理
  ```gdscript
  match buff_type:
	  "card_cost":
		  player_buffs[player_id].card_cost_reduction += value
	  "dice":
		  player_buffs[player_id].dice_bonus += value
	  # ... 全てのバフがハードコード
  ```
- **新バフ追加時の修正範囲が広い**
  - `initialize_player_buffs()`
  - `apply_buff()`
  - `apply_debuff()`
  - その他関連メソッド

### 推奨解決方針
バフを動的なデータ構造に変更

#### 実装ステップ
1. **BuffObject クラスを定義**
   ```gdscript
   class BuffObject:
	   var type: String        # "card_cost_reduction", "dice_bonus" など
	   var value: float
	   var duration: int       # ターン数（-1 = 無制限）
   ```

2. **プレイヤーバフを配列に変更**
   ```gdscript
   # Before:
   player_buffs[player_id] = {card_cost_reduction: 0, dice_bonus: 0, ...}
   
   # After:
   player_buffs[player_id] = [BuffObject(...), BuffObject(...), ...]
   ```

3. **apply_buff() を単純化**
   ```gdscript
   func apply_buff(player_id: int, buff_type: String, value: float, duration: int):
	   player_buffs[player_id].append(BuffObject(buff_type, value, duration))
   ```

4. **計算メソッドを修正**
   ```gdscript
   func get_card_cost_reduction(player_id: int) -> float:
	   var total = 0.0
	   for buff in player_buffs[player_id]:
		   if buff.type == "card_cost_reduction":
			   total += buff.value
	   return total
   ```

#### 利点
- 新バフ追加時は BuffObject インスタンス生成のみ
- SkillSystem のコアロジック不要
- 拡張性が格段に向上

#### 影響範囲
- `SkillSystem.gd`: バフ管理の完全リファクタリング
- バフを使用する全ての箇所（modify_card_cost など）

---

## 4. SkillSystem のリネーム 【優先度: 低】

### 現在の問題
- クラス名 `SkillSystem` が汎用的すぎる
- **混同のリスク**: クリーチャースキルやタイル効果スキルとの混同

### 推奨リネーム
`PlayerBuffSystem` または `GlobalEffectSystem`

#### 実装ステップ
1. ファイルリネーム: `SkillSystem.gd` → `PlayerBuffSystem.gd`
2. クラス名変更
3. 全参照を更新

#### 影響範囲
- ファイル名変更
- クラス宣言
- 全インスタンス化箇所

---

## 実装優先度

| 優先度 | 項目 | 理由 |
|--------|------|------|
| **高** | TileDataManager / CreatureManager SSoT統一 | 整合性バグの根本原因。HP系統の安定性に直結 |
| **中** | SkillSystem の拡張性向上 | 将来のバフ追加コストを削減。数十種類バフ存在時に効果大 |
| **中** | TileDataManager のビジュアル分離 | 保守性向上。直近では低緊急度だが構造改善 |
| **低** | SkillSystem のリネーム | 混乱防止。機能リファクタリング後に実施 |

---

## 実装時の注意点

### テスト戦略
- 各リファクタリング実施後、既存バトル・マップシステムの動作確認
- HP 計算、バフ適用、表示更新の一連動作検証

### ドキュメント更新
- 各リファクタリング完了時に関連ドキュメントを更新
- API/インターフェース変更を記録

### 段階的実施
- 一度に全て実施しない
- 優先度順に1つずつ完了させ、動作確認後に次へ進む

---

**作成日**: 2025-11-21  
**レビュー元**: Google Gemini による設計レビュー
