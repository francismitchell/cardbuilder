@tool
class_name BoardData
extends Resource

@export var board : Array[CardData]:
	set(value):
		if board != value:
			board = value
			emit_changed()
