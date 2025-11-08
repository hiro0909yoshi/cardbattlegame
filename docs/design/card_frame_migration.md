# CardFrame.tscn → Card.tscn 移行計画

## 📅 作成日
2025-11-07

## 🎯 目的
新しく作成した美しいCardFrame.tscnを、既存のCard.tscnと置き換えてゲーム全体で使用する。

---

## 📐 サイズ仕様（実測値）

### CardFrame.tscn（新デザイン）
- **デザインサイズ**: 220 × 293 px（`custom_minimum_size`で確認済み）
- **用途**: 高品質なビジュアルデザイン
- **特徴**: 
  - 4つの宝石バッジ（コスト、攻撃力、現在HP、最大HP）
  - 装飾的な枠
  - シェーダー対応（迷彩パターン）

### ゲーム内表示サイズ（実測値）
- **実際の表示サイズ**: **290 × 390 px** ← ✅ 実際に稼働中
- **拡大倍率**: 
  - 横: 290 / 220 = **1.318** (約132%)
  - 縦: 390 / 293 = **1.331** (約133%)
- **理由**: 既存のゲームが290×390で稼働していた
- **定義場所**: 
  - `scripts/ui_components/hand_display.gd` (CARD_WIDTH/HEIGHT)
  - `scripts/ui_components/card_ui_helper.gd` (CARD_WIDTH/HEIGHT)

---

## 🔄 移行手順

### Step 1: ファイルのリネーム
1. 既存の`scenes/Card.tscn`をバックアップ
2. `scenes/CardFrame.tscn`を`scenes/Card.tscn`にリネーム
3. `scripts/card_frame.gd`は削除（不要）

### Step 2: card.gdの修正
既存の`scripts/card.gd`を修正して新しいノード構造に対応

#### 2-1. 基準サイズの変更
```gdscript
# 変更前（旧Card.tscn）
var original_width = 120.0
var original_height = 160.0

# 変更後（新CardFrame.tscn）
var original_width = 220.0
var original_height = 293.0
```

#### 2-2. ゲーム内表示サイズの設定
```gdscript
# カードの実際の表示サイズ（実測値）
var target_width = 290.0
var target_height = 390.0

# 拡大倍率を計算
var scale_x = target_width / original_width   # 290 / 220 = 1.318
var scale_y = target_height / original_height # 390 / 293 = 1.331
```

#### 2-3. ノードパスの変更
既存のCard.tscnと新CardFrame.tscnでノード構造が異なるため、パスを更新：

**重要**: 新CardFrame.tscnでは、現在HPバッジの位置が設計書と異なります！

| データ | 旧ノードパス | 新ノードパス（実測）| 備考 |
|--------|-------------|-------------------|------|
| コスト | `CostLabel` | `CostBadge/CostCircle/CostLabel` | 右上・青い丸 |
| カード名 | `NameLabel` | `NameBanner/NameLabel` | 中央下部バナー |
| 説明文 | `DescriptionLabel` | `DescriptionBox/DescriptionLabel` | 最下部・古い紙風 |
| カード画像 | `CardImage` | `CardArtContainer/CardArt` | 上部中央 |
| 攻撃力（AP） | `StatsLabel`の一部 | `LeftStatBadge/LeftStatCircle/LeftStatLabel` | 左下・赤い丸 |
| 最大HP | `StatsLabel`の一部 | `RightStatBadge/RightStatCircle/RightStatLabel` | 右下・緑の大きい丸 |
| 現在HP | なし（新規） | `CurrentHPBadge/CurrentHPCircle/CurrentHPLabel` | **右中央**・緑の小さい丸⚠️ | 旧ノードパス | 新ノードパス |
|--------|-------------|-------------|
| コスト | `CostLabel` | `CostBadge/CostCircle/CostLabel` |
| カード名 | `NameLabel` | `NameBanner/NameLabel` |
| 説明文 | `DescriptionLabel` | `DescriptionBox/DescriptionLabel` |
| カード画像 | `CardImage` | `CardArtContainer/CardArt` |
| 攻撃力（AP） | `StatsLabel`の一部 | `LeftStatBadge/LeftStatCircle/LeftStatLabel` |
| 最大HP | `StatsLabel`の一部 | `RightStatBadge/RightStatCircle/RightStatLabel` |
| 現在HP | なし（新規） | `CurrentHPBadge/CurrentHPCircle/CurrentHPLabel` |

---

## 📊 各バッジの役割

### 1. コストバッジ（右上・青い丸）
- **ノード**: `CostBadge/CostCircle/CostLabel`
- **表示内容**: カード使用コスト
- **データソース**: `card_data.get("cost", 1)`

### 2. 攻撃力バッジ（左下・赤い丸）
- **ノード**: `LeftStatBadge/LeftStatCircle/LeftStatLabel`
- **表示内容**: 攻撃力（AP）
- **データソース**: `card_data.get("ap", 0)` + `card_data.get("base_up_ap", 0)`

