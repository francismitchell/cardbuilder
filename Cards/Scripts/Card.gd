@tool
class_name Card
extends Node2D

const HP_CARD_OFFSET_PX : int = 192
const SHEAR_SCALE : float = 0.0002

signal card_pressed
signal card_mouse_entered
signal card_mouse_exited
signal card_killed
signal card_mouse_motion

var neutral_position : Vector2
var card_hovered : bool = false
@onready var current_hp : int = card_data.card_hp:
	set(value):
		current_hp = value
		_on_card_data_changed()
@onready var base_transform : Transform2D = transform

@export var card_data : CardData:
	set(value):
		card_data = value
		if card_data:
			if not card_data.changed.is_connected(_on_card_data_changed):
				card_data.changed.connect(_on_card_data_changed)

func _ready() -> void:
	if card_data:
		if not card_data.changed.is_connected(_on_card_data_changed):
			print('connecting card data changed signal')
			card_data.changed.connect(_on_card_data_changed)
		current_hp = card_data.card_hp
	_on_card_data_changed()
			
			
func _on_card_data_card_health_depleted() -> void:
	pass

func _on_card_data_changed() -> void:
	if not card_data:
		return
	if card_data.card_type == CardData.CARD_TYPE.AP_CARD:
		$ApComponents/Area2D.input_pickable = true
		$HpComponents/Area2D.input_pickable = false
		$CompComponents/Area2D.input_pickable = false
		$AbilityLabel.position.y = -36
		$ApComponents.show()
		$HpComponents.hide()
		$CompComponents.hide()
	elif card_data.card_type == CardData.CARD_TYPE.HP_CARD:
		$ApComponents/Area2D.input_pickable = false
		$HpComponents/Area2D.input_pickable = true
		$CompComponents/Area2D.input_pickable = false
		$AbilityLabel.position.y = 36
		$ApComponents.hide()
		$HpComponents.show()
		$CompComponents.hide()
	elif card_data.card_type == CardData.CARD_TYPE.COMPLETE_CARD:
		$ApComponents/Area2D.input_pickable = false
		$HpComponents/Area2D.input_pickable = false
		$CompComponents/Area2D.input_pickable = true
		$AbilityLabel.position.y = -36
		$ApComponents.show()
		$HpComponents.show()
		$CompComponents.show()
	$ApComponents/ApBackground/ApLabel.text = str(card_data.card_ap)
	$HpComponents/HpBackground/HpLabel.text = str(current_hp)
	$ApComponents/ApBackground/ApSprite.texture = card_data.card_ap_texture
	$HpComponents/HpBackground/HpSprite.texture = card_data.card_hp_texture
	if card_data.card_team == CardData.CARD_TEAM.ENEMY:
		$ApComponents/ApBackground.material.set("shader_parameter/enabled",true)
		$ApComponents/ApBackground/ApSprite.material.set("shader_parameter/enabled",true)
		$HpComponents/HpBackground.material.set("shader_parameter/enabled",true)
		$HpComponents/HpBackground/HpSprite.material.set("shader_parameter/enabled",true)

	else:
		$ApComponents/ApBackground.material.set("shader_parameter/enabled",false)
		$ApComponents/ApBackground/ApSprite.material.set("shader_parameter/enabled",false)
		$HpComponents/HpBackground.material.set("shader_parameter/enabled",false)
		$HpComponents/HpBackground/HpSprite.material.set("shader_parameter/enabled",false)
		
	if not card_data.card_ap_ability:
		$AbilityLabel.scale = Vector2()
	$AbilityLabel/Label.text = str(card_data.CardApAbility.keys()[card_data.card_ap_ability])
	

	
func _on_ap_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseMotion:
		card_mouse_motion.emit(self, event.global_position)
	if event is InputEventMouseButton:
		if event.pressed:
			card_pressed.emit(self)

func _on_hp_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseMotion:
		card_mouse_motion.emit(self, event.global_position)
	if event is InputEventMouseButton:
		if event.pressed:
			card_pressed.emit(self)
			
func _on_complete_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseMotion:
		card_mouse_motion.emit(self, event.global_position)
	if event is InputEventMouseButton:
		if event.pressed:
			card_pressed.emit(self)

func _on_ap_area_2d_mouse_entered() -> void:
	card_mouse_entered.emit(self)
	
func _on_hp_area_2d_mouse_entered() -> void:
	card_mouse_entered.emit(self)
	
func _on_ap_area_2d_mouse_exited() -> void:
	card_mouse_exited.emit(self)
	
func _on_hp_area_2d_mouse_exited() -> void:
	card_mouse_exited.emit(self)
		
func _on_complete_area_2d_mouse_entered() -> void:
	card_mouse_entered.emit(self)
	
func _on_complete_area_2d_mouse_exited() -> void:
	card_mouse_exited.emit(self)
			
func damage_card(dmg : int) -> void:
	current_hp -= dmg
	_on_card_data_changed()
	if current_hp <= 0:
		_kill_card()
	else:
		# do damage animation
		var tween = get_tree().create_tween()
		tween.tween_property(self, "scale", scale * Vector2(0.5, 1.5), 0.05)
		tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.05)
		
func _kill_card() -> void:
	card_killed.emit()
	# play death animation
	var tween = get_tree().create_tween()
	tween.tween_property(self, "scale", scale * Vector2(0.5, 1.5), 0.05)
	tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.05)
	tween.tween_property(self, "scale", Vector2(0.01, 0.01), 0.2)
	await tween.finished
	self.queue_free()
	
func hover(mouse_pos : Vector2) -> void:
	# get vector from origin to mouse position
	var v : Vector2
	if card_data.card_type == CardData.CARD_TYPE.AP_CARD:
		v = mouse_pos - $ApComponents.global_position
	elif card_data.card_type == CardData.CARD_TYPE.HP_CARD:
		v = mouse_pos - $HpComponents.global_position
	elif card_data.card_type == CardData.CARD_TYPE.COMPLETE_CARD:
		v = mouse_pos - $CompComponents.global_position
	transform.x = base_transform.x + SHEAR_SCALE * v
	transform.y = base_transform.y + SHEAR_SCALE * v
	z_index = 1
	
func unhover() -> void:
	z_index = 0
	var tween = get_tree().create_tween()
	#tween.tween_property(self, "scale", Vector2(1,1), 0.05)
	tween.parallel().tween_property(self, "transform:x", base_transform.x, 0.05)
	tween.parallel().tween_property(self, "transform:y", base_transform.y, 0.05)


func _on_ability_area_2d_mouse_entered() -> void:
	$AbilityLabel/Label.show()

func _on_ability_area_2d_mouse_exited() -> void:
	$AbilityLabel/Label.hide()
