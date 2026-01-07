extends Node
class_name TileActionProcessor

# タイルアクション処理クラス
# タイル到着時の各種アクション処理を管理

signal action_completed()
signal invasion_completed(success: bool, tile_index: int)

# 定数をpreload
const GameConstants = preload("res://scripts/game_constants.gd")
# TileHelper はグローバルclass_nameとして定義済み

# システム参照
var board_system: BoardSystem3D
var player_system: PlayerSystem
var card_system: CardSystem
var battle_system: BattleSystem
var special_tile_system: SpecialTileSystem
var ui_manager: UIManager
var game_flow_manager = null  # GameFlowManagerへの参照
var cpu_turn_processor  # CPUTurnProcessor型を一時的に削除
var card_sacrifice_helper: CardSacrificeHelper = null  # カード犠牲システム
var creature_synthesis: CreatureSynthesis = null  # クリーチャー合成システム

# デバッグフラグ
var debug_disable_card_sacrifice: bool = true  # カード犠牲を無効化
var debug_disable_lands_required: bool = true  # 土地条件を無効化

# 状態管理
var is_action_processing = false
var is_sacrifice_selecting = false  # カード犠牲選択中フラグ

# バトル情報の一時保存
var pending_battle_card_index: int = -1
var pending_battle_card_data: Dictionary = {}  # カードデータを保存
var pending_battle_tile_info: Dictionary = {}
var pending_attacker_item: Dictionary = {}
var pending_defender_item: Dictionary = {}
var is_waiting_for_defender_item: bool = false

# 遠隔配置モード（ベースタイル用）
var remote_placement_tile: int = -1  # -1 = 通常モード、0以上 = 指定タイルに配置

## 遠隔配置モードを設定（ベースタイルから呼び出し）
func set_remote_placement(tile_index: int):
	remote_placement_tile = tile_index
	print("[TileActionProcessor] 遠隔配置モード設定: タイル%d" % tile_index)

## 遠隔配置モードをクリア
func clear_remote_placement():
	remote_placement_tile = -1

func _ready():
	pass

# 初期化
func setup(b_system: BoardSystem3D, p_system: PlayerSystem, c_system: CardSystem,
		   bt_system: BattleSystem, st_system: SpecialTileSystem, ui: UIManager, gf_manager = null):
	board_system = b_system
	player_system = p_system
	card_system = c_system
	battle_system = bt_system
	special_tile_system = st_system
	ui_manager = ui
	game_flow_manager = gf_manager
	
	# クリーチャー合成システムを初期化
	if CardLoader:
		creature_synthesis = CreatureSynthesis.new(CardLoader)

# CPUプロセッサーを設定
func set_cpu_processor(cpu_processor):  # CPUTurnProcessor型を一時的に削除
	cpu_turn_processor = cpu_processor
	if cpu_turn_processor:
		cpu_turn_processor.cpu_action_completed.connect(_on_cpu_action_completed)

# === タイル到着処理 ===

# タイル到着時のメイン処理
func process_tile_landing(tile_index: int, current_player_index: int, player_is_cpu: Array, debug_manual_control_all: bool = false):
	if is_action_processing:
		print("Warning: Already processing tile action")
		return
	
	if not board_system.tile_nodes.has(tile_index):
		emit_signal("action_completed")
		return
	
	is_action_processing = true
	
	var tile = board_system.tile_nodes[tile_index]
	var tile_info = board_system.get_tile_info(tile_index)
	
	# 特殊マス処理（処理完了を待ってから次フェーズに進む）
	if _is_special_tile(tile.tile_type):
		if special_tile_system:
			# 特殊タイル処理を実行し、完了を待つ
			await special_tile_system.process_special_tile_3d(tile.tile_type, tile_index, current_player_index)
	
	# CPUかプレイヤーかで分岐（デバッグモードでは全て手動）
	var is_cpu_turn = player_is_cpu[current_player_index] and not debug_manual_control_all
	if is_cpu_turn:
		_process_cpu_tile(tile, tile_info, current_player_index)
	else:
		_process_player_tile(tile, tile_info, current_player_index)

# プレイヤーのタイル処理
func _process_player_tile(tile: BaseTile, tile_info: Dictionary, player_index: int):
	# カメラを手動モードに
	if board_system and board_system.camera_controller:
		board_system.camera_controller.enable_manual_mode()
		board_system.camera_controller.set_current_player(player_index)
	
	# 特殊タイルかチェック（特殊タイルのUI設定はspecial_tile_system側で完了済み）
	# パスボタン押下で_complete_action()が呼ばれるため、ここではreturnのみ
	var is_special = _is_special_tile(tile.tile_type)
	if is_special:
		return
	
	if tile_info["owner"] == -1:
		# 空き地 - 召喚UI表示
		show_summon_ui()
	elif tile_info["owner"] == player_index:
		# 自分の土地 - 召喚不可（領地コマンドで操作可能）
		show_summon_ui_disabled()
	else:
		# 敵の土地
		# peace呪いチェック
		var spell_curse_toll = null
		if board_system.has_meta("spell_curse_toll"):
			spell_curse_toll = board_system.get_meta("spell_curse_toll")
		
		var current_tile_index = board_system.movement_controller.get_player_tile(player_index)
		
		# peace呪いがあれば戦闘UI表示するがグレーアウト
		if spell_curse_toll and spell_curse_toll.has_peace_curse(current_tile_index):
			show_battle_ui_disabled()
		# プレイヤー侵略不可呪い（バンフィズム）
		elif spell_curse_toll and spell_curse_toll.is_player_invasion_disabled(player_index):
			show_battle_ui_disabled()
		# マーシフルワールド（下位侵略不可）- SpellWorldCurseに委譲
		elif game_flow_manager and game_flow_manager.spell_world_curse and game_flow_manager.spell_world_curse.check_invasion_blocked(player_index, tile_info.get("owner", -1), false):
			show_battle_ui_disabled()
		else:
			# 通常の戦闘UI
			if tile_info.get("creature", {}).is_empty():
				show_battle_ui("invasion")
			else:
				show_battle_ui("battle")

