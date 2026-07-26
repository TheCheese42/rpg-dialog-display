class_name ConversationReader
extends Node

## If a tree script returns true, the tree won't be followed any longer.
## This can be used to route the conversation from the script.
var call_script: Callable = func(id: String) -> void: pass:
	get:
		return call_script
	set(value):
		call_script = value
		_dialog_box.call_script = call_script
var conversation: DialogFile.Conversation
var presets: Dictionary[String, Dictionary]
var color_presets: Dictionary[String, Color]
var speed_presets: Dictionary[String, int]
var delay_presets: Dictionary[String, int]
var speakers: Dictionary[String, SpeakerMeta]
var global: Resource

var _dialog_box: DialogBox
var _dialog_box_scene: PackedScene = preload("res://addons/rpg_dialog_display/dialog_box.tscn")


func _init(
	dialog_box: DialogBox,
	conversation_: DialogFile.Conversation,
) -> void:
	_dialog_box = dialog_box
	conversation = conversation_


## Walk the entire conversation tree from the beginning.
func execute_conversation() -> void:
	await _walk_dialog(conversation)


## Execute a single page without walking further. If the page has choices,
## The picked choice and all of its children will be executed too.
func execute_single_page(id: String) -> void:
	await _walk_dialog(conversation, _StringObject.new(id), "", id)


## Walk the conversation tree starting from the page with id.
func execute_from_page(id: String) -> void:
	await _walk_dialog(conversation, _StringObject.new(id))


func _walk_dialog(
	component: DialogFile.DialogComponent,
	# Uses _StringObject to pass the id by reference so one tree
	from_id: _StringObject = _StringObject.new(),
	speaker: String = "",
	stop_after_id: String = "",
) -> bool:
	# Returns false if the method should continue walking the tree,
	# true if otherwise.
	var id: DialogUID = component.get("id")
	if is_instance_of(component, DialogFile.Speaker):
		speaker = (component as DialogFile.Speaker).name
		if not speaker:
			printerr("ERROR Can't find speaker {0}.".format([(component as DialogFile.Speaker).name]))
	elif (from_id.str and not id) or (from_id.str and id and from_id.str != str(id)):
		# This comes after speaker so the scan for the correct page actually
		# keeps track of the reader.
		pass
	elif is_instance_of(component, DialogFile.Page):
		var choice: DialogFile.Choice = await _dialog_box.execute_page(
			component as DialogFile.Page, speaker, conversation.preset)
		if choice:
			from_id.str = ""
			return await _walk_dialog(choice, _StringObject.new(), speaker)
		else:
			if from_id.str and from_id.str == stop_after_id:
				return true
			from_id.str = ""
			return false
	elif is_instance_of(component, DialogFile.Goto):
		await _walk_dialog(conversation, _StringObject.new((
			component as DialogFile.Goto).target_id))
		return true
	elif is_instance_of(component, DialogFile.Script_):
		if await call_script.call((component as DialogFile.Script_).script_id) == true:
			return true

	var contents: Variant = component.get("contents")
	if contents:
		for content: DialogFile.DialogComponent in contents:
			if await _walk_dialog(content, from_id, speaker, stop_after_id):
				return true
	return false


class _StringObject extends RefCounted:
	var str: String

	func _init(str: String = "") -> void:
		self.str = str

	func _to_string() -> String:
		return str
