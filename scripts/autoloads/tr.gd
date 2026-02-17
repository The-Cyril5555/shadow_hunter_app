## Tr - Translation helper autoload (Singleton)
## Loads locale JSON dictionaries and provides Tr.t("key") for translated strings.
## Supports format args: Tr.t("key", [val1, val2])
class_name TrClass
extends Node


var _strings: Dictionary = {}
var _current_locale: String = ""


func _ready() -> void:
	_load_locale(UserSettings.locale)
	UserSettings.locale_changed.connect(_on_locale_changed)


func _load_locale(locale: String) -> void:
	var path = "res://data/locales/%s.json" % locale
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[Tr] Cannot open locale file: %s" % path)
		return
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()
	if error != OK:
		push_error("[Tr] JSON parse error in %s: %s" % [path, json.get_error_message()])
		return
	_strings = json.data if json.data is Dictionary else {}
	_current_locale = locale
	print("[Tr] Loaded locale: %s (%d keys)" % [locale, _strings.size()])


func _on_locale_changed(new_locale: String) -> void:
	_load_locale(new_locale)


## Get translated string. Supports format args: Tr.t("key", [val1, val2])
func t(key: String, args: Array = []) -> String:
	var text = _strings.get(key, key)  # Fallback = key itself
	if args.size() > 0:
		text = text % args
	return text


## Get current locale
func get_locale() -> String:
	return _current_locale