# CPUのタイル処理
func _process_cpu_tile(tile: BaseTile, tile_info: Dictionary, player_index: int):
	# CPUはcpu_turn_processorで処理（特殊タイルでも領地コマンドを検討）
	if cpu_turn_processor:
		cpu_turn_processor.process_cpu_turn(tile, tile_info, player_index)
	else:
		print("Warning: CPU turn processor not set")
		_complete_action()

# === UI表示 ===

# 召喚UI表示
func show_summon_ui():
	if ui_manager:
		# スペルカードは召喚フェーズでは使えないので、フィルターは空（スペル以外が選択可能）
		ui_manager.card_selection_filter = ""
		ui_manager.phase_label.text = "召喚するクリーチャーを選択"
		ui_manager.show_card_selection_ui(player_system.get_current_player())

# 召喚UI表示（グレーアウト）- 自分の土地に止まった場合
func show_summon_ui_disabled():
	if ui_manager:
		ui_manager.phase_label.text = "自分の土地: 召喚不可（パスまたは領地コマンドを使用）"
		# フィルターを"disabled"に設定してすべてのカードをグレーアウト
		ui_manager.card_selection_filter = "disabled"
		ui_manager.show_card_selection_ui(player_system.get_current_player())

# レベルアップUI表示
func show_level_up_ui(tile_info: Dictionary):
	if ui_manager:
		var current_player_index = board_system.current_player_index
		var current_magic = player_system.get_magic(current_player_index)
		ui_manager.show_level_up_ui(tile_info, current_magic)

# バトルUI表示
func show_battle_ui(mode: String):
	if ui_manager:
		# 防御型クリーチャーはバトルで使用不可
		ui_manager.card_selection_filter = "battle"
		if mode == "invasion":
			ui_manager.phase_label.text = "侵略するクリーチャーを選択"
		else:
			ui_manager.phase_label.text = "バトルするクリーチャーを選択"
		ui_manager.show_card_selection_ui(player_system.get_current_player())

# バトルUI表示（グレーアウト）peace呪い用
func show_battle_ui_disabled():
	if ui_manager:
		ui_manager.phase_label.text = "peace呪い: 侵略不可（パスまたは領地コマンドを使用）"
		# フィルターを"disabled"に設定してすべてのカードをグレーアウト
		ui_manager.card_selection_filter = "disabled"
		ui_manager.show_card_selection_ui(player_system.get_current_player())

# === アクション処理 ===

# カード選択時の処理
func on_card_selected(card_index: int):
	if not is_action_processing:
		return
	
	# カード犠牲選択中は通常のカード選択を無視
	if is_sacrifice_selecting:
		return
	
	var current_player_index = board_system.current_player_index
	var current_tile = board_system.movement_controller.get_player_tile(current_player_index)
	var tile_info = board_system.get_tile_info(current_tile)
	
	# 特殊タイル上ではカード選択を無視（UIは維持）
	# ただし遠隔配置モードの場合は許可（ベースタイルから別タイルに配置）
	var tile = board_system.tile_nodes.get(current_tile)
	if tile and _is_special_tile(tile.tile_type) and remote_placement_tile < 0:
		print("[TileActionProcessor] 特殊タイル上ではカードを使用できません")
		if ui_manager:
			# メッセージのみ更新し、UIは維持（パスボタンも残る）
			ui_manager.phase_label.text = "❌ 特殊タイル上では召喚できません"
			# 少し待ってから元のメッセージに戻す
			await board_system.get_tree().create_timer(1.5).timeout
			ui_manager.phase_label.text = "特殊タイル: 召喚できません（パスまたは領地コマンドを使用）"
		return
	
	# 遠隔配置モードの場合は無条件で召喚処理
	if remote_placement_tile >= 0:
		print("[TileActionProcessor] 遠隔配置モードで召喚実行: card_index=%d" % card_index)
		await execute_summon(card_index)
		return
	elif tile_info["owner"] == -1 or tile_info["owner"] == current_player_index:
		# 召喚処理
		execute_summon(card_index)
	else:
		# バトル処理
		execute_battle(card_index, tile_info)

