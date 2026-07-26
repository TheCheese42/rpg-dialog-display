class_name LineFlow
extends HFlowContainer

var color_regex := RegEx.create_from_string(r'<c(?: (\w+)|)>')
var speed_regex := RegEx.create_from_string(r'<s(?: (\w+)|)>')
var delay_regex := RegEx.create_from_string(r'<d (\w+)>')
var wave_regex := RegEx.create_from_string(r'<wave(?: (\d+) (\d+)|)>')
var shake_regex := RegEx.create_from_string(r'<shake(?: (\d+) (\d+)|)>')
var cursor_regex := RegEx.create_from_string(r'<cur(?: (\d+)|)>')
var backspace_regex := RegEx.create_from_string(r'<b(?: (\d+)|)>')
var script_regex := RegEx.create_from_string(r'<script (\w+)>')
var char_to_word: Dictionary[DialogCharLabel, DialogWord] = {}
var cursor_pos: int = 0:
	get:
		return cursor_pos
	set(value):
		cursor_pos = clampi(value, 0, len(_chars))
var call_script: Callable = func(id: String) -> void: pass
var skip: bool = false
## If true, words will automatically wrap around lines.
## Can only be set while empty.
var allow_flow: bool = true:
	get:
		return allow_flow
	set(value):
		if not _words:
			allow_flow = value
var _words: Array[DialogWord] = []
var _chars: Array[DialogCharLabel] = []
var _execution_steps: Array[ExecutionStep] = []
var _color_presets: Dictionary[String, Color]
var _speed_presets: Dictionary[String, int]
var _delay_presets: Dictionary[String, int]

var _voice_player: AudioStreamPlayer


func _init(
	color_presets: Dictionary[String, Color],
	speed_presets: Dictionary[String, int],
	delay_presets: Dictionary[String, int],
) -> void:
	_color_presets = color_presets
	_speed_presets = speed_presets
	_delay_presets = delay_presets
	_voice_player = AudioStreamPlayer.new()
	_voice_player.max_polyphony = 10
	add_child(_voice_player, false, Node.INTERNAL_MODE_BACK)


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("h_separation", 0)
	add_theme_constant_override("v_separation", 0)


func initialize_voice(voice: AudioStream) -> void:
	_voice_player.stream = voice


