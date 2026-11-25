class_name ChallengePanel
extends VBoxContainer
## "Play a challenge": paste a friend's code, see what it is, play it.

signal play_requested(challenge: Dictionary)

var _input: LineEdit
var _preview: Label
var _play: Button
var _decoded: Dictionary = {}


func _ready() -> void:
	add_theme_constant_override("separation", 16)
	add_child(UIStyle.label("PLAY A CHALLENGE", 30, UIStyle.WHITE, 5))
	var desc := UIStyle.label("Got a code from a friend? You'll get exactly the same planets. Beat their score.", 20, Color(UIStyle.WHITE, 0.65))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(560, 0)
	add_child(desc)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_input = LineEdit.new()
	_input.placeholder_text = "ORB-XXXX-XXXX-XXXXXX"
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.custom_minimum_size = Vector2(0, 72)
	_input.add_theme_font_override("font", UIStyle.spaced_font(3))
	_input.add_theme_font_size_override("font_size", 22)
	_input.add_theme_color_override("font_color", UIStyle.WHITE)
	_input.add_theme_stylebox_override("normal", _field_box(Color(UIStyle.WHITE, 0.18)))
	_input.add_theme_stylebox_override("focus", _field_box(UIStyle.AQUA))
	_input.text_changed.connect(_on_text)
	row.add_child(_input)
	var paste := UIStyle.button("PASTE", false, UIStyle.AQUA, 72)
	paste.custom_minimum_size.x = 160
	paste.pressed.connect(func():
		_input.text = DisplayServer.clipboard_get()
		_on_text(_input.text))
	row.add_child(paste)
	add_child(row)

	_preview = UIStyle.label("", 18, Color(UIStyle.WHITE, 0.5), 3)
	add_child(_preview)
	_play = UIStyle.button("PLAY CHALLENGE", true, UIStyle.AQUA, 92)
	_play.disabled = true
	_play.pressed.connect(func():
		if not _decoded.is_empty():
			play_requested.emit(_decoded))
	add_child(_play)


func _on_text(text: String) -> void:
	_decoded = ChallengeCode.decode(text)
	if text.strip_edges() == "":
		_preview.text = ""
	elif _decoded.is_empty():
		_preview.text = "That code doesn't look right — check it and try again"
		_preview.add_theme_color_override("font_color", Color("#FF9F7A"))
	else:
		var mode := Session.load_mode(_decoded["mode"])
		_preview.text = "%s  ·  %s  ·  BEAT %s" % [mode.title.to_upper(),
			Difficulty.NAMES[clampi(_decoded["difficulty"], 0, 2)].to_upper(), ShareText.group(_decoded["score"])]
		_preview.add_theme_color_override("font_color", UIStyle.AQUA)
	_play.disabled = _decoded.is_empty()


func _field_box(border: Color) -> StyleBoxFlat:
	var b := UIStyle.box(Color(UIStyle.SURFACE, 0.9), border, 22, 2)
	b.content_margin_left = 20
	b.content_margin_right = 20
	return b
