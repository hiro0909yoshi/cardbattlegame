extends Control
# カード表示・操作・選択スクリプト - CardFrame.tscn対応版
const GC = preload("res://scripts/game_constants.gd")
# 更新日: 2025-11-07


# Phase 10-B: Signal（アクション通知）
signal card_button_pressed(card_index: int)
signal card_info_requested(card_data: Dictionary)

# 静的変数：現在選択中のカード
static var currently_selected_card: Node = null

var is_dragging = false
var card_data = {}
var mouse_over = false
var card_index = -1
var is_selectable = false
var is_selected = false
var is_grayed_out = false  # グレーアウト状態（選択不可だがインフォパネルは表示可能）
var restriction_overlay: Control = null  # 制限理由表示用（禁止マーク描画）
var restriction_e_label: Label = null  # EP不足用ラベル（E）
var restriction_reason: String = ""  # 制限理由（"ep", "restriction", ""）
var original_position: Vector2
var original_size: Vector2
var original_scale: Vector2 = Vector2(1.0, 1.0)

# Phase 10-B: 参照（読み取り専用、hand_display から注入）
var _card_selection_service_ref = null
var _card_selection_ui_ref = null
var _game_flow_manager_ref = null

# 密命カード用の変数
var owner_player_id: int = -1      # このカードの所有者
var viewing_player_id: int = -1    # 現在表示を見ているプレイヤー
var is_showing_secret_back: bool = false  # 裏面（真っ黒）表示中か

# CardFrame.tscnのサイズ定義
const CARDFRAME_WIDTH = 220.0   # CardFrame.tscnの設計サイズ
const CARDFRAME_HEIGHT = 293.0
const GAME_CARD_WIDTH = 290.0   # ゲーム内表示サイズ
const GAME_CARD_HEIGHT = 390.0

## 参照を設定（hand_display から呼ばれる）
func set_references(css, csui, gfm) -> void:
	_card_selection_service_ref = css
	_card_selection_ui_ref = csui
	_game_flow_manager_ref = gfm

func _ready():
	# 元のサイズを記録
	original_size = size

	# マウスイベントを接続
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	# マウスフィルターを設定（重要！）
	mouse_filter = Control.MOUSE_FILTER_STOP

	# サイズ変更時に子要素を調整
	resized.connect(_on_resized)
	adjust_children_size()

	
	# 制限理由ラベルを作成
	_create_restriction_label()

# サイズ変更時の処理
func _on_resized():
	adjust_children_size()

# 子要素のサイズを親に合わせて調整（CardFrame.tscn対応）
# 注：スケールはhand_display.gdで設定されるため、ここでは何もしない
func adjust_children_size():
	# フォントサイズはシーンファイルのデフォルト値を使用
	# 必要に応じて将来的に調整可能
	pass


# 制限理由表示を作成（禁止マーク＋Eラベル）
func _create_restriction_label():
	if restriction_overlay:
		return

	# 「E」ラベル（カード中央）
	var e_container = Control.new()
	e_container.name = "RestrictionEContainer"
	e_container.set_anchors_preset(Control.PRESET_CENTER)
	e_container.size = Vector2(150, 150)
	e_container.position = Vector2(-75, -75)
	e_container.z_index = 10
	e_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(e_container)

	restriction_e_label = Label.new()
	restriction_e_label.name = "RestrictionELabel"
	restriction_e_label.text = "E"
	restriction_e_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	restriction_e_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	restriction_e_label.add_theme_font_size_override("font_size", 150)
	restriction_e_label.add_theme_color_override("font_color", GC.COLOR_WHITE)
	restriction_e_label.add_theme_constant_override("outline_size", 8)
	restriction_e_label.add_theme_color_override("font_outline_color", GC.COLOR_BLACK)
	restriction_e_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	restriction_e_label.visible = false
	e_container.add_child(restriction_e_label)

	# 禁止マーク（カード中央やや下、コード描画）
	var overlay_container = Control.new()
	overlay_container.name = "RestrictionOverlayContainer"
	overlay_container.set_anchors_preset(Control.PRESET_CENTER)
	overlay_container.size = Vector2(150, 150)
	overlay_container.position = Vector2(-75, -35)
	overlay_container.z_index = 11
	overlay_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay_container)

	restriction_overlay = _ProhibitionMark.new()
	restriction_overlay.name = "RestrictionOverlay"
	restriction_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	restriction_overlay.visible = false
	restriction_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_container.add_child(restriction_overlay)


