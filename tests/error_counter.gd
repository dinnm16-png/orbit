extends Logger
## Counts every error the engine reports (script errors, shader compile
## errors, failed asserts...) so the test runner can fail on them even when
## no individual test assertion noticed anything.

var errors: PackedStringArray = PackedStringArray()
var _mutex := Mutex.new()


func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type == ERROR_TYPE_WARNING:
		return
	_mutex.lock()
	errors.append("%s (%s:%d %s)" % [rationale if rationale != "" else code, file, line, function])
	_mutex.unlock()
