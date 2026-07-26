class_name DialogCharLabel
extends Label

## If true, the label will always take up space, even while being invisible.
var reserve_space: bool = true:
	get:
		return reserve_space
	set(value):
		reserve_space = value
		if modulate.a == 0.0:
			visible = value
## Offset the waving animation by a certain amount of ms.
var wave_animation_offset_time: int = 0
var chr: String
var speaker: SpeakerMeta
var color: Color
var wave_intensity: int
var wave_speed: int
var shake_intensity: int
var shake_speed: int
var _wave_tween: Tween
var _shake_timer: Timer


func init(
	chr_: String,
	speaker_: SpeakerMeta,
	formatting: Formatting,
) -> void:
	chr = chr_
	speaker = speaker_
	color = formatting.color
	wave_intensity = formatting.wave_intensity
	wave_speed = formatting.wave_speed
	shake_intensity = formatting.shake_intensity
	shake_speed = formatting.shake_speed


func _ready() -> void:
	text = chr
	var settings := LabelSettings.new()
	if speaker.font:
		settings.font = speaker.font
	else:
		settings.font = get_theme_default_font()
	if speaker.font_size:
		settings.font_size = speaker.font_size
	else:
		settings.font_size = get_theme_default_font_size()
	settings.font_color = color
	label_settings = settings
	conceil()


func display() -> void:
	modulate.a = 1.0
	visible = true
	setup_tweens()


func conceil() -> void:
	modulate.a = 0.0
	if not reserve_space:
		visible = false
	clear_tweens()


func clear_tweens() -> void:
	if _wave_tween:
		_wave_tween.kill()
	if _shake_timer:
		_shake_timer.stop()
		_shake_timer.queue_free()


func setup_tweens() -> void:
	clear_tweens()
	if wave_intensity > 0 and wave_speed > 0:
		var real_offset: int = wave_animation_offset_time % (wave_speed * 2)
		await get_tree().create_timer(float(real_offset) / 1000.0).timeout
		_wave_tween = create_tween()
		_wave_tween.set_trans(Tween.TRANS_SINE)
		_wave_tween.set_loops()
		_wave_tween.tween_property(
			self, "offset_transform_position",
			Vector2(0, -wave_intensity),
			wave_speed / 1000.0,
		)
		_wave_tween.tween_property(
			self, "offset_transform_position",
			Vector2(0, wave_intensity),
			wave_speed / 1000.0,
		)
		#_wave_tween.set_speed_scale(20.0)
		#_wave_tween.set_speed_scale(1.0)
	if shake_intensity > 0 and shake_speed > 0:
		_shake_timer = Timer.new()
		add_child(_shake_timer)
		_shake_timer.timeout.connect(_shake)
		_shake_timer.start(shake_speed / 1000.0)


func _shake() -> void:
	offset_transform_position.x = randi_range(-shake_intensity / 2, shake_intensity / 2)
	offset_transform_position.y = randi_range(-shake_intensity, shake_intensity)


func _to_string() -> String:
	return chr
