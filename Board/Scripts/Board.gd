@tool
class_name Board
extends Node2D

enum BoardState {PLACING_CARDS, PLAYER_TURN, ENEMY_TURN}

signal empty_tile_pressed
signal enemy_card_attacking_player
signal board_state_changed
signal selected_tile_changed
signal enemy_card_killed
signal player_win

const CARD_X_SEPARATION_PX : int = 384
const CARD_Y_SEPARATION_PX : int = 384
const ENEMY_MOVE_INTERVAL_SEC : float = 0.4
const card_scene = preload("res://Cards/BaseCard.tscn")

var board_state : BoardState = BoardState.PLACING_CARDS: set = set_state
var selected_tile : BoardTile:
	set(value):
		selected_tile_changed.emit(value)
		var previous_selected_tile = selected_tile
		if value != selected_tile:
			selected_tile = value
		# if no selected tile then show which ones can be clicked
		if not value:
			previous_selected_tile.highlight_state = BoardTile.HighlightState.NEUTRAL
			_show_clickable_tiles()
		# otherwise highlighted the selected tile
		else:
			selected_tile.highlight_state = BoardTile.HighlightState.CLICKED
var cards_played_this_round : Array[int]
	
@export var toggle_populate_board : bool = false:
	set(value):
		_populate_board()
@export var board_data : BoardData:
	set(value):
		if board_data != value:
			board_data = value
		if board_data:
			if not board_data.changed.is_connected(_on_board_data_changed):
				board_data.changed.connect(_on_board_data_changed)
		
func _ready() -> void:	
	for child : BoardTile in get_children():
		if not child.tile_pressed.is_connected(_on_board_tile_pressed):
			child.tile_pressed.connect(_on_board_tile_pressed)
		if not child.tile_mouse_entered.is_connected(_on_board_tile_mouse_entered):
			child.tile_mouse_entered.connect(_on_board_tile_mouse_entered)
		if not child.tile_mouse_exited.is_connected(_on_board_tile_mouse_exited):
			child.tile_mouse_exited.connect(_on_board_tile_mouse_exited)
		if not child.tile_card_killed.is_connected(_on_board_tile_card_killed):
			child.tile_card_killed.connect(_on_board_tile_card_killed)
			
	_populate_board()
	
func set_state(state : BoardState) -> void:
	board_state_changed.emit(state)
	var _previous_state = board_state
	# call this here as the callback function _progress_enemies changes the state at the end of its loop
	board_state = state
	if _previous_state == BoardState.PLAYER_TURN and state == BoardState.ENEMY_TURN:
		# apply status effects to player cards
		_apply_status_effects(CardData.CARD_TEAM.FRIENDLY)
	if state == BoardState.PLAYER_TURN:
		get_parent().create_table_callout("Player turn") # bit hacky - can improve 
		# reset list tracking which cards have been played this round
		cards_played_this_round.clear()
		# half-highlight cards that player can move (clickable cards)
		_show_clickable_tiles()
	if state == BoardState.ENEMY_TURN:
		get_parent().create_table_callout("Enemy turn") # bit hacky - can improve 
		# progress all enemy cards forward
		await _progress_enemies()
		# see if any enemies are left
		var enemies_left : bool = false
		for child : BoardTile in get_children():
			if child.tile_state == BoardTile.TileState.CONTAINS_ENEMY_CARD:
				enemies_left = true
		if not enemies_left:
			player_win.emit()
		# apply status effects
		_apply_status_effects(CardData.CARD_TEAM.ENEMY)
		
func get_complete_player_cards() -> DeckData:
	var deck : Array[CardData]
	for child : BoardTile in get_children():
		if child.tile_state == BoardTile.TileState.CONTAINS_PLAYER_CARD:
			deck.append(child.get_card().card_data)
	var deck_data : DeckData = DeckData.new()
	deck_data.deck_type = CardData.CARD_TYPE.COMPLETE_CARD
	deck_data.deck_orientation = DeckData.DECK_ORIENTATION.LANDSCAPE
	deck_data.deck = deck
	return deck_data