## アイテムフェーズ完了後のコールバック
func _on_item_phase_completed():
	if not is_waiting_for_defender_item:
		# 攻撃側のアイテムフェーズ完了 → 防御側のアイテムフェーズ開始
		print("[TileActionProcessor] 攻撃側アイテムフェーズ完了")
		
		# 合体が発生した場合、バトルカードデータを更新
		if game_flow_manager and game_flow_manager.item_phase_handler:
			if game_flow_manager.item_phase_handler.was_merged():
				pending_battle_card_data = game_flow_manager.item_phase_handler.get_merged_creature()
				print("[TileActionProcessor] 合体発生: %s" % pending_battle_card_data.get("name", "?"))
		
		# 攻撃側のアイテムを保存
		if game_flow_manager and game_flow_manager.item_phase_handler:
			pending_attacker_item = game_flow_manager.item_phase_handler.get_selected_item()
		
		# 防御側のアイテムフェーズを開始
		var defender_owner = pending_battle_tile_info.get("owner", -1)
		if defender_owner >= 0:
			is_waiting_for_defender_item = true
			
			# 🎬 防御側を強調表示に切り替え
			if game_flow_manager and game_flow_manager.battle_status_overlay:
				game_flow_manager.battle_status_overlay.highlight_side("defender")
			
			# 防御側のアイテムフェーズ開始
			if game_flow_manager and game_flow_manager.item_phase_handler:
				# 再度シグナルに接続（ONE_SHOTなので再接続が必要）
				if not game_flow_manager.item_phase_handler.item_phase_completed.is_connected(_on_item_phase_completed):
					game_flow_manager.item_phase_handler.item_phase_completed.connect(_on_item_phase_completed, CONNECT_ONE_SHOT)
				
				print("[TileActionProcessor] 防御側アイテムフェーズ開始: プレイヤー ", defender_owner + 1)
				# 防御側クリーチャーのデータを取得して渡す
				var defender_creature = pending_battle_tile_info.get("creature", {})
				# 攻撃側クリーチャーデータを設定（無効化判定用）
				game_flow_manager.item_phase_handler.set_opponent_creature(pending_battle_card_data)
				# タイル情報を設定（シミュレーション用）
				game_flow_manager.item_phase_handler.set_defense_tile_info(pending_battle_tile_info)
				game_flow_manager.item_phase_handler.start_item_phase(defender_owner, defender_creature)
			else:
				# ItemPhaseHandlerがない場合は直接バトル
				_execute_pending_battle()
		else:
			# 防御側がいない場合（ありえないが念のため）
			_execute_pending_battle()
	else:
		# 防御側のアイテムフェーズ完了 → バトル開始
		print("[TileActionProcessor] 防御側アイテムフェーズ完了、バトル開始")
		
		# 防御側の合体が発生した場合、tile_infoのcreatureを更新 + タイルも永続更新
		if game_flow_manager and game_flow_manager.item_phase_handler:
			if game_flow_manager.item_phase_handler.was_merged():
				var merged_data = game_flow_manager.item_phase_handler.get_merged_creature()
				pending_battle_tile_info["creature"] = merged_data
				print("[TileActionProcessor] 防御側合体発生: %s" % merged_data.get("name", "?"))
				
				# タイルのクリーチャーデータも永続更新
				var tile_index = pending_battle_tile_info.get("index", -1)
				if tile_index >= 0 and board_system.tile_nodes.has(tile_index):
					var tile = board_system.tile_nodes[tile_index]
					tile.creature_data = merged_data
					print("[TileActionProcessor] タイル%d のクリーチャーデータを更新（永続化）" % tile_index)
		
		# 防御側のアイテムを保存
		if game_flow_manager and game_flow_manager.item_phase_handler:
			pending_defender_item = game_flow_manager.item_phase_handler.get_selected_item()
		
		is_waiting_for_defender_item = false
		_execute_pending_battle()

## 保留中のバトルを実行
func _execute_pending_battle():
	if pending_battle_card_index < 0 or pending_battle_card_data.is_empty():
		print("[TileActionProcessor] エラー: バトル情報が保存されていません")
		_complete_action()
		return
	
	# 🎬 バトルステータスオーバーレイを非表示
	if game_flow_manager and game_flow_manager.battle_status_overlay:
		game_flow_manager.battle_status_overlay.hide_battle_status()
	
	var current_player_index = board_system.current_player_index
	
	# バトルカードは既に on_card_selected() で消費済み
	
	# バトル完了シグナルに接続
	var callable = Callable(self, "_on_battle_completed")
	if not battle_system.invasion_completed.is_connected(callable):
		battle_system.invasion_completed.connect(callable, CONNECT_ONE_SHOT)
	
	# バトル実行（カードデータとアイテム情報を渡す）
	# card_indexには-1を渡して、BattleSystem内でカード使用処理をスキップさせる
	await battle_system.execute_3d_battle_with_data(current_player_index, pending_battle_card_data, pending_battle_tile_info, pending_attacker_item, pending_defender_item)
	
	# バトル情報をクリア
	pending_battle_card_index = -1
	pending_battle_card_data = {}
	pending_battle_tile_info = {}
	pending_attacker_item = {}
	pending_defender_item = {}
	is_waiting_for_defender_item = false

