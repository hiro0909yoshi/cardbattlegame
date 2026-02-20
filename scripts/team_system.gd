extends Node
class_name TeamSystem

## チーム管理システム — 敵味方判定・勝利判定の一元化
## Source of Truth: _player_team_map がチーム所属の唯一の真実

## チームデータ（内部クラス）
class TeamData:
	var team_id: int = -1
	var members: Array[int] = []  # 固定配列（ゲーム中に変更しない）

	func has_member(player_id: int) -> bool:
		return player_id in members

# === 内部状態 ===
var _teams: Array = []  # Array[TeamData]
var _player_team_map: Dictionary = {}  # player_id → TeamData（唯一の真実）
var _player_system = null  # PlayerSystem参照

# ============================================
# セットアップ
# ============================================

## チームをセットアップ
## teams_array: [[0, 2], [1]] 形式の二重配列
func setup_teams(teams_array: Array, player_system) -> void:
	_player_system = player_system
	_teams.clear()
	_player_team_map.clear()

	for team_index in range(teams_array.size()):
		var team = TeamData.new()
		team.team_id = team_index
		for player_id in teams_array[team_index]:
			if player_id >= 0 and _player_system and player_id < _player_system.players.size():
				team.members.append(player_id)
				_player_team_map[player_id] = team
		_teams.append(team)

	print("[TeamSystem] チームセットアップ完了: %d チーム" % _teams.size())
	for team in _teams:
		print("[TeamSystem]   チーム%d: メンバー %s" % [team.team_id, str(team.members)])

# ============================================
# 判定メソッド
# ============================================

## チームが存在するか（FFA判定用）
func has_teams() -> bool:
	return not _teams.is_empty()

## 2人のプレイヤーが同盟か
func are_allies(player_id_a: int, player_id_b: int) -> bool:
	if player_id_a == player_id_b:
		return true  # 自分自身は常に味方
	if not _player_team_map.has(player_id_a) or not _player_team_map.has(player_id_b):
		return false  # チーム未割り当て = 味方ではない
	return _player_team_map[player_id_a] == _player_team_map[player_id_b]

# ============================================
# チーム情報取得
# ============================================

## プレイヤーのチームを取得
func get_team_for_player(player_id: int) -> TeamData:
	return _player_team_map.get(player_id, null)

## プレイヤーの同チームメンバーを取得（自分含む）
func get_team_members(player_id: int) -> Array[int]:
	var team = get_team_for_player(player_id)
	if team:
		return team.members
	return [player_id]  # チームなし = 自分だけ

## 全チームを取得
func get_all_teams() -> Array:
	return _teams

# ============================================
# チーム合算計算
# ============================================

## チーム合算TEPを計算
func get_team_total_assets(player_id: int) -> int:
	if not _player_system:
		return 0
	var team = get_team_for_player(player_id)
	if not team:
		# チームなし = 個人の資産を返す
		return _player_system.calculate_total_assets(player_id)
	var total: int = 0
	for member_id in team.members:
		total += _player_system.calculate_total_assets(member_id)
	return total

# ============================================
# 生存判定
# ============================================

## 生存チーム一覧（生存プレイヤーが1人以上いるチーム）
## members は固定配列のため、player_system.is_alive() で実際の生存を確認する
func get_surviving_teams() -> Array:
	var surviving: Array = []
	for team in _teams:
		for member_id in team.members:
			if _player_system and _player_system.is_alive(member_id):
				surviving.append(team)
				break  # 1人でも生存していればチーム生存
	return surviving

## ゲーム終了判定（生存チームが1つ以下）
func is_game_over() -> bool:
	return get_surviving_teams().size() <= 1
