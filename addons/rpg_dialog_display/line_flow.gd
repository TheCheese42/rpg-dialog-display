class_name LineFlow
extends HFlowContainer

var color_regex := RegEx.create_from_string(r'<c(?: (\w+)|)>')
var speed_regex := RegEx.create_from_string(r'<s(?: (\w+)|)>')
var delay_regex := RegEx.create_from_string(r'<d (\w+)>')
var wave_regex := RegEx.create_from_string(r'<wave(?: (\d+) (\d+)|)>')
var shake_regex := RegEx.create_from_string(r'<shake(?: (\d+) (\d+)|)>')
var char_to_word: Dictionary[DialogCharLabel, DialogWord] = {}
var cursor_pos: int = 0:
	get:
		return cursor_pos
	set(value):
		cursor_pos = clampi(value, 0, len(_chars))
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
var _color_presets: Dictionary[String, Color]
var _speed_presets: Dictionary[String, int]
var _delay_presets: Dictionary[String, int]


func _init(
	color_presets: Dictionary[String, Color],
	speed_presets: Dictionary[String, int],
	delay_presets: Dictionary[String, int],
) -> void:
	_color_presets = color_presets
	_speed_presets = speed_presets
	_delay_presets = delay_presets


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("h_separation", 0)
	add_theme_constant_override("v_separation", 0)


func build_from_text(text: String, preset: Dictionary, speaker: SpeakerMeta) -> void:
	var formatting := Formatting.new(
		preset["color"] as Color,
		preset["speed"] as int,
		preset["wave_intensity"] as int,
		preset["wave_speed"] as int,
		preset["shake_intensity"] as int,
		preset["shake_speed"] as int,
	)
	var accumulated_delay: int = 0
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
								formatting.speed = _speed_presets[group]
							elif group and group.is_valid_int():
								formatting.speed = int(group)
							elif group:
								printerr("ERROR Invalid dialog speed identifier: {0}.".format(
									match_.get_string()
								))
							else:
								formatting.speed = preset["speed"]
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
							accumulated_delay += delay_
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
					i = i + match_.get_end() - 1
		elif chr != "\\" or text[i + 1] != "<":
			# Eventually modify the speed for this particular character before writing
			var char_speed: int = formatting.speed
			var regular_speed: int = formatting.speed
			if text[i - 1] == ",":
				char_speed *= 3
			elif text[i - 1] in [".", ":", ";"]:
				char_speed *= 5
			char_speed += accumulated_delay
			accumulated_delay = 0
			formatting.speed = char_speed
			write(chr, speaker, formatting)
			formatting.speed = regular_speed
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
		if cursor_pos < len(_chars) and word == char_to_word[_chars[cursor_pos]]:
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
			_words.insert(idx + 1, word)
			add_child(word)
			move_child(word, idx + 1)
	elif word.is_space:
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
	# else: Append to last word
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
	for label: DialogCharLabel in _chars:
		await delay(label.speed)
		label.display()
