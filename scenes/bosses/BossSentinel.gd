class_name BossSentinel
extends BossBase

## Sentinel Boss — Level 4
## Protected by a full rotating force-field shield ring.
## Bullets hitting the shield while active are deflected with energy sparks.
## The shield periodically fades out (fully, ring-wide) to open a clear,
## guaranteed window to hit the core — rather than relying on the player
## threading shots through a narrow rotating gap, which could leave the
## boss effectively unhittable depending on timing/rotation speed.

const SHIELD_COUNT: int = 6
const SHIELD_RADIUS: float = 135.0

var _shields: Array[Area2D] = []
var _shield_polys: Array[Polygon2D] = []
var _shield_rotation: float = 0.0
var _fire_timer: float = 0.0
var _cross_timer: float = 0.0

## Whether the shield is currently solid enough to block/deflect shots.
var _shield_active: bool = true
var _shield_fade_timer: float = 0.0
## Full up-down-up fade cycle length, seconds — shortens each phase so
## vulnerability windows come more often (and briefer) as the fight escalates.
const SHIELD_FADE_PERIOD: Array[float] = [4.0, 3.2, 2.4]
## Below this alpha the shield is considered "down" — collision disabled.
const SHIELD_COLLISION_ALPHA_THRESHOLD: float = 0.35

var _patrol_dir: int = 1
const PATROL_SPEED: float = 85.0
const PATROL_RANGE: float = 220.0

func _ready() -> void:
	boss_name = "Sentinel"
	max_health = 1000
	phase_count = 3
	boss_color = Color(0.35, 0.65, 0.95, 1.0)
	size_scale = 1.15
	entry_speed = 180.0
	score_value = 7000

	super._ready()
	_create_shields()

func _create_shields() -> void:
	# Segments form a complete, gapless ring — vulnerability comes from the
	# whole ring periodically fading out, not from finding a physical gap.
	var segment_span: float = 360.0 / SHIELD_COUNT
	var arc_poly: PackedVector2Array = _build_arc_segment(SHIELD_RADIUS, segment_span)

	for i: int in range(SHIELD_COUNT):
		var shield_area := Area2D.new()
		shield_area.name = "ShieldSegment%d" % i
		shield_area.collision_layer = 32  # boss collision layer
		shield_area.collision_mask = 4   # player bullets
		shield_area.add_to_group("boss_shield")

		var poly := Polygon2D.new()
		poly.polygon = arc_poly
		poly.color = Color(0.3, 0.7, 1.0, 0.85)
		shield_area.add_child(poly)
		_shield_polys.append(poly)

		var col := CollisionPolygon2D.new()
		col.polygon = arc_poly
		shield_area.add_child(col)

		shield_area.rotation_degrees = (360.0 / SHIELD_COUNT) * i
		add_child(shield_area)
		_shields.append(shield_area)

		# Intercept bullets on the shield perimeter
		shield_area.area_entered.connect(_on_shield_hit.bind(i))

