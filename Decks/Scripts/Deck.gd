@tool
class_name Deck extends TextureRect

enum DeckState {STACKED, FOLDED, UNFOLDED}

signal card_selected
signal card_deselected
signal deck_folded
signal deck_stacked
signal deck_unfolded

const card_scene = preload("res://Cards/BaseCard.tscn")
const CARD_X_OFFSET_PX = 160
const CARD_Y_TOGGLE_OFFSET_PX = 32
const DECK_FOLD_TIME_PER_CARD = 0.1
const DECK_UNFOLD_TIME_PER_CARD = 0.15

var selected_card : Card
var hovered_card : Card
var deck_position : Vector2
var folded : bool = false
var deck_state : DeckState: set = set_deck_state
var hovered_cards : Array[Card]

@export var DECK_CARD_MAX_SEPARATION = 128
@export var fold_deck : bool:
	set(value):
		if Engine.is_editor_hint():
			deck_state = DeckState.FOLDED
@export var unfold_deck : bool:
	set(value):
		if Engine.is_editor_hint():
			deck_state = DeckState.UNFOLDED
@export var deck_unfold_node : Marker2D:
	set(value):
		if value != deck_unfold_node:
			deck_unfold_node = value
@export var deck_width_px = 960
@export var deck_data : DeckData:
	set(value):
		deck_data = value
		if deck_data:
			if not deck_data.changed.is_connected(_on_deck_data_changed):
				deck_data.changed.connect(_on_deck_data_changed)
				
func set_deck_state(state):
	print(name, ' changing deck state to ', state)
	var previous_state = deck_state
	deck_state = state
	if state == DeckState.STACKED:
		if get_children().size() > 0:
			var tween = get_tree().create_tween()
			for card : Card in get_children():
				if card.is_queued_for_deletion(): continue
				var end_position = global_position
				if deck_data.deck_type == CardData.CARD_TYPE.AP_CARD:
					end_position.y += size.y * scale.y
				end_position.x += size.x * scale.x / 2
				tween.parallel().tween_property(card, "global_position", end_position, DECK_FOLD_TIME_PER_CARD)
			await tween.finished
		deck_stacked.emit()
	if state == DeckState.FOLDED:
		var i = 0
		for card : Card in get_children():
			if card.is_queued_for_deletion(): continue
			var tween = get_tree().create_tween()
			var end_position = global_position
			if deck_data.deck_orientation == DeckData.DECK_ORIENTATION.LANDSCAPE:
				if deck_data.deck_type == CardData.CARD_TYPE.AP_CARD:
					end_position.y += size.y * scale.y
				end_position.x += size.x * scale.x / 2
				end_position.x += 16*i
			else:
				if deck_data.deck_type == CardData.CARD_TYPE.AP_CARD:
					end_position.y += size.y * scale.y
				end_position.x += size.x * scale.x / 2
				end_position.y += 16*i #deck_width_px - 16*i
				#end_position.y -= 130
			tween.tween_property(card, "global_position", end_position, DECK_FOLD_TIME_PER_CARD)
			# fold cards simultaneously if previously stacked
			if previous_state == DeckState.STACKED:
				pass
			else:
				await tween.finished
			i += 1
		# if removed then the signal won't be picked up if emitted by empty deck
		await get_tree().create_timer(0.001).timeout
		deck_folded.emit()
	if state == DeckState.UNFOLDED:
		# count number of non-null cards in deck
		var number_cards : int = deck_data.deck.size() - deck_data.deck.count(null)
		# how far apart each card should be
		var card_x_offset = float(deck_width_px) / (float(number_cards)-1) if number_cards > 1 else 0.0
		# clamp offset at a max separation
		card_x_offset = minf(card_x_offset, DECK_CARD_MAX_SEPARATION)
		# get cards
		var cards : Array[Card]
		for child in get_children():
			if child is Card:
				cards.push_back(child)
		if deck_data.deck_type == CardData.CARD_TYPE.AP_CARD: cards.reverse()
		var i = 0
		for card : Card in cards:
			# skip cards that will be gone next turn
			if card.is_queued_for_deletion(): continue
			var unfold_position = Vector2()
			# set position dependent on index and deck settings
			if deck_data.deck_orientation == DeckData.DECK_ORIENTATION.LANDSCAPE:
				if deck_data.deck_type == CardData.CARD_TYPE.AP_CARD:
					unfold_position.x = (number_cards-i-1) * card_x_offset
					if not deck_unfold_node:
						unfold_position.y += size.y
				elif deck_data.deck_type == CardData.CARD_TYPE.HP_CARD:
					unfold_position.x = (number_cards-i-1) * card_x_offset
				elif deck_data.deck_type == CardData.CARD_TYPE.COMPLETE_CARD:
					unfold_position.x = i * card_x_offset
			elif deck_data.deck_orientation == DeckData.DECK_ORIENTATION.PORTRAIT:
				if deck_data.deck_type == CardData.CARD_TYPE.AP_CARD:
					unfold_position.y = (number_cards - i) * card_x_offset - card_x_offset
				else:
					unfold_position.y = i * card_x_offset
			# displace by deck unfold node if set
			if deck_unfold_node:
				unfold_position += deck_unfold_node.global_position
			# move card
			var tween = get_tree().create_tween()
			if deck_unfold_node:
				tween.tween_property(card, "global_position", unfold_position, DECK_UNFOLD_TIME_PER_CARD)
			else:
				tween.tween_property(card, "position", unfold_position, DECK_UNFOLD_TIME_PER_CARD)
			if previous_state == DeckState.STACKED or previous_state == DeckState.UNFOLDED:
				pass # unfold cards simultaneously
			else:
				await tween.finished
			i += 1
		print('deck unfolded being emitted')
		deck_unfolded.emit()

