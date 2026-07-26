class_name DefaultDialogExecutor
extends DialogExecutor

var time_between_lines: int = 500
var time_before_interjection: int = 500
var time_before_choices: int = 500
## For this time, the choices will take up space without actually being
## visible, which allows resizing the text box.
var time_before_choices_visible: int = 300


func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("dialog_skip"):
		_dialog_box.skip_to_end()


func execute_page(
	page: DialogFile.Page,
	speaker: SpeakerMeta,
	preset: Dictionary,
	replacements: Array[Variant] = [],
) -> DialogFile.Choice:
	var lines := page.text.strip_edges(false).split("\n")
	for line: String in lines:
		var line_flow: LineFlow = build_line(
			line, preset, speaker, _dialog_box.global, replacements,
		)
		_dialog_box.add_line(line_flow)
		await line_flow.execute()
		# Delay between lines
		if lines[-1] != line:
			await delay(time_between_lines)
	if page.interjection.name or page.interjection.text:
		await delay(time_before_interjection)
		var int_speaker: SpeakerMeta = _dialog_box.speakers.get(page.interjection.name)
		var line_flow: LineFlow = build_line(
			page.interjection.text, preset, int_speaker, _dialog_box.global, replacements, false
		)
		_dialog_box.set_interjection_line(line_flow)
		await line_flow.execute_as_interjection()
	var choices: Array[DialogFile.Choice] = []
	choices.assign(page.contents as Array[DialogFile.Choice])
	if choices:
		await delay(time_before_choices)
	_dialog_box.setup_choices(choices)
	_dialog_box.choices_margin.modulate.a = 0.0
	if choices:
		await delay(time_before_choices_visible)
	_dialog_box.choices_margin.modulate.a = 1.0
	while true:
		await _dialog_box.page_confirmed
		if not page.contents or _dialog_box.selected_choice:
			break
	var choice := _dialog_box.selected_choice  # Saving choice due to following clear() call
	_dialog_box.clear()
	return choice
