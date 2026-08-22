class_name PickupFX
extends Node2D
## PickupFX — high-impact arcade powerup collection effect.
## Features spring-animated pop badge, radial energy light rays, cross flares,
## multi-layered expanding shockwaves, and floating sparkling star dust.

const WEAPON_NAMES: Array[String] = [
	"VULCAN", "LASER", "PLASMA", "MISSILE", "WAVE",
	"BOUNCER", "DRILL", "RICOCHET", "GRAVITY", "LIGHTNING"
]

const WEAPON_COLORS: Array[Color] = [
	Color(0.0, 1.0, 1.0),   # 0 Vulcan     - cyan
	Color(1.0, 0.0, 1.0),   # 1 Laser      - magenta
	Color(0.2, 1.0, 0.3),   # 2 Plasma     - green
	Color(1.0, 0.5, 0.0),   # 3 Missile    - orange
	Color(0.4, 0.6, 1.0),   # 4 Wave       - blue
	Color(1.0, 0.95, 0.1),  # 5 Bouncer    - yellow
	Color(1.0, 0.2, 0.2),   # 6 Drill      - red
	Color(0.8, 0.3, 1.0),   # 7 Ricochet   - violet
	Color(0.2, 0.4, 1.0),   # 8 Gravity    - deep blue
	Color(1.0, 1.0, 1.0),   # 9 Lightning  - bright white
]

var _sparks: Array[Dictionary] = []
var _rays: Array[Dictionary] = []
var _ring_radius: float = 10.0
var _color: Color = Color.CYAN
var _weapon_name: String = "WEAPON"
var _lifetime: float = 0.0
const DURATION: float = 0.9

var _label: Label

func _init() -> void:
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 24)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 10)
	_label.anchors_preset = Control.PRESET_CENTER
	_label.position = Vector2(-100, -20)
	_label.size = Vector2(200, 40)
	_label.pivot_offset = Vector2(100, 20)
	add_child(_label)

func _ready() -> void:
	if _label:
		_label.text = "⚡ " + _weapon_name
		_label.add_theme_color_override("font_color", _color.lightened(0.5))

func setup(pos: Vector2, weapon_index: int) -> void:
	global_position = pos
	_color = WEAPON_COLORS[weapon_index] if weapon_index < WEAPON_COLORS.size() else Color.CYAN
	_weapon_name = WEAPON_NAMES[weapon_index] if weapon_index < WEAPON_NAMES.size() else "POWER UP"

	if _label:
		_label.text = "⚡ " + _weapon_name
		_label.add_theme_color_override("font_color", _color.lightened(0.5))

	_create_sparks_and_rays()

func setup_custom(pos: Vector2, text_msg: String, custom_col: Color) -> void:
	global_position = pos
	_color = custom_col
	_weapon_name = text_msg

	if _label:
		_label.text = "⚡ " + text_msg
		_label.add_theme_color_override("font_color", _color.lightened(0.6))

	_create_sparks_and_rays()

func _create_sparks_and_rays() -> void:
	_sparks.clear()
	_rays.clear()
	# 20 sparkling particles with varied angles and upward buoyancy
	for i in range(20):
		var angle: float = (TAU / 20.0) * i + randf_range(-0.2, 0.2)
		var speed: float = randf_range(110.0, 280.0)
		_sparks.append({
			"pos": Vector2.ZERO,
			"vel": Vector2.RIGHT.rotated(angle) * speed + Vector2(0, -40.0),
			"size": randf_range(3.5, 7.0),
			"color": _color.lightened(randf_range(0.2, 0.8))
		})

	# 12 radial light rays
	for i in range(12):
		var angle: float = (TAU / 12.0) * i
		_rays.append({
			"dir": Vector2.RIGHT.rotated(angle),
			"length": randf_range(50.0, 130.0),
			"width": randf_range(2.0, 4.5)
		})

func _process(delta: float) -> void:
	_lifetime += delta
	var progress: float = _lifetime / DURATION
	if progress >= 1.0:
		queue_free()
		return

	# Expand shockwave ring
	_ring_radius = lerpf(8.0, 130.0, ease(progress, 0.3))

	# Spring pop badge text animation
	if _label:
		var pop: float = 1.0 + 0.5 * exp(-progress * 8.0) * sin(progress * 18.0)
		_label.scale = Vector2(pop, pop)
		_label.position.y = -20.0 - progress * 55.0
		_label.modulate.a = 1.0 - ease(progress, 2.2)

	# Update sparkling particles
	for s in _sparks:
		s["pos"] += s["vel"] * delta
		s["vel"].y -= 30.0 * delta # upward rise
		s["vel"] *= 0.92
		s["size"] = max(0.5, s["size"] * 0.94)

	queue_redraw()

func _draw() -> void:
	var alpha: float = 1.0 - (_lifetime / DURATION)
	var progress: float = _lifetime / DURATION

	# 1. Radial Energy Light Rays
	var ray_mult: float = (1.0 - progress) * 1.2
	var ray_lines := PackedVector2Array()
	for r in _rays:
		var start_p: Vector2 = r["dir"] * (_ring_radius * 0.2)
		var end_p: Vector2 = r["dir"] * (r["length"] * ray_mult)
		ray_lines.append(start_p)
		ray_lines.append(end_p)
	if ray_lines.size() > 0:
		draw_multiline(ray_lines, Color(_color.r, _color.g, _color.b, alpha * 0.65), 2.5)

	# 2. Cross-Flare Optical Stars
	var flare_len: float = (1.0 - ease(progress, 2.0)) * 75.0
	if flare_len > 2.0:
		draw_line(Vector2(-flare_len, 0), Vector2(flare_len, 0), Color(1, 1, 1, alpha * 0.9), 3.0)
		draw_line(Vector2(0, -flare_len * 0.6), Vector2(0, flare_len * 0.6), Color(1, 1, 1, alpha * 0.9), 2.0)
		draw_line(Vector2(-flare_len * 0.5, 0), Vector2(flare_len * 0.5, 0), Color(_color.r, _color.g, _color.b, alpha), 6.0)

	# 3. Radiant Core Flash
	var flash_rad: float = max(0.0, (1.0 - _lifetime / 0.25) * 45.0)
	if flash_rad > 1.0:
		draw_circle(Vector2.ZERO, flash_rad, Color(1, 1, 1, alpha * 0.85))
		draw_circle(Vector2.ZERO, flash_rad * 1.5, Color(_color.r, _color.g, _color.b, alpha * 0.45))

	# 4. Expanding Dual Energy Shockwaves
	draw_arc(Vector2.ZERO, _ring_radius, 0, TAU, 36, Color(_color.r, _color.g, _color.b, alpha * 0.9), 3.5)
	draw_arc(Vector2.ZERO, max(1.0, _ring_radius - 4.0), 0, TAU, 36, Color(1, 1, 1, alpha * 0.7), 1.5)

	# 5. Sparkling Energy Stars
	for s in _sparks:
		var c: Color = s["color"]
		var p: Vector2 = s["pos"]
		var sz: float = s["size"]
		var diamond := PackedVector2Array([
			p + Vector2(0, -sz),
			p + Vector2(sz, 0),
			p + Vector2(0, sz),
			p + Vector2(-sz, 0)
		])
		draw_colored_polygon(diamond, Color(c.r, c.g, c.b, alpha))