# 制限理由を設定
# reason: "ep"（EP不足/土地条件）, "restriction"（配置制限/刻印等）, ""（制限なし）
func set_restriction_reason(reason: String):
	restriction_reason = reason
	_update_restriction_display()


# 制限理由の表示を更新
func _update_restriction_display():
	if not restriction_overlay:
		_create_restriction_label()

	match restriction_reason:
		"ep":
			# EP不足 / 土地条件未達 - 「E」と禁止マークを重ねて表示
			restriction_e_label.visible = true
			restriction_overlay.visible = true
		"restriction":
			# 配置制限 / 禁呪刻印等 - 禁止マークのみ
			restriction_e_label.visible = false
			restriction_overlay.visible = true
		_:
			# 制限なし
			restriction_e_label.visible = false
			restriction_overlay.visible = false

func _on_mouse_entered():
	mouse_over = true
	if not is_dragging and not is_selectable:
		z_index = 5

func _on_mouse_exited():
	mouse_over = false
	if not is_dragging and not is_selectable:
		z_index = 0

func load_card_data(card_id):
	# CardLoaderを使用
	if CardLoader:
		card_data = CardLoader.get_card_by_id(card_id)
		if not card_data.is_empty():
			update_label()
			set_element_color()
			load_creature_image(card_id)
			adjust_children_size()
			_update_card_type_symbol()  # 記号表示を追加
		return
	
	print("[Card] ERROR: CardLoaderが見つかりません")

# クリーチャーの動的データを読み込む（バトル中の変更を反映）
func load_dynamic_creature_data(data: Dictionary):
	if data.is_empty():
		return
	
	# 渡されたデータをそのまま使用（バトル中の変更が含まれる）
	card_data = data.duplicate()
	
	# 表示を更新
	update_dynamic_stats()
	set_element_color()
	load_creature_image(data.get("id", 0))
	adjust_children_size()

# 基本ラベル更新（静的データ）
func update_label():
	# コスト
	var cost_label = get_node_or_null("CostBadge/CostCircle/CostLabel")
	if cost_label:
		var cost = card_data.get("cost", 1)
		if typeof(cost) == TYPE_DICTIONARY and cost.has("ep"):
			cost = cost.ep
		cost_label.text = str(cost)
		cost_label.add_theme_color_override("font_color", Color.WHITE)
	
	# 名前
	var name_label = get_node_or_null("NameBanner/NameLabel")
	if name_label:
		name_label.text = card_data.get("name", "???")
		name_label.add_theme_color_override("font_color", Color.WHITE)
	
	# 攻撃力（AP）
	var left_stat_label = get_node_or_null("LeftStatBadge/LeftStatCircle/LeftStatLabel")
	if left_stat_label:
		var ap = card_data.get("ap", 0)
		left_stat_label.text = str(ap)
		left_stat_label.add_theme_color_override("font_color", Color.WHITE)
	
	# 最大HP
	var right_stat_label = get_node_or_null("RightStatBadge/RightStatCircle/RightStatLabel")
	if right_stat_label:
		var hp = card_data.get("hp", 0)
		right_stat_label.text = str(hp)
		right_stat_label.add_theme_color_override("font_color", Color.WHITE)
	
	# 現在HP（初期状態では最大HPと同じ）
	var current_hp_label = get_node_or_null("CurrentHPBadge/CurrentHPCircle/CurrentHPLabel")
	if current_hp_label:
		var hp = card_data.get("hp", 0)
		current_hp_label.text = str(hp)
		current_hp_label.add_theme_color_override("font_color", Color.WHITE)
	
	# 説明文
	var desc_label = get_node_or_null("DescriptionBox/DescriptionLabel")
	if desc_label:
		var ability_text = card_data.get("ability", "")
		var element = card_data.get("element", "")
		
		if ability_text.is_empty():
			ability_text = element + "属性"
		
		desc_label.text = ability_text
		desc_label.add_theme_color_override("font_color", Color(0.25, 0.2, 0.15))

