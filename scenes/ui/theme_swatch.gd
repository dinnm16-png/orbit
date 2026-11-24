class_name ThemeSwatch
extends Button
## A theme choice: a mini orbit drawn in that theme's own colors.

signal chosen(theme_id: String)

var theme_id: String = "nebula"
var is_selected: bool = false
var locked: bool = false
var lock_hint: String = ""


func setup(p_id: String, p_selected: bool, p_locked: bool = false, p_lock_hint: String = "") -> void:
	theme_id = p_id
	is_selected = p_selected
	locked = p_locked
	lock_hint = p_lock_hint


func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(150, 190)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	disabled = locked
	pressed.connect(func(): chosen.emit(theme_id))
	# Planet bodies use the shared planet shader.
	var t: Dictionary = Themes.DATA[theme_id]
	var cols: Array = t["planets"]
	var spots := [[Vector2(0, 0), 20.0, 0], [Vector2(-34, 16), 9.0, 1], [Vector2(32, -18), 11.0, 2], [Vector2(24, 26), 7.0, 4]]
	for spot in spots:
		var p := Node2D.new()
		p.material = PlanetArt.material()
		var col := Color(cols[spot[2]])
		var r: float = spot[1]
		p.draw.connect(func(): PlanetArt.draw_body(p, r, col))
		p.position = Vector2(75, 70) + spot[0]
		p.modulate.a = 0.35 if locked else 1.0
		add_child(p)


func _draw() -> void:
	var t: Dictionary = Themes.DATA[theme_id]
	var rect := Rect2(Vector2(6, 6), Vector2(size.x - 12, 128))
	var bg := UIStyle.box(Color(t["bg"]), Color(t["primary"], 0.9 if is_selected else 0.18), 26, 3 if is_selected else 1)
	draw_style_box(bg, rect)
	var font := UIStyle.spaced_font(3)
	draw_string(font, Vector2(0, 166), t["name"].to_upper(), HORIZONTAL_ALIGNMENT_CENTER, size.x, 17,
		UIStyle.WHITE if is_selected else Color(UIStyle.WHITE, 0.55))
	if locked:
		draw_string(font, Vector2(0, 186), lock_hint, HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, Color(UIStyle.WHITE, 0.35))
