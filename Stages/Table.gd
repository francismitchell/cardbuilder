class_name Table 
extends Node2D

enum TableState {NEUTRAL, PLAYER_HOLDING_CARD, PLAYER_TURN, ENEMY_TURN}

signal player_win
signal battle_started

const callout_label_settings = preload("res://Board/CalloutLabelSettings.tres")

var table_state : TableState = TableState.NEUTRAL: set = set_state
var complete_deck_data : DeckData
var num_selected_cards = 0

func set_state(new_state : TableState) -> void:
	var previous_state = table_state
	table_state = new_state
	if table_state == TableState.PLAYER_HOLDING_CARD:
		# make tiles that card can be placed in visibily show this
		$Board.show_placeable_tiles()
	if previous_state == TableState.PLAYER_HOLDING_CARD:
		$Board.hide_placeable_tiles()
	# this state effectively starts the gameplay following cards being placed
	if table_state == TableState.PLAYER_TURN:
		battle_started.emit()
		$Board.board_state = Board.BoardState.PLAYER_TURN

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not $Board.player_win.is_connected(_on_player_win):
		$Board.player_win.connect(_on_player_win)
	if not $Board.empty_tile_pressed.is_connected(_on_board_empty_tile_pressed):
		$Board.empty_tile_pressed.connect(_on_board_empty_tile_pressed)
	if not $Board.enemy_card_attacking_player.is_connected(_on_board_enemy_card_attacking_player):
		$Board.enemy_card_attacking_player.connect(_on_board_enemy_card_attacking_player)
	if not $Board.enemy_card_killed.is_connected(_on_board_enemy_card_killed):
		$Board.enemy_card_killed.connect(_on_board_enemy_card_killed)
	if not $CompleteCardDeck.card_selected.is_connected(_on_deck_card_selected):
		$CompleteCardDeck.card_selected.connect(_on_deck_card_selected)
	if not $CompleteCardDeck.card_deselected.is_connected(_on_deck_card_deselected):
		$CompleteCardDeck.card_deselected.connect(_on_deck_card_deselected)
	if not $CapturedApDeck.card_selected.is_connected(_on_captured_ap_deck_card_selected):
		$CapturedApDeck.card_selected.connect(_on_captured_ap_deck_card_selected)
	if not $CapturedHpDeck.card_selected.is_connected(_on_captured_hp_deck_card_selected):
		$CapturedHpDeck.card_selected.connect(_on_captured_hp_deck_card_selected)
	
func scene_setup() -> void:
	# move board off screen initially
	var board_final_position_x : int = $Board.global_position.x 
	$Board.global_position.x = 1215
	$ApDeck.deck_unfold_node = $ApUnfoldLoc
	$HpDeck.deck_unfold_node = $HpUnfoldLoc
	var tween = get_tree().create_tween()
	tween.parallel().tween_property($CompleteCardDeck, "global_position:x", 125, 0.5)
	tween.parallel().tween_property($Board, "global_position:x", board_final_position_x, 0.5)
	await tween.finished
	$CompleteCardDeck.deck_state = Deck.DeckState.UNFOLDED
	$CapturedApDeck.clear_deck()
	$CapturedHpDeck.clear_deck()

	
func _on_captured_ap_deck_card_selected(card : Card) -> void:
	$ApDeck.add_card_data(card.card_data)
	$ApDeck.get_children().back().global_position = card.global_position
	$CapturedApDeck.erase_selected_card()
	$ApDeck.deck_state = Deck.DeckState.UNFOLDED
	num_selected_cards += 1
	if num_selected_cards >= 2:
		change_scene()
	
func _on_captured_hp_deck_card_selected(card : Card) -> void:
	$HpDeck.add_card_data(card.card_data)
	$HpDeck.get_children().back().global_position = card.global_position
	$CapturedHpDeck.erase_selected_card()
	$HpDeck.deck_state = Deck.DeckState.UNFOLDED
	num_selected_cards += 1
	if num_selected_cards >= 2:
		change_scene()