# 動的ステータスを更新（MHP/ST増加を反映）
func update_dynamic_stats():
	# コスト
	var cost_label = get_node_or_null("CostBadge/CostCircle/CostLabel")
	if cost_label:
		var cost = card_data.get("cost", 1)
		if typeof(cost) == TYPE_DICTIONARY and cost.has("ep"):
			cost = cost.ep
		cost_label.text = str(cost)
		cost_label.add_theme_color_override("font_color", Color.WHITE)
	
	# 名前
	var name_label = get_node_or_null("NameBanner/NameLabel")
	if name_label:
		name_label.text = card_data.get("name", "???")
		name_label.add_theme_color_override("font_color", Color.WHITE)
	
	# 攻撃力（AP）- 基礎値 + 増加分
	var left_stat_label = get_node_or_null("LeftStatBadge/LeftStatCircle/LeftStatLabel")
	if left_stat_label:
		var base_ap = card_data.get("ap", 0)
		var base_up_ap = card_data.get("base_up_ap", 0)
		var total_ap = base_ap + base_up_ap
		left_stat_label.text = str(total_ap)
		
		# 変化がある場合は色を変える
		if base_up_ap > 0:
			left_stat_label.add_theme_color_override("font_color", Color.GREEN)
		elif base_up_ap < 0:
			left_stat_label.add_theme_color_override("font_color", Color.RED)
		else:
			left_stat_label.add_theme_color_override("font_color", Color.WHITE)
	
	# 最大HP - 基礎値 + 増加分
	var right_stat_label = get_node_or_null("RightStatBadge/RightStatCircle/RightStatLabel")
	if right_stat_label:
		var base_hp = card_data.get("hp", 0)
		var base_up_hp = card_data.get("base_up_hp", 0)
		var total_hp = base_hp + base_up_hp
		right_stat_label.text = str(total_hp)
		
		# 変化がある場合は色を変える
		if base_up_hp > 0:
			right_stat_label.add_theme_color_override("font_color", Color.GREEN)
		elif base_up_hp < 0:
			right_stat_label.add_theme_color_override("font_color", Color.RED)
		else:
			right_stat_label.add_theme_color_override("font_color", Color.WHITE)
	
	# 現在HP（バトル中の動的データ）
	var current_hp_label = get_node_or_null("CurrentHPBadge/CurrentHPCircle/CurrentHPLabel")
	if current_hp_label:
		var current_hp = card_data.get("current_hp", card_data.get("hp", 0))
		current_hp_label.text = str(current_hp)
		
		# HPが減っている場合は色を変える
		var max_hp = card_data.get("hp", 0) + card_data.get("base_up_hp", 0)
		if current_hp < max_hp:
			current_hp_label.add_theme_color_override("font_color", Color.YELLOW)
		else:
			current_hp_label.add_theme_color_override("font_color", Color.WHITE)
	
	# 説明文
	var desc_label = get_node_or_null("DescriptionBox/DescriptionLabel")
	if desc_label:
		var ability_text = card_data.get("ability", "")
		var element = card_data.get("element", "")
		
		# アイテム情報を追加
		var items = card_data.get("items", [])
		if items.size() > 0:
			var item_names = []
			for item in items:
				item_names.append(item.get("name", "???"))
			ability_text += "\n[装備: " + ", ".join(item_names) + "]"
		
		# 永続効果を表示
		var permanent_effects = card_data.get("permanent_effects", [])
		if permanent_effects.size() > 0:
			ability_text += "\n[永続: " + str(permanent_effects.size()) + "個]"
		
		# 一時効果を表示
		var temporary_effects = card_data.get("temporary_effects", [])
		if temporary_effects.size() > 0:
			ability_text += "\n[一時: " + str(temporary_effects.size()) + "個]"
		
		if ability_text.is_empty():
			ability_text = element + "属性"
		
		desc_label.text = ability_text
		desc_label.add_theme_color_override("font_color", Color(0.25, 0.2, 0.15))

