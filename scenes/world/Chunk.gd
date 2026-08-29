class_name Chunk
extends Node2D
## Chunk — a procedurally generated modular section of scrolling level landscape.
## Features distinct biome-themed props, glowing energy crystals, and terrain collisions.

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
var _biome_props: Array[Dictionary] = [] # [{type, pts, color, outline}]
var _beacon_points: Array[Dictionary] = [] # [{pos, color, radius}]

var _wall_color: Color = Color(0.12, 0.18, 0.30)
var _detail_color: Color = Color(0.18, 0.28, 0.45)
var _glow_color: Color = Color(0.3, 0.8, 1.0, 0.8)
var _level_theme: int = 1

var scroll_speed: float = 180.0

@onready var _top_col: CollisionPolygon2D = $StaticBody2D/TopCol
@onready var _bot_col: CollisionPolygon2D = $StaticBody2D/BotCol

func _physics_process(delta: float) -> void:
	global_position.x -= scroll_speed * delta
	if global_position.x < -CHUNK_WIDTH - 100.0:
		queue_free()

func _draw() -> void:
	# 1. Base Wall Cavern Geometry
	if _top_wall_poly.size() >= 3:
		draw_colored_polygon(_top_wall_poly, _wall_color)
	if _bot_wall_poly.size() >= 3:
		draw_colored_polygon(_bot_wall_poly, _wall_color)

	# 2. Tech Conduits / Circuit Lines on Cavern Walls
	for line in _tech_lines:
		if line.size() >= 2:
			draw_line(line[0], line[1], _wall_color.lightened(0.18), 2.5)

	# 3. Biome Themed Props (Crystals, Pipes, Bio-Pods, Girders, Vents)
	for prop in _biome_props:
		var pts: PackedVector2Array = prop["pts"]
		var col: Color = prop["color"]
		draw_colored_polygon(pts, col)
		if prop.get("outline", true):
			for j in range(pts.size()):
				var p1: Vector2 = pts[j]
				var p2: Vector2 = pts[(j + 1) % pts.size()]
				draw_line(p1, p2, _glow_color * 0.85, 2.0)

	# 4. Modular Obstacle Formations (Stalagmites / Pylons)
	for pts in _obstacle_polygons:
		draw_colored_polygon(pts, _detail_color)
		for j in range(pts.size()):
			var p1: Vector2 = pts[j]
			var p2: Vector2 = pts[(j + 1) % pts.size()]
			draw_line(p1, p2, _glow_color * 0.7, 1.8)

	# 5. Glowing Landscape Border Rails
	draw_line(Vector2(0, corridor_top_left), Vector2(CHUNK_WIDTH + 2.0, corridor_top_right), _glow_color, 3.5)
	draw_line(Vector2(0, corridor_bottom_left), Vector2(CHUNK_WIDTH + 2.0, corridor_bottom_right), _glow_color, 3.5)

	# Inner neon glow
	draw_line(Vector2(0, corridor_top_left - 4), Vector2(CHUNK_WIDTH + 2.0, corridor_top_right - 4), _glow_color * 0.45, 6.0)
	draw_line(Vector2(0, corridor_bottom_left + 4), Vector2(CHUNK_WIDTH + 2.0, corridor_bottom_right + 4), _glow_color * 0.45, 6.0)

	# 6. Glowing Themed Beacons & Crystals
	for b in _beacon_points:
		var b_pos: Vector2 = b["pos"]
		var b_col: Color = b["color"]
		var rad: float = b.get("radius", 5.0)
		draw_circle(b_pos, rad, b_col)
		draw_circle(b_pos, rad * 2.2, Color(b_col.r, b_col.g, b_col.b, 0.35))

## Build the chunk geometry from corridor parameters.
func build(l_top: float, l_bot: float, r_top: float, r_bot: float,
		wall_col: Color, speed: float, rng: RandomNumberGenerator, level_num: int = 1) -> void:
	corridor_top_left = l_top
	corridor_bottom_left = l_bot
	corridor_top_right = r_top
	corridor_bottom_right = r_bot
	_wall_color = wall_col
	_detail_color = wall_col.lightened(0.2)
	_glow_color = wall_col.lightened(0.65)
	_glow_color.a = 0.9
	_level_theme = level_num
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

	# Build circuit grid lines
	_tech_lines.clear()
	var step_count: int = 4
	for i in range(step_count):
		var x_ratio: float = float(i) / float(step_count)
		var x_pos: float = x_ratio * CHUNK_WIDTH
		var top_y: float = lerpf(l_top, r_top, x_ratio)
		var bot_y: float = lerpf(l_bot, r_bot, x_ratio)
		_tech_lines.append(PackedVector2Array([Vector2(x_pos, 0), Vector2(x_pos, top_y)]))
		_tech_lines.append(PackedVector2Array([Vector2(x_pos, bot_y), Vector2(x_pos, SCREEN_HEIGHT)]))

	# Generate distinct themed props
	_generate_themed_props(l_top, l_bot, r_top, r_bot, rng)
	_generate_sparse_obstacles(l_top, l_bot, r_top, r_bot, rng)
	queue_redraw()