# deck is reparented between scenes so clear reference to unfold node when unparented
func _notification(what: int) -> void:
	if what == NOTIFICATION_UNPARENTED:
		deck_unfold_node = null
			
func _ready() -> void:
	if not deck_data.changed.is_connected(_on_deck_data_changed):
		deck_data.changed.connect(_on_deck_data_changed)
	deck_position = global_position
	# centre cards on deck
	if deck_data.deck_type == CardData.CARD_TYPE.AP_CARD:
		deck_position.y += size.y * scale.y
	deck_position.x += size.x * scale.x / 2
	for child in get_children():
		child.free()
	for card_data in deck_data.deck:
		if card_data:
			add_card_node(card_data)
	
func add_card_data(card_data : CardData) -> void:
	deck_data.deck.append(card_data)
	add_card_node(deck_data.deck.back())
	
func add_card_node(card_data : CardData) -> void:
	# instantiate new card
	var new_card = card_scene.instantiate()
	new_card.card_data = card_data
	new_card.card_pressed.connect(_on_card_pressed)
	new_card.card_mouse_entered.connect(_on_card_mouse_entered)
	new_card.card_mouse_exited.connect(_on_card_mouse_exited)
	new_card.card_mouse_motion.connect(_on_mouse_motion)
	new_card.global_position = deck_position
	add_child(new_card)
	new_card._on_card_data_changed()
	new_card.owner = self

func assign_card_neutral_positions() -> void:
	# count number of non-null cards in deck
	var number_cards : int = deck_data.deck.size() - deck_data.deck.count(null)
	if number_cards == 0: return
	# how far apart each card should be
	var card_x_offset
	if number_cards > 1:
		card_x_offset = float(deck_width_px) / (float(number_cards)-1)
	else:
		card_x_offset = 0
	card_x_offset = min(card_x_offset, DECK_CARD_MAX_SEPARATION)
	var i = 0
	var tmp : Array[Card]
	for card : Card in get_children():
		if card.is_queued_for_deletion() or card.card_data not in deck_data.deck: continue
		tmp.append(card)
	if deck_data.deck_type == CardData.CARD_TYPE.AP_CARD: tmp.reverse()
	for card : Card in tmp:
		if card.is_queued_for_deletion() or card.card_data not in deck_data.deck: continue
		# reset card neutral position
		card.neutral_position = Vector2()
		if deck_data.deck_orientation == DeckData.DECK_ORIENTATION.LANDSCAPE:
			if deck_data.deck_type == CardData.CARD_TYPE.AP_CARD:
				card.neutral_position.x = (number_cards-i-1) * card_x_offset
				if not deck_unfold_node:
					card.neutral_position.y += size.y
			elif deck_data.deck_type == CardData.CARD_TYPE.HP_CARD:
				card.neutral_position.x = (number_cards-i-1) * card_x_offset
			elif deck_data.deck_type == CardData.CARD_TYPE.COMPLETE_CARD:
				card.neutral_position.x = i * card_x_offset
		elif deck_data.deck_orientation == DeckData.DECK_ORIENTATION.PORTRAIT:
			if deck_data.deck_type == CardData.CARD_TYPE.AP_CARD:
				card.neutral_position.y = (number_cards - i) * card_x_offset - card_x_offset
			else:
				card.neutral_position.y = i * card_x_offset
				
		if deck_unfold_node:
			card.neutral_position += deck_unfold_node.global_position

		i += 1
		
