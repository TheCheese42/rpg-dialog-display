class_name DialogBox
extends VBoxContainer

signal script_called(id: String)
signal page_confirmed(choice: DialogFile.Choice)

@onready var portrait: TextureRect = $HBoxContainer/Portrait
@onready var lines_v_box: VBoxContainer = $HBoxContainer/ScrollContainer/MainVBox/LinesVBox
@onready var interjection_portrait: TextureRect = $HBoxContainer/ScrollContainer/MainVBox/InterjectionHBox/InterjectionPortrait
@onready var interjection_h_box: HBoxContainer = $HBoxContainer/ScrollContainer/MainVBox/InterjectionHBox

var star_character: String = "*"
var _conversation: DialogFile.Conversation
var _presets: Dictionary[String, Dictionary]
var _color_presets: Dictionary[String, Color]
var _speed_presets: Dictionary[String, int]
var _delay_presets: Dictionary[String, int]
var _speakers: Dictionary[String, SpeakerMeta]
var _skip: bool = false


func init(
	conversation: DialogFile.Conversation,
	presets: Dictionary[String, Dictionary],
	color_presets: Dictionary[String, Color],
	speed_presets: Dictionary[String, int],
	delay_presets: Dictionary[String, int],
	speakers: Dictionary[String, SpeakerMeta],
) -> void:
	_conversation = conversation
	_presets = presets
	_color_presets = color_presets
	_speed_presets = speed_presets
	_delay_presets = delay_presets
	_speakers = speakers


func _ready() -> void:
	add_theme_constant_override("h_separation", 0)
	add_theme_constant_override("v_separation", 0)


func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("dialog_confirm"):
		emit_signal("page_confirmed")


func start() -> void:
	await _walk_dialog(_conversation)


func skip_to_end() -> void:
	_skip = true


func clear() -> void:
	portrait.texture = null
	for child: Node in lines_v_box.get_children():
		child.queue_free()
	interjection_portrait.texture = null
	for child: Node in interjection_h_box.get_children().slice(1):
		child.queue_free()


func execute_page(
	page: DialogFile.Page,
	speaker: SpeakerMeta,
	global: Resource = null,
	replacements: Array[Variant] = [],
) -> DialogFile.Choice:
	clear()

	var preset: Dictionary = _presets[
		page.preset if page.preset else _conversation.preset
	]

	portrait.texture = speaker.portrait
	var lines: PackedStringArray = page.text.strip_edges(false).split("\n")
	for line: String in lines:
		var line_h_box := HBoxContainer.new()
		lines_v_box.add_child(line_h_box)
		var star := Label.new()
		star.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		star.text = star_character
		line_h_box.add_child(star)
		var line_flow: LineFlow = build_line(line, preset, speaker, global, replacements)
		line_h_box.add_child(line_flow)
		await line_flow.execute()
		if line != lines[-1]:
			# Delay between lines
			await line_flow.delay(500)
	if page.interjection.name or page.interjection.text:
		var int_speaker: SpeakerMeta
		if page.interjection.name:
			int_speaker = _speakers.get(page.interjection.name)
			if not int_speaker:
				printerr("ERROR Can't find speaker {0}.".format([page.interjection.name]))
			else:
				interjection_portrait.texture = int_speaker.portrait
		else:
			int_speaker = speaker
		var line_flow: LineFlow = build_line(
			page.interjection.text, preset, int_speaker, global, replacements, false
		)
		interjection_h_box.add_child(line_flow)
		if not _skip:
			line_flow.offset_transform_enabled = true
			line_flow.offset_transform_position.x = line_flow.size.x
			await line_flow.delay(500)  # Delay before interjection
		line_flow.skip = true
		await line_flow.execute()
		if not _skip:
			create_tween().tween_property(
				line_flow, "offset_transform_position", Vector2.ZERO, line_flow.size.x / 500
			)
	await page_confirmed
	clear()
	return null


func resolve_text(text: String, global: Resource, replacements: Array[Variant]) -> String:
	if global:
		var variable_regex := RegEx.create_from_string(r'{([a-z][a-z0-9_.]*)}')
		for match_: RegExMatch in variable_regex.search_all(text):
			var path: String = match_.get_string(1)
			var value: Resource = global
			for segment: String in path.split("."):
				value = value.get(segment)
				if value == null:
					printerr(
						"ERROR Dialog variable {0} could not be resolved at segment {1}.".format(
							[path, segment]
						)
					)
					break
			if value != null:
				text = text.replace(match_.get_string(), str(value))
	return text.format(replacements)


func build_line(
	text: String,
	preset: Dictionary,
	speaker: SpeakerMeta,
	global: Resource = null,
	replacements: Array[Variant] = [],
	allow_flow: bool = true,
) -> LineFlow:
	text = resolve_text(text, global, replacements)
	var line := LineFlow.new(_color_presets, _speed_presets, _delay_presets)
	line.allow_flow = allow_flow
	line.build_from_text(text, preset, speaker)
	line.skip = _skip
	return line


func _walk_dialog(
	component: DialogFile.DialogComponent,
	from_id: String = "",
	speaker: SpeakerMeta = null,
) -> bool:
	# Returns false if the method should continue walking the tree,
	# true if otherwise.
	var id: DialogUID = component.get("id")
	if (from_id and not id) or (from_id and id and from_id != str(id)):
		pass
	elif is_instance_of(component, DialogFile.Page):
		var choice: DialogFile.Choice = await execute_page(component as DialogFile.Page, speaker)
		if choice:
			return await _walk_dialog(choice, "", speaker)
		else:
			return false
	elif is_instance_of(component, DialogFile.Speaker):
		speaker = _speakers.get((component as DialogFile.Speaker).name)
		if not speaker:
			printerr("ERROR Can't find speaker {0}.".format([(component as DialogFile.Speaker).name]))
	elif is_instance_of(component, DialogFile.Goto):
		await _walk_dialog(_conversation, (component as DialogFile.Goto).target_id)
		return true
	elif is_instance_of(component, DialogFile.Script_):
		emit_signal("script_called", (component as DialogFile.Script_).script_id)

	var contents: Variant = component.get("contents")
	if contents:
		for content: DialogFile.ConversationContent in contents:
			if await _walk_dialog(content, "", speaker):
				return true
	return false
