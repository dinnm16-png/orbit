extends "res://tests/test_case.gd"
## Guards the release setup: icons exist at the sizes stores require, export
## presets point to real files, and the app ID is valid.

const PRESETS := "res://export_presets.cfg"


func _presets() -> ConfigFile:
	var cfg := ConfigFile.new()
	assert_eq(cfg.load(PRESETS), OK, "export_presets.cfg readable")
	return cfg


func _section_for(cfg: ConfigFile, platform: String) -> String:
	for section in cfg.get_sections():
		if cfg.has_section_key(section, "platform") and cfg.get_value(section, "platform") == platform:
			return section + ".options"
	return ""


func _image_size(path: String) -> Vector2i:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	return img.get_size() if img else Vector2i.ZERO


func test_icon_files_have_required_sizes() -> void:
	var expected := {
		"icon_1024.png": 1024, "icon_192.png": 192, "icon_256.png": 256,
		"adaptive_foreground.png": 432, "adaptive_background.png": 432,
		"adaptive_monochrome.png": 432,
	}
	for file in expected:
		var s := _image_size("res://resources/icons/" + file)
		assert_eq(s, Vector2i(expected[file], expected[file]), file)


func test_ios_icon_is_fully_opaque() -> void:
	# Apple rejects app icons with transparency.
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://resources/icons/icon_1024.png"))
	var transparent := 0
	for y in range(0, 1024, 16):
		for x in range(0, 1024, 16):
			if img.get_pixel(x, y).a < 0.999:
				transparent += 1
	assert_eq(transparent, 0, "no transparent pixels in the iOS icon")


func test_export_presets_point_to_existing_files() -> void:
	var cfg := _presets()
	for platform in ["Android", "iOS"]:
		var section := _section_for(cfg, platform)
		assert_true(section != "", "%s preset exists" % platform)
		for key in cfg.get_section_keys(section):
			if key.begins_with("launcher_icons/") or key.begins_with("icons/"):
				var path: String = cfg.get_value(section, key)
				assert_true(path != "" and FileAccess.file_exists(path), "%s %s -> %s exists" % [platform, key, path])


func test_app_ids_are_valid_and_not_placeholders() -> void:
	var cfg := _presets()
	var re := RegEx.create_from_string("^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$")
	var android: String = cfg.get_value(_section_for(cfg, "Android"), "package/unique_name")
	var ios: String = cfg.get_value(_section_for(cfg, "iOS"), "application/bundle_identifier")
	for id in [android, ios]:
		assert_true(re.search(id) != null, "valid app id: %s" % id)
		assert_false(id.begins_with("com.example"), "not a placeholder: %s" % id)
	assert_eq(android, ios, "same id on both stores")


func test_versions_match_project() -> void:
	var cfg := _presets()
	var v: String = ProjectSettings.get_setting("application/config/version")
	assert_eq(cfg.get_value(_section_for(cfg, "Android"), "version/name"), v, "Android version name")
	assert_eq(cfg.get_value(_section_for(cfg, "iOS"), "application/short_version"), v, "iOS version")


func test_builds_request_no_internet_permission() -> void:
	# Privacy promise: ORBIT is offline and collects no data.
	var cfg := _presets()
	assert_false(cfg.get_value(_section_for(cfg, "Android"), "permissions/internet", false), "no INTERNET permission")