func _build_arc_segment(radius: float, span_deg: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var inner_r: float = radius - 20.0
	var steps: int = 8
	var half: float = span_deg * 0.5

	for i: int in range(steps + 1):
		var a: float = deg_to_rad(-half + (span_deg / steps) * i)
		pts.append(Vector2(cos(a) * radius, sin(a) * radius))
	for i: int in range(steps + 1):
		var a: float = deg_to_rad(half - (span_deg / steps) * i)
		pts.append(Vector2(cos(a) * inner_r, sin(a) * inner_r))
	return pts

func _on_shield_hit(area: Area2D, shield_idx: int) -> void:
	if not _shield_active:
		return
	if area is Bullet and not area.is_enemy_bullet:
		_deflect_bullet(area, shield_idx)
	elif area.is_in_group("player_bullet"):
		_deflect_bullet(area, shield_idx)

func _deflect_bullet(bullet_node: Node, shield_idx: int) -> void:
	# Flash the hit shield segment
	if shield_idx >= 0 and shield_idx < _shield_polys.size():
		var poly: Polygon2D = _shield_polys[shield_idx]
		if poly and is_instance_valid(poly):
			poly.color = Color(1.0, 1.0, 1.0, 1.0)
			var tw := create_tween()
			tw.tween_property(poly, "color", Color(0.3, 0.7, 1.0, 0.85), 0.12)

	# Destroy the absorbed bullet and spawn deflecting sparks
	_spawn_deflect_sparks(bullet_node.global_position if "global_position" in bullet_node else global_position)
	if bullet_node.has_method("queue_free"):
		bullet_node.queue_free()

func _spawn_deflect_sparks(pos: Vector2) -> void:
	var fx: Node2D = load("res://scenes/effects/ExplosionFX.tscn").instantiate()
	var parent_node: Node = get_parent() if get_parent() else get_tree().current_scene
	if parent_node:
		parent_node.call_deferred("add_child", fx)
		if fx.has_method("setup"):
			fx.setup(pos, Color(0.4, 0.8, 1.0), 0.5)

func _phase_attack(delta: float) -> void:
	_patrol(delta)
	_rotate_shields(delta)
	_update_shield_fade(delta)

	if current_phase >= 1:
		_fire_timer += delta
		var rate: float = 1.2 if current_phase == 1 else 0.8
		if _fire_timer >= rate:
			_fire_timer = 0.0
			_fire_at_player(480.0, 14, Color(0.4, 0.7, 1.0, 1.0))

	if current_phase == 2:
		_cross_timer += delta
		if _cross_timer >= 1.5:
			_cross_timer = 0.0
			_fire_cross()

func _patrol(_delta: float) -> void:
	var center_y: float = 540.0
	if global_position.y > center_y + PATROL_RANGE:
		_patrol_dir = -1
	elif global_position.y < center_y - PATROL_RANGE:
		_patrol_dir = 1
	velocity.y = _patrol_dir * PATROL_SPEED
	velocity.x = 0.0

func _rotate_shields(delta: float) -> void:
	var speed: float = 50.0  # degrees per second phase 0
	match current_phase:
		1:
			speed = 95.0
		2:
			speed = 160.0

	_shield_rotation += speed * delta
	if _shield_rotation > 360.0:
		_shield_rotation -= 360.0

	for i: int in range(_shields.size()):
		var base_angle: float = (360.0 / SHIELD_COUNT) * i
		_shields[i].rotation_degrees = base_angle + _shield_rotation

## Smoothly fades the whole shield ring in and out (rather than an instant
## on/off), so the player gets a clear, telegraphed window to hit the core.
## Active in every phase — the cycle just runs faster in later phases.
func _update_shield_fade(delta: float) -> void:
	var period: float = SHIELD_FADE_PERIOD[clampi(current_phase, 0, SHIELD_FADE_PERIOD.size() - 1)]
	_shield_fade_timer += delta
	if _shield_fade_timer >= period:
		_shield_fade_timer -= period

	var alpha: float = 0.5 + 0.5 * cos(TAU * _shield_fade_timer / period)
	_shield_active = alpha >= SHIELD_COLLISION_ALPHA_THRESHOLD

	for i: int in range(_shields.size()):
		_shields[i].modulate.a = alpha
		var col_shape = _shields[i].get_node_or_null("CollisionPolygon2D")
		if col_shape:
			col_shape.disabled = !_shield_active

func _fire_cross() -> void:
	var directions: Array = [
		Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)
	]
	for dir in directions:
		_spawn_boss_bullet(dir * 500.0, Color(0.5, 0.8, 1.0, 1.0), 16)

func _on_phase_change(new_phase: int) -> void:
	match new_phase:
		1:
			for s: Polygon2D in _shield_polys:
				s.color = Color(0.5, 0.85, 1.0, 0.9)
		2:
			for s: Polygon2D in _shield_polys:
				s.color = Color(0.8, 0.4, 1.0, 0.95)
