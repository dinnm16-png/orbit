class_name FxLayer
extends CanvasLayer
## Full-screen effects above the game world and below the HUD:
## the shockwave (screen distortion) and the danger vignette.
## Both are hidden when idle, so they cost nothing most of the time.

const SHOCK := preload("res://resources/shaders/shockwave.gdshader")
const VIGNETTE := preload("res://resources/shaders/vignette.gdshader")

var _shock: ColorRect
var _vignette: ColorRect
var _shock_t: float = 1.0
var _shock_strength: float = 0.0
var _shock_speed: float = 1.0
## 0..1 tension (Main sets it every frame) and a heartbeat pulse on top.
var tension: float = 0.0
var _pulse: float = 0.0


func _ready() -> void:
	layer = 1
	_shock = _rect(SHOCK)
	_vignette = _rect(VIGNETTE)
	_shock.visible = false
	_vignette.visible = false


func _rect(shader: Shader) -> ColorRect:
	var r := ColorRect.new()
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = shader
	r.material = m
	add_child(r)
	return r


## Starts a shockwave at a point given in screen pixels.
func shockwave(screen_pos: Vector2, strength: float = 0.02, speed: float = 1.4) -> void:
	var size := get_viewport().get_visible_rect().size
	var m: ShaderMaterial = _shock.material
	m.set_shader_parameter("center", screen_pos / size)
	m.set_shader_parameter("aspect", size.x / size.y)
	_shock_t = 0.0
	_shock_strength = strength
	_shock_speed = speed
	_shock.visible = true


## Draw both effects once at zero strength so their shaders get compiled now.
func prewarm() -> void:
	_shock.visible = true
	_shock_t = 0.999
	_shock_strength = 0.0
	_vignette.visible = true
	var vm: ShaderMaterial = _vignette.material
	vm.set_shader_parameter("amount", 0.0)


func heartbeat() -> void:
	_pulse = 1.0


func _process(delta: float) -> void:
	# Real time, so effects play at the same speed during slow motion.
	var real := delta / maxf(Engine.time_scale, 0.01)
	if _shock.visible:
		_shock_t += real * _shock_speed
		var m: ShaderMaterial = _shock.material
		m.set_shader_parameter("radius", _shock_t * 0.9)
		m.set_shader_parameter("strength", _shock_strength * (1.0 - _shock_t))
		if _shock_t >= 1.0:
			_shock.visible = false
	_pulse = maxf(_pulse - real * 2.5, 0.0)
	var amount := clampf(tension + _pulse * 0.25 * signf(tension), 0.0, 1.0)
	_vignette.visible = amount > 0.01
	if _vignette.visible:
		var vm: ShaderMaterial = _vignette.material
		vm.set_shader_parameter("amount", amount)
		var size := get_viewport().get_visible_rect().size
		vm.set_shader_parameter("aspect", size.x / size.y)
