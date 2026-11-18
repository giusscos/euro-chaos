extends SceneTree
## Headless test runner. Runs every test_* method of every
## res://tools/tests/test_*.gd script. A test fails if it reports a failed
## expectation or if any engine/script error is logged while it runs.
##
##   $GODOT --headless --path . --fixed-fps 60 --script res://tools/run_tests.gd
##   ... -- vehicle          (only test files whose name contains "vehicle")
##
## --fixed-fps 60 makes every frame exactly one physics tick: fast and
## deterministic.

const TESTS_DIR: String = "res://tools/tests"

var _counter := ErrorCounter.new()


func _initialize() -> void:
	OS.add_logger(_counter)
	_run.call_deferred()


func _run() -> void:
	var filters: PackedStringArray = OS.get_cmdline_user_args()
	var passed: int = 0
	var failed: int = 0
	for file_name: String in DirAccess.get_files_at(TESTS_DIR):
		if not file_name.begins_with("test_") or file_name.get_extension() != "gd":
			continue
		if not filters.is_empty() and not _matches(file_name, filters):
			continue
		var script := load(TESTS_DIR.path_join(file_name)) as GDScript
		if script == null:
			failed += 1
			print("FAIL %s (does not load)" % file_name)
			continue
		print(file_name)
		for method: Dictionary in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			var test := script.new() as TestCase
			test.tree = self
			_counter.take_errors()
			await test.call(method_name)
			await test.cleanup()
			var problems: PackedStringArray = test.failures()
			for error: String in _counter.take_errors():
				problems.append("engine error: " + error)
			if problems.is_empty():
				passed += 1
				print("  ok   ", method_name)
			else:
				failed += 1
				print("  FAIL ", method_name)
				for problem: String in problems:
					print("       - ", problem)
	print("\n%d passed, %d failed" % [passed, failed])
	OS.remove_logger(_counter)
	quit(1 if failed > 0 else 0)


func _matches(file_name: String, filters: PackedStringArray) -> bool:
	for filter: String in filters:
		if file_name.contains(filter):
			return true
	return false
