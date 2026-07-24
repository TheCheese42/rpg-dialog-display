class_name DialogBox
extends VBoxContainer

signal script_called(id: String)
signal page_confirmed(choice: DialogFile.Choice)

@onready var portrait: TextureRect = $HBoxContainer/Portrait
@onready var lines_v_box: VBoxContainer = $HBoxContainer/MainVBox/LinesVBox
@onready var interjection_portrait: TextureRect = $HBoxContainer/MainVBox/InterjectionHBox/InterjectionPortrait
@onready var interjection_h_box: HBoxContainer = $HBoxContainer/MainVBox/InterjectionHBox
@onready var choices_h_box: HBoxContainer = $MarginContainer/ChoicesHBox
@onready var choices_v_box: VBoxContainer = $MarginContainer/ChoicesHBox/ChoicesVBox
@onready var choice_left: Label = $MarginContainer/ChoicesHBox/ChoiceLeft
@onready var choice_top: Label = $MarginContainer/ChoicesHBox/ChoicesVBox/ChoiceTop
@onready var choice_center: Label = $MarginContainer/ChoicesHBox/ChoicesVBox/ChoiceCenter
@onready var choice_bottom: Label = $MarginContainer/ChoicesHBox/ChoicesVBox/ChoiceBottom
@onready var choice_right: Label = $MarginContainer/ChoicesHBox/ChoiceRight
@onready var choice_star: Label = $MarginContainer/ChoicesHBox/ChoicesVBox/ChoiceCenter/ChoiceStar

var star_character: String = "*"
var choice_character: String = "*"
var selected_choice: DialogFile.Choice = null
var selected_choice_color: Color = Color.YELLOW
var executor: DialogExecutor:
	get:
		return executor
	set(value):
		if executor:
			remove_child(executor)
			executor.queue_free()
		executor = value
		add_child(executor)
var conversation: DialogFile.Conversation
var presets: Dictionary[String, Dictionary]
var color_presets: Dictionary[String, Color]
var speed_presets: Dictionary[String, int]
var delay_presets: Dictionary[String, int]
var speakers: Dictionary[String, SpeakerMeta]
var global: Resource
var skip: bool = false


func init(
	conversation_: DialogFile.Conversation,
	presets_: Dictionary[String, Dictionary],
	color_presets_: Dictionary[String, Color],
	speed_presets_: Dictionary[String, int],
	delay_presets_: Dictionary[String, int],
	speakers_: Dictionary[String, SpeakerMeta],
	global_: Resource = null
) -> void:
	conversation = conversation_
	presets = presets_
	color_presets = color_presets_
	speed_presets = speed_presets_
	delay_presets = delay_presets_
	speakers = speakers_
	global = global_


func _ready() -> void:
	add_theme_constant_override("h_separation", 0)
	add_theme_constant_override("v_separation", 0)
	executor = DefaultDialogExecutor.new(self)


func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("left"):
		if (
			choice_center.has_meta("choice")
			and choice_right.has_meta("choice")
			and selected_choice == choice_right.get_meta("choice")
		):
			select_choice(choice_center)
		elif (
			choice_left.has_meta("choice")
			and choice_left.has_meta("choice")
			and selected_choice != choice_left.get_meta("choice")
		):
			select_choice(choice_left)
	elif Input.is_action_just_pressed("right"):
		if (
			choice_center.has_meta("choice")
			and choice_left.has_meta("choice")
			and selected_choice == choice_left.get_meta("choice")
		):
			select_choice(choice_center)
		elif (
			choice_right.has_meta("choice")
			and choice_right.has_meta("choice")
			and selected_choice != choice_right.get_meta("choice")
		):
			select_choice(choice_right)
	elif Input.is_action_just_pressed("up"):
		if (
			choice_center.has_meta("choice")
			and choice_bottom.has_meta("choice")
			and selected_choice == choice_bottom.get_meta("choice")
		):
			select_choice(choice_center)
		elif (
			choice_top.has_meta("choice")
			and choice_top.has_meta("choice")
			and selected_choice != choice_top.get_meta("choice")
		):
			select_choice(choice_top)
	elif Input.is_action_just_pressed("down"):
		if (
			choice_center.has_meta("choice")
			and choice_top.has_meta("choice")
			and selected_choice == choice_top.get_meta("choice")
		):
			select_choice(choice_center)
		elif (
			choice_bottom.has_meta("choice")
			and choice_bottom.has_meta("choice")
			and selected_choice != choice_bottom.get_meta("choice")
		):
			select_choice(choice_bottom)
	if Input.is_action_just_pressed("dialog_confirm"):
		emit_signal("page_confirmed")


