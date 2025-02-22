@tool
class_name Viscera
extends Line2D

const MAX_STRETCH = 100.0
@export_range(0, MAX_STRETCH, 0.01) var stretch_amount : float:
	set(value):
		stretch_amount = value
		stretch_viscera(stretch_amount)
	


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func stretch_viscera(amount) -> void:
	var num_points = get_point_count()
	for i in range(0, num_points):
		var y_offset : float
		if i < num_points / 2:
			y_offset = amount * (num_points/2-i) / (num_points/2)
		else:
			y_offset = -amount * (i-num_points/2) / (num_points/2)
		points[i].y = y_offset
	for i in range(0, width_curve.get_point_count()):
		width_curve.set_point_value(i,maxf(0.0,  amount / MAX_STRETCH * (4*(0.25*i-0.5)**2)+1-amount/MAX_STRETCH))
	#$Line2D.width_curve.set_point_value(1, 0.9 - 0.5*t/freq)
	material.set("shader_parameter/Strength", 1.5*amount / MAX_STRETCH)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
