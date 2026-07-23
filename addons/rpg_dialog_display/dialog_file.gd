@tool
class_name DialogFile
extends Resource

@export var locale: String = ""
@export var relative_path_to_original: String = ""
@export var presets: Dictionary[String, Dictionary] = {}
@export var color_presets: Dictionary[String, Color] = {}
@export var speed_presets: Dictionary[String, int] = {}
@export var delay_presets: Dictionary[String, int] = {}
# Serializing the Conversation due to (probably?) bugs in Resource handling.
@export var conversations: Array[Dictionary] = []


@abstract class DialogComponent extends Resource:
	@abstract func _to_string() -> String
	@abstract func to_dict() -> Dictionary
	static func from_dict(_dict: Dictionary) -> DialogComponent: return

	func unregister() -> void:
		var contents: Variant = self.get("contents")
		if contents is Array:
			for content: DialogComponent in contents:
				content.unregister()

	static func _serialize_contents(contents: Array) -> Array[Dictionary]:
		var arr: Array = []
		for content: DialogComponent in contents:
			arr.append(content.to_dict())
		return arr

	static func _deserialize_contents(serialized: Array) -> Array:
		var arr: Array = []
		for dict: Dictionary in serialized:
			var comp: DialogComponent
			match dict["type"]:
				"Conversation":
					comp = Conversation.from_dict(dict)
				"Speaker":
					comp = Speaker.from_dict(dict)
				"Page":
					comp = Page.from_dict(dict)
				"Interjection":
					comp = Interjection.from_dict(dict)
				"Goto":
					comp = Goto.from_dict(dict)
				"Script":
					comp = Script_.from_dict(dict)
				"Choice":
					comp = Choice.from_dict(dict)
			if comp:
				arr.append(comp)
		return arr


class Conversation extends DialogComponent:
	@export var original_hash: int = 0
	@export var id: DialogUID = DialogUID.new()
	@export var preset: String = Globals.generic_preset_names[0]
	@export var contents: Array = []

	func _init() -> void:
		if preset not in Globals.generic_preset_names:
			preset = Globals.generic_preset_names[0]

	func _to_string() -> String:
		return str(id)
	
	func to_dict() -> Dictionary:
		return {
			"type": "Conversation",
			"original_hash": self.original_hash,
			"id": str(self.id),
			"preset": self.preset,
			"contents": _serialize_contents(self.contents),
		}

	static func from_dict(dict: Dictionary) -> DialogComponent:
		var obj := Conversation.new()
		obj.original_hash = dict["original_hash"]
		obj.id = DialogUID.new(dict["id"] as String)
		obj.preset = dict["preset"]
		obj.contents = _deserialize_contents(dict["contents"] as Array)
		return obj

	func unregister() -> void:
		super.unregister()
		id.unregister()


@abstract class ConversationContent extends DialogComponent:
	pass


class Speaker extends ConversationContent:
	@export var name: String = ""
	@export var contents: Array

	func _to_string() -> String:
		return "{0}:".format([name])
	
	func to_dict() -> Dictionary:
		return {
			"type": "Speaker",
			"name": self.name,
			"contents": _serialize_contents(self.contents),
		}

	static func from_dict(dict: Dictionary) -> DialogComponent:
		var obj := Speaker.new()
		obj.name = dict["name"]
		obj.contents = _deserialize_contents(dict["contents"] as Array)
		return obj


class Page extends ConversationContent:
	@export var id: DialogUID = DialogUID.new()
	@export var text: String = ""
	@export var preset: String = ""
	@export var interjection: Interjection = Interjection.new()
	@export var contents: Array

	func _init() -> void:
		if preset and preset not in Globals.generic_preset_names:
			preset = ""

	func _to_string() -> String:
		return "[{0}] {1}".format([id, text])
	
	func to_dict() -> Dictionary:
		return {
			"type": "Page",
			"id": str(self.id),
			"text": self.text,
			"preset": self.preset,
			"interjection": self.interjection.to_dict(),
			"contents": _serialize_contents(self.contents),
		}

	static func from_dict(dict: Dictionary) -> DialogComponent:
		var obj := Page.new()
		obj.id = DialogUID.new(dict["id"] as String)
		obj.text = dict["text"]
		obj.preset = dict["preset"]
		obj.interjection = Interjection.from_dict(
			dict["interjection"] as Dictionary)
		obj.contents = _deserialize_contents(dict["contents"] as Array)
		return obj

	func unregister() -> void:
		super.unregister()
		id.unregister()


class Interjection extends DialogComponent:
	@export var name: String = ""
	@export var text: String = ""

	func _to_string() -> String:
		return "{0}: {1}".format([name, text])
	
	func to_dict() -> Dictionary:
		return {
			"type": "Interjection",
			"name": self.name,
			"text": self.text,
		}

	static func from_dict(dict: Dictionary) -> DialogComponent:
		var obj := Interjection.new()
		obj.name = dict["name"]
		obj.text = dict["text"]
		return obj


class Goto extends ConversationContent:
	@export var target_id: String = ""

	func _to_string() -> String:
		return "Goto: {0}".format([target_id])
	
	func to_dict() -> Dictionary:
		return {
			"type": "Goto",
			"target_id": self.target_id,
		}

	static func from_dict(dict: Dictionary) -> DialogComponent:
		var obj := Goto.new()
		obj.target_id = dict["target_id"]
		return obj


class Script_ extends ConversationContent:
	@export var script_id: String = ""

	func _to_string() -> String:
		return "Script: {0}".format([script_id])
	
	func to_dict() -> Dictionary:
		return {
			"type": "Script",
			"script_id": self.script_id,
		}

	static func from_dict(dict: Dictionary) -> DialogComponent:
		var obj := Script_.new()
		obj.script_id = dict["script_id"]
		return obj


class Choice extends DialogComponent:
	@export var text: String = ""
	@export var contents: Array = []

	func _to_string() -> String:
		return "[{0}]".format([text])
	
	func to_dict() -> Dictionary:
		return {
			"type": "Choice",
			"text": self.text,
			"contents": _serialize_contents(self.contents),
		}

	static func from_dict(dict: Dictionary) -> DialogComponent:
		var obj := Choice.new()
		obj.text = dict["text"]
		obj.contents = _deserialize_contents(dict["contents"] as Array)
		return obj