func clear_deck() -> void:
	deck_data.deck.clear()
	for child : Card in get_children():
		child.queue_free()
		
func erase_selected_card() -> void:
	deck_data.deck.erase(selected_card.card_data)
	selected_card.queue_free()
	selected_card = null
	hovered_card = null

# fold a single card into the deck, e.g. when just captured enemy cards
func fold_card(card : Card) -> void:
	var idx = deck_data.deck.find(card.card_data)
	var end_position = global_position
	if deck_data.deck_orientation == DeckData.DECK_ORIENTATION.LANDSCAPE:
		if deck_data.deck_type == CardData.CARD_TYPE.AP_CARD:
			end_position.y += size.y * scale.y
		end_position.x += size.x * scale.x
		end_position.x -= 16*idx
	else:
		if deck_data.deck_type == CardData.CARD_TYPE.AP_CARD:
			end_position.x += size.y * scale.y
		end_position.y += size.x * scale.x / 2
		end_position.y += 16*idx
	var tween = get_tree().create_tween()
	tween.tween_property(card, "global_position", end_position, DECK_FOLD_TIME_PER_CARD).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	await tween.finished
	
func _on_deck_data_changed() -> void:
	print(name, ' deck changed')
	var card_node_card_data : Array[CardData]
	# make list of card data stored in card nodes
	# delete card nodes where corresponding card data no longer exists
	for child in get_children():
		if child.is_queued_for_deletion(): continue
		if child.card_data in deck_data.deck:
			card_node_card_data.append(child.card_data)
		else:
			child.queue_free()
	# check which deck card data is in the card node card data list
	# if deck card data not in this list then add a card node for it
	for card_data in deck_data.deck:
		if card_data not in card_node_card_data and card_data != null:
			# add node
			add_card_node(card_data)

# callback function to deal with card hovering
func _on_mouse_motion(card: Card, mouse_pos: Vector2) -> void:
	# find closest card to mouse pos
	var closest_card : Card = card
	# find closest card 
	for child : Card in get_children():
		if child.global_position.distance_squared_to(mouse_pos) < closest_card.global_position.distance_squared_to(mouse_pos):
			closest_card = child
	if hovered_card and hovered_card != closest_card:
		hovered_card.unhover()
		hovered_card = closest_card
		hovered_card.hover(mouse_pos)
	else:
		hovered_card = closest_card
		hovered_card.hover(mouse_pos)

	
			
func _on_card_mouse_entered(card: Card) -> void:
	pass
	#if deck_state != DeckState.UNFOLDED: return
	#
	#
	#
	#
	#if hovered_cards.size() > 0:
		#var tween = get_tree().create_tween()
		#tween.tween_property(hovered_cards.back(), "scale", Vector2(1,1), 0.2)
		#hovered_cards.back().z_index = 0
	#hovered_cards.push_back(card)
	##print(hovered_cards)
	#if card != selected_card:
		#card.z_index = 1
		#var tween = get_tree().create_tween()
		#tween.tween_property(card, "scale", Vector2(1.1,1.1), 0.05)
	
func _on_card_mouse_exited(card: Node2D) -> void:
	card.unhover()
		
	#if deck_state != DeckState.UNFOLDED: return
	#hovered_cards.erase(card)
	#if hovered_cards.size() > 0:
		#hovered_cards.back().z_index = 1
		#var tween = get_tree().create_tween()
		#tween.tween_property(hovered_cards.back(), "scale", Vector2(1.1,1.1), 0.05)
	##print(hovered_cards)
	#if card != selected_card:
		#card.z_index = 0
		#var tween = get_tree().create_tween()
		#tween.tween_property(card, "scale", Vector2(1,1), 0.2)
	
func _on_card_pressed(card: Card) -> void:
	if deck_state != DeckState.UNFOLDED: return
	if card != hovered_card: return
	# is there currently a selected card?
	if not selected_card:
		selected_card = card
		# signal that this card has been pressed
		card_selected.emit(card)
	# is this deck item currently selected?
	elif selected_card == card:
		# shrink down selected card
		card.z_index = 0
		var tween = get_tree().create_tween()
		tween.tween_property(card, "scale", Vector2(1,1), 0.2)
		selected_card = null
		card_deselected.emit(card)
		deck_state = DeckState.UNFOLDED
	# otherwise a card is already selected so change to new one
	else:
		# shrink down selected card
		selected_card.z_index = 0
		var tween = get_tree().create_tween()
		tween.tween_property(selected_card, "scale", Vector2(1,1), 0.2)
		card_deselected.emit(selected_card)
		selected_card = null
		selected_card = card
		deck_state = DeckState.UNFOLDED
		card_selected.emit(card)
