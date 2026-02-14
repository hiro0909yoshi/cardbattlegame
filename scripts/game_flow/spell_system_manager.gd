extends Node
class_name SpellSystemManager

## スペルシステム統括管理者
##
## GameFlowManager の子として配置され、全スペルシステムを管理。
## SpellSystemContainer を保持し、アクセサメソッド経由で各スペルシステムへのアクセスを提供。
## 後方互換性を維持しながら、階層構造を統一する。

# コアスペルシステムコンテナ
var spell_container: SpellSystemContainer = null

# Node型のスペルシステム（今後の拡張用）
var spell_curse_toll = null
var spell_cost_modifier = null


func _ready():
	print("[SpellSystemManager] 初期化完了")


## セットアップ
##
## SpellSystemContainer を受け取り、管理開始
func setup(container: SpellSystemContainer) -> void:
	if not container:
		push_error("[SpellSystemManager] SpellSystemContainer が null です")
		return

	spell_container = container
	print("[SpellSystemManager] setup 完了")


# ============================================================
# アクセサメソッド（後方互換性・10個すべて）
# ============================================================

## スペルドロー システムへのアクセス
func get_spell_draw():
	return spell_container.spell_draw if spell_container else null


## スペルマジック システムへのアクセス
func get_spell_magic():
	return spell_container.spell_magic if spell_container else null


## スペルランド システムへのアクセス
func get_spell_land():
	return spell_container.spell_land if spell_container else null


## スペルカース システムへのアクセス
func get_spell_curse():
	return spell_container.spell_curse if spell_container else null


## スペルダイス システムへのアクセス
func get_spell_dice():
	return spell_container.spell_dice if spell_container else null


## スペルカースステット システムへのアクセス
func get_spell_curse_stat():
	return spell_container.spell_curse_stat if spell_container else null


## スペルワールドカース システムへのアクセス
func get_spell_world_curse():
	return spell_container.spell_world_curse if spell_container else null


## スペルプレイヤームーブ システムへのアクセス
func get_spell_player_move():
	return spell_container.spell_player_move if spell_container else null


## スペルカーストール システムへのアクセス（派生システム）
func get_spell_curse_toll():
	return spell_container.spell_curse_toll if spell_container else null


## スペルコストモディファイア システムへのアクセス（派生システム）
func get_spell_cost_modifier():
	return spell_container.spell_cost_modifier if spell_container else null
