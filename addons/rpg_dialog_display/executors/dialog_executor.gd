@abstract
class_name DialogExecutor
extends Node

var _dialog_box: DialogBox


func _init(dialog_box: DialogBox,) -> void:
	_dialog_box = dialog_box


## Executes all lines within the page, as well as a possible interjection and
## shows any choices. Also handles skipping and waiting until the page is
## dismissed.
## For every line, this should create and build a LineFlow, add it to the
## DialogBox as well as execute it.
## It should also set a LineFlow as interjection line on the DialogBox,
## execute it as interjection and make sure a choice is being picked.
@abstract
func execute_page(
	page: DialogFile.Page,
	speaker: SpeakerMeta,
	preset: Dictionary,
) -> DialogFile.Choice


## Prepares the underlying DialogBox to execute individual lines.
func setup(speaker: SpeakerMeta, page: DialogFile.Page, preset: Dictionary) -> void:
	_dialog_box.setup_page(speaker, page.interjection.name, preset)


## Sets up and executes the whole dialog page, returning the selected choice,
## if any.
func run(
	page: DialogFile.Page,
	speaker: SpeakerMeta,
	preset: Dictionary,
) -> DialogFile.Choice:
	setup(speaker, page, preset)
	return await execute_page(page, speaker, preset)


func delay(time_ms: int) -> void:
	if _dialog_box.skip:
		return
	while time_ms > 50:
		await get_tree().create_timer(0.05).timeout
		if _dialog_box.skip:
			return
		time_ms -= 50
	await get_tree().create_timer(time_ms / 1000).timeout


static func resolve_text(text: String, global: Resource, replacements: Array[Variant]) -> String:
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
	var line := LineFlow.new(
		_dialog_box.color_presets, _dialog_box.speed_presets, _dialog_box.delay_presets
	)
	line.allow_flow = allow_flow
	line.build_from_text(text, preset, speaker)
	line.skip = _dialog_box.skip
	return line