func start() -> void:
	await _walk_dialog(conversation)


func clear() -> void:
	portrait.texture = null
	for child: Node in lines_v_box.get_children():
		child.queue_free()
	interjection_portrait.texture = null
	for child: Node in interjection_h_box.get_children().slice(1):
		child.queue_free()
	for choice: Label in [choice_left, choice_top, choice_center, choice_bottom, choice_right]:
		choice.text = ""
		choice.set_meta("choice", null)
	choice_star.offset_transform_position = Vector2.ZERO
	selected_choice = null
	choices_h_box.visible = false


## Clears the box and reinitializes everything necessary.
func setup_page(
	speaker: SpeakerMeta,
	interjection_speaker_name: String,
	preset: Dictionary,
) -> void:
	clear()
	portrait.texture = speaker.portrait
	interjection_portrait.texture = speakers[interjection_speaker_name].portrait
	choice_star.text = choice_character


func add_line(line_flow: LineFlow) -> void:
	var line_h_box := HBoxContainer.new()
	lines_v_box.add_child(line_h_box)
	var star := Label.new()
	star.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	star.text = star_character
	line_h_box.add_child(star)
	line_h_box.add_child(line_flow)


func set_interjection_line(line_flow: LineFlow) -> void:
	interjection_h_box.add_child(line_flow)


## Setup 1-5 choices.
func setup_choices(choices: Array[DialogFile.Choice]) -> void:
	var count: int = len(choices)
	if not count or count > 5:
		return
	choices_h_box.visible = true
	var order: Array[Label] = [choice_left, choice_right, choice_top, choice_bottom]
	if count == 1 or count == 5:
		order.insert(0, choice_center)
	for i: int in count:
		order[i].text = choices[i].text
		order[i].set_meta("choice", choices[i])
		if i == 0 and count in [1, 5]:
			select_choice(choice_center, false)


func select_choice(label: Label, animate: bool = true) -> void:
	for other: Label in [choice_center, choice_left, choice_right, choice_top, choice_bottom]:
		if other != label:
			other.remove_theme_color_override("font_color")
	if label:
		var choice: DialogFile.Choice = label.get_meta("choice")
		selected_choice = choice
		label.add_theme_color_override("font_color", selected_choice_color)
		await get_tree().process_frame
		var star_offset := (
			Vector2(
				# The label is a little wider than the character, hence +4
				label.global_position.x + 4,
				label.global_position.y + label.size.y / 2,
			)
			- Vector2(
				choice_star.global_position.x + choice_star.size.x,
				choice_star.global_position.y + choice_star.size.y / 2,
			)
		)
		if animate:
			var tween: Tween = create_tween()
			tween.set_ease(Tween.EASE_OUT)
			tween.set_trans(Tween.TRANS_EXPO)
			tween.tween_property(choice_star, "offset_transform_position", star_offset, 0.4)
		else:
			choice_star.offset_transform_position = star_offset


func execute_page(page: DialogFile.Page, speaker: SpeakerMeta) -> DialogFile.Choice:
	var preset := presets[page.preset if page.preset else conversation.preset]
	return await executor.run(page, speaker, preset)


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
		speaker = speakers.get((component as DialogFile.Speaker).name)
		if not speaker:
			printerr("ERROR Can't find speaker {0}.".format([(component as DialogFile.Speaker).name]))
	elif is_instance_of(component, DialogFile.Goto):
		await _walk_dialog(conversation, (component as DialogFile.Goto).target_id)
		return true
	elif is_instance_of(component, DialogFile.Script_):
		emit_signal("script_called", (component as DialogFile.Script_).script_id)

	var contents: Variant = component.get("contents")
	if contents:
		for content: DialogFile.ConversationContent in contents:
			if await _walk_dialog(content, "", speaker):
				return true
	return false
