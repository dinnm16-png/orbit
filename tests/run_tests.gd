extends SceneTree
## Headless test runner. Usage (from the project folder):
##   godot --headless -s res://tests/run_tests.gd
## Exit code 0 = all tests passed, 1 = at least one failure.

const TEST_DIRS := ["res://tests/unit", "res://tests/integration"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var passed := 0
	var failed := 0
	for dir in TEST_DIRS:
		var files := DirAccess.get_files_at(dir)
		files.sort()
		for file in files:
			if not (file.begins_with("test_") and file.ends_with(".gd")):
				continue
			var script: GDScript = load(dir.path_join(file))
			print("\n%s" % file)
			for method in script.get_script_method_list():
				var name: String = method["name"]
				if not name.begins_with("test_"):
					continue
				var test = script.new()
				test.tree = self
				await test.call(name)
				if test.failures.is_empty():
					passed += 1
					print("  PASS  %s" % name)
				else:
					failed += 1
					print("  FAIL  %s" % name)
					for f in test.failures:
						print("        - %s" % f)
	print("\n%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
