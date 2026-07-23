@tool
class_name DialogUID
extends Resource

@export var _uid: String


func _init(uid: String = "") -> void:
	Globals.uid_objects.append(self)
	if uid and _check_valid(uid):
		_uid = uid
	else:
		_uid = _generate_id()


func _to_string() -> String:
	return _uid


func set_id(uid: String) -> bool:
	## Returns whether setting was successful.
	if _check_valid(uid):
		_uid = uid
		return true
	return false


func unregister() -> void:
	Globals.uid_objects.erase(self)


func _generate_id() -> String:
	# Generate 8 character long string uid
	var characters := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
	var id: String = ""
	for _i in 8:
		id += characters[randi_range(0, len(characters) - 1)]
	if not _check_valid(id):
		return _generate_id()
	return id


func _check_valid(uid: String) -> bool:
	for other: DialogUID in Globals.uid_objects:
		if str(other) == uid:
			return false
	return true
