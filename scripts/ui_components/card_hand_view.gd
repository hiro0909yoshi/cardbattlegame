# CardHandView - Lightweight card display for hand using cached textures
# Replaces Card.tscn instantiation with a single TextureRect + Button overlay
# Maintains the same external interface as Card.gd for compatibility
class_name CardHandView
extends Control

## Signals (same as card.gd)
signal card_button_pressed(card_index: int)
signal card_info_requested(card_data: Dictionary)

## Public properties (compatible with card.gd interface)
var card_data: Dictionary = {}
var card_index: int = -1
var is_selectable: bool = false
var is_selected: bool = false
var is_grayed_out: bool = false
var owner_player_id: int = 0
var viewing_player_id: int = 0
var restriction_reason: String = ""

## Internal references
var _texture_rect: TextureRect = null
var _button: Button = null
var _restriction_overlay: Control = null
var _secret_overlay: Control = null
var _selection_indicator: Control = null

var _card_selection_service_ref = null
var _card_selection_ui_ref = null
var _game_flow_manager_ref = null

var mouse_over: bool = false

## Constants
const CARD_WIDTH = 220
const CARD_HEIGHT = 293
const RESTRICTED_COLOR = Color(0.8, 0.3, 0.3, 0.7)
const SECRET_OVERLAY_COLOR = Color(0.1, 0.1, 0.1, 1.0)
const SELECTION_COLOR = Color(1.0, 1.0, 0.0, 0.5)

func _ready():
	_setup_ui()

## Initialize UI components
func _setup_ui():
	# Set control properties
	custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	size = Vector2(CARD_WIDTH, CARD_HEIGHT)

	# Create TextureRect for card texture
	_texture_rect = TextureRect.new()
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_texture_rect)

	# 入力を受け取る
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Create secret overlay (initially hidden)
	_secret_overlay = ColorRect.new()
	_secret_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_secret_overlay.color = SECRET_OVERLAY_COLOR
	_secret_overlay.visible = false
	_secret_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_secret_overlay)

	# Create selection indicator - border only (initially hidden)
	_selection_indicator = ReferenceRect.new()
	_selection_indicator.set_anchors_preset(Control.PRESET_FULL_RECT)
	_selection_indicator.border_color = Color.YELLOW
	_selection_indicator.border_width = 4.0
	_selection_indicator.editor_only = false
	_selection_indicator.visible = false
	_selection_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_selection_indicator)

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

## Load card data from ID (compatible with card.gd interface)
func load_card_data(card_id: int) -> void:
	if not CardLoader:
		push_error("[CardHandView] CardLoader not available")
		return

	card_data = CardLoader.get_card_by_id(card_id)
	if card_data.is_empty():
		push_error("[CardHandView] Failed to load card data for id %d" % card_id)
		return

	# Load and display cached texture
	await _load_texture_from_cache(card_id)

	# Update secret display if needed
	update_secret_display()

## Load dynamic creature data for battle updates (compatible with card.gd interface)
func load_dynamic_creature_data(data: Dictionary) -> void:
	if data.is_empty():
		return

	# Update card_data with dynamic data
	card_data.merge(data)

	# Invalidate cache and reload texture
	var card_id = card_data.get("id", 0)
	if card_id > 0:
		# Note: We could invalidate and re-render, but for now just keep current texture
		# In a full implementation, you'd invalidate CardTextureCache here
		pass

## Set system references (compatible with card.gd interface)
func set_references(css, csui, gfm) -> void:
	_card_selection_service_ref = css
	_card_selection_ui_ref = csui
	_game_flow_manager_ref = gfm

## Set restriction reason and show overlay
func set_restriction_reason(reason: String) -> void:
	restriction_reason = reason
	_update_restriction_display()

## Update secret card display overlay
func update_secret_display() -> void:
	if card_data.is_empty():
		return
	var keywords = card_data.get("keywords", [])
	var should_hide = keywords.has("密命") and viewing_player_id != owner_player_id and viewing_player_id != -1
	if _secret_overlay:
		_secret_overlay.visible = should_hide

## Select the card (for hand interaction)
func select_card() -> void:
	if is_selected:
		return
	is_selected = true
	z_index = 10
	_update_selection_display()

## Deselect the card
func deselect_card() -> void:
	if not is_selected:
		return
	is_selected = false
	z_index = 0
	_update_selection_display()

## Internal: Load texture from cache asynchronously
func _load_texture_from_cache(card_id: int) -> void:
	# Get the global CardTextureCache instance
	var cache = _get_card_texture_cache_instance()
	if not cache:
		push_error("[CardHandView] Failed to get CardTextureCache instance")
		return

	var texture = cache.get_card_texture_sync(card_id)
	if not texture:
		# Not in cache - render it asynchronously
		texture = await cache.prerender_card_async(card_id)

	if texture and _texture_rect:
		_texture_rect.texture = texture

