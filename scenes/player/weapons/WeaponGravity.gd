class_name WeaponGravity
extends WeaponBase
## WeaponGravity — launches dark matter singularity vortexes that drag enemies into their path.
## Super Charge: Event Horizon Singularity — massive dark matter vortex.

func _do_fire(spawn_pos: Vector2) -> void:
	var b: Bullet = _spawn_bullet(spawn_pos, Vector2.RIGHT * bullet_speed * 0.8, bullet_color, damage, 1.4, "gravity", 1)
	if b:
		_attach_vortex(b, 180.0, 120.0)

func _do_charge_fire(spawn_pos: Vector2, charge_level: float) -> void:
	var raw_dmg: float = damage * 2.5 * charge_level + 16.0
	var gravity_dmg: int = max(1, int(raw_dmg * get_charge_tier_multiplier(charge_level) * get_charge_damage_scale()))
	var vortex_size: float = lerpf(1.8, 3.2, charge_level)
	var radius: float = lerpf(220.0, 380.0, charge_level)
	var pull: float = lerpf(160.0, 360.0, charge_level)
	var pierces: int = 2 if charge_level < 1.0 else 6

	var b: Bullet = _spawn_bullet(spawn_pos, Vector2.RIGHT * bullet_speed * 0.65, bullet_color.lightened(0.4 if charge_level < 1.0 else 0.8), gravity_dmg, vortex_size, "gravity", pierces, charge_level >= 1.0)
	if b:
		_attach_vortex(b, radius, pull)

func _attach_vortex(b: Bullet, radius: float, pull_strength: float) -> void:
	var timer := Timer.new()
	timer.wait_time = 0.04
	timer.autostart = true
	b.add_child(timer)
	timer.timeout.connect(func():
		if not is_instance_valid(b) or b.is_queued_for_deletion():
			return
		var tree := get_tree()
		if tree == null:
			return
		var enemies: Array = tree.get_nodes_in_group("enemies")
		for e in enemies:
			if is_instance_valid(e) and e is Node2D and not e.is_queued_for_deletion():
				var enemy_node: Node2D = e as Node2D
				var d: float = b.global_position.distance_to(enemy_node.global_position)
				if d < radius and d > 12.0:
					var pull_dir: Vector2 = (b.global_position - enemy_node.global_position).normalized()
					enemy_node.global_position += pull_dir * pull_strength * 0.04
	)
