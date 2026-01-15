# 制限解除スペルシステム
# リリース（2125）: プレイヤーのアイテム制限・召喚条件を解除
# ドキュメント: docs/design/spells/制限解除.md
class_name SpellRestriction


# ========================================
# 制限解除判定（静的メソッド）
# ========================================

## 制限解除呪いを持っているかチェック
## @param player: プレイヤーデータ（player_system.players[id]）
## @return bool: 制限解除呪いを持っているか
static func has_restriction_release(player: Dictionary) -> bool:
	var curse = player.get("curse", {})
	if curse.is_empty():
		return false
	# curse_typeがrestriction_release
	if curse.get("curse_type") == "restriction_release":
		return true
	# paramsにignore_item_restrictionまたはignore_summon_conditionがある
	var params = curse.get("params", {})
	return params.get("ignore_item_restriction", false) or params.get("ignore_summon_condition", false)


## アイテム制限が解除されているかチェック
## cannot_use（武器/防具/巻物/道具使用不可）を無視できるか
## @param player: プレイヤーデータ
## @return bool: アイテム制限が解除されているか
static func is_item_restriction_released(player: Dictionary) -> bool:
	var curse = player.get("curse", {})
	if curse.is_empty():
		return false
	# curse_typeがrestriction_release
	if curse.get("curse_type") == "restriction_release":
		return true
	# paramsにignore_item_restrictionがある
	var params = curse.get("params", {})
	return params.get("ignore_item_restriction", false)


## 召喚条件が解除されているかチェック
## cost_lands_required（土地条件）、cost_cards_sacrifice（カード犠牲）を無視できるか
## @param player: プレイヤーデータ
## @return bool: 召喚条件が解除されているか
static func is_summon_condition_released(player: Dictionary) -> bool:
	var curse = player.get("curse", {})
	if curse.is_empty():
		return false
	# curse_typeがrestriction_release
	if curse.get("curse_type") == "restriction_release":
		return true
	# paramsにignore_summon_conditionがある
	var params = curse.get("params", {})
	return params.get("ignore_summon_condition", false)
