extends Control

# カードフレームの各要素への参照
@onready var card_art = $CardArtContainer/CardArt
@onready var cost_label = $CostBadge/CostCircle/CostLabel
@onready var name_label = $NameBanner/NameLabel
# @onready var subtitle_label = $NameBanner/SubtitleLabel  # 削除済み
@onready var description_label = $DescriptionBox/DescriptionLabel
@onready var left_stat_label = $LeftStatBadge/LeftStatCircle/LeftStatLabel
@onready var right_stat_label = $RightStatBadge/RightStatCircle/RightStatLabel
@onready var current_hp_label = $CurrentHPBadge/CurrentHPCircle/CurrentHPLabel
# @onready var ascended_banner = $AscendedBanner  # 削除済み

# カードデータ
var card_name: String = "DISPLACER"
# var card_subtitle: String = "THE CINDER AVENGER"  # 削除済み
var card_cost: int = 10
var card_description: String = "Gets +1 for every Power you have."
var left_stat: int = 15
var right_stat: int = 15
var current_hp: int = 10
var max_hp: int = 15  # RightStatが最大HP
# var is_ascended: bool = true  # 削除済み
var card_texture: Texture2D

func _ready():
	update_card_display()

# カードの表示を更新
func update_card_display():
	if name_label:
		name_label.text = card_name
	# subtitle_label削除済み
	if cost_label:
		cost_label.text = str(card_cost)
	if description_label:
		description_label.text = card_description
	if left_stat_label:
		left_stat_label.text = str(left_stat)
	if right_stat_label:
		right_stat_label.text = str(right_stat)
	if current_hp_label:
		current_hp_label.text = str(current_hp)
	# ascended_banner削除済み
	if card_art and card_texture:
		card_art.texture = card_texture

# カードデータをセット
func set_card_data(data: Dictionary):
	if data.has("name"):
		card_name = data.name
	# subtitle削除済み
	if data.has("cost"):
		card_cost = data.cost
	if data.has("description"):
		card_description = data.description
	if data.has("left_stat"):
		left_stat = data.left_stat
	if data.has("right_stat"):
		right_stat = data.right_stat
	# ascended削除済み
	if data.has("texture"):
		card_texture = data.texture
	
	update_card_display()

# 個別の値を設定する関数
func set_cost(value: int):
	card_cost = value
	if cost_label:
		cost_label.text = str(value)

func set_card_name(value: String):
	card_name = value
	if name_label:
		name_label.text = value

# set_subtitle関数削除済み

func set_description(value: String):
	card_description = value
	if description_label:
		description_label.text = value

func set_left_stat(value: int):
	left_stat = value
	if left_stat_label:
		left_stat_label.text = str(value)

func set_right_stat(value: int):
	right_stat = value
	if right_stat_label:
		right_stat_label.text = str(value)

func set_current_hp(value: int):
	current_hp = value
	if current_hp_label:
		current_hp_label.text = str(value)

func set_max_hp(value: int):
	max_hp = value
	if right_stat_label:
		right_stat_label.text = str(value)

# set_ascended関数削除済み

func set_card_art(texture: Texture2D):
	card_texture = texture
	if card_art:
		card_art.texture = texture