# 召喚実行
func execute_summon(card_index: int):
	print("[TileActionProcessor] execute_summon開始: card_index=%d, remote=%d" % [card_index, remote_placement_tile])
	if card_index < 0:
		_complete_action()
		return
	
	var current_player_index = board_system.current_player_index
	var card_data = card_system.get_card_data_for_player(current_player_index, card_index)
	print("[TileActionProcessor] カード取得: %s" % card_data.get("name", "?"))
	
	if card_data.is_empty():
		_complete_action()
		return
	
	# 配置先タイルを決定（遠隔配置モードならremote_placement_tile、通常はcurrent_tile）
	var target_tile: int
	var is_remote_placement = remote_placement_tile >= 0
	if is_remote_placement:
		target_tile = remote_placement_tile
		print("[TileActionProcessor] 遠隔配置モード: タイル%d に配置" % target_tile)
	else:
		target_tile = board_system.movement_controller.get_player_tile(current_player_index)
	
	var tile = board_system.tile_nodes.get(target_tile)
	
	# 配置可能タイルかチェック（タイル側のメソッドを使用）
	if tile and not tile.can_place_creature():
		print("[TileActionProcessor] このタイルには配置できません: %s" % tile.tile_type)
		if ui_manager:
			ui_manager.phase_label.text = "このタイルには配置できません"
		_complete_action()
		return
	
	# 防御型チェック: 空き地以外には召喚できない
	var creature_type = card_data.get("creature_type", "normal")
	if creature_type == "defensive":
		var tile_info = board_system.get_tile_info(target_tile)
		
		# 空き地（owner = -1）でなければ召喚不可
		if tile_info["owner"] != -1:
			print("[TileActionProcessor] 防御型クリーチャーは空き地にのみ召喚できます")
			if ui_manager:
				ui_manager.phase_label.text = "防御型は空き地にのみ召喚可能です"
			_complete_action()
			return
	
	# 土地条件チェック（lands_required）
	# ブライトワールド発動中は土地条件を無視
	if not debug_disable_lands_required and not _is_summon_condition_ignored():
		var check_result = _check_lands_required(card_data, current_player_index)
		if not check_result.passed:
			print("[TileActionProcessor] 土地条件未達: %s" % check_result.message)
			if ui_manager:
				ui_manager.phase_label.text = check_result.message
			_complete_action()
			return
	
	# カード犠牲処理（クリーチャー合成用）
	# ブライトワールド発動中はカード犠牲を無視
	var sacrifice_card = {}
	if _requires_card_sacrifice(card_data) and not debug_disable_card_sacrifice and not _is_summon_condition_ignored():
		sacrifice_card = await _process_card_sacrifice(current_player_index, card_index)
		if sacrifice_card.is_empty() and _requires_card_sacrifice(card_data):
			# キャンセル時は召喚をキャンセル
			if ui_manager:
				ui_manager.phase_label.text = "召喚をキャンセルしました"
			_complete_action()
			return
	
	# クリーチャー合成処理
	var is_synthesized = false
	if not sacrifice_card.is_empty() and creature_synthesis:
		is_synthesized = creature_synthesis.check_condition(card_data, sacrifice_card)
		if is_synthesized:
			card_data = creature_synthesis.apply_synthesis(card_data, sacrifice_card, true)
			print("[TileActionProcessor] 合成成立: %s" % card_data.get("name", "?"))
	
	var cost_data = card_data.get("cost", 1)
	var cost = 0
	if typeof(cost_data) == TYPE_DICTIONARY:
		cost = cost_data.get("mp", 0)
	else:
		cost = cost_data
	
	# ライフフォース呪いチェック（クリーチャーコスト0化）
	if game_flow_manager and game_flow_manager.spell_cost_modifier:
		cost = game_flow_manager.spell_cost_modifier.get_modified_cost(current_player_index, card_data)
	
	var current_player = player_system.get_current_player()
	
	if current_player.magic_power >= cost:
		# カード使用と魔力消費
		card_system.use_card_for_player(current_player_index, card_index)
		player_system.add_magic(current_player_index, -cost)
		
		# 土地取得とクリーチャー配置（遠隔配置でも同様）
		board_system.set_tile_owner(target_tile, current_player_index)
		board_system.place_creature(target_tile, card_data)
		
		# Phase 1-A: 召喚後にダウン状態を設定（不屈チェック）
		if tile and tile.has_method("set_down_state"):
				# 不屈持ちでなければダウン状態にする
				if not PlayerBuffSystem.has_unyielding(card_data):
					tile.set_down_state(true)
				else:
					print("[TileActionProcessor] 不屈により召喚後もダウンしません: タイル", target_tile)
		
		if is_remote_placement:
			print("遠隔召喚成功！タイル%dを取得しました" % target_tile)
		else:
			print("召喚成功！土地を取得しました")
		
		# UI更新
		if ui_manager:
			ui_manager.hide_card_selection_ui()
			ui_manager.update_player_info_panels()
	else:
		print("魔力不足で召喚できません")
	
	print("[TileActionProcessor] execute_summon完了、_complete_action呼び出し")
	_complete_action()


