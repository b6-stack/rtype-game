class_name PickupFX
extends Node2D
## PickupFX — vibrant weapon collection celebration effect.
## Features expanding holographic shockwave ring, floating glowing weapon name badge,
## and ascending sparkling energy particles.

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
var _ring_radius: float = 10.0
var _color: Color = Color.CYAN
var _weapon_name: String = "WEAPON"
var _lifetime: float = 0.0
const DURATION: float = 0.85

var _label: Label

func _ready() -> void:
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 8)
	_label.anchors_preset = Control.PRESET_CENTER
	_label.position = Vector2(-100, -20)
	_label.size = Vector2(200, 40)
	add_child(_label)

func setup(pos: Vector2, weapon_index: int) -> void:
	global_position = pos
	_color = WEAPON_COLORS[weapon_index] if weapon_index < WEAPON_COLORS.size() else Color.CYAN
	_weapon_name = WEAPON_NAMES[weapon_index] if weapon_index < WEAPON_NAMES.size() else "POWER UP"

	if _label:
		_label.text = "+ " + _weapon_name
		_label.add_theme_color_override("font_color", _color.lightened(0.5))

	_create_sparks()

func setup_custom(pos: Vector2, text_msg: String, custom_col: Color) -> void:
	global_position = pos
	_color = custom_col
	_weapon_name = text_msg

	if _label:
		_label.text = "+ " + text_msg
		_label.add_theme_color_override("font_color", _color.lightened(0.6))

	_create_sparks()

func _create_sparks() -> void:
	_sparks.clear()
	for i in range(14):
		var angle: float = (TAU / 14.0) * i + randf_range(-0.15, 0.15)
		var speed: float = randf_range(90.0, 220.0)
		_sparks.append({
			"pos": Vector2.ZERO,
			"vel": Vector2.RIGHT.rotated(angle) * speed,
			"size": randf_range(3.0, 6.0),
			"color": _color.lightened(randf_range(0.2, 0.7))
		})

func _process(delta: float) -> void:
	_lifetime += delta
	var progress: float = _lifetime / DURATION
	if progress >= 1.0:
		queue_free()
		return

	# Expand holographic ring
	_ring_radius = lerpf(10.0, 110.0, ease(progress, 0.35))

	# Float text upward
	if _label:
		_label.position.y = -20.0 - progress * 45.0
		_label.modulate.a = 1.0 - ease(progress, 2.0)

	# Update sparks
	for s in _sparks:
		s["pos"] += s["vel"] * delta
		s["vel"] *= 0.93
		s["size"] = max(0.5, s["size"] * 0.95)

	queue_redraw()

func _draw() -> void:
	var alpha: float = 1.0 - (_lifetime / DURATION)

	# 1. Radiant central flash
	var flash_rad: float = max(0.0, (1.0 - _lifetime / 0.3) * 35.0)
	if flash_rad > 1.0:
		draw_circle(Vector2.ZERO, flash_rad, Color(1, 1, 1, alpha * 0.8))
		draw_circle(Vector2.ZERO, flash_rad * 1.6, Color(_color.r, _color.g, _color.b, alpha * 0.4))

	# 2. Expanding holographic energy ring
	draw_arc(Vector2.ZERO, _ring_radius, 0, TAU, 36, Color(_color.r, _color.g, _color.b, alpha * 0.9), 3.0)
	draw_arc(Vector2.ZERO, max(1.0, _ring_radius - 3.0), 0, TAU, 36, Color(1, 1, 1, alpha * 0.6), 1.5)

	# 3. Sparkling energy diamonds
	for s in _sparks:
		var c: Color = s["color"]
		var p: Vector2 = s["pos"]
		var sz: float = s["size"]
		# Draw small diamond/cross sparkle
		var diamond := PackedVector2Array([
			p + Vector2(0, -sz),
			p + Vector2(sz, 0),
			p + Vector2(0, sz),
			p + Vector2(-sz, 0)
		])
		draw_colored_polygon(diamond, Color(c.r, c.g, c.b, alpha))