func _on_player_win() -> void:
	print(name, ' processing win')
	create_table_callout("Player win!") # bit hacky - can improve 
	# fold cards back into complete cards deck
	fold_board_cards()
	$CompleteCardDeck.deck_state = Deck.DeckState.UNFOLDED
	# show captured cards 
	$CapturedApDeck.deck_state = Deck.DeckState.STACKED
	$CapturedHpDeck.deck_state = Deck.DeckState.STACKED
	await $CapturedHpDeck.deck_stacked
	await get_tree().create_timer(0.5).timeout
	var tween = get_tree().create_tween()
	$ApDeck.global_position.x = 950
	$HpDeck.global_position.x = 950
	tween.parallel().tween_property($ApDeck,"global_position:y",$ApDeck.global_position.y+500,0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property($HpDeck,"global_position:y",$HpDeck.global_position.y-500,0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	#tween.parallel().tween_property($ApDeck,"global_position:x",200,0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	#tween.parallel().tween_property($HpDeck,"global_position:x",200,0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property($CapturedApDeck, "global_position:x", 300, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property($CapturedHpDeck, "global_position:x", 300, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished
	$CapturedApDeck.deck_state = Deck.DeckState.UNFOLDED
	$CapturedHpDeck.deck_state = Deck.DeckState.UNFOLDED
	$ApDeck.show()
	$HpDeck.show()
	$ApDeck.deck_state = Deck.DeckState.UNFOLDED
	$HpDeck.deck_state = Deck.DeckState.UNFOLDED
	$CompleteCardDeck.deck_state = Deck.DeckState.UNFOLDED
	create_table_callout("Select two cards")
	
# todo: better naming and fit into other logic better
func change_scene() -> void:
	for child in $CapturedApDeck.get_children():
		var tween = get_tree().create_tween()
		tween.tween_property(child, "scale", Vector2(), 0.2).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	for child in $CapturedHpDeck.get_children():
		var tween = get_tree().create_tween()
		tween.tween_property(child, "scale", Vector2(), 0.2).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(0.5).timeout
	$ApDeck.deck_state = Deck.DeckState.STACKED
	$HpDeck.deck_state = Deck.DeckState.STACKED
	$CompleteCardDeck.deck_state = Deck.DeckState.STACKED
	await get_tree().create_timer(0.3).timeout
	var tween = get_tree().create_tween()
	tween.parallel().tween_property($ApDeck, "global_position:y", $ApDeck.global_position.y - 500, 0.5)
	tween.parallel().tween_property($HpDeck, "global_position:y", $HpDeck.global_position.y + 500, 0.5)
	tween.parallel().tween_property($CompleteCardDeck, "global_position:x", 1018, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.5).timeout
	player_win.emit()
	
func _on_board_enemy_card_attacking_player(enemy_card : Card) -> void:
	# tween card attacking player
	var tween = get_tree().create_tween()
	var original_position = enemy_card.global_position
	tween.tween_property(enemy_card, "global_position", original_position + Vector2(0,64),0.2).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	await tween.finished
	var tween2 = get_tree().create_tween()
	$PlayerHealth.set_value($PlayerHealth.get_value() - enemy_card.card_data.card_ap)
	tween2.tween_property(enemy_card, "global_position", original_position,0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween2.finished
	
func _on_deck_card_selected(_card : Card) -> void:
	table_state = TableState.PLAYER_HOLDING_CARD

func _on_deck_card_deselected(_card : Card) -> void:
	table_state = TableState.NEUTRAL

func _on_board_empty_tile_pressed(board_tile : BoardTile) -> void:
	if $CompleteCardDeck.selected_card:
		board_tile.add_card($CompleteCardDeck.selected_card.card_data)
		$CompleteCardDeck.erase_selected_card()
		table_state = TableState.NEUTRAL
	
func _on_board_enemy_card_killed(card_to_bisect : Card) -> void:
	print('enemy card killed')
	# create ap and hp cards from complete card
	var new_ap_card_data : CardData = CardData.new()
	new_ap_card_data.card_type = CardData.CARD_TYPE.AP_CARD
	new_ap_card_data.card_ap = card_to_bisect.card_data.card_ap
	new_ap_card_data.card_ap_texture = card_to_bisect.card_data.card_ap_texture
	var new_hp_card_data : CardData = CardData.new()
	new_hp_card_data.card_type = CardData.CARD_TYPE.HP_CARD
	new_hp_card_data.card_hp = card_to_bisect.card_data.card_hp
	new_hp_card_data.card_hp_texture = card_to_bisect.card_data.card_hp_texture
	## fold decks to show we are putting cards in them
	#$ApDeck.deck_state = Deck.DeckState.FOLDED
	#await $ApDeck.deck_folded
	#$HpDeck.deck_state = Deck.DeckState.FOLDED
	#await $HpDeck.deck_folded
	#await get_tree().create_timer(0.2).timeout
	# add cards to deck
	$CapturedApDeck.add_card_data(new_ap_card_data)
	print("captured ap deck num cards: ", $CapturedApDeck.get_children().size())
	$CapturedHpDeck.add_card_data(new_hp_card_data)
	print("captured ap deck num cards: ", $CapturedHpDeck.get_children().size())
	# put cards back to start position so that tween plays correctly
	$CapturedApDeck.get_children().back().global_position = card_to_bisect.global_position
	$CapturedHpDeck.get_children().back().global_position = card_to_bisect.global_position
	#$CapturedApDeck.deck_state = Deck.DeckState.STACKED
	#$CapturedApDeck.deck_state = Deck.DeckState.FOLDED
	$CapturedApDeck.fold_card($CapturedApDeck.get_children().back())
	await get_tree().create_timer(0.2).timeout
	$CapturedHpDeck.fold_card($CapturedHpDeck.get_children().back())
	#$CapturedHpDeck.deck_state = Deck.DeckState.STACKED
	#$CapturedHpDeck.deck_state = Deck.DeckState.FOLDED
	
func _on_play_button_pressed() -> void:
	table_state = TableState.PLAYER_TURN
	$CompleteCardDeck.deck_state = Deck.DeckState.FOLDED
	$PlayButton.hide()

func _on_end_turn_button_pressed() -> void:
	$Board.board_state = Board.BoardState.ENEMY_TURN

func _on_enemy_health_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			# check if board selected card is a player card
			if $Board.selected_tile:
				var board_selected_tile : BoardTile = $Board.selected_tile
				if int(board_selected_tile.name.split('BoardTile')[1]) <= 3:
					$EnemyHealth.set_value($EnemyHealth.get_value() - board_selected_tile.get_card().card_data.card_ap)
					$Board.cards_played_this_round.append(board_selected_tile.get_card().card_data.get_instance_id())
					$Board.selected_tile = null
					
	
func _on_enemy_health_value_changed(value: float) -> void:
	if value <= 0:
		player_win.emit()

func stack_decks() -> void:
	# first put all the cards from the board back into the complete deck
	for child : BoardTile in $Board.get_children():
		if child.tile_state == BoardTile.TileState.CONTAINS_PLAYER_CARD:
			$CompleteCardDeck.add_card_data(child.get_card().card_data)
			$CompleteCardDeck.get_children().back().global_position = child.get_card().global_position
			child.remove_card()
	$CompleteCardDeck.deck_state = Deck.DeckState.FOLDED
	await $CompleteCardDeck.deck_folded
	# then stack all cards simultaneously
	$ApDeck.deck_state = Deck.DeckState.STACKED
	$HpDeck.deck_state = Deck.DeckState.STACKED
	$CompleteCardDeck.deck_state = Deck.DeckState.STACKED
	# to-do: find another way to wait for all decks to be stacked first
	await get_tree().create_timer(0.3).timeout

# fold the remaining cards on the board back into the complete card deck
func fold_board_cards() -> void:
	for child : BoardTile in $Board.get_children():
		if child.tile_state == BoardTile.TileState.CONTAINS_PLAYER_CARD:
			$CompleteCardDeck.add_card_data(child.get_card().card_data)
			$CompleteCardDeck.get_children().back().global_position = child.get_card().global_position
			child.remove_card()

func create_table_callout(callout_text : String) -> void:
	var callout = Label.new()
	callout.label_settings = callout_label_settings
	callout.text = callout_text
	add_child(callout)
	callout.position = get_node('Board').position
	callout.scale = Vector2(0.5,0.5)
	callout.z_index = 10
	# animate floating and fading	
	var tween = get_tree().create_tween()
	tween.parallel().tween_property(callout, "modulate", Color.TRANSPARENT, 2.0)
	tween.parallel().tween_property(callout, "position:y", callout.position.y - 128, 2.0)
	tween.tween_callback(callout.queue_free)
	
func load_board(board_data : BoardData):
	$Board.board_data = board_data
