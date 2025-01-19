@tool
class_name DeckData
extends Resource

@export var deck_type : CardData.CARD_TYPE:
	set(value):
		if deck_type != value:
			deck_type = value
			emit_changed()
@export var deck_orientation : DECK_ORIENTATION:
	set(value):
		if deck_orientation != value:
			deck_orientation = value
			emit_changed()
@export var deck : Array[CardData]:
	set(value):
		if deck != value:
			deck = value
			emit_changed()
	
enum DECK_ORIENTATION {LANDSCAPE, PORTRAIT}