# 属性色を設定（OuterFrameの背景色とシェーダーを変更）
func set_element_color():
	var outer_frame = get_node_or_null("OuterFrame")
	if not outer_frame:
		return
	
	var element = card_data.get("element", "")
	var card_type = card_data.get("type", "")
	
	# アイテム、スペル、無属性クリーチャーは全てグレー
	var is_gray = (card_type == "item" or card_type == "spell" or element == "neutral" or element == "")
	
	# StyleBoxFlatの背景色を変更
	var style = outer_frame.get_theme_stylebox("panel")
	if style and style is StyleBoxFlat:
		if is_gray:
			style.bg_color = Color(0.4, 0.4, 0.4)  # グレー
		else:
			match element:
				"fire":
					style.bg_color = Color(0.8, 0.1, 0.1)  # 赤
				"water":
					style.bg_color = Color(0.1, 0.3, 0.8)  # 青
				"wind":
					style.bg_color = Color(0.1, 0.7, 0.3)  # 緑
				"earth":
					style.bg_color = Color(0.6, 0.4, 0.1)  # 茶色
				_:
					style.bg_color = Color(0.4, 0.4, 0.4)  # グレー（フォールバック）
	
	# シェーダーマテリアルの色を変更
	# 重要：マテリアルを複製して個別に設定（共有を避ける）
	var shader_mat = outer_frame.material as ShaderMaterial
	if shader_mat and shader_mat.shader:
		# マテリアルを複製（このカード専用にする）
		if not outer_frame.material.resource_local_to_scene:
			shader_mat = shader_mat.duplicate()
			outer_frame.material = shader_mat
		if is_gray:
			# グレー系の迷彩パターン（アイテム・スペル・無属性）
			shader_mat.set_shader_parameter("color_dark", Color(0.3, 0.3, 0.3, 1))
			shader_mat.set_shader_parameter("color_mid", Color(0.5, 0.5, 0.5, 1))
			shader_mat.set_shader_parameter("color_light", Color(0.7, 0.7, 0.7, 1))
		else:
			match element:
				"fire":
					# 赤系の迷彩パターン
					shader_mat.set_shader_parameter("color_dark", Color(0.6, 0.05, 0.05, 1))
					shader_mat.set_shader_parameter("color_mid", Color(0.8, 0.1, 0.1, 1))
					shader_mat.set_shader_parameter("color_light", Color(0.95, 0.2, 0.2, 1))
				"water":
					# 青系の迷彩パターン
					shader_mat.set_shader_parameter("color_dark", Color(0.05, 0.2, 0.6, 1))
					shader_mat.set_shader_parameter("color_mid", Color(0.1, 0.4, 0.8, 1))
					shader_mat.set_shader_parameter("color_light", Color(0.2, 0.6, 0.95, 1))
				"wind":
					# 緑系の迷彩パターン
					shader_mat.set_shader_parameter("color_dark", Color(0.05, 0.5, 0.1, 1))
					shader_mat.set_shader_parameter("color_mid", Color(0.1, 0.7, 0.2, 1))
					shader_mat.set_shader_parameter("color_light", Color(0.2, 0.9, 0.3, 1))
				"earth":
					# 茶色系の迷彩パターン
					shader_mat.set_shader_parameter("color_dark", Color(0.5, 0.3, 0.05, 1))
					shader_mat.set_shader_parameter("color_mid", Color(0.7, 0.45, 0.1, 1))
					shader_mat.set_shader_parameter("color_light", Color(0.9, 0.6, 0.2, 1))
				_:
					# フォールバック：グレー
					shader_mat.set_shader_parameter("color_dark", Color(0.3, 0.3, 0.3, 1))
					shader_mat.set_shader_parameter("color_mid", Color(0.5, 0.5, 0.5, 1))
					shader_mat.set_shader_parameter("color_light", Color(0.7, 0.7, 0.7, 1))

