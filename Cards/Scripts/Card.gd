@tool
class_name Card
extends Node2D

@export var split_cards : bool = false:
	set(value):
		split_card()
@export var unsplit_cards : bool = false:
	set(value):
		unsplit_card()

const HP_CARD_OFFSET_PX : int = 192
const SHEAR_SCALE : float = 0.0002

signal card_pressed
signal card_mouse_entered
signal card_mouse_exited
signal card_killed
signal card_mouse_motion
signal card_split
signal card_unsplit

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
		if Engine.is_editor_hint():
			_on_card_data_changed()

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
		$ApBackground/Area2D.input_pickable = true
		$HpBackground/Area2D.input_pickable = false
		$Area2D.input_pickable = false
		$ApBackground.show()
		$HpBackground.hide()
		$Area2D.hide()
	elif card_data.card_type == CardData.CARD_TYPE.HP_CARD:
		$ApBackground/Area2D.input_pickable = false
		$HpBackground/Area2D.input_pickable = true
		$Area2D.input_pickable = false
		$ApBackground.hide()
		$HpBackground.show()
		$Area2D.hide()
	elif card_data.card_type == CardData.CARD_TYPE.COMPLETE_CARD:
		$ApBackground/Area2D.input_pickable = false
		$HpBackground/Area2D.input_pickable = false
		$Area2D.input_pickable = true
		$ApBackground.show()
		$HpBackground.show()
		$Area2D.show()
	$ApBackground/ApLabel.text = str(card_data.card_ap)
	$HpBackground/HpLabel.text = str(current_hp)
	$ApBackground/ApSprite.texture = card_data.card_ap_texture
	$HpBackground/HpSprite.texture = card_data.card_hp_texture
	if card_data.card_team == CardData.CARD_TEAM.ENEMY:
		material.set_shader_parameter("effect_idx",1)
	elif card_data.card_team == CardData.CARD_TEAM.FRIENDLY:
		print('changing shader parameter')
		material.set_shader_parameter("effect_idx",2)
	# label text
	#var label_text = "AP ability: {0}\nHP ability: {1}".format(str(card_data.CardApAbility.keys()[card_data.card_ap_ability]), str(card_data.CardApAbility.keys()[card_data.card_hp_ability]))
	#print(card_data.CardHpAbility.keys()[card_data.card_hp_ability])
	var format_text = "AP ability: %s\nHP ability: %s" % [card_data.CardApAbility.keys()[card_data.card_ap_ability], card_data.CardHpAbility.keys()[card_data.card_hp_ability]]
	$Panel/Info.text = format_text
	
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
	$Panel.show()
	# get vector from origin to mouse position
	var v : Vector2
	if card_data.card_type == CardData.CARD_TYPE.AP_CARD:
		v = mouse_pos - $ApBackground.global_position
		# adjust shader
		material.set("shader_parameter/shift",0.01*(v - $ApBackground.texture.get_size() / 2.0).length())
	elif card_data.card_type == CardData.CARD_TYPE.HP_CARD:
		v = mouse_pos - $HpBackground.global_position
		# adjust shader
		material.set("shader_parameter/shift",0.01*(v - $HpBackground.texture.get_size() / 2.0).length())
	elif card_data.card_type == CardData.CARD_TYPE.COMPLETE_CARD:
		v = mouse_pos - $Area2D.global_position
		# adjust shader
		material.set("shader_parameter/shift",0.01*(v - $ApBackground.texture.get_size() / 2.0).length())
	transform.x = base_transform.x + SHEAR_SCALE * v
	transform.y = base_transform.y + SHEAR_SCALE * v
	z_index = 1
	
	
func unhover() -> void:
	$Panel.hide()
	z_index = 0
	var tween = get_tree().create_tween()
	#tween.tween_property(self, "scale", Vector2(1,1), 0.05)
	tween.parallel().tween_property(self, "transform:x", base_transform.x, 0.05)
	tween.parallel().tween_property(self, "transform:y", base_transform.y, 0.05)
	
func split_card() -> void:
	if card_data.card_type != card_data.CARD_TYPE.COMPLETE_CARD: return
	var tween = get_tree().create_tween()
	tween.parallel().tween_property($ApBackground, "position:y", $ApBackground.position.y - 100, 0.5).set_trans(Tween.TRANS_BOUNCE)
	tween.parallel().tween_property($HpBackground, "position:y", $HpBackground.position.y + 100, 0.5).set_trans(Tween.TRANS_BOUNCE)
	for child in get_children():
		if child is Viscera:
			tween.parallel().tween_property(child, "stretch_amount", 100.0, 0.5).set_trans(Tween.TRANS_BOUNCE)
	$CPUParticles2D.emitting = true
	$CPUParticles2D2.emitting = true
	$CPUParticles2D3.emitting = true
	await tween.finished
	card_split.emit()


func unsplit_card() -> void:
	var tween = get_tree().create_tween()
	tween.parallel().tween_property($ApBackground, "position:y", $ApBackground.position.y + 100, 0.2).set_trans(Tween.TRANS_SPRING)
	tween.parallel().tween_property($HpBackground, "position:y", $HpBackground.position.y - 100, 0.2).set_trans(Tween.TRANS_SPRING)
	for child in get_children():
		if child is Viscera:
			tween.parallel().tween_property(child, "stretch_amount", 0.0, 0.2).set_trans(Tween.TRANS_SPRING)
	await tween.finished
	card_unsplit.emit()
	
func prepare_for_amalgamation() -> void:
	if card_data.card_type != card_data.CARD_TYPE.COMPLETE_CARD: return
	$ApBackground.position.y -= 100
	$HpBackground.position.y += 100