func build_from_text(text: String, preset: Dictionary, speaker: SpeakerMeta) -> void:
	initialize_voice(speaker.voice)
	var formatting := Formatting.new(
		preset["color"] as Color,
		preset["wave_intensity"] as int,
		preset["wave_speed"] as int,
		preset["shake_intensity"] as int,
		preset["shake_speed"] as int,
	)
	var execution_speed: int = preset["speed"]
	## This is used to not make characters that should be inserted later in
	## the animation reserve their space.
	var should_reserve_space: bool = true
	var i: int = 0
	while i < len(text):
		var chr: String = text[i]
		if chr == "<" and (i == 0 or text[i - 1] != "\\"):
			# Must be any special override
			var end: int = text.find(">", i)
			if end > i:
				var match_: RegExMatch
				var used_regex: RegEx
				for regex: RegEx in [
					color_regex,
					speed_regex,
					delay_regex,
					wave_regex,
					shake_regex,
					cursor_regex,
					backspace_regex,
					script_regex,
				]:
					used_regex = regex
					match_ = regex.search(text.substr(i, end - i + 1))
					if match_:
						break
				if match_:
					match used_regex:
						color_regex:
							var group: String = match_.get_string(1)
							if group and group in _color_presets:
								formatting.color = _color_presets[group]
							elif group and group.is_valid_html_color():
								formatting.color = Color(group)
							elif group:
								printerr("ERROR Invalid dialog color identifier: {0}.".format(
									match_.get_string()
								))
							else:
								formatting.color = preset["color"]
						speed_regex:
							var group: String = match_.get_string(1)
							if group and group in _speed_presets:
								execution_speed = _speed_presets[group]
							elif group and group.is_valid_int():
								execution_speed = int(group)
							elif group:
								printerr("ERROR Invalid dialog speed identifier: {0}.".format(
									match_.get_string()
								))
							else:
								execution_speed = preset["speed"]
						delay_regex:
							var delay_: int = 0
							var group: String = match_.get_string(1)
							if group and group in _delay_presets:
								delay_ = _delay_presets[group]
							elif group and group.is_valid_int():
								delay_ = int(group)
							else:
								printerr("ERROR Invalid dialog delay identifier: {0}.".format(
									match_.get_string()
								))
							_execution_steps.append(ExecutionStep.new(
								ExecutionStepType.DELAY, delay_,
							))
						wave_regex:
							if match_.get_string(1):
								formatting.wave_intensity = int(match_.get_string(1))
								formatting.wave_speed = int(match_.get_string(2))
							else:
								formatting.wave_intensity = preset["wave_intensity"]
								formatting.wave_speed = preset["wave_speed"]
						shake_regex:
							if match_.get_string(1):
								formatting.shake_intensity = int(match_.get_string(1))
								formatting.shake_speed = int(match_.get_string(2))
							else:
								formatting.shake_intensity = preset["shake_intensity"]
								formatting.shake_speed = preset["shake_speed"]
						cursor_regex:
							var group: String = match_.get_string(1)
							if group and group.is_valid_int():
								cursor_pos = int(group)
							elif group:
								printerr("ERROR Invalid cursor position: {0}.".format(
									match_.get_string()
								))
							else:
								cursor_pos = len(_chars)
							# From now on, characters do not reserve their space anymore.
							should_reserve_space = false
						backspace_regex:
							var group: String = match_.get_string(1)
							var amount: int = 1
							if group and group.is_valid_int():
								amount = int(group)
							elif group:
								printerr("ERROR Invalid backspace amount: {0}.".format(
									match_.get_string()
								))
							for idx: int in range(cursor_pos - 1, cursor_pos - 1 - amount, -1):
								var label = _chars[idx]
								_execution_steps.append(ExecutionStep.new(
									ExecutionStepType.HIDE_LABEL, [label, execution_speed]
								))
						script_regex:
							_execution_steps.append(ExecutionStep.new(
								ExecutionStepType.CALL_SCRIPT, match_.get_string(1),
							))
					i = i + match_.get_end() - 1
		elif chr != "\\" or text[i + 1] != "<":
			# Possibly modify the speed for this particular character before writing
			var char_speed: int = execution_speed
			var punctuation: Array[String] = [".", ":", ";", "?", "!"]
			if i > 0 and text[i - 1] == ",":
				char_speed *= 3
			elif i > 0 and text[i - 1] in punctuation and text[i] not in punctuation:
				char_speed *= 5
			var label: DialogCharLabel = write(chr, speaker, formatting)
			label.reserve_space = should_reserve_space
			_execution_steps.append(ExecutionStep.new(
				ExecutionStepType.DISPLAY_LABEL, [label, char_speed]
			))
		i += 1


func write(
	chr: String,
	speaker: SpeakerMeta,
	formatting: Formatting
) -> DialogCharLabel:
	if _words and not allow_flow:
		var label_: DialogCharLabel = _words[0].insert_char(chr, speaker, formatting, cursor_pos)
		_chars.insert(cursor_pos, label_)
		char_to_word[label_] = _words[0]
		cursor_pos += 1
		return label_

	var pos_in_word: int = -1
	var word := char_to_word[_chars[cursor_pos - 1]] if _chars else null
	if not word:
		# First word
		word = DialogWord.new()
		_words.append(word)
		add_child(word)
	elif chr == " ":
		var idx: int = _words.find(word)
		if (
			cursor_pos < len(_chars)
			and word == char_to_word[_chars[cursor_pos]]
			and cursor_pos != 0
		):
			# Split up the current word and insert a space word in between
			var new_split_word := word.split(_chars[cursor_pos].get_index())
			_words.insert(idx + 1, new_split_word)
			add_child(new_split_word)
			move_child(new_split_word, idx + 1)
			word = DialogWord.new()
			word.is_space = true
			_words.insert(idx + 1, word)
			add_child(word)
			move_child(word, idx + 1)
		else:
			# Insert a new space word
			word = DialogWord.new()
			word.is_space = true
			_words.insert(idx + 1 if cursor_pos != 0 else idx, word)
			add_child(word)
			move_child(word, idx + 1 if cursor_pos != 0 else idx)
	elif word.is_space or cursor_pos == 0:
		if cursor_pos == len(_chars):
			# New word, end of the line_
			word = DialogWord.new()
			_words.append(word)
			add_child(word)
		else:
			word = char_to_word[_chars[cursor_pos]]
			if word.is_space:
				# Insert word between spaces
				var idx: int = _words.find(word)
				word = DialogWord.new()
				_words.insert(idx, word)
				add_child(word)
				move_child(word, idx)
			else:
				# Prepend to next word
				pos_in_word = 0
	elif cursor_pos < len(_chars):
		# Write into word
		pos_in_word = _chars[cursor_pos - 1].get_index() + 1
	# Otherwise, append to last word
	var label: DialogCharLabel = word.insert_char(chr, speaker, formatting, pos_in_word)
	_chars.insert(cursor_pos, label)
	char_to_word[label] = word
	cursor_pos += 1
	return label