# クリーチャー画像を読み込む
func load_creature_image(card_id: int):
	var card_art = get_node_or_null("CardArtContainer/CardArt")
	if not card_art:
		return

	# カードタイプと属性からパスを構築
	var image_path = _get_card_image_path(card_id)

	# 画像ファイルが存在するか確認（Web版では.pck内リソースはFileAccessで検出不可）
	if ResourceLoader.exists(image_path):
		var texture = load(image_path)
		if texture:
			card_art.texture = texture
	else:
		# 画像がない場合はデフォルト表示（属性に応じた色）
		var placeholder = Image.create(199, 185, false, Image.FORMAT_RGBA8)

		# 属性に応じた色で塗りつぶし
		var element = card_data.get("element", "")
		var fill_color = Color(0.5, 0.5, 0.5)  # デフォルトはグレー

		match element:
			"fire":
				fill_color = Color(0.9, 0.4, 0.3)
			"water":
				fill_color = Color(0.4, 0.6, 0.9)
			"wind":
				fill_color = Color(0.4, 0.8, 0.5)
			"earth":
				fill_color = Color(0.8, 0.6, 0.4)

		placeholder.fill(fill_color)
		card_art.texture = ImageTexture.create_from_image(placeholder)


## カードIDからフォルダ分けされた画像パスを返す
func _get_card_image_path(card_id: int) -> String:
	var card_type = card_data.get("type", "creature")

	match card_type:
		"spell":
			return "res://assets/images/spells/" + str(card_id) + ".png"
		"item":
			return "res://assets/images/items/" + str(card_id) + ".png"
		_:
			# クリーチャー: 属性別フォルダ
			var element = card_data.get("element", "neutral")
			if element.is_empty():
				element = "neutral"
			return "res://assets/images/creatures/" + element + "/" + str(card_id) + ".png"

# カードを選択可能にする
func set_selectable(selectable: bool, index: int = -1):
	is_selectable = selectable
	card_index = index
	
	# 全ての子要素のマウスフィルターを設定
	for child in get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if not selectable:
		# 選択モード解除時は元に戻す
		if is_selected:
			deselect_card()

# カードを選択状態にする（1段階目）
func select_card():
	if is_selected:
		return
	
	# 他のカードが選択中なら解除
	if currently_selected_card and currently_selected_card != self:
		currently_selected_card.deselect_card()
	
	currently_selected_card = self
	is_selected = true
	original_position = position
	original_scale = scale  # 元のスケールを保存
	
	# カードを大きく表示
	z_index = 100
	
	# アニメーション（安全に実行）
	if get_tree():
		var tween = get_tree().create_tween()
		if tween:
			tween.set_trans(Tween.TRANS_ELASTIC)
			tween.set_ease(Tween.EASE_OUT)
			
			# 上に移動して1.06倍に拡大（元のスケールを基準に）
			var target_scale = original_scale * 1.06
			tween.parallel().tween_property(self, "position", 
				Vector2(position.x , position.y - 5), 0.3)
			tween.parallel().tween_property(self, "scale", 
				target_scale, 0.3)

# カードの選択を解除
func deselect_card():
	if not is_selected:
		return
	
	if currently_selected_card == self:
		currently_selected_card = null
	
	is_selected = false
	z_index = 0
	
	# 元の位置とスケールに戻す
	position = original_position
	scale = original_scale
	
	# グレーアウト状態または制限理由がある場合はグレー色を維持
	if is_grayed_out or restriction_reason != "":
		modulate = Color(0.5, 0.5, 0.5, 1.0)
	else:
		modulate = Color(1.0, 1.0, 1.0)

# スペルフェーズがアクティブかどうかを判定
func _is_spell_phase_active() -> bool:
	if _card_selection_service_ref and _card_selection_service_ref.card_selection_filter == "spell":
		return true
	return false

