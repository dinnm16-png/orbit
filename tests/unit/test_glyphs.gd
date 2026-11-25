extends "res://tests/test_case.gd"
## Every character the game draws must exist in the built-in font. On the web
## and on phones there is no system font to fall back on: a missing glyph shows
## as an empty box (this caught "✦" and "★" in the web demo).

## Text in these files goes to the clipboard / console, not the screen.
const SKIP := ["share_text.gd", "puzzle_check.gd", "balance.gd"]


func _scan(dir: String, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd") and not SKIP.has(f):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_scan(dir.path_join(d), out)


func test_all_drawn_characters_exist_in_the_font() -> void:
	var font := ThemeDB.fallback_font
	var files := []
	_scan("res://scenes", files)
	_scan("res://scripts", files)
	var missing := {}
	for path in files:
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for n in lines.size():
			var line := lines[n].strip_edges()
			if line.begins_with("#"):
				continue  # Comments are never drawn.
			var code := line.split(" #")[0]
			for i in code.length():
				var c := code.unicode_at(i)
				if c > 127 and not font.has_char(c):
					missing["%s:%d '%s'" % [path.get_file(), n + 1, code[i]]] = true
	assert_true(missing.is_empty(), "characters missing from the font: %s" % ", ".join(missing.keys()))