func _generate_themed_props(l_top: float, l_bot: float, r_top: float, r_bot: float, rng: RandomNumberGenerator) -> void:
	_biome_props.clear()
	_beacon_points.clear()

	var prop_count: int = rng.randi_range(2, 4)
	for i in range(prop_count):
		var t: float = rng.randf_range(0.1, 0.9)
		var x: float = t * CHUNK_WIDTH
		var on_top: bool = rng.randf() < 0.5
		var base_y: float = lerpf(l_top, r_top, t) if on_top else lerpf(l_bot, r_bot, t)
		var dir_y: float = 1.0 if on_top else -1.0

		match (_level_theme - 1) % 10:
			0, 4, 8: # Azure Caverns / Void Nexus / Cosmic Void (Crystal Spires)
				var h: float = rng.randf_range(30.0, 55.0)
				var w: float = rng.randf_range(14.0, 26.0)
				var pts := PackedVector2Array([
					Vector2(x - w, base_y),
					Vector2(x - w * 0.4, base_y + dir_y * h * 0.7),
					Vector2(x, base_y + dir_y * h),
					Vector2(x + w * 0.4, base_y + dir_y * h * 0.7),
					Vector2(x + w, base_y),
				])
				_biome_props.append({"pts": pts, "color": _detail_color.lightened(0.2), "outline": true})
				_beacon_points.append({"pos": Vector2(x, base_y + dir_y * (h + 4.0)), "color": _glow_color, "radius": 4.5})

			1, 6, 9: # Magma Foundry / Crimson Core / Solar Core (Pipes & Vents)
				var h: float = rng.randf_range(25.0, 45.0)
				var w: float = rng.randf_range(20.0, 36.0)
				var pts := PackedVector2Array([
					Vector2(x - w * 0.5, base_y),
					Vector2(x - w * 0.5, base_y + dir_y * h),
					Vector2(x + w * 0.5, base_y + dir_y * h),
					Vector2(x + w * 0.5, base_y),
				])
				_biome_props.append({"pts": pts, "color": Color(0.35, 0.15, 0.1), "outline": true})
				_beacon_points.append({"pos": Vector2(x, base_y + dir_y * h), "color": Color(1.0, 0.4, 0.1), "radius": 6.0})

			2: # Alien Bio-Hive (Spore Pods & Tendrils)
				var rad: float = rng.randf_range(16.0, 26.0)
				var pod_y: float = base_y + dir_y * rad
				var circle_pts: PackedVector2Array = PackedVector2Array()
				for seg in 8:
					var ang: float = seg * TAU / 8.0
					circle_pts.append(Vector2(x + cos(ang) * rad, pod_y + sin(ang) * rad * 0.8))
				_biome_props.append({"pts": circle_pts, "color": Color(0.15, 0.35, 0.15), "outline": true})
				_beacon_points.append({"pos": Vector2(x, pod_y), "color": Color(0.3, 1.0, 0.4), "radius": 5.0})

			_: # Fortress / Cryo / Dreadnought (Steel Girders & Capacitors)
				var h: float = rng.randf_range(30.0, 50.0)
				var w: float = rng.randf_range(24.0, 40.0)
				var pts := PackedVector2Array([
					Vector2(x - w * 0.5, base_y),
					Vector2(x - w * 0.25, base_y + dir_y * h),
					Vector2(x + w * 0.25, base_y + dir_y * h),
					Vector2(x + w * 0.5, base_y),
				])
				_biome_props.append({"pts": pts, "color": _detail_color, "outline": true})
				_beacon_points.append({"pos": Vector2(x, base_y + dir_y * h), "color": _glow_color, "radius": 4.0})

func _generate_sparse_obstacles(l_top: float, l_bot: float, r_top: float, r_bot: float, rng: RandomNumberGenerator) -> void:
	_obstacle_polygons.clear()

	if rng.randf() < 0.65:
		var t: float = rng.randf_range(0.25, 0.75)
		var x: float = t * CHUNK_WIDTH
		var interp_top: float = lerpf(l_top, r_top, t)
		var interp_bot: float = lerpf(l_bot, r_bot, t)
		var corridor_h: float = interp_bot - interp_top

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
				_beacon_points.append({"pos": Vector2(x, interp_top + protrude + 8.0), "color": _glow_color, "radius": 5.0})
			else:
				pts = PackedVector2Array([
					Vector2(x - half_w * 0.5, interp_bot - protrude),
					Vector2(x, interp_bot - protrude - 15.0),
					Vector2(x + half_w * 0.5, interp_bot - protrude),
					Vector2(x + half_w, interp_bot),
					Vector2(x - half_w, interp_bot),
				])
				_beacon_points.append({"pos": Vector2(x, interp_bot - protrude - 8.0), "color": _glow_color, "radius": 5.0})

			_obstacle_polygons.append(pts)

func emit_spawns(spawn_data: Array) -> void:
	for s in spawn_data:
		if s["type"] == "enemy":
			enemy_spawn_requested.emit(global_position + s["pos"], s["id"])
		elif s["type"] == "powerup":
			powerup_spawn_requested.emit(global_position + s["pos"], s["id"])