func backspace() -> void:
	if cursor_pos < 1:
		return

	if not allow_flow:
		var label_ := _chars[cursor_pos - 1]
		var word_ := _words[0]
		word_.delete_char(cursor_pos - 1)
		_chars.erase(label_)
		char_to_word.erase(label_)
		if not word_.length:
			_words.erase(word_)
			word_.queue_free()
		cursor_pos -= 1
		return

	var word := char_to_word[_chars[cursor_pos - 1]]
	if word.is_space and cursor_pos not in [1, len(_chars)]:
		# Not at beginning or end
		var preceding_word := char_to_word[_chars[cursor_pos - 2]]
		var following_word := char_to_word[_chars[cursor_pos]]
		if not preceding_word.is_space and not following_word.is_space:
			# Glue surrounding _words
			preceding_word.append_other(following_word)
			_words.erase(following_word)
			following_word.queue_free()
	var label := _chars[cursor_pos - 1]
	var idx_in_word: int = label.get_index()
	word.delete_char(idx_in_word)
	_chars.erase(label)
	char_to_word.erase(label)
	if not word.length:
		_words.erase(word)
		word.queue_free()
	cursor_pos -= 1


func delay(time_ms: int) -> void:
	if skip:
		return
	while time_ms > 50:
		await get_tree().create_timer(0.05).timeout
		if skip:
			return
		time_ms -= 50
	await get_tree().create_timer(time_ms / 1000).timeout


func execute() -> void:
	for step: ExecutionStep in _execution_steps:
		match step.type:
			ExecutionStepType.DISPLAY_LABEL:
				var label: DialogCharLabel = step.value[0]
				if not skip:
					var ms: int = step.value[1]
					await delay(ms)
					_voice_player.play()
				if skip and label.wave_intensity and label.wave_speed:
					# Wave offset
					var offset_time: int = 0
					for previous: DialogCharLabel in _chars:
						if previous == label:
							break
						offset_time += step.value[1]
					label.wave_animation_offset_time = offset_time
				label.display()
			ExecutionStepType.HIDE_LABEL:
				var label: DialogCharLabel = step.value[0]
				var ms: int = step.value[1]
				await delay(ms)
				label.reserve_space = false
				label.conceil()
			ExecutionStepType.DELAY:
				var ms: int = step.value
				await delay(ms)
			ExecutionStepType.CALL_SCRIPT:
				var id: String = step.value
				await call_script.call(id)


func execute_as_interjection() -> void:
	var skip_animation := skip
	skip = true
	if not skip_animation:
		get_parent().offset_transform_enabled = true
		get_parent().offset_transform_position.x = get_parent().size.x
	await execute()
	if not skip_animation:
		if not size.x:
			visible = false
			await get_tree().process_frame
			visible = true
		get_parent().offset_transform_position.x = get_parent().size.x + 100
		await create_tween().tween_property(
			get_parent(), "offset_transform_position", Vector2.ZERO, get_parent().size.x / 200
		).finished
		get_parent().offset_transform_enabled = false


class ExecutionStep extends Resource:
	var type: ExecutionStepType
	var value: Variant
	
	func _init(type_: ExecutionStepType, value_: Variant = null) -> void:
		self.type = type_
		self.value = value_


enum ExecutionStepType {
	## value[0]: DialogCharLabel = label, value[1]: int = speed
	DISPLAY_LABEL,
	## value[0]: DialogCharLabel = label, value[1]: int = speed
	HIDE_LABEL,
	## value: int = speed
	DELAY,
	## value: String = script_id
	CALL_SCRIPT,
}