func _attack_enemy(attacking_tile : BoardTile, defending_tile : BoardTile) -> void:
	# get attacker and defender cards
	var attacking_card : Card = attacking_tile.get_card()
	var defending_card : Card = defending_tile.get_card()
	# calculate attack damage depending on attacking card ability
	var attack_dmg : int  = attacking_card.card_data.card_ap
	match attacking_card.card_data.card_ap_ability:
		CardData.CardApAbility.BLEED:
			if CardData.CardStatus.BLEEDING not in defending_card.card_data.card_statuses:
				defending_card.card_data.card_statuses.append(CardData.CardStatus.BLEEDING)
				defending_tile.create_damage_callout("Bleeding!")
		CardData.CardApAbility.DISARM:
			if CardData.CardStatus.DISARMED not in defending_card.card_data.card_statuses:
				defending_card.card_data.card_statuses.append(CardData.CardStatus.DISARMED)
				defending_tile.create_damage_callout("Disarmed!")
		CardData.CardApAbility.INSTANT_KILL:
			attack_dmg += 999
			defending_tile.create_damage_callout("Instakill!")
		CardData.CardApAbility.LIFESTEAL:
			attacking_card.current_hp += attacking_card.card_data.card_ap
			defending_tile.create_damage_callout("Lifesteal!")
	# check if any debuffs modify damage
	for status : CardData.CardStatus in attacking_card.card_data.card_statuses:
		match status:
			CardData.CardStatus.DISARMED:
				attack_dmg = 0
				attacking_tile.create_damage_callout("Disarmed!")
	# apply damage to defending card
	if attack_dmg > 0:
		defending_card.damage_card(attack_dmg)
		defending_tile.create_damage_callout("Damaged!")
		# check if defending card has any effects that damage attacker
		match defending_card.card_data.card_hp_ability:
			CardData.CardHpAbility.SPINES:
				if CardData.CardStatus.BLEEDING not in attacking_card.card_data.card_statuses:
					attacking_card.card_data.card_statuses.append(CardData.CardStatus.BLEEDING)
					attacking_tile.create_damage_callout("Spiked!")
	
func _move_card_to_tile(from_tile: BoardTile, to_tile : BoardTile) -> void:
	# first store card data to be transferred
	var card_data_to_transfer : CardData = from_tile.get_card().card_data
	# then animate card moving to new tile position
	from_tile.get_card().z_index += 1
	var tween = get_tree().create_tween()
	tween.tween_property(from_tile.get_card(), "global_position", to_tile.global_position, 0.4).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	await tween.finished
	# remove card from original tile and add new card to target tile
	from_tile.remove_card()
	to_tile.add_card(card_data_to_transfer)
	
func _progress_enemies() -> void:
	# first get a list of tiles containing enemy cards
	var enemy_card_tiles : Array[BoardTile]
	var board_tiles := get_children()
	# reverse board tiles so we start attacking with those closest to player
	board_tiles.reverse()
	for child : BoardTile in board_tiles:
		if child.tile_state == BoardTile.TileState.CONTAINS_ENEMY_CARD:
			enemy_card_tiles.append(child)
			# highlight card
			child.highlight_state = BoardTile.HighlightState.HOVER
	for enemy_tile : BoardTile in enemy_card_tiles:
		# start unhighlighting this tile
		enemy_tile.highlight_state = BoardTile.HighlightState.NEUTRAL
		var next_row_idx = int(enemy_tile.name.split("BoardTile")[1]) + 4
		# see if card in final row before player
		if next_row_idx > 15:
			# attack player
			enemy_card_attacking_player.emit(enemy_tile.get_card())
			await get_tree().create_timer(ENEMY_MOVE_INTERVAL_SEC).timeout
			continue
		var board_tile : BoardTile = get_node("BoardTile" + str(next_row_idx))
		if board_tile.tile_state == BoardTile.TileState.EMPTY:
			# highlight the space
			board_tile.highlight_state = BoardTile.HighlightState.CLICKED
			# move into space
			_move_card_to_tile(enemy_tile, board_tile)
			await get_tree().create_timer(ENEMY_MOVE_INTERVAL_SEC).timeout
		elif board_tile.tile_state == BoardTile.TileState.CONTAINS_PLAYER_CARD:
			# highlight the space
			board_tile.highlight_state = BoardTile.HighlightState.CLICKED
			_attack_enemy(enemy_tile, board_tile)
			# see if attack killed enemy (tile will now be empty)
			if enemy_tile.tile_state == BoardTile.TileState.EMPTY:
				_move_card_to_tile(enemy_tile, board_tile)
			await get_tree().create_timer(ENEMY_MOVE_INTERVAL_SEC).timeout
		else:
			await get_tree().create_timer(ENEMY_MOVE_INTERVAL_SEC).timeout
		# reset tile highlight states once logic complete
		board_tile.highlight_state = BoardTile.HighlightState.NEUTRAL
	# end turn
	board_state = BoardState.PLAYER_TURN
	
