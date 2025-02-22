# every scene should handle their own setup and cleanup
# this scene then handles changing scenes
extends Node2D

enum GAME_STATE {MAIN_MENU, CARD_BUILDING, BATTLING}

const SCENE_TRANSITION_TIME = 0.5
const STAGE_TRANSITION_TWEEN = Tween.TRANS_CUBIC
const card_builder_scene = preload("res://Stages/CardBuilder.tscn")
const table_scene = preload("res://Stages/Table.tscn")

# set to card building as default for now as we don't have a main menu
var game_state : GAME_STATE = GAME_STATE.CARD_BUILDING
var card_builder = null
var table = null
var boards : Array[BoardData]
var level := 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	boards.push_back(load("res://Board/BoardLevel1.tres"))
	boards.push_back(load("res://Board/BoardLevel2.tres"))
	load_card_builder()
	
func load_card_builder() -> void:
	# instantiate card builder scene
	card_builder = card_builder_scene.instantiate()
	card_builder.deck_complete.connect(_on_deck_complete)
	if table:
		# free decks that we will replace with those carried over from table scene
		card_builder.get_node('CompleteCardDeck').free()
		card_builder.get_node('ApDeck').free()
		card_builder.get_node('HpDeck').free()
		# free captured decks as we don't want to carry these over to the card builder
		table.get_node('CapturedApDeck').free()
		table.get_node('CapturedHpDeck').free()
		# free nodes from table scene
		for child in table.get_children():
			if child is Deck:
				child.reparent(card_builder)

		table.queue_free()
	add_child(card_builder)
	card_builder.scene_setup()
	
func load_table() -> void:
	table = table_scene.instantiate()
	table.player_win.connect(_on_player_win)
	# free deck which we will replace with the one carried over
	var comp_deck_pos_x = table.get_node('CompleteCardDeck').global_position.x
	table.get_node('CompleteCardDeck').free()
	# free nodes from card builder scene
	for child in card_builder.get_children():
		if child is Deck:
			child.reparent(table)
	table.load_board(boards[level])
	# get rid of cardbuilder
	card_builder.queue_free()
	add_child(table)
	table.scene_setup(comp_deck_pos_x)
	
func _on_deck_complete() -> void:
	await card_builder.scene_shutdown()
	load_table()
	
func _on_player_win() -> void:
	level += 1
	load_card_builder()
