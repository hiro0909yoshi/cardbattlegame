extends Node
class_name SkillSecret

## 密命スキル - カード表示制御
## キーワード: "密命"
## 効果: 敵プレイヤーから見ると真っ黒に表示される

## デバッグフラグをSpellPhaseHandlerから取得
static func _get_debug_disable_secret_cards(card: Node) -> bool:
	if not card.get_tree():
		return false
	
	var root = card.get_tree().root
	if not root:
		return false
	
	var main_scene = root.get_node_or_null("Main")
	if not main_scene:
		return false
	
	var game_flow_manager = main_scene.get_node_or_null("GameFlowManager")
	if not game_flow_manager:
		return false
	
	var spell_phase_handler = game_flow_manager.get_node_or_null("SpellPhaseHandler")
	if not spell_phase_handler:
		return false
	
	return spell_phase_handler.debug_disable_secret_cards

## 密命カードの表示を制御
## カードの表示状態を更新（所有者以外には真っ黒表示）
static func apply_secret_display(card: Node, card_data: Dictionary, viewer_id: int, owner_id: int):
	# 密命キーワードがない場合は通常表示
	if not card_data.get("keywords", []).has("密命"):
		card.show_card_front()
		return
	
	# デバッグモード: 密命カードを無効化
	if _get_debug_disable_secret_cards(card):
		card.show_card_front()
		return
	
	# 所有者以外が見ている場合は密命表示
	if viewer_id != owner_id and viewer_id != -1:
		# 将来的にここで専用シーン（裏面デザイン）をロード可能
		card.show_secret_back()
	else:
		card.show_card_front()