# アイテムフェーズがアクティブかどうかを判定
func _is_item_phase_active() -> bool:
	if _card_selection_service_ref and _card_selection_service_ref.card_selection_filter in ["item", "item_or_assist"]:
		return true
	return false

# 犠牲選択モードまたは捨て札モードがアクティブかどうかを判定
func _is_sacrifice_mode_active() -> bool:
	if _card_selection_ui_ref:
		return _card_selection_ui_ref.selection_mode in ["sacrifice", "discard"]
	return false

# カード選択ハンドラーによる手札選択がアクティブかどうかを判定
# （敵手札選択、デッキカード選択、カード変換選択など）
func _is_handler_card_selection_active() -> bool:
	if not _card_selection_service_ref:
		return false
	var filter = _card_selection_service_ref.card_selection_filter
	# destroy_*, item_or_spell など card_selection_handler が使うフィルターをチェック
	if filter.begins_with("destroy_") or filter == "item_or_spell":
		return true
	return false

# ドミニオコマンド中かどうか
func _is_dominio_command_active() -> bool:
	if not _game_flow_manager_ref or not _game_flow_manager_ref.dominio_command_handler:
		return false
	var dominio = _game_flow_manager_ref.dominio_command_handler
	# 交換モード中はカード選択UIが表示されるため、通常のカード操作を許可する
	if dominio.current_state == dominio.State.SELECTING_SWAP:
		return false
	# アイテムフェーズ中は通常のカード操作を許可する（移動侵略時のアイテム選択）
	if _game_flow_manager_ref.item_phase_handler and _game_flow_manager_ref.item_phase_handler.is_item_phase_active():
		return false
	return dominio.current_state != dominio.State.CLOSED


# 移動中の方向選択・分岐選択中かどうか
func _is_movement_selection_active() -> bool:
	if not _game_flow_manager_ref or not _game_flow_manager_ref.board_system_3d:
		return false
	return _game_flow_manager_ref.board_system_3d.is_movement_selection_active()


# アルカナアーツ効果適用中のカード選択（ルーンアデプト等）は許可する
func _is_mystic_selection_phase() -> bool:
	if not _game_flow_manager_ref:
		return false

	if not _game_flow_manager_ref.spell_phase_handler or not _game_flow_manager_ref.spell_phase_handler.spell_mystic_arts:
		return false

	var mystic_arts = _game_flow_manager_ref.spell_phase_handler.spell_mystic_arts

	# アルカナアーツフェーズがアクティブでない場合は通常処理
	if not mystic_arts.is_active():
		return false

	# アルカナアーツ効果適用中のカード選択は許可（filter が special な値の場合）
	var filter = ""
	if _card_selection_service_ref:
		filter = _card_selection_service_ref.card_selection_filter
	if filter in ["single_target_spell", "spell_borrow"]:
		return false  # 効果適用中のカード選択は許可

	# CardSelectionHandlerがアクティブなら許可
	var handler = _game_flow_manager_ref.spell_phase_handler.card_selection_handler
	if handler and handler.is_selecting():
		return false

	# アルカナアーツ選択フェーズ中（クリーチャー/アルカナアーツ選択中）
	return true

# カードが決定された時の処理（2段階目）
func on_card_confirmed():
	if is_selectable and is_selected and card_index >= 0:
		card_button_pressed.emit(card_index)

# グレーアウト時・特殊フェーズ中のインフォパネル表示（閲覧専用）
func _show_info_panel_only():
	# 選択中のカードがあれば選択解除
	if currently_selected_card and currently_selected_card != self:
		currently_selected_card.deselect_card()
	# Signal で通知（UIManager が処理）
	card_info_requested.emit(card_data)

# GameFlowManagerを取得
func _get_game_flow_manager():
	return _game_flow_manager_ref
	
