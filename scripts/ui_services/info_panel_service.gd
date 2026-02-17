extends Node
class_name InfoPanelService

## コンポーネント参照
var _creature_info_panel_ui: CreatureInfoPanelUI = null
var _spell_info_panel_ui: SpellInfoPanelUI = null
var _item_info_panel_ui: ItemInfoPanelUI = null


## 初期化
func setup(creature_panel: CreatureInfoPanelUI, spell_panel: SpellInfoPanelUI, item_panel: ItemInfoPanelUI) -> void:
	_creature_info_panel_ui = creature_panel
	_spell_info_panel_ui = spell_panel
	_item_info_panel_ui = item_panel


## ============================================================================
## パネル表示メソッド
## ============================================================================

## カード情報パネルを表示（ナビゲーションに触らない）
## ドミニオの土地プレビュー等、表示の一部として使用する場合用
func show_card_info_only(card_data: Dictionary, tile_index: int = -1) -> void:
	var card_type = card_data.get("type", "")
	# 既存パネルを閉じる（ナビゲーションに触らない）
	if _creature_info_panel_ui and _creature_info_panel_ui.is_panel_visible():
		_creature_info_panel_ui.hide_panel(false)
	if _spell_info_panel_ui and _spell_info_panel_ui.is_panel_visible():
		_spell_info_panel_ui.hide_panel(false)
	if _item_info_panel_ui and _item_info_panel_ui.is_panel_visible():
		_item_info_panel_ui.hide_panel(false)
	# パネル表示（setup_buttons=false、×ボタンも設定しない）
	match card_type:
		"creature":
			if _creature_info_panel_ui:
				_creature_info_panel_ui.show_view_mode(card_data, tile_index, false)
		"spell":
			if _spell_info_panel_ui:
				_spell_info_panel_ui.show_view_mode(card_data, false)
		"item":
			if _item_info_panel_ui:
				_item_info_panel_ui.show_view_mode(card_data, false)


## カード種別に応じたインフォパネルを表示（選択モード）
func show_card_selection(card_data: Dictionary, hand_index: int = -1,
		confirmation_text: String = "", restriction_reason: String = "",
		selection_mode: String = "") -> void:
	var card_type = card_data.get("type", "")
	# 他のパネルを閉じる
	hide_all_info_panels(false)
	match card_type:
		"creature":
			if _creature_info_panel_ui:
				_creature_info_panel_ui.show_selection_mode(card_data, confirmation_text, restriction_reason)
		"spell":
			if _spell_info_panel_ui:
				_spell_info_panel_ui.show_spell_info(card_data, hand_index, restriction_reason, selection_mode, confirmation_text)
		"item":
			if _item_info_panel_ui:
				_item_info_panel_ui.show_item_info(card_data, hand_index, restriction_reason, selection_mode, confirmation_text)


## ============================================================================
## パネル管理メソッド
## ============================================================================

## 全てのインフォパネルを閉じる
func hide_all_info_panels(clear_buttons: bool = true) -> void:
	if _creature_info_panel_ui and _creature_info_panel_ui.is_panel_visible():
		_creature_info_panel_ui.hide_panel(clear_buttons)
	if _spell_info_panel_ui and _spell_info_panel_ui.is_panel_visible():
		_spell_info_panel_ui.hide_panel(clear_buttons)
	if _item_info_panel_ui and _item_info_panel_ui.is_panel_visible():
		_item_info_panel_ui.hide_panel(clear_buttons)


## いずれかのインフォパネルが表示中か
func is_any_info_panel_visible() -> bool:
	if _creature_info_panel_ui and _creature_info_panel_ui.is_panel_visible():
		return true
	if _spell_info_panel_ui and _spell_info_panel_ui.is_panel_visible():
		return true
	if _item_info_panel_ui and _item_info_panel_ui.is_panel_visible():
		return true
	return false


## パネル表示を更新（データ更新時）
func update_display(creature_data: Dictionary) -> void:
	if _creature_info_panel_ui and not creature_data.is_empty():
		_creature_info_panel_ui.update_display(creature_data)


## ============================================================================
## パネル参照アクセサ（UIコンポーネントからの正当な参照用）
## ============================================================================

## CreatureInfoPanelUI への参照を取得
func get_creature_info_panel() -> CreatureInfoPanelUI:
	return _creature_info_panel_ui


## SpellInfoPanelUI への参照を取得
func get_spell_info_panel() -> SpellInfoPanelUI:
	return _spell_info_panel_ui


## ItemInfoPanelUI への参照を取得
func get_item_info_panel() -> ItemInfoPanelUI:
	return _item_info_panel_ui
