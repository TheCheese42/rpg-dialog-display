class_name DialogWord
extends HBoxContainer

var length: int = 0
var is_space: bool = false


func _ready() -> void:
	add_theme_constant_override("separation", 0)


func insert_char(
	chr: String,
	speaker: SpeakerMeta,
	formatting: Formatting,
	pos: int = -1,
) -> DialogCharLabel:
	assert(
		not is_space or (not get_child_count() and chr == " "),
		"ERROR Attempted inserting char {0} into a space word.".format([chr]),
	)
	var label := DialogCharLabel.new()
	label.offset_transform_enabled = true
	label.init(chr, speaker, formatting)
	add_child(label)
	move_child(label, pos)
	length += 1
	return label


func delete_char(pos: int = -1) -> void:
	remove_child(get_child(pos))
	length -= 1


func append_other(word: DialogWord) -> void:
	for child: DialogCharLabel in word.get_children():
		word.delete_char(0)
		add_child(child)
		length += 1


func split(from: int) -> DialogWord:
	var word := DialogWord.new()
	for child: DialogCharLabel in get_children().slice(from):
		remove_child(child)
		length -= 1
		word.add_child(child)
		word.length += 1
	return word


func _to_string() -> String:
	var str_: String = ""
	for child: DialogCharLabel in get_children():
		str_ += str(child)
	return str_
