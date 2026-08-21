extends Node2D
## ScrollingBackground — multi-layer parallax starfield for gameplay.
## Three layers at different scroll speeds create depth.

const STAR_COUNTS := [80, 50, 25]
const SPEEDS := [0.1, 0.3, 0.6]      # parallax motion_scale values
const SIZES := [1.0, 2.0, 3.5]
const BRIGHTNESSES := [0.4, 0.65, 0.9]

var _layers: Array[Array] = [[], [], []]   # each: Array[Dictionary{pos,size,bright}]

func _ready() -> void:
	var screen_size: Vector2 = get_viewport_rect().size
	for layer in 3:
		for i in STAR_COUNTS[layer]:
			_layers[layer].append({
				"pos": Vector2(randf() * (screen_size.x + 480.0), randf() * screen_size.y),
				"size": randf_range(SIZES[layer] * 0.6, SIZES[layer] * 1.4),
				"bright": randf_range(BRIGHTNESSES[layer] * 0.7, BRIGHTNESSES[layer] * 1.2),
			})

func scroll(scroll_speed: float, delta: float) -> void:
	## Call this from LevelGenerator or Game each frame with the current scroll speed.
	var screen_size: Vector2 = get_viewport_rect().size
	for layer in 3:
		var layer_speed: float = scroll_speed * float(SPEEDS[layer])
		for s in _layers[layer]:
			s["pos"].x -= layer_speed * delta
			if s["pos"].x < -10.0:
				s["pos"].x = screen_size.x + 490.0
				s["pos"].y = randf() * screen_size.y
	queue_redraw()

func _draw() -> void:
	for layer in 3:
		for s in _layers[layer]:
			var b: float = s["bright"]
			draw_circle(s["pos"], s["size"], Color(b, b, b + 0.1, 1.0))
	# Subtle nebula tint bands
	var screen_width: float = get_viewport_rect().size.x
	draw_rect(Rect2(0, 200, screen_width, 300), Color(0.05, 0.02, 0.15, 0.08))
	draw_rect(Rect2(0, 700, screen_width, 250), Color(0.02, 0.05, 0.12, 0.06))