# バトル（侵略）実行
func execute_battle(card_index: int, tile_info: Dictionary):
	if card_index < 0:
		_complete_action()
		return
	
	var current_player_index = board_system.current_player_index
	var card_data = card_system.get_card_data_for_player(current_player_index, card_index)
	
	if card_data.is_empty():
		_complete_action()
		return
	
	# 土地条件チェック（lands_required）
	# ブライトワールド発動中は土地条件を無視
	if not debug_disable_lands_required and not _is_summon_condition_ignored():
		var check_result = _check_lands_required(card_data, current_player_index)
		if not check_result.passed:
			print("[TileActionProcessor] 土地条件未達（バトル）: %s" % check_result.message)
			if ui_manager:
				ui_manager.phase_label.text = check_result.message
			_complete_action()
			return
	
	# カード犠牲処理（クリーチャー合成用）
	# ブライトワールド発動中はカード犠牲を無視
	var sacrifice_card = {}
	if _requires_card_sacrifice(card_data) and not debug_disable_card_sacrifice and not _is_summon_condition_ignored():
		# カード選択UIを一度閉じる
		if ui_manager:
			ui_manager.hide_card_selection_ui()
		sacrifice_card = await _process_card_sacrifice(current_player_index, card_index)
		if sacrifice_card.is_empty() and _requires_card_sacrifice(card_data):
			# キャンセル時はバトルをキャンセル
			if ui_manager:
				ui_manager.phase_label.text = "バトルをキャンセルしました"
			_complete_action()
			return
	
	# クリーチャー合成処理
	var is_synthesized = false
	if not sacrifice_card.is_empty() and creature_synthesis:
		is_synthesized = creature_synthesis.check_condition(card_data, sacrifice_card)
		if is_synthesized:
			card_data = creature_synthesis.apply_synthesis(card_data, sacrifice_card, true)
			print("[TileActionProcessor] 合成成立（バトル）: %s" % card_data.get("name", "?"))
	
	# バトル情報を保存
	pending_battle_card_index = card_index
	pending_battle_card_data = card_data  # 合成後のデータを使用
	pending_battle_tile_info = tile_info
	
	# コスト計算
	var cost_data = card_data.get("cost", 1)
	var cost = 0
	if typeof(cost_data) == TYPE_DICTIONARY:
		cost = cost_data.get("mp", 0)
	else:
		cost = cost_data
	
	# ライフフォース呪いチェック（クリーチャーコスト0化）
	if game_flow_manager and game_flow_manager.spell_cost_modifier:
		cost = game_flow_manager.spell_cost_modifier.get_modified_cost(current_player_index, pending_battle_card_data)
	
	var current_player = player_system.get_current_player()
	if current_player.magic_power < cost:
		print("[TileActionProcessor] 魔力不足でバトルできません")
		_complete_action()
		return
	
	# カードを使用して魔力消費
	card_system.use_card_for_player(current_player_index, card_index)
	player_system.add_magic(current_player_index, -cost)
	print("[TileActionProcessor] バトルカード消費: ", pending_battle_card_data.get("name", "???"))
	
	# 🎬 バトルステータスオーバーレイ表示（アイテムフェーズ中）
	var defender_creature = pending_battle_tile_info.get("creature", {})
	if game_flow_manager and game_flow_manager.battle_status_overlay:
		# 土地ボーナスを計算（攻撃側=侵略なので0、防御側=自分の土地）
		var attacker_display = pending_battle_card_data.duplicate()
		attacker_display["land_bonus_hp"] = 0  # 侵略側は土地ボーナスなし
		
		var defender_display = defender_creature.duplicate()
		defender_display["land_bonus_hp"] = _calculate_land_bonus_for_display(defender_creature, pending_battle_tile_info)
		
		game_flow_manager.battle_status_overlay.show_battle_status(
			attacker_display, defender_display, "attacker")
	
	# CPU攻撃側の合体処理をチェック
	if _is_cpu_player(current_player_index):
		var merge_executed = _check_and_execute_cpu_attacker_merge(current_player_index)
		if merge_executed:
			# 合体後のデータでバトルオーバーレイを更新
			if game_flow_manager and game_flow_manager.battle_status_overlay:
				var attacker_display = pending_battle_card_data.duplicate()
				attacker_display["land_bonus_hp"] = 0
				var defender_display = defender_creature.duplicate()
				defender_display["land_bonus_hp"] = _calculate_land_bonus_for_display(defender_creature, pending_battle_tile_info)
				game_flow_manager.battle_status_overlay.show_battle_status(
					attacker_display, defender_display, "attacker")
	
	# GameFlowManagerのitem_phase_handlerを通じてアイテムフェーズ開始
	if game_flow_manager and game_flow_manager.item_phase_handler:
		# アイテムフェーズ完了シグナルに接続
		if not game_flow_manager.item_phase_handler.item_phase_completed.is_connected(_on_item_phase_completed):
			game_flow_manager.item_phase_handler.item_phase_completed.connect(_on_item_phase_completed, CONNECT_ONE_SHOT)
		
		# アイテムフェーズ開始（バトル参加クリーチャーのデータを渡す）
		game_flow_manager.item_phase_handler.start_item_phase(current_player_index, pending_battle_card_data)
	else:
		# ItemPhaseHandlerがない場合は直接バトル
		_execute_pending_battle()


