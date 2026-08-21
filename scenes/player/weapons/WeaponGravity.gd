class_name WeaponGravity
extends WeaponBase
## WeaponGravity — launches a singularity projectile that pulls enemies towards its path.

func _do_fire(spawn_pos: Vector2) -> void:
	var b: Bullet = _spawn_bullet(spawn_pos, Vector2.RIGHT * bullet_speed * 0.8, bullet_color, damage, 1.3, "plasma")
	if b:
		_attach_vortex(b, 160.0, 100.0)

func _do_charge_fire(spawn_pos: Vector2, charge_level: float) -> void:
	var raw_dmg: float = damage * 2.2
	var gravity_dmg: int = max(1, int(raw_dmg * get_charge_tier_multiplier(charge_level)))
	var b: Bullet = _spawn_bullet(spawn_pos, Vector2.RIGHT * bullet_speed * 0.6, bullet_color.lightened(0.4 if charge_level < 1.0 else 0.75), gravity_dmg, 2.4, "plasma")
	if b:
		_attach_vortex(b, 260.0, 180.0)

func _attach_vortex(b: Bullet, radius: float, pull_strength: float) -> void:
	var timer := Timer.new()
	timer.wait_time = 0.05
	timer.autostart = true
	b.add_child(timer)
	timer.timeout.connect(func():
		if not is_instance_valid(b):
			return
		var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
		for e in enemies:
			if is_instance_valid(e) and e is Node2D:
				var enemy_node: Node2D = e as Node2D
				var d: float = b.global_position.distance_to(enemy_node.global_position)
				if d < radius and d > 10.0:
					var pull_dir: Vector2 = (b.global_position - enemy_node.global_position).normalized()
					enemy_node.global_position += pull_dir * pull_strength * 0.05
	)
