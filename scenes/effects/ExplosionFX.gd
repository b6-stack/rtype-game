class_name ExplosionFX
extends Node2D
## ExplosionFX — procedural arcade particle explosion with shockwave rings,
## glowing core burst, and scattering burning sparks.

var _sparks: Array[Dictionary] = []
var _shockwave_radius: float = 5.0
var _shockwave_max_radius: float = 90.0
var _flash_radius: float = 30.0
var _color: Color = Color(1.0, 0.6, 0.1)
var _lifetime: float = 0.0
const DURATION: float = 0.6

func setup(pos: Vector2, col: Color = Color(1.0, 0.6, 0.1), scale_factor: float = 1.0) -> void:
	global_position = pos
	_color = col
	_shockwave_max_radius = 80.0 * scale_factor
	_flash_radius = 35.0 * scale_factor

	# Create 16-24 scattering sparks
	var spark_count: int = int(18 * scale_factor)
	for i in range(spark_count):
		var angle: float = randf() * TAU
		var speed: float = randf_range(120.0, 380.0) * scale_factor
		var vel: Vector2 = Vector2.RIGHT.rotated(angle) * speed
		_sparks.append({
			"pos": Vector2.ZERO,
			"vel": vel,
			"size": randf_range(3.0, 7.0) * scale_factor,
			"color": col.lightened(randf_range(0.1, 0.6))
		})

func _process(delta: float) -> void:
	_lifetime += delta
	var progress: float = _lifetime / DURATION
	if progress >= 1.0:
		queue_free()
		return

	# Expand shockwave
	_shockwave_radius = lerpf(5.0, _shockwave_max_radius, ease(progress, 0.3))
	_flash_radius = lerpf(35.0, 0.0, progress)

	# Update sparks
	for s in _sparks:
		s["pos"] += s["vel"] * delta
		s["vel"] *= 0.94 # drag
		s["size"] = max(0.5, s["size"] * 0.96)

	queue_redraw()

func _draw() -> void:
	var alpha: float = 1.0 - (_lifetime / DURATION)

	# 1. Central Core Flash
	if _flash_radius > 1.0:
		draw_circle(Vector2.ZERO, _flash_radius, Color(1.0, 1.0, 1.0, alpha * 0.9))
		draw_circle(Vector2.ZERO, _flash_radius * 1.5, Color(_color.r, _color.g, _color.b, alpha * 0.4))

	# 2. Glowing Shockwave Ring
	draw_arc(Vector2.ZERO, _shockwave_radius, 0, TAU, 32, Color(_color.r, _color.g, _color.b, alpha * 0.8), 3.5)
	draw_arc(Vector2.ZERO, max(1.0, _shockwave_radius - 4.0), 0, TAU, 32, Color(1.0, 1.0, 1.0, alpha * 0.5), 2.0)

	# 3. High-velocity burning sparks
	for s in _sparks:
		var c: Color = s["color"]
		draw_circle(s["pos"], s["size"], Color(c.r, c.g, c.b, alpha))