func _apply_status_effects(team : CardData.CARD_TEAM) -> void:
	# first get a list of tiles containing cards
	var card_tiles : Array[BoardTile]
	var board_tiles := get_children()
	# reverse board tiles so we start applying with those closest to player
	board_tiles.reverse()
	for child : BoardTile in board_tiles:
		if child.tile_state != BoardTile.TileState.EMPTY:
			if child.get_card().card_data.card_team == team:
				card_tiles.append(child)
	for tile : BoardTile in card_tiles:
		for status : CardData.CardStatus in tile.get_card().card_data.card_statuses:
			match status:
				CardData.CardStatus.BLEEDING:
					tile.get_card().damage_card(1)
					tile.create_damage_callout("Bleeding!")
	
func _show_clickable_tiles() -> void:
	for child : BoardTile in get_children():
		if child.tile_state == BoardTile.TileState.CONTAINS_PLAYER_CARD:
			if child.get_card().card_data.get_instance_id() not in cards_played_this_round:
				child.highlight_state = BoardTile.HighlightState.CLICKABLE
	
func _hide_clickable_tiles() -> void:
	for child : BoardTile in get_children():
		if child.tile_state == BoardTile.TileState.CONTAINS_PLAYER_CARD and child.highlight_state == BoardTile.HighlightState.CLICKABLE:
			child.highlight_state = BoardTile.HighlightState.NEUTRAL
	
# helper functions called by table to show where player can place cards during setup
func show_placeable_tiles() -> void:
	for child : BoardTile in get_children():
		if child.can_place_card:
			child.highlight_state = BoardTile.HighlightState.CLICKABLE
			
func hide_placeable_tiles() -> void:
	for child : BoardTile in get_children():
		if child.can_place_card:
			child.highlight_state = BoardTile.HighlightState.NEUTRAL
			
func _populate_board() -> void:
	var i = 0
	for card_data in board_data.board:
		var board_tile : BoardTile = get_node("BoardTile" + str(i))
		if card_data == null: 
			board_tile.remove_card()
			i += 1
			continue
		board_tile.add_card(card_data)
		i += 1
	
func _on_board_data_changed() -> void:
	for card_data in board_data.board:
		if card_data == null: continue
		if not card_data.changed.is_connected(_on_card_data_changed):
			card_data.changed.connect(_on_card_data_changed)
	_populate_board()
	
func _on_card_data_changed() -> void:
	_populate_board()
	
func _highlight_adjacent_tiles(tile : BoardTile) -> void:
	for i in _get_moveable_tile_indicies(int(tile.name.split("BoardTile")[1]), tile.get_card().card_data.card_hp_ability):
		var tile_to_highlight : BoardTile = get_node("BoardTile{0}".format([i]))
		if tile_to_highlight.tile_state != BoardTile.TileState.CONTAINS_PLAYER_CARD:
			tile_to_highlight.highlight_state = BoardTile.HighlightState.CLICKABLE
		
func _unhighlight_adjacent_tiles(tile : BoardTile) -> void:
	for i in _get_moveable_tile_indicies(int(tile.name.split("BoardTile")[1]), tile.get_card().card_data.card_hp_ability):
		var tile_to_highlight : BoardTile = get_node("BoardTile{0}".format([i]))
		tile_to_highlight.highlight_state = BoardTile.HighlightState.NEUTRAL
		
