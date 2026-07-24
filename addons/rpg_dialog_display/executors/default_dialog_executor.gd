class_name DefaultDialogExecutor
extends DialogExecutor


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
		# Delay after lines
		await delay(500)
	if page.interjection.name or page.interjection.text:
		var int_speaker: SpeakerMeta = _dialog_box.speakers.get(page.interjection.name)
		var line_flow: LineFlow = build_line(
			page.interjection.text, preset, int_speaker, _dialog_box.global, replacements, false
		)
		_dialog_box.set_interjection_line(line_flow)
		await line_flow.execute_as_interjection()
		await delay(500)
	var choices: Array[DialogFile.Choice] = []
	choices.assign(page.contents as Array[DialogFile.Choice])
	_dialog_box.setup_choices(choices)
	while true:
		await _dialog_box.page_confirmed
		if not page.contents or _dialog_box.selected_choice:
			break
	return _dialog_box.selected_choice
