class_name WeaponMissile
extends WeaponBase
## WeaponMissile — heavy smart-seeking micro-torpedoes with anti-spam concurrency limiter.
## Super Charge: 6-Missile Macross Swarm Salvo.

var _active_missiles: Array = []
const MAX_ACTIVE_PRIMARY_MISSILES: int = 2

func can_fire() -> bool:
	_cleanup_active_missiles()
	if _active_missiles.size() >= MAX_ACTIVE_PRIMARY_MISSILES:
		return false
	return super.can_fire()

func _cleanup_active_missiles() -> void:
	var valid: Array = []
	for m in _active_missiles:
		if is_instance_valid(m) and not m.is_queued_for_deletion():
			valid.append(m)
	_active_missiles = valid

func _do_fire(spawn_pos: Vector2) -> void:
	_cleanup_active_missiles()
	if _active_missiles.size() >= MAX_ACTIVE_PRIMARY_MISSILES:
		return

	var b: Bullet = _spawn_bullet(spawn_pos, Vector2.RIGHT * bullet_speed, bullet_color, damage, 1.15, "missile")
	if b:
		_active_missiles.append(b)
		_attach_homing(b, 0.25)

func _do_charge_fire(spawn_pos: Vector2, charge_level: float) -> void:
	var count: int = 3 if charge_level < 0.6 else (4 if charge_level < 1.0 else 6)
	var raw_dmg: float = damage * lerpf(1.5, 2.2, charge_level)
	var missile_dmg: int = max(1, int(raw_dmg * get_charge_tier_multiplier(charge_level)))
	var missile_size: float = lerpf(1.2, 1.8, charge_level)

	var angles: Array = [-35.0, -15.0, 15.0, 35.0, -50.0, 50.0]
	for i in count:
		var angle: float = float(angles[i % angles.size()])
		var vel: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(angle)) * (bullet_speed * 1.1)
		var b: Bullet = _spawn_bullet(spawn_pos, vel, bullet_color.lightened(0.25 if charge_level < 1.0 else 0.6), missile_dmg, missile_size, "missile", 0, charge_level >= 1.0)
		if b:
			_attach_homing(b, 0.35)

## Miss-detonation window: a missile that hasn't hit anything within this
## long self-destructs instead of drifting off-screen — otherwise a miss
## (no target found, or it flew past one) ties up one of only
## MAX_ACTIVE_PRIMARY_MISSILES concurrent slots for up to Bullet.MAX_LIFETIME.
const MISS_DETONATE_TIME: float = 1.6

func _attach_homing(b: Bullet, turn_rate: float = 0.25) -> void:
	var steer_timer := Timer.new()
	steer_timer.wait_time = 0.04
	steer_timer.autostart = true
	b.add_child(steer_timer)
	var elapsed: float = 0.0
	steer_timer.timeout.connect(func():
		if not is_instance_valid(b) or b.is_queued_for_deletion():
			return
		elapsed += steer_timer.wait_time
		if elapsed >= MISS_DETONATE_TIME:
			_detonate_missed_missile(b)
			return
		var tree := get_tree()
		if tree == null:
			return
		var targets: Array = []
		targets.append_array(tree.get_nodes_in_group("enemies"))
		targets.append_array(tree.get_nodes_in_group("bosses"))
		var closest: Node2D = null
		var min_dist: float = 99999.0
		for t in targets:
			if is_instance_valid(t) and t is Node2D and not t.is_queued_for_deletion():
				var t_node: Node2D = t as Node2D
				if t_node.global_position.x > b.global_position.x - 60.0:
					var d: float = b.global_position.distance_to(t_node.global_position)
					if d < min_dist:
						min_dist = d
						closest = t_node
		if closest and is_instance_valid(closest):
			var desired: Vector2 = (closest.global_position - b.global_position).normalized() * b.velocity.length()
			b.velocity = b.velocity.lerp(desired, turn_rate)
			b.rotation = b.velocity.angle()
	)

## A missile that ran out its miss window explodes in place — small splash
## damage so it isn't a total waste, then frees its slot immediately
## rather than drifting for up to Bullet.MAX_LIFETIME (4s).
func _detonate_missed_missile(b: Bullet) -> void:
	if not is_instance_valid(b):
		return
	var pos: Vector2 = b.global_position
	var tree := get_tree()
	if tree:
		for t in tree.get_nodes_in_group("enemies"):
			if is_instance_valid(t) and t is Node2D and not t.is_queued_for_deletion():
				if (t as Node2D).global_position.distance_to(pos) <= 70.0 and t.has_method("take_damage"):
					t.take_damage(max(1, int(b.damage * 0.5)))
	var fx: Node2D = load("res://scenes/effects/ExplosionFX.tscn").instantiate()
	var parent_node: Node = b.get_parent()
	if parent_node:
		parent_node.call_deferred("add_child", fx)
		if fx.has_method("setup"):
			fx.setup(pos, Color(1.0, 0.5, 0.0), 0.7)
	b.queue_free()