## カード犠牲が必要か判定
func _requires_card_sacrifice(card_data: Dictionary) -> bool:
	# 正規化されたフィールドをチェック
	if card_data.get("cost_cards_sacrifice", 0) > 0:
		return true
	# 正規化されていない場合、元のcostフィールドもチェック
	var cost = card_data.get("cost", {})
	if typeof(cost) == TYPE_DICTIONARY:
		return cost.get("cards_sacrifice", 0) > 0
	return false


## 土地条件チェック（属性ごとにカウント）
## 戻り値: {passed: bool, message: String}
func _check_lands_required(card_data: Dictionary, player_id: int) -> Dictionary:
	var lands_required = _get_lands_required_array(card_data)
	if lands_required.is_empty():
		return {"passed": true, "message": ""}
	
	# プレイヤーの所有土地の属性をカウント
	var owned_elements = {}  # {"fire": 2, "water": 1, ...}
	var player_tiles = board_system.get_player_tiles(player_id)
	for tile in player_tiles:
		var element = tile.tile_type if tile else ""
		if element != "" and element != "neutral":
			owned_elements[element] = owned_elements.get(element, 0) + 1
	
	# 必要な属性をカウント
	var required_elements = {}  # {"fire": 2, ...}
	for element in lands_required:
		required_elements[element] = required_elements.get(element, 0) + 1
	
	# 各属性の条件を満たしているかチェック
	for element in required_elements.keys():
		var required_count = required_elements[element]
		var owned_count = owned_elements.get(element, 0)
		if owned_count < required_count:
			var element_name = _get_element_display_name(element)
			return {
				"passed": false,
				"message": "%s属性の土地が%d個必要です（所有: %d）" % [element_name, required_count, owned_count]
			}
	
	return {"passed": true, "message": ""}


## 土地条件の配列を取得
func _get_lands_required_array(card_data: Dictionary) -> Array:
	# 正規化されたフィールドをチェック
	if card_data.has("cost_lands_required"):
		var lands = card_data.get("cost_lands_required", [])
		if typeof(lands) == TYPE_ARRAY:
			return lands
		return []
	# 正規化されていない場合、元のcostフィールドもチェック
	var cost = card_data.get("cost", {})
	if typeof(cost) == TYPE_DICTIONARY:
		var lands = cost.get("lands_required", [])
		if typeof(lands) == TYPE_ARRAY:
			return lands
	return []


## 属性の表示名を取得
func _get_element_display_name(element: String) -> String:
	match element:
		"fire": return "火"
		"water": return "水"
		"earth": return "地"
		"wind": return "風"
		_: return element


## ブライトワールド（召喚条件解除）が発動中か
func _is_summon_condition_ignored() -> bool:
	if not game_flow_manager:
		return false
	var game_stats = game_flow_manager.game_stats
	return SpellWorldCurse.is_summon_condition_ignored(game_stats)


## カード犠牲処理（手札選択UI表示→カード破棄）
func _process_card_sacrifice(player_id: int, summon_card_index: int) -> Dictionary:
	# CardSacrificeHelperを初期化
	if not card_sacrifice_helper:
		card_sacrifice_helper = CardSacrificeHelper.new(card_system, player_system, ui_manager)
	
	# 犠牲選択モードに入る
	is_sacrifice_selecting = true
	
	# 手札選択UIを表示（召喚するカード以外を選択可能）
	if ui_manager:
		ui_manager.phase_label.text = "犠牲にするカードを選択"
		ui_manager.card_selection_filter = ""
		var player = player_system.players[player_id]
		ui_manager.show_card_selection_ui_mode(player, "sacrifice")
	
	# カード選択を待つ
	var selected_index = await ui_manager.card_selected
	
	# 犠牲選択モードを終了
	is_sacrifice_selecting = false
	
	# UIを閉じる
	ui_manager.hide_card_selection_ui()
	
	# 選択されたカードを取得
	if selected_index < 0:
		return {}
	
	# 召喚するカードと同じインデックスは選択不可
	if selected_index == summon_card_index:
		if ui_manager:
			ui_manager.phase_label.text = "召喚するカードは犠牲にできません"
		return {}
	
	var hand = card_system.get_all_cards_for_player(player_id)
	if selected_index >= hand.size():
		return {}
	
	var sacrifice_card = hand[selected_index]
	
	# カードを破棄
	card_system.discard_card(player_id, selected_index, "sacrifice")
	print("[TileActionProcessor] %s を犠牲にしました" % sacrifice_card.get("name", "?"))
	
	return sacrifice_card

