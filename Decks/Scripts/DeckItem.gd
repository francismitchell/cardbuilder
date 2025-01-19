class_name DeckItem
extends Resource

@export var card_data : CardData:
	set(value):
		if card_data != value:
			card_data = value
			emit_changed()
var selected : bool
var card : Node2D
var neutral_position : Vector2