# 通常の入力処理とカード選択処理
func _input(event):


	# 入力ロック中は無視
	var game_flow_manager = _game_flow_manager_ref
	if game_flow_manager and game_flow_manager.is_input_locked():
		#print("[Card] 入力ロック中のためスキップ")
		return
	
	# アルカナアーツ選択フェーズ中はインフォパネル表示のみ許可
	if _is_mystic_selection_phase() and mouse_over and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_show_info_panel_only()
			get_viewport().set_input_as_handled()
		return
	
	# ドミニオコマンド中はインフォパネル表示のみ許可
	if _is_dominio_command_active() and mouse_over and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_show_info_panel_only()
			get_viewport().set_input_as_handled()
			return
	
	# 方向選択・分岐選択中はインフォパネル表示のみ許可（mouse_overが効かないためRect判定）
	if _is_movement_selection_active() and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if get_global_rect().has_point(event.position):
				_show_info_panel_only()
				get_viewport().set_input_as_handled()
				return
	
	# カード選択モード時のクリック処理（グレーアウト時もインフォパネル表示のみ許可）
	if (is_selectable or is_grayed_out) and mouse_over and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# グレーアウト時はインフォパネル表示のみ（使用不可）
			if is_grayed_out:
				# 他のカードの選択状態は維持したまま、インフォパネルだけ表示
				_show_info_panel_only()
				get_viewport().set_input_as_handled()
				return
			
			if not is_selected:
				# 1回目のクリック
				# 他のカードの選択を解除（親ノードの全子要素をチェック）
				var parent = get_parent()
				if parent:
					for sibling in parent.get_children():
						if sibling != self and sibling.has_method("deselect_card"):
							sibling.deselect_card()
				
				# クリーチャーカード（情報パネルON）、スペルカード（スペルフェーズ中）、
				# アイテムフェーズ中のカード、犠牲選択モードは即決定
				var card_type = card_data.get("type", "")
				var is_creature_with_panel = card_type == "creature" and GameSettings.use_creature_info_panel
				var is_spell_in_spell_phase = card_type == "spell" and _is_spell_phase_active()
				var is_item_phase = _is_item_phase_active()
				var is_handler_selection = _is_handler_card_selection_active()
				var is_sacrifice_mode = _is_sacrifice_mode_active()
				
				if is_creature_with_panel or is_spell_in_spell_phase or is_item_phase or is_handler_selection or is_sacrifice_mode:
					select_card()
					on_card_confirmed()
				else:
					select_card()
			else:
				# 2回目のクリック：決定
				on_card_confirmed()
			
			get_viewport().set_input_as_handled()
			return
	
	# 選択モード中はドラッグ無効
	if is_selectable:
		return
	
	# ドラッグ中の移動処理
	if is_dragging and event is InputEventMouseMotion:
		global_position = get_global_mouse_position() - size / 2
		return
	
	# マウスボタンを離した時の処理
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if is_dragging:
				is_dragging = false
				z_index = 0
				return

# ========================================
# 密命カードシステム
# ========================================

# カードデータを設定（所有者情報も含む）
func set_card_data_with_owner(data: Dictionary, owner_id: int):
	card_data = data
	owner_player_id = owner_id
	update_secret_display()

# 表示を見ているプレイヤーを設定
func set_viewing_player(viewer_id: int):
	viewing_player_id = viewer_id
	update_secret_display()

# 表示を更新（密命判定）
func update_secret_display():
	SkillSecret.apply_secret_display(self, card_data, viewing_player_id, owner_player_id)

# 裏面表示に切り替え（表面の子ノードを隠し、裏面を表示）
func show_secret_back():
	if is_showing_secret_back:
		return

	is_showing_secret_back = true

	# 表面の子ノードを全て非表示にする
	for child in get_children():
		if child.name != "CardBackOverlay":
			child.visible = false

	# 裏面を表示
	var card_back = get_node_or_null("CardBackOverlay")
	if card_back:
		card_back.visible = true
		move_child(card_back, get_child_count() - 1)

# 通常表示に切り替え（表面の子ノードを復帰し、裏面を非表示）
func show_card_front():
	if not is_showing_secret_back:
		return

	is_showing_secret_back = false

	# 裏面を非表示
	var card_back = get_node_or_null("CardBackOverlay")
	if card_back:
		card_back.visible = false

	# 表面の子ノードを全て表示に戻す
	for child in get_children():
		if child.name != "CardBackOverlay":
			child.visible = true