# パス処理（通行料支払いはend_turn()で一本化）
func on_action_pass():
	if not is_action_processing:
		return
	
	# パス時は支払い処理なし（end_turn()内で敵地判定・支払いを実行）
	print("[パス処理] タイルアクション完了")
	_complete_action()

# レベルアップ選択時の処理
func on_level_up_selected(target_level: int, cost: int):
	if not is_action_processing:
		return
	
	if target_level == 0 or cost == 0:
		# キャンセル
		_complete_action()
		return
	
	var current_player_index = board_system.current_player_index
	var current_tile = board_system.movement_controller.get_player_tile(current_player_index)
	var current_player = player_system.get_current_player()
	
	if current_player.magic_power >= cost:
		# レベルアップ実行
		var tile = board_system.tile_nodes[current_tile]
		tile.set_level(target_level)
		player_system.add_magic(current_player_index, -cost)
		
		# 表示更新
		if board_system.tile_info_display:
			board_system.tile_info_display.update_display(current_tile, board_system.get_tile_info(current_tile))
		
		if ui_manager:
			ui_manager.update_player_info_panels()
			ui_manager.hide_level_up_ui()
		
		print("土地をレベル", target_level, "にアップグレード！（コスト: ", cost, "G）")
	
	_complete_action()

# === コールバック ===

# 特殊アクション完了時
# バトル完了時
func _on_battle_completed(success: bool, tile_index: int):
	print("バトル結果受信: success=", success, " tile=", tile_index)
	
	# 衰弱（プレイグ）ダメージ処理
	_apply_plague_damage_after_battle(tile_index)
	
	if ui_manager:
		ui_manager.hide_card_selection_ui()
		ui_manager.update_player_info_panels()
	
	emit_signal("invasion_completed", success, tile_index)
	_complete_action()


## バトル終了後の衰弱ダメージ処理
## ※衰弱はSkillBattleEndEffectsで処理されるため、ここでは何もしない
func _apply_plague_damage_after_battle(_tile_index: int) -> void:
	# 衰弱ダメージはbattle_execution.gd内のSkillBattleEndEffects.process_allで処理
	# ナチュラルワールド等による無効化チェックもそちらで行う
	pass

# CPUアクション完了時
func _on_cpu_action_completed():
	_complete_action()

# === ヘルパー関数 ===

# 特殊タイルかチェック（TileHelperに委譲）
# 特殊タイルかチェック（TileHelperに委譲）
func _is_special_tile(tile_type: String) -> bool:
	return TileHelper.is_special_type(tile_type)



# 外部からアクション完了を通知するための公開メソッド
func complete_action():
	_complete_action()

# Phase 1-D: クリーチャー交換処理
func execute_swap(tile_index: int, card_index: int, _old_creature_data: Dictionary):
	if not is_action_processing:
		print("Warning: Not processing any action")
		return
	
	if card_index < 0:
		print("[TileActionProcessor] 交換キャンセル")
		_complete_action()
		return
	
	var current_player_index = board_system.current_player_index
	var card_data = card_system.get_card_data_for_player(current_player_index, card_index)
	
	if card_data.is_empty():
		print("[TileActionProcessor] カードデータが取得できません")
		_complete_action()
		return
	
	# 🔄 最新のタイルデータを再取得（死者復活などで変身している可能性があるため）
	var tile_info = board_system.get_tile_info(tile_index)
	var actual_creature_data = tile_info.get("creature", {})
	
	# デバッグ: タイルデータの内容を確認
	print("[デバッグ] タイルデータ再取得:")
	print("  tile_info.has_creature: ", tile_info.get("has_creature", false))
	print("  creature.name: ", actual_creature_data.get("name", "なし"))
	print("  creature.id: ", actual_creature_data.get("id", "なし"))
	
	if actual_creature_data.is_empty():
		print("[TileActionProcessor] エラー: タイルにクリーチャーがいません")
		_complete_action()
		return
	
	# コストチェック
	var cost_data = card_data.get("cost", 1)
	var cost = 0
	if typeof(cost_data) == TYPE_DICTIONARY:
		cost = cost_data.get("mp", 0)  # 等倍
	else:
		cost = cost_data  # 等倍
	
	# ライフフォース呪いチェック（クリーチャーコスト0化）
	if game_flow_manager and game_flow_manager.spell_cost_modifier:
		cost = game_flow_manager.spell_cost_modifier.get_modified_cost(current_player_index, card_data)
	
	var current_player = player_system.get_current_player()
	
	if current_player.magic_power < cost:
		print("[TileActionProcessor] 魔力不足で交換できません")
		_complete_action()
		return
	
	print("[TileActionProcessor] クリーチャー交換開始")
	print("  対象土地: タイル", tile_index)
	print("  元のクリーチャー: ", actual_creature_data.get("name", "不明"))
	print("  新しいクリーチャー: ", card_data.get("name", "不明"))
	
	# 1. 元のクリーチャーを手札に戻す（最新のデータを使用）
	card_system.return_card_to_hand(current_player_index, actual_creature_data)
	
	# 2. 選択したカードを使用（手札から削除）
	card_system.use_card_for_player(current_player_index, card_index)
	
	# 3. 魔力消費
	player_system.add_magic(current_player_index, -cost)
	
	# 4. 新しいクリーチャーを配置（土地レベル・属性は維持される）
	board_system.place_creature(tile_index, card_data)
	
	# 5. ダウン状態を設定（不屈チェック）
	if board_system.tile_nodes.has(tile_index):
		var tile = board_system.tile_nodes[tile_index]
		if tile and tile.has_method("set_down_state"):
			# 不屈持ちでなければダウン状態にする
			if not PlayerBuffSystem.has_unyielding(card_data):
				tile.set_down_state(true)
			else:
				print("[TileActionProcessor] 不屈により交換後もダウンしません: タイル", tile_index)
	
	# UI更新
	if ui_manager:
		ui_manager.hide_card_selection_ui()
		ui_manager.update_player_info_panels()
	
	print("[TileActionProcessor] クリーチャー交換完了")
	_complete_action()

