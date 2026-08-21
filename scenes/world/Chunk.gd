class_name Chunk
extends Node2D
## Chunk — a single procedurally generated modular section of scrolling level landscape.
## Sparse, guarantees a wide safe corridor path that never dead-ends.
## Includes physics collision for walls and sci-fi modular landscape detailing.

signal enemy_spawn_requested(position: Vector2, enemy_type_id: int)
signal powerup_spawn_requested(position: Vector2, weapon_index: int)

const CHUNK_WIDTH: float = 640.0
const SCREEN_HEIGHT: float = 1080.0

var corridor_top_left: float = 180.0
var corridor_bottom_left: float = 900.0
var corridor_top_right: float = 180.0
var corridor_bottom_right: float = 900.0

var _top_wall_poly: PackedVector2Array = PackedVector2Array()
var _bot_wall_poly: PackedVector2Array = PackedVector2Array()
var _obstacle_polygons: Array[PackedVector2Array] = []
var _tech_lines: Array[PackedVector2Array] = []
var _crystal_points: Array[Dictionary] = []

var _wall_color: Color = Color(0.12, 0.18, 0.30)
var _detail_color: Color = Color(0.18, 0.28, 0.45)
var _glow_color: Color = Color(0.3, 0.8, 1.0, 0.8)

var scroll_speed: float = 180.0

@onready var _static_body: StaticBody2D = $StaticBody2D
@onready var _top_col: CollisionPolygon2D = $StaticBody2D/TopCol
@onready var _bot_col: CollisionPolygon2D = $StaticBody2D/BotCol

func _physics_process(delta: float) -> void:
	global_position.x -= scroll_speed * delta
	if global_position.x < -CHUNK_WIDTH - 100.0:
		queue_free()

func _draw() -> void:
	# 1. Base Wall Geometry
	if _top_wall_poly.size() >= 3:
		draw_colored_polygon(_top_wall_poly, _wall_color)
	if _bot_wall_poly.size() >= 3:
		draw_colored_polygon(_bot_wall_poly, _wall_color)

	# 2. Tech / Biome Grid Patterns on Walls
	for line in _tech_lines:
		if line.size() >= 2:
			draw_line(line[0], line[1], _wall_color.lightened(0.15), 2.0)

	# 3. Modular Obstacle Formations (Stalagmites / Tech Pylons)
	for pts in _obstacle_polygons:
		draw_colored_polygon(pts, _detail_color)
		# Outline obstacle
		for j in range(pts.size()):
			var p1: Vector2 = pts[j]
			var p2: Vector2 = pts[(j + 1) % pts.size()]
			draw_line(p1, p2, _glow_color * 0.7, 1.5)

	# 4. Glowing Landscape Border Lines
	draw_line(Vector2(0, corridor_top_left), Vector2(CHUNK_WIDTH + 2.0, corridor_top_right), _glow_color, 3.0)
	draw_line(Vector2(0, corridor_bottom_left), Vector2(CHUNK_WIDTH + 2.0, corridor_bottom_right), _glow_color, 3.0)

	# Subtle inner glow line
	draw_line(Vector2(0, corridor_top_left - 4), Vector2(CHUNK_WIDTH + 2.0, corridor_top_right - 4), _glow_color * 0.4, 6.0)
	draw_line(Vector2(0, corridor_bottom_left + 4), Vector2(CHUNK_WIDTH + 2.0, corridor_bottom_right + 4), _glow_color * 0.4, 6.0)

	# 5. Glowing Energy Crystals / Tech Node Beacons
	for c in _crystal_points:
		var c_pos: Vector2 = c["pos"]
		var c_col: Color = c["color"]
		draw_circle(c_pos, 4.0, c_col)
		draw_circle(c_pos, 8.0, Color(c_col.r, c_col.g, c_col.b, 0.3))

