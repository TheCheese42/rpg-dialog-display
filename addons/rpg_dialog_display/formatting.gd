class_name Formatting
extends Resource

var color: Color
var wave_speed: int
var wave_intensity: int
var shake_speed: int
var shake_intensity: int


func _init(
	color_: Color,
	wave_speed_: int, wave_intensity_: int,
	shake_speed_: int, shake_intensity_: int,
) -> void:
	color = color_
	wave_speed = wave_speed_
	wave_intensity = wave_intensity_
	shake_speed = shake_speed_
	shake_intensity = shake_intensity_
