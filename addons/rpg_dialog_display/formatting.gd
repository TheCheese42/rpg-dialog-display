class_name Formatting
extends Resource

var color: Color
var wave_intensity: int
var wave_speed: int
var shake_intensity: int
var shake_speed: int


func _init(
	color_: Color,
	wave_intensity_: int,
	wave_speed_: int,
	shake_intensity_: int,
	shake_speed_: int,
) -> void:
	color = color_
	wave_intensity = wave_intensity_
	wave_speed = wave_speed_
	shake_intensity = shake_intensity_
	shake_speed = shake_speed_