func _on_board_tile_pressed(pressed_tile : BoardTile, can_place_card : bool) -> void:
	if board_state == BoardState.ENEMY_TURN:
		pass
	# behaviour depends on state
	elif board_state == BoardState.PLACING_CARDS:
		print(pressed_tile.name, ' tile pressed placing cards')
		# see if card contained in tile (to-do: make more elegant)
		if not can_place_card:
			# handle logic to show that card cannot be placed in this tile
			return
		if pressed_tile.tile_state == BoardTile.TileState.EMPTY:
			empty_tile_pressed.emit(pressed_tile)
			# show available options, e.g. where it can move/attack
		else:
			pass
	elif board_state == BoardState.PLAYER_TURN:
		print(pressed_tile, ' tile pressed player turn')
		# check that card hasn't been played already
		if pressed_tile.tile_state == BoardTile.TileState.CONTAINS_PLAYER_CARD:
			if pressed_tile.get_card().card_data.get_instance_id() in cards_played_this_round: return
		# if the player clicks an empty tile with no tile selected we do nothing
		if not selected_tile and pressed_tile.tile_state == BoardTile.TileState.EMPTY: return
		# first hide the tiles which were clickable
		_hide_clickable_tiles()
		# handle logic for when a tile has been selected
		if selected_tile:
			# ATTACKING
			if pressed_tile.highlight_state == BoardTile.HighlightState.HOVER and pressed_tile.tile_state == BoardTile.TileState.CONTAINS_ENEMY_CARD:
				print('tile pressed attacking')
				_unhighlight_adjacent_tiles(selected_tile)
				cards_played_this_round.append(selected_tile.get_card().card_data.get_instance_id())
				_attack_enemy(selected_tile, pressed_tile)
				# see if attack killed enemy (tile will now be empty)
				if pressed_tile.tile_state == BoardTile.TileState.EMPTY:
					_move_card_to_tile(selected_tile, pressed_tile)
				selected_tile.highlight_state = BoardTile.HighlightState.NEUTRAL
				selected_tile = null
			# MOVING 
			elif pressed_tile.highlight_state == BoardTile.HighlightState.HOVER:
				_unhighlight_adjacent_tiles(selected_tile)
				cards_played_this_round.append(selected_tile.get_card().card_data.get_instance_id())
				_move_card_to_tile(selected_tile, pressed_tile)
				selected_tile.highlight_state = BoardTile.HighlightState.NEUTRAL
				selected_tile = null
			# deselect tile if unhighlighted or selected tile pressed
			elif pressed_tile.highlight_state != BoardTile.HighlightState.HOVER or pressed_tile == selected_tile:
				_unhighlight_adjacent_tiles(selected_tile)
				selected_tile = null
			# change selected tile
			elif pressed_tile != selected_tile and pressed_tile.tile_state == BoardTile.TileState.CONTAINS_PLAYER_CARD:
				_unhighlight_adjacent_tiles(selected_tile)
				# highlight tiles
				_highlight_adjacent_tiles(pressed_tile)
				selected_tile = pressed_tile
		else:
			if pressed_tile.tile_state == BoardTile.TileState.CONTAINS_PLAYER_CARD:
				# highlight tiles
				_highlight_adjacent_tiles(pressed_tile)
				selected_tile = pressed_tile
	
func _on_board_tile_mouse_entered(hovered_tile : BoardTile):
	if hovered_tile.highlight_state == BoardTile.HighlightState.CLICKED: return
	if hovered_tile.highlight_state == BoardTile.HighlightState.CLICKABLE:
		hovered_tile.highlight_state = BoardTile.HighlightState.HOVER
	
func _on_board_tile_mouse_exited(hovered_tile : BoardTile):
	if hovered_tile.highlight_state == BoardTile.HighlightState.CLICKED: return
	if hovered_tile.highlight_state == BoardTile.HighlightState.HOVER:
		hovered_tile.highlight_state = BoardTile.HighlightState.CLICKABLE
	