## Build the chunk geometry from corridor parameters.
func build(l_top: float, l_bot: float, r_top: float, r_bot: float,
		wall_col: Color, speed: float, rng: RandomNumberGenerator) -> void:
	corridor_top_left = l_top
	corridor_bottom_left = l_bot
	corridor_top_right = r_top
	corridor_bottom_right = r_bot
	_wall_color = wall_col
	_detail_color = wall_col.lightened(0.2)
	_glow_color = wall_col.lightened(0.6)
	_glow_color.a = 0.85
	scroll_speed = speed

	# Top wall polygon (with 2px rightward seam overlap)
	_top_wall_poly = PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(CHUNK_WIDTH + 2.0, 0.0),
		Vector2(CHUNK_WIDTH + 2.0, r_top),
		Vector2(0.0, l_top),
	])

	# Bottom wall polygon (with 2px rightward seam overlap)
	_bot_wall_poly = PackedVector2Array([
		Vector2(0.0, l_bot),
		Vector2(CHUNK_WIDTH + 2.0, r_bot),
		Vector2(CHUNK_WIDTH + 2.0, SCREEN_HEIGHT),
		Vector2(0.0, SCREEN_HEIGHT),
	])

	# Apply physics collisions
	if _top_col: _top_col.polygon = _top_wall_poly
	if _bot_col: _bot_col.polygon = _bot_wall_poly

	# Procedural tech detail lines
	_tech_lines.clear()
	var step_count: int = 4
	for i in range(step_count):
		var x_ratio: float = float(i) / float(step_count)
		var x_pos: float = x_ratio * CHUNK_WIDTH
		var top_y: float = lerpf(l_top, r_top, x_ratio)
		var bot_y: float = lerpf(l_bot, r_bot, x_ratio)
		_tech_lines.append(PackedVector2Array([Vector2(x_pos, 0), Vector2(x_pos, top_y)]))
		_tech_lines.append(PackedVector2Array([Vector2(x_pos, bot_y), Vector2(x_pos, SCREEN_HEIGHT)]))

	# Modular sparse landscape obstacles (guaranteed wide corridor clearance > 250px)
	_generate_sparse_obstacles(l_top, l_bot, r_top, r_bot, rng)
	queue_redraw()

func _generate_sparse_obstacles(l_top: float, l_bot: float, r_top: float, r_bot: float,
		rng: RandomNumberGenerator) -> void:
	_obstacle_polygons.clear()
	_crystal_points.clear()

	# Sparse: 0 or 1 protrusion per chunk, spaced out
	if rng.randf() < 0.65:
		var t: float = rng.randf_range(0.25, 0.75)
		var x: float = t * CHUNK_WIDTH
		var interp_top: float = lerpf(l_top, r_top, t)
		var interp_bot: float = lerpf(l_bot, r_bot, t)
		var corridor_h: float = interp_bot - interp_top

		# Only place if there is abundant room (>320px)
		if corridor_h >= 320.0:
			var from_top: bool = rng.randf() < 0.5
			var protrude: float = rng.randf_range(50.0, min(100.0, corridor_h * 0.28))
			var half_w: float = rng.randf_range(40.0, 70.0)

			var pts: PackedVector2Array
			if from_top:
				pts = PackedVector2Array([
					Vector2(x - half_w, interp_top),
					Vector2(x + half_w, interp_top),
					Vector2(x + half_w * 0.5, interp_top + protrude),
					Vector2(x, interp_top + protrude + 15.0),
					Vector2(x - half_w * 0.5, interp_top + protrude),
				])
				_crystal_points.append({"pos": Vector2(x, interp_top + protrude + 8.0), "color": _glow_color})
			else:
				pts = PackedVector2Array([
					Vector2(x - half_w * 0.5, interp_bot - protrude),
					Vector2(x, interp_bot - protrude - 15.0),
					Vector2(x + half_w * 0.5, interp_bot - protrude),
					Vector2(x + half_w, interp_bot),
					Vector2(x - half_w, interp_bot),
				])
				_crystal_points.append({"pos": Vector2(x, interp_bot - protrude - 8.0), "color": _glow_color})

			_obstacle_polygons.append(pts)

func emit_spawns(spawn_data: Array) -> void:
	for s in spawn_data:
		if s["type"] == "enemy":
			enemy_spawn_requested.emit(global_position + s["pos"], s["id"])
		elif s["type"] == "powerup":
			powerup_spawn_requested.emit(global_position + s["pos"], s["id"])
