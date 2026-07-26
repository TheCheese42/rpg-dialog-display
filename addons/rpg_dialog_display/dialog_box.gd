class_name DialogBox
extends VBoxContainer

signal page_confirmed(choice: DialogFile.Choice)

@onready var portrait_margin: MarginContainer = $HBoxContainer/PortraitMargin
@onready var portrait: TextureRect = $HBoxContainer/PortraitMargin/Portrait
@onready var lines_v_box: VBoxContainer = $HBoxContainer/MainVBox/LinesVBox
@onready var interjection_portrait: TextureRect = $HBoxContainer/MainVBox/InterjectionHBox/InterjectionPortrait
@onready var interjection_h_box: HBoxContainer = $HBoxContainer/MainVBox/InterjectionHBox
@onready var choices_margin: MarginContainer = $MarginContainer
@onready var choices_h_box: HBoxContainer = $MarginContainer/ChoicesHBox
@onready var choices_v_box: VBoxContainer = $MarginContainer/ChoicesHBox/ChoicesVBox
@onready var choice_left: Label = $MarginContainer/ChoicesHBox/ChoiceLeft
@onready var choice_top: Label = $MarginContainer/ChoicesHBox/ChoicesVBox/ChoiceTop
@onready var choice_center: Label = $MarginContainer/ChoicesHBox/ChoicesVBox/ChoiceCenter
@onready var choice_bottom: Label = $MarginContainer/ChoicesHBox/ChoicesVBox/ChoiceBottom
@onready var choice_right: Label = $MarginContainer/ChoicesHBox/ChoiceRight
@onready var choice_star: Label = $MarginContainer/ChoicesHBox/ChoicesVBox/ChoiceCenter/ChoiceStar
@onready var bottom_spacer: Control = $BottomSpacer

var call_script: Callable = func(id: String) -> void: pass
var star_character: String = "*"
var choice_character: String = "*"
var line_alignment: FlowContainer.AlignmentMode = FlowContainer.AlignmentMode.ALIGNMENT_BEGIN
var allow_skip: bool = true
## If true, takes precedence over allow_skip and doesn't get reset.
var permanently_disable_skip: bool = false
var portrait_size: Vector2 = Vector2(64, 64):
	get:
		return portrait_size
	set(value):
		portrait_size = value
		portrait.custom_minimum_size = value
		portrait.custom_maximum_size = value
var interjection_portrait_size: Vector2 = Vector2(24, 24):
	get:
		return interjection_portrait_size
	set(value):
		interjection_portrait_size = value
		interjection_portrait.custom_minimum_size = value
		interjection_portrait.custom_maximum_size = value
var has_skipped: bool = false
var last_was_skipped: bool = false
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
var presets: Dictionary[String, Dictionary]
var color_presets: Dictionary[String, Color]
var speed_presets: Dictionary[String, int]
var delay_presets: Dictionary[String, int]
var speakers: Dictionary[String, SpeakerMeta]
var global: Resource

var _line_flows: Array[LineFlow] = []


func init(
	presets_: Dictionary[String, Dictionary],
	color_presets_: Dictionary[String, Color],
	speed_presets_: Dictionary[String, int],
	delay_presets_: Dictionary[String, int],
	speakers_: Dictionary[String, SpeakerMeta],
	global_: Resource = null
) -> void:
	presets = presets_
	color_presets = color_presets_
	speed_presets = speed_presets_
	delay_presets = delay_presets_
	speakers = speakers_
	global = global_
	clear()


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


func skip_to_end() -> void:
	if not allow_skip or permanently_disable_skip:
		return
	for line in _line_flows:
		line.skip = true
	has_skipped = true


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
	visible = false
	interjection_h_box.visible = false
	choices_margin.visible = false
	bottom_spacer.custom_minimum_size = Vector2.ZERO
	portrait_margin.visible = false
	last_was_skipped = has_skipped
	has_skipped = false
	allow_skip = true
	_line_flows.clear()


## Reinitializes everything necessary.
func setup_page(
	speaker: SpeakerMeta,
	interjection_speaker_name: String,
	preset: Dictionary,
) -> void:
	if speaker.portrait:
		portrait.texture = speaker.portrait
		portrait_margin.visible = true
	interjection_portrait.texture = speakers[interjection_speaker_name].portrait
	choice_star.text = choice_character
	visible = true
	# Reset skip in setup so presses during wait time do not count.
	has_skipped = false


func add_line(line_flow: LineFlow) -> void:
	var line_h_box := HBoxContainer.new()
	lines_v_box.add_child(line_h_box)
	if star_character:
		var star := Label.new()
		star.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		star.text = star_character
		line_h_box.add_child(star)
	line_h_box.add_child(line_flow)
	line_flow.alignment = line_alignment
	line_flow.call_script = call_script
	if has_skipped:
		line_flow.skip = true
	_line_flows.append(line_flow)


func set_interjection_line(line_flow: LineFlow) -> void:
	interjection_h_box.visible = true
	interjection_h_box.add_child(line_flow)
	if has_skipped:
		line_flow.skip = true


## Setup 1-5 choices.
func setup_choices(choices: Array[DialogFile.Choice]) -> void:
	var count: int = len(choices)
	if not count or count > 5:
		return
	choices_margin.visible = true
	var order: Array[Label] = [choice_left, choice_right, choice_top, choice_bottom]
	if count == 1 or count == 5:
		order.insert(0, choice_center)
	for i: int in count:
		order[i].text = choices[i].text
		order[i].set_meta("choice", choices[i])
		if i == 0 and count in [1, 5]:
			select_choice(choice_center, false)
	if count >= 4:
		bottom_spacer.custom_minimum_size = Vector2(0.0, 20.0)


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
				# Using get_character_bounds(0) to align to the first character,
				# as the characters are centered.
				label.global_position.x + label.get_character_bounds(0).position.x + 4,
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


## page.preset takes precedence over conversation_preset, however, at least
## one of those must not be null.
func execute_page(
	page: DialogFile.Page,
	speaker: String,
	conversation_preset: String = "",
	instant: bool = false,
) -> DialogFile.Choice:
	var preset := presets.get(page.preset if page.preset else conversation_preset)
	assert(preset, "At least one of page.preset and conversation_preset must be provided.")
	executor.setup(speakers[speaker], page, preset)
	if instant:
		skip_to_end()
	return await executor.execute_page(page, speakers[speaker], preset)


## Create a dialog from formatted text instead of a page.
func execute_text(text: String, speaker: String, preset: String) -> void:
	var page := DialogFile.Page.new()
	page.preset = preset
	page.text = text
	await execute_page(page, speaker)
	page.unregister()