func _get_moveable_tile_indicies(tile_idx : int, card_hp_ability : CardData.CardHpAbility) -> Array[int]:
	var moveable_tile_indicies : Array[int]
	if card_hp_ability == CardData.CardHpAbility.HOP:
		# calculate adjacent and diagonal squares
		# tile on left edge
		if tile_idx == 0 or tile_idx % 4 == 0:
			moveable_tile_indicies.append(tile_idx - 8)
			moveable_tile_indicies.append(tile_idx - 4)
			moveable_tile_indicies.append(tile_idx - 3)
		# tile on right edge
		elif (tile_idx + 1) % 4 == 0:
			moveable_tile_indicies.append(tile_idx - 8)
			moveable_tile_indicies.append(tile_idx - 5)
			moveable_tile_indicies.append(tile_idx - 4)
		else:
			moveable_tile_indicies.append(tile_idx - 8)
			moveable_tile_indicies.append(tile_idx - 5)
			moveable_tile_indicies.append(tile_idx - 4)
			moveable_tile_indicies.append(tile_idx - 3)
	else:
		# calculate adjacent and diagonal squares
		if tile_idx == 0 or tile_idx % 4 == 0:
			moveable_tile_indicies.append(tile_idx - 4)
			moveable_tile_indicies.append(tile_idx - 3)
		elif (tile_idx + 1) % 4 == 0:
			moveable_tile_indicies.append(tile_idx - 5)
			moveable_tile_indicies.append(tile_idx - 4)
		else:
			moveable_tile_indicies.append(tile_idx - 5)
			moveable_tile_indicies.append(tile_idx - 4)
			moveable_tile_indicies.append(tile_idx - 3)
			
	var i = moveable_tile_indicies.size() - 1
	while i >= 0:
		if moveable_tile_indicies[i] < 0 or moveable_tile_indicies[i] > 15:
			moveable_tile_indicies.remove_at(i)
		i -= 1
	moveable_tile_indicies.sort()
	
	return moveable_tile_indicies
	
func _get_adjacent_tile_indicies(tile_idx : int) -> Array[int]:
	var adjacent_tile_indicies : Array[int]
	# calculate adjacent and diagonal squares
	if tile_idx == 0 or tile_idx % 4 == 0:
		adjacent_tile_indicies.append(tile_idx - 4)
		adjacent_tile_indicies.append(tile_idx - 3)
		adjacent_tile_indicies.append(tile_idx + 1)
		adjacent_tile_indicies.append(tile_idx + 4)
		adjacent_tile_indicies.append(tile_idx + 5)
	elif (tile_idx + 1) % 4 == 0:
		adjacent_tile_indicies.append(tile_idx - 5)
		adjacent_tile_indicies.append(tile_idx - 4)
		adjacent_tile_indicies.append(tile_idx - 1)
		adjacent_tile_indicies.append(tile_idx + 3)
		adjacent_tile_indicies.append(tile_idx + 4)
	else:
		adjacent_tile_indicies.append(tile_idx - 5)
		adjacent_tile_indicies.append(tile_idx - 4)
		adjacent_tile_indicies.append(tile_idx - 3)
		adjacent_tile_indicies.append(tile_idx - 1)
		adjacent_tile_indicies.append(tile_idx + 1)
		adjacent_tile_indicies.append(tile_idx + 3)
		adjacent_tile_indicies.append(tile_idx + 4)
		adjacent_tile_indicies.append(tile_idx + 5)
	var i = adjacent_tile_indicies.size() - 1
	while i >= 0:
		if adjacent_tile_indicies[i] < 0 or adjacent_tile_indicies[i] > 15:
			adjacent_tile_indicies.remove_at(i)
		i -= 1
	adjacent_tile_indicies.sort()
	
	return adjacent_tile_indicies
		
func _on_board_tile_card_killed(card: Card) -> void:
	if card.card_data.card_team == CardData.CARD_TEAM.ENEMY:
		enemy_card_killed.emit(card)
	