## アイテムフェーズ表示用の土地ボーナス計算
func _calculate_land_bonus_for_display(creature_data: Dictionary, tile_info: Dictionary) -> int:
	var creature_element = creature_data.get("element", "")
	var tile_element = tile_info.get("element", "")
	var tile_level = tile_info.get("level", 1)
	
	# 無属性タイルは全クリーチャーにボーナス
	if tile_element == "neutral":
		return tile_level * 10
	
	# 属性が一致すれば土地ボーナス
	if creature_element != "" and creature_element == tile_element:
		return tile_level * 10
	
	return 0

## プレイヤーがCPUかどうか判定
func _is_cpu_player(player_index: int) -> bool:
	if board_system and "player_is_cpu" in board_system:
		var cpu_flags = board_system.player_is_cpu
		if player_index >= 0 and player_index < cpu_flags.size():
			return cpu_flags[player_index]
	return false

## CPU攻撃側の合体処理をチェック・実行
func _check_and_execute_cpu_attacker_merge(player_index: int) -> bool:
	# cpu_ai_handlerから合体データを取得
	if not board_system or not board_system.cpu_turn_processor:
		return false
	
	var cpu_handler = board_system.cpu_turn_processor.cpu_ai_handler
	if not cpu_handler:
		return false
	
	if not cpu_handler.has_pending_merge():
		return false
	
	var merge_data = cpu_handler.get_pending_merge_data()
	print("[TileActionProcessor] CPU攻撃側合体実行: %s → %s" % [
		pending_battle_card_data.get("name", "?"),
		merge_data.get("result_name", "?")
	])
	
	# 合体相手のデータ
	var partner_index = merge_data.get("partner_index", -1)
	var partner_data = merge_data.get("partner_data", {})
	var cost = merge_data.get("cost", 0)
	var result_id = merge_data.get("result_id", -1)
	
	if partner_index < 0 or result_id < 0:
		cpu_handler.clear_pending_merge_data()
		return false
	
	# 合体結果のクリーチャーを取得
	var result_creature = CardLoader.get_card_by_id(result_id)
	if result_creature.is_empty():
		print("[TileActionProcessor] 合体結果のクリーチャーが見つかりません")
		cpu_handler.clear_pending_merge_data()
		return false
	
	# 魔力消費（合体相手のコスト）
	player_system.add_magic(player_index, -cost)
	print("[CPU合体] 魔力消費: %dG" % cost)
	
	# 合体相手を捨て札へ
	card_system.discard_card(player_index, partner_index, "merge")
	print("[CPU合体] %s を捨て札へ" % partner_data.get("name", "?"))
	
	# 合体後のクリーチャーデータを準備
	var new_creature_data = result_creature.duplicate(true)
	
	# 永続化フィールドの初期化
	if not new_creature_data.has("base_up_hp"):
		new_creature_data["base_up_hp"] = 0
	if not new_creature_data.has("base_up_ap"):
		new_creature_data["base_up_ap"] = 0
	if not new_creature_data.has("permanent_effects"):
		new_creature_data["permanent_effects"] = []
	if not new_creature_data.has("temporary_effects"):
		new_creature_data["temporary_effects"] = []
	
	# current_hpの初期化
	var max_hp = new_creature_data.get("hp", 0) + new_creature_data.get("base_up_hp", 0)
	new_creature_data["current_hp"] = max_hp
	
	# バトルカードデータを更新
	pending_battle_card_data = new_creature_data
	
	print("[CPU合体] 完了: %s (HP:%d AP:%d)" % [
		new_creature_data.get("name", "?"),
		max_hp,
		new_creature_data.get("ap", 0)
	])
	
	# 合体データをクリア
	cpu_handler.clear_pending_merge_data()
	
	return true

# アクション完了（内部用）
func _complete_action():
	print("[TileActionProcessor] _complete_action開始")
	# カメラを追従モードに戻し、プレイヤー位置に復帰
	if board_system and board_system.camera_controller:
		board_system.camera_controller.enable_follow_mode()
		board_system.camera_controller.return_to_player()
	
	# 遠隔配置モードをクリア
	remote_placement_tile = -1
	
	is_action_processing = false
	print("[TileActionProcessor] action_completedシグナル発火")
	emit_signal("action_completed")