### 3. 現在HPバッジ（右中央・緑の小さい丸）⚠️
- **ノード**: `CurrentHPBadge/CurrentHPCircle/CurrentHPLabel`
- **位置**: 右中央（offset: -29.0, 171.0 / -3.6, 196.4）← **設計書と異なる！**
- **表示内容**: ダメージを受けた後の現在HP
- **データソース**: バトル中の動的データ（新機能）
- **注意**: 設計書では「右上コストの下」だったが、実際は「右中央カードアートの横」

### 4. 最大HPバッジ（右下・緑の大きい丸）
- **ノード**: `RightStatBadge/RightStatCircle/RightStatLabel`
- **表示内容**: 最大HP（MHP）
- **データソース**: `card_data.get("hp", 0)` + `card_data.get("base_up_hp", 0)`

---

## 🔧 card.gdで必要な修正箇所

### 1. `_adjust_children_size()` 関数
- 基準サイズを220×293に変更
- ゲーム内表示サイズ120×160への縮小処理を追加
- 新しいノードパスに対応

### 2. `update_label()` 関数
- `StatsLabel`（攻:X 防:Y）を廃止
- 個別のバッジに分けて表示

### 3. `update_dynamic_stats()` 関数
- 現在HPバッジへの表示処理を追加
- 攻撃力と最大HPを個別のバッジに表示

### 4. `load_creature_image()` 関数
- ノードパスを`CardImage`から`CardArtContainer/CardArt`に変更

---

## ✅ 期待される結果

- ゲーム内の全てのカード表示が新しいCardFrameデザインになる
- サイズは120×160で統一（既存と同じ）
- 既存のコード（Card.tscnを参照している箇所）は変更不要
- より美しく情報量の多いカード表示

---

## ⚠️ 前回の移行失敗の原因

### 問題1: サイズが290×390に拡大されなかった
- **原因**: `_adjust_children_size()`が120×160基準のまま
- **結果**: 外枠だけ290×390、中身は220×293のまま
- **解決**: 基準を220×293に変更し、1.318倍に拡大する処理を追加

### 問題2: ノード構造の不一致
- **原因**: 旧Card.tscnのノードパス（`NameLabel`等）を参照
- **結果**: 何も表示されない、またはエラー
- **解決**: 新CardFrame.tscnのノードパス（`NameBanner/NameLabel`等）に変更

### 問題3: CurrentHPバッジの位置
- **原因**: 設計書と実際のtscnファイルで位置が異なっていた
- **結果**: レイアウト崩れ
- **解決**: 実際のtscnファイルの座標（右中央）を使用

---

## 📝 注意事項

1. **バックアップ必須**: 既存のCard.tscnは完全に失われるため、事前にバックアップ
2. **ノード名の正確性**: 新しいCardFrame.tscnのノード名が正確でないと表示エラーになる
3. **テスト必須**: リネーム後、ゲームを起動して全てのカード表示を確認

---

## 🔗 関連ファイル

- **シーン**: `scenes/CardFrame.tscn` → `scenes/Card.tscn`
- **スクリプト**: `scripts/card.gd`（修正対象）
- **デザインドキュメント**: `docs/design/card_frame_design_v1.md`（メモリに保存済み）

---

最終更新: 2025-11-09（完全版・属性別枠色実装含む✅）

---

## ✅ 移行完了報告

**実施日**: 2025-11-07  
**追加実装**: 2025-11-09（属性別枠色）  
**結果**: 成功 🎉

### 修正されたファイル一覧

#### シーンファイル
1. **scenes/Card.tscn**
   - CardFrame.tscnからリネーム
   - ルートノードのoffsetを220×293に修正
   - スクリプト参照をcard.gdに変更
   - ノード名を"CardFrame" → "Card"に変更

#### スクリプトファイル
2. **scripts/card.gd**（完全新規作成）
   - CardFrame.tscn用に完全に書き直し
   - 4つの宝石バッジ対応
   - 属性別枠色実装（迷彩パターン）
   - マテリアル複製処理

3. **scripts/ui_components/card_ui_helper.gd**
   - CARDFRAME_WIDTH/HEIGHT = 220×293
   - BASE_SCALE = 1.318
   - `final_scale = scale * BASE_SCALE`

4. **scripts/ui_components/hand_display.gd**
   - CARD_WIDTH/HEIGHT を220×293に変更

5. **scripts/creatures/creature_card_3d_quad.gd**
   - VIEWPORT_WIDTH/HEIGHT = 220×293
   - 3D表示用の調整

#### バックアップファイル
- `backups/Card_backup_20251107.tscn` - 旧Card.tscn
- `backups/card_backup_20251107.gd` - 旧card.gd
- `backups/CardFrame_original_20251107.tscn` - 元のCardFrame.tscn
- `backups/card_frame_original_20251107.gd` - 元のcard_frame.gd

### 動作確認済み
- ✅ 手札表示（290×390で正常表示）
- ✅ タイル上のクリーチャーカード（3D表示も正常）
- ✅ 4つの宝石バッジが正しく配置
- ✅ カード画像が鮮明に表示
- ✅ テキストが読みやすい
- ✅ **属性別の枠色変更（迷彩パターン）** 🆕
  - 🔥 火属性クリーチャー: 赤系
  - 💧 水属性クリーチャー: 青系
  - 🌪️ 風属性クリーチャー: 緑系
  - 🪨 地属性クリーチャー: 茶色系
  - ⚪ 無属性クリーチャー・アイテム・スペル: グレー系