## Internal: Get the global CardTextureCache instance (create if needed)
var _cache_instance = null
func _get_card_texture_cache_instance():
	if _cache_instance and is_instance_valid(_cache_instance):
		return _cache_instance

	# Try to find existing instance in scene tree
	var scene_root = get_tree().root
	for child in scene_root.get_children():
		if child is CardTextureCache:
			_cache_instance = child
			return _cache_instance

	# Create new instance if not found
	_cache_instance = CardTextureCache.new()
	_cache_instance.name = "CardTextureCache"
	scene_root.add_child(_cache_instance)
	return _cache_instance

## Internal: Update restriction overlay display
func _update_restriction_display() -> void:
	# 制限表示はmodulateで対応（オーバーレイ不要）
	pass

## Internal: Update selection indicator display
func _update_selection_display() -> void:
	if not _selection_indicator:
		return

	_selection_indicator.visible = is_selected

## 入力処理（元のcard.gdの_inputと同等のロジック）
func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return

	# 入力ロック中は無視
	if _game_flow_manager_ref and _game_flow_manager_ref.is_input_locked():
		return

	# 特殊フェーズ中はすべてインフォパネル表示のみ
	if _is_mystic_selection_phase() or _is_dominio_command_active() or _is_movement_selection_active():
		_show_info_panel_only()
		accept_event()
		return

	# グレーアウト時はインフォパネル表示のみ
	if is_grayed_out or not is_selectable:
		_show_info_panel_only()
		accept_event()
		return

	# 選択可能なカードの処理
	if not is_selected:
		_deselect_siblings()
		select_card()
		_try_auto_confirm()
	else:
		on_card_confirmed()
	accept_event()

## Internal: Deselect sibling cards
func _deselect_siblings() -> void:
	var parent = get_parent()
	if parent:
		for sibling in parent.get_children():
			if sibling != self and sibling.has_method("deselect_card"):
				sibling.deselect_card()

## Internal: Try to auto-confirm card if conditions met
func _try_auto_confirm() -> void:
	var card_type = card_data.get("type", "")
	var is_creature_with_panel = card_type == "creature" and GameSettings.use_creature_info_panel
	var is_spell_in_spell_phase = card_type == "spell" and _is_spell_phase_active()
	var is_item_phase = _is_item_phase_active()
	var is_handler_selection = _is_handler_card_selection_active()
	var is_sacrifice_mode = _is_sacrifice_mode_active()

	if is_creature_with_panel or is_spell_in_spell_phase or is_item_phase or is_handler_selection or is_sacrifice_mode:
		on_card_confirmed()

## Internal: Show info panel only (for grayed out or restricted cards)
func _show_info_panel_only() -> void:
	card_info_requested.emit(card_data)

## Internal: Card confirmation handler
func on_card_confirmed() -> void:
	if is_selectable and is_selected and card_index >= 0:
		card_button_pressed.emit(card_index)

## Internal: Phase checkers (same as card.gd)

func _is_mystic_selection_phase() -> bool:
	if _card_selection_service_ref and _card_selection_service_ref.has_method("is_selecting"):
		return _card_selection_service_ref.is_selecting()
	return false

func _is_dominio_command_active() -> bool:
	# Check via card_selection_service if available
	if _card_selection_service_ref:
		# Dominio is a special filter mode
		return _card_selection_service_ref.card_selection_filter == "dominio"
	return false

func _is_movement_selection_active() -> bool:
	# Check via card_selection_service if available
	if _card_selection_service_ref:
		return _card_selection_service_ref.card_selection_filter == "movement"
	return false

func _is_spell_phase_active() -> bool:
	if _card_selection_service_ref and _card_selection_service_ref.card_selection_filter == "spell":
		return true
	return false

func _is_item_phase_active() -> bool:
	if _card_selection_service_ref and _card_selection_service_ref.card_selection_filter in ["item", "item_or_assist"]:
		return true
	return false

func _is_handler_card_selection_active() -> bool:
	if _card_selection_service_ref:
		return _card_selection_service_ref.card_selection_filter in ["mystic", "sacrifice"]
	return false

func _is_sacrifice_mode_active() -> bool:
	if _card_selection_ui_ref and _card_selection_ui_ref.has_method("get_selection_mode"):
		return _card_selection_ui_ref.get_selection_mode() in ["sacrifice", "discard"]
	return false

## Internal: Handle mouse entering card area
func _on_mouse_entered() -> void:
	mouse_over = true
	z_index = 5

## Internal: Handle mouse exiting card area
func _on_mouse_exited() -> void:
	mouse_over = false
	if not is_selected:
		z_index = 0
