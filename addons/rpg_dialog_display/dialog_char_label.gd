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
var _chr: String
var _speaker: SpeakerMeta
var _color: Color
var _wave_intensity: int
var _wave_speed: int
var _shake_intensity: int
var _shake_speed: int
var _wave_tween: Tween
var _shake_timer: Timer


func init(
	chr: String,
	speaker: SpeakerMeta,
	formatting: Formatting,
) -> void:
	_chr = chr
	_speaker = speaker
	_color = formatting.color
	_wave_intensity = formatting.wave_intensity
	_wave_speed = formatting.wave_speed
	_shake_intensity = formatting.shake_intensity
	_shake_speed = formatting.shake_speed


func _ready() -> void:
	text = _chr
	var settings := LabelSettings.new()
	if _speaker.font:
		settings.font = _speaker.font
	if _speaker.font_size:
		settings.font_size = _speaker.font_size
	settings.font_color = _color
	label_settings = settings
	hide()

func display() -> void:
	modulate.a = 1.0
	visible = true
	setup_tweens()


func hide() -> void:
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
	if _wave_intensity > 0 and _wave_speed > 0:
		_wave_tween = create_tween()
		_wave_tween.set_trans(Tween.TRANS_SINE)
		_wave_tween.set_loops()
		_wave_tween.tween_property(
			self, "offset_transform_position",
			Vector2(0, -_wave_intensity),
			_wave_speed / 1000.0,
		)
		_wave_tween.tween_property(
			self, "offset_transform_position",
			Vector2(0, _wave_intensity),
			_wave_speed / 1000.0,
		)
	if _shake_intensity > 0 and _shake_speed > 0:
		_shake_timer = Timer.new()
		add_child(_shake_timer)
		_shake_timer.timeout.connect(_shake)
		_shake_timer.start(_shake_speed / 1000.0)


func _shake() -> void:
	offset_transform_position.x = randi_range(-_shake_intensity / 2, _shake_intensity / 2)
	offset_transform_position.y = randi_range(-_shake_intensity, _shake_intensity)


func _to_string() -> String:
	return _chr