# ========================================
# カードタイプ記号表示システム
# ========================================

# カードタイプに応じた記号を表示
func _update_card_type_symbol():
	# 既存の記号ラベルを削除
	var existing_label = get_node_or_null("CardTypeSymbol")
	if existing_label:
		existing_label.queue_free()
	
	if card_data.is_empty():
		return
	
	# 記号と色を取得
	var symbol_info = _get_card_type_symbol_info()
	if symbol_info.symbol.is_empty():
		return
	
	# 記号ラベルを作成
	var symbol_label = Label.new()
	symbol_label.name = "CardTypeSymbol"
	symbol_label.text = symbol_info.symbol
	symbol_label.add_theme_font_size_override("font_size", 24)
	symbol_label.add_theme_color_override("font_color", symbol_info.color)
	
	# 左上に配置
	symbol_label.position = Vector2(8, 5)
	symbol_label.z_index = 10
	symbol_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	add_child(symbol_label)

# カードタイプに応じた記号と色を取得
func _get_card_type_symbol_info() -> Dictionary:
	var card_type = card_data.get("type", "")
	
	match card_type:
		"creature":
			# クリーチャー: ● 属性色
			var element = card_data.get("element", "neutral")
			return {"symbol": "●", "color": _get_element_color(element)}
		
		"item":
			# アイテム: ▲ 種類色
			var item_type = card_data.get("item_type", "")
			return {"symbol": "▲", "color": _get_item_type_color(item_type)}
		
		"spell":
			# スペル: ◆ スペルタイプ色
			var spell_type = card_data.get("spell_type", "")
			return {"symbol": "◆", "color": _get_spell_type_color(spell_type)}
		
		_:
			return {"symbol": "", "color": Color.WHITE}

# 属性の色を取得
func _get_element_color(element: String) -> Color:
	match element:
		"fire":
			return Color(1.0, 0.27, 0.27)  # 赤
		"water":
			return Color(0.27, 0.53, 1.0)  # 青
		"earth":
			return Color(0.53, 0.8, 0.27)  # 緑
		"wind":
			return Color(1.0, 0.8, 0.27)  # 黄
		"neutral":
			return Color(0.67, 0.67, 0.67)  # グレー
		_:
			return Color.WHITE

# アイテム種類の色を取得
func _get_item_type_color(item_type: String) -> Color:
	match item_type:
		"武器":
			return Color(1.0, 0.4, 0.27)  # オレンジ
		"防具":
			return Color(0.27, 0.4, 1.0)  # 青
		"アクセサリ":
			return Color(0.27, 0.8, 0.53)  # 緑
		"巻物":
			return Color(0.8, 0.27, 1.0)  # 紫
		_:
			return Color.WHITE

# スペルタイプの色を取得
func _get_spell_type_color(spell_type: String) -> Color:
	match spell_type:
		"単体対象":
			return Color(1.0, 0.27, 0.27)  # 赤
		"単体特殊能力付与":
			return Color(0.27, 1.0, 0.53)  # 緑
		"複数対象":
			return Color(1.0, 0.67, 0.27)  # オレンジ
		"複数特殊能力付与":
			return Color(0.27, 0.8, 1.0)  # 水色
		"世界呪":
			return Color(0.67, 0.27, 1.0)  # 紫
		_:
			return Color.WHITE


## 禁止マーク描画用内部クラス（絵文字はWeb版で文字化けするためコード描画）
class _ProhibitionMark extends Control:
	func _draw():
		var center = size / 2.0
		var radius = min(size.x, size.y) * 0.4
		var color = GC.COLOR_RESTRICTION_ICON
		var line_width = radius * 0.2

		# 赤い丸
		draw_arc(center, radius, 0, TAU, 64, color, line_width, true)
		# 斜め線（左上→右下）
		var offset = radius * 0.707  # cos(45°)
		draw_line(
			center + Vector2(-offset, -offset),
			center + Vector2(offset, offset),
			color, line_width, true
		)
