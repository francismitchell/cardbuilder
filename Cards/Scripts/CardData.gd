@tool
class_name CardData
extends Resource

enum CARD_TYPE {AP_CARD, HP_CARD, COMPLETE_CARD}
enum CARD_TEAM {FRIENDLY, ENEMY}
enum CardApAbility {NONE, BLEED, DISARM, INSTANT_KILL, LIFESTEAL}
enum CardHpAbility {NONE}
enum CardStatus {BLEEDING, DISARMED}

@export var card_team : CARD_TEAM:
	set(value):
		if card_team != value:
			card_team = value
			emit_changed()
@export var card_type : CARD_TYPE:
	set(value):
		if card_type != value:
			card_type = value
			emit_changed()
@export var card_ap_ability : CardApAbility = CardApAbility.NONE:
	set(value):
		if card_ap_ability != value:
			card_ap_ability = value
			emit_changed()
@export var card_hp_ability : CardHpAbility = CardHpAbility.NONE:
	set(value):
		if card_hp_ability != value:
			card_hp_ability = value
			emit_changed()
@export var card_statuses : Array[CardStatus] = []:
	set(value):
		if card_statuses != value:
			card_statuses = value
			emit_changed()
@export var card_name : String:
	set(value):
		if card_name != value:
			card_name = value
			emit_changed()
@export var card_ap_texture : Texture2D:
	set(value):
		if card_ap_texture != value:
			card_ap_texture = value
			emit_changed()
@export var card_hp_texture : Texture2D:
	set(value):
		if card_hp_texture != value:
			card_hp_texture = value
			emit_changed()
@export var card_ap : int = 1:
	set(value):
		if card_ap != value:
			card_ap = value
			emit_changed()
@export var card_hp : int = 1:
	set(value):
		if card_hp != value:
			card_hp = value
			emit_changed()
