extends Node2D

signal deck_complete
signal all_decks_stacked

func _ready() -> void:
	$ApDeck.card_selected.connect(_on_card_selected)
	$HpDeck.card_selected.connect(_on_card_selected)
	$CompleteCardDeck.card_selected.connect(_on_card_selected)
	$ApDeck.deck_state = Deck.DeckState.STACKED
	$HpDeck.deck_state = Deck.DeckState.STACKED
	$CompleteCardDeck.deck_state = Deck.DeckState.STACKED
	$ApDeck.position = $ApDeckLoc.position
	$HpDeck.position = $HpDeckLoc.position
	$CompleteCardDeck.position = $CompleteDeckLoc.position
	$ApDeck.deck_unfold_node = $ApUnfoldLoc
	$HpDeck.deck_unfold_node = $HpUnfoldLoc
	
func scene_setup() -> void:
	$ApDeck.deck_state = Deck.DeckState.UNFOLDED
	$HpDeck.deck_state = Deck.DeckState.UNFOLDED
	$CompleteCardDeck.deck_state = Deck.DeckState.UNFOLDED

func scene_shutdown() -> void:
	$ApDeck.deck_state = Deck.DeckState.FOLDED
	await $ApDeck.deck_folded
	$HpDeck.deck_state = Deck.DeckState.FOLDED
	await $HpDeck.deck_folded
	$CompleteCardDeck.deck_state = Deck.DeckState.FOLDED
	await $CompleteCardDeck.deck_folded
	await get_tree().create_timer(0.3).timeout
	# then stack all cards simultaneously
	$ApDeck.deck_state = Deck.DeckState.STACKED
	$HpDeck.deck_state = Deck.DeckState.STACKED
	$CompleteCardDeck.deck_state = Deck.DeckState.STACKED
	await get_tree().create_timer(0.3).timeout
	var tween = get_tree().create_tween()
	tween.parallel().tween_property($ApDeck, "global_position:y", $ApDeck.global_position.y - 500, 0.5)
	tween.parallel().tween_property($HpDeck, "global_position:y", $HpDeck.global_position.y + 500, 0.5)
	
func _on_card_selected(card: Node2D) -> void:
	if card.card_data.card_type == CardData.CARD_TYPE.AP_CARD:
		var tween = get_tree().create_tween()
		tween.tween_property(card, "global_position", $ApAmalLoc.position, 0.5).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	elif card.card_data.card_type == CardData.CARD_TYPE.HP_CARD:
		var tween = get_tree().create_tween()
		tween.tween_property(card, "global_position", $HpAmalLoc.position, 0.5).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	elif card.card_data.card_type == CardData.CARD_TYPE.COMPLETE_CARD:
		var tween = get_tree().create_tween()
		tween.tween_property(card, "global_position", $ApAmalLoc.position, 0.5).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

func _on_amalgamate_pressed() -> void:
	# check if two cards are selected
	if not ($ApDeck.selected_card and $HpDeck.selected_card):
		return
	# get selected card data
	var selected_ap_card_data : CardData = $ApDeck.selected_card.card_data
	var selected_hp_card_data : CardData = $HpDeck.selected_card.card_data
	# create new card from ap and hp
	var new_card_data : CardData = CardData.new()
	new_card_data.card_type = CardData.CARD_TYPE.COMPLETE_CARD
	new_card_data.card_ap = selected_ap_card_data.card_ap
	new_card_data.card_hp = selected_hp_card_data.card_hp
	new_card_data.card_ap_ability = selected_ap_card_data.card_ap_ability
	new_card_data.card_hp_ability = selected_hp_card_data.card_hp_ability
	new_card_data.card_ap_texture = selected_ap_card_data.card_ap_texture
	new_card_data.card_hp_texture = selected_hp_card_data.card_hp_texture
	$CompleteCardDeck.add_card_data(new_card_data)
	$CompleteCardDeck.get_children().back().global_position = $ApAmalLoc.position
	$CompleteCardDeck.deck_state = Deck.DeckState.UNFOLDED
	$ApDeck.erase_selected_card()
	#$ApDeck.deck_state = Deck.DeckState.UNFOLDED
	$HpDeck.erase_selected_card()
	#$HpDeck.deck_state = Deck.DeckState.UNFOLDED

func _on_bisect_pressed() -> void:
	if not $CompleteCardDeck.selected_card: return
	# create ap and hp cards from complete card
	var new_ap_card_data : CardData = CardData.new()
	new_ap_card_data.card_type = CardData.CARD_TYPE.AP_CARD
	new_ap_card_data.card_ap = $CompleteCardDeck.selected_card.card_data.card_ap
	new_ap_card_data.card_ap_ability = $CompleteCardDeck.selected_card.card_data.card_ap_ability
	new_ap_card_data.card_ap_texture = $CompleteCardDeck.selected_card.card_data.card_ap_texture
	$ApDeck.add_card_data(new_ap_card_data)
	var new_hp_card_data : CardData = CardData.new()
	new_hp_card_data.card_type = CardData.CARD_TYPE.HP_CARD
	new_hp_card_data.card_hp = $CompleteCardDeck.selected_card.card_data.card_hp
	new_hp_card_data.card_hp_ability = $CompleteCardDeck.selected_card.card_data.card_hp_ability
	new_hp_card_data.card_hp_texture = $CompleteCardDeck.selected_card.card_data.card_hp_texture
	$HpDeck.add_card_data(new_hp_card_data)
	# put cards back to start position so that tween plays correctly
	$ApDeck.get_children().back().global_position = $ApAmalLoc.position
	$HpDeck.get_children().back().global_position = $HpAmalLoc.position
	
	$CompleteCardDeck.erase_selected_card()
	
	$ApDeck.deck_state = Deck.DeckState.UNFOLDED
	$HpDeck.deck_state = Deck.DeckState.UNFOLDED

func _on_deck_complete_pressed() -> void:
	deck_complete.emit()
	
func _on_ap_spawner_pressed() -> void:
	var new_card_data : CardData = CardData.new()
	new_card_data.card_type = CardData.CARD_TYPE.AP_CARD
	new_card_data.card_ap = randi_range(1,5)
	new_card_data.card_ap_texture = load("res://Cards/Images/AP_placeholder.png")
	new_card_data.card_ap_ability = randi_range(0,CardData.CardApAbility.values().size()-1)
	$ApDeck.add_card_data(new_card_data)
	$ApDeck.deck_state = Deck.DeckState.UNFOLDED

func _on_hp_spawner_pressed() -> void:
	var new_card_data : CardData = CardData.new()
	new_card_data.card_type = CardData.CARD_TYPE.HP_CARD
	new_card_data.card_hp = randi_range(1,5)
	new_card_data.card_hp_texture = load("res://Cards/Images/HP_placeholder.png")
	$HpDeck.add_card_data(new_card_data)
	$HpDeck.deck_state = Deck.DeckState.UNFOLDED


func _on_comp_spawner_pressed() -> void:
	var new_card_data : CardData = CardData.new()
	new_card_data.card_type = CardData.CARD_TYPE.COMPLETE_CARD
	new_card_data.card_ap = randi_range(1,5)
	new_card_data.card_ap_texture = load("res://Cards/Images/AP_placeholder.png")
	new_card_data.card_hp = randi_range(1,5)
	new_card_data.card_hp_texture = load("res://Cards/Images/HP_placeholder.png")
	$CompleteCardDeck.add_card_data(new_card_data)
	$CompleteCardDeck.deck_state = Deck.DeckState.UNFOLDED
