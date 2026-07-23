class_name SpeakerMeta
extends Resource

@export var name: String
@export var voice: AudioStream
# Note: In order to support different attributes per speaker,
# use several SpeakerMeta objects with different identifiers (what the user
# enters in the editor) and the same name (the name property in this
# file) to change the attributes individually.
@export var portrait: Texture2D
@export var font: Font
@export var font_size: int


func _init(
	name_: String = "",
	voice_: AudioStream = null,
	portrait_: Texture2D = null,
	font_: Font = null,
	font_size_: int = 0,
) -> void:
	name = name_
	voice = voice_
	portrait = portrait_
	font = font_
	font_size = font_size_
