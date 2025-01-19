# Logic for interacting with single tile on the board.
# Includes logic for add/removing a card from this tile.
@tool
class_name BoardTile
extends Sprite2D

enum TileState {EMPTY, CONTAINS_PLAYER_CARD, CONTAINS_ENEMY_CARD}
enum HighlightState {NEUTRAL, CLICKABLE, HOVER, CLICKED}

signal tile_pressed
signal tile_mouse_entered
signal tile_mouse_exited
signal tile_card_killed

const card_scene = preload("res://Cards/BaseCard.tscn")
const callout_label_settings = preload("res://Board/CalloutLabelSettings.tres")

var tile_state : TileState = TileState.EMPTY: set = set_tile_state
var highlight_state : HighlightState: set = set_highlight_state

@export var can_place_card : bool = false

func _ready() -> void:
	if not $Area2D.input_event.is_connected(_on_area_2d_input_event):
		$Area2D.input_event.connect(_on_area_2d_input_event)
	if not $Area2D.mouse_entered.is_connected(_on_area_2d_mouse_entered):
		$Area2D.mouse_entered.connect(_on_area_2d_mouse_entered)
	if not $Area2D.mouse_exited.is_connected(_on_area_2d_mouse_exited):
		$Area2D.mouse_exited.connect(_on_area_2d_mouse_exited)

func set_highlight_state(state : HighlightState) -> void:
	var _previous_state = highlight_state
	var tween = get_tree().create_tween()
	if state == HighlightState.NEUTRAL:
		tween.tween_method(set_tile_brightness, material.get("shader_parameter/brightness"), 1.0, 0.1)
	elif state == HighlightState.CLICKABLE:
		tween.tween_method(set_tile_brightness, material.get("shader_parameter/brightness"), 1.2, 0.1)
	elif state == HighlightState.HOVER:
		tween.tween_method(set_tile_brightness, material.get("shader_parameter/brightness"), 1.3, 0.1)
	elif state == HighlightState.CLICKED:
		tween.tween_method(set_tile_brightness, material.get("shader_parameter/brightness"), 1.7, 0.1)
	highlight_state = state
				
func set_tile_brightness(brightness : float):
	material.set("shader_parameter/brightness",brightness)
				
func set_tile_state(new_state : TileState) -> void:
	var _previous_state = tile_state
	tile_state = new_state
	
# create card node on tile from CardData
func add_card(card_data : CardData) -> void:
	# create card node
	var new_card : Card = card_scene.instantiate()
	# set card data then connect changed signal to tile so we can track HP
	new_card.card_data = card_data
	# connect card killed signal to callback to handle card death
	new_card.card_killed.connect(_on_board_tile_card_killed)
	# resize card (TEMPORARY)
	new_card.scale *= 1.3
	# add to scene
	add_child(new_card)
	# update tile state
	if card_data.card_team == CardData.CARD_TEAM.FRIENDLY:
		tile_state = TileState.CONTAINS_PLAYER_CARD
	elif card_data.card_team == CardData.CARD_TEAM.ENEMY:
		tile_state = TileState.CONTAINS_ENEMY_CARD
		
func remove_card() -> void:
	for child in get_children():
		if child is Card:
			child.queue_free()
	# update tile state
	tile_state = TileState.EMPTY
		
func get_card() -> Card:
	for child in get_children():
		if child is Card:
			return child
	return null
		
func _on_board_tile_card_killed() -> void:
	tile_card_killed.emit(get_card())
	tile_state = TileState.EMPTY
	create_damage_callout("Killed!")
	
func create_damage_callout(callout_text : String) -> void:
	var callout = Label.new()
	callout.label_settings = callout_label_settings
	callout.text = callout_text
	add_child(callout)
	if get_children().size() == 1:
		callout.position = get_node('CardMarker').position - Vector2(callout.size.x / 2, 0) 
	else: 
		callout.position = get_children().back().position + Vector2(0,-128*(get_children().size()-1))
	# animate floating and fading	
	var tween = get_tree().create_tween()
	tween.parallel().tween_property(callout, "modulate", Color.TRANSPARENT, 1.0)
	tween.parallel().tween_property(callout, "position:y", callout.position.y - 256, 1.0)
	tween.tween_callback(callout.queue_free)

func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			tile_pressed.emit(self, can_place_card)

func _on_area_2d_mouse_entered() -> void:
	tile_mouse_entered.emit(self)

func _on_area_2d_mouse_exited() -> void:
	tile_mouse_exited.emit(self)