### 最終的な設定値
- **Card.tscnサイズ**: 220×293（CardFrame.tscn）
- **手札表示**: 220×293 × 1.318 = 290×390相当
- **3D表示**: 220×293（SubViewport）

### 3D表示の実装
**ファイル**: `scripts/creatures/creature_card_3d_quad.gd`

タイル上のクリーチャーカード3D表示も修正が必要でした：

```gdscript
# Card.tscnの実サイズ
const CARDFRAME_WIDTH = 220
const CARDFRAME_HEIGHT = 293

# 3D表示用のViewportサイズ
const VIEWPORT_WIDTH = CARDFRAME_WIDTH   # 220
const VIEWPORT_HEIGHT = CARDFRAME_HEIGHT  # 293

func _setup_card():
	viewport = SubViewport.new()
	viewport.size = Vector2i(VIEWPORT_WIDTH, VIEWPORT_HEIGHT)
	
	card_instance = CARD_SCENE.instantiate()
	card_instance.size = Vector2(VIEWPORT_WIDTH, VIEWPORT_HEIGHT)
	# scaleは設定しない（Viewportサイズで調整）
```

**注意**: 当初、高解像度化のために2倍のViewportサイズを試みましたが、カード内部のレイアウトが崩れたため、220×293のまま使用することになりました。

---

## 📊 実装のポイント

### サイズ拡大の仕組み
CardFrame.tscnは220×293で設計されているが、ゲーム内では290×390で表示する必要がある。

```gdscript
# _adjust_children_size()での処理
var original_width = 220.0   # CardFrame.tscnの設計サイズ
var original_height = 293.0
var target_width = 290.0     # ゲーム内表示サイズ
var target_height = 390.0

var scale_x = target_width / original_width    # 1.318
var scale_y = target_height / original_height  # 1.331

# 各要素の位置とサイズをこの倍率で拡大
```

### ノードアクセスの注意
新CardFrame.tscnは階層が深いため、`get_node_or_null()`で慎重にアクセス：

```gdscript
# ❌ 間違い（旧Card.tscn）
var cost_label = get_node_or_null("CostLabel")

# ✅ 正しい（新CardFrame.tscn）
var cost_label = get_node_or_null("CostBadge/CostCircle/CostLabel")
```

### 属性別の枠色実装（2025-11-09追加）

**実装ファイル**: `scripts/card.gd`の`set_element_color()`関数

#### 重要：マテリアルの複製
シェーダーマテリアルは**デフォルトで全カード間で共有される**ため、1枚のカードの色を変更すると全カードが同じ色になってしまう問題がありました。

**解決方法**: マテリアルを`duplicate()`して各カード専用にする

```gdscript
func set_element_color():
	var outer_frame = get_node_or_null("OuterFrame")
	if not outer_frame:
		return
	
	var element = card_data.get("element", "")
	var card_type = card_data.get("type", "")
	
	# アイテム、スペル、無属性は全てグレー
	var is_gray = (card_type == "item" or card_type == "spell" or element == "neutral" or element == "")
	
	# マテリアルを複製（重要！）
	var material = outer_frame.material as ShaderMaterial
	if material and material.shader:
		if not outer_frame.material.resource_local_to_scene:
			material = material.duplicate()  # ← これが必須
			outer_frame.material = material
		
		# 属性別に色を設定
		if is_gray:
			material.set_shader_parameter("color_dark", Color(0.3, 0.3, 0.3, 1))
			material.set_shader_parameter("color_mid", Color(0.5, 0.5, 0.5, 1))
			material.set_shader_parameter("color_light", Color(0.7, 0.7, 0.7, 1))
		else:
			match element:
				"fire":
					material.set_shader_parameter("color_dark", Color(0.6, 0.05, 0.05, 1))
					material.set_shader_parameter("color_mid", Color(0.8, 0.1, 0.1, 1))
					material.set_shader_parameter("color_light", Color(0.95, 0.2, 0.2, 1))
				# ... 他の属性も同様
```

### Card.tscnの追加修正が必要だった項目

#### 1. ルートノードのoffset修正
Card.tscnをリネームしただけでは不十分で、以下の修正も必要でした：

```gdscript
# scenes/Card.tscn
[node name="Card" type="Control"]
custom_minimum_size = Vector2(220, 293)
offset_right = 220.0  # ← 111.8から変更
offset_bottom = 293.0 # ← 148.9から変更
```

#### 2. UID重複警告の解決
移行後、以下の警告が出ました：
```
WARNING: UID duplicate detected between res://scenes/CardFrame.tscn and res://scenes/Card.tscn
```

**解決方法**: 
- `scenes/CardFrame.tscn` → `backups/CardFrame_original_20251107.tscn`に移動
- `scripts/card_frame.gd` → `backups/card_frame_original_20251107.gd`に移動
