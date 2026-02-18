## プレイヤー情報パネル更新サービス
## PlayerInfoPanel への委譲を一元管理（描画更新のみ）
extends Node
class_name PlayerInfoService

var _player_info_panel: PlayerInfoPanel = null


func setup(player_info_panel: PlayerInfoPanel) -> void:
	_player_info_panel = player_info_panel


func update_panels() -> void:
	if _player_info_panel and _player_info_panel.has_method("update_all_panels"):
		_player_info_panel.update_all_panels()
