class_name ErrorCounter
extends Logger
## Counts engine and script errors so headless tools can fail on them.
## Loggers can be called from any thread, hence the mutex.

var _mutex := Mutex.new()
var _errors: PackedStringArray = []


func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type == ERROR_TYPE_WARNING:
		return
	var message: String = rationale if rationale != "" else code
	_mutex.lock()
	_errors.append("%s (%s:%d in %s)" % [message, file, line, function])
	_mutex.unlock()


func _log_message(_message: String, _error: bool) -> void:
	pass


func count() -> int:
	_mutex.lock()
	var n: int = _errors.size()
	_mutex.unlock()
	return n


func take_errors() -> PackedStringArray:
	_mutex.lock()
	var copy: PackedStringArray = _errors.duplicate()
	_errors.clear()
	_mutex.unlock()
	return copy
