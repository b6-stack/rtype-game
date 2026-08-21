class_name WeaponLightning
extends WeaponBase
## WeaponLightning — discharges high-voltage electrical arcs that arc between hostiles.

func _do_fire(spawn_pos: Vector2) -> void:
	var b: Bullet = _spawn_bullet(spawn_pos, Vector2.RIGHT * bullet_speed * 1.1, bullet_color, damage, 0.85)
	if b:
		_chain_electric(b, 1)

func _do_charge_fire(spawn_pos: Vector2, charge_level: float) -> void:
	var raw_dmg: float = damage * 1.6
	var zap_dmg: int = max(1, int(raw_dmg * get_charge_tier_multiplier(charge_level)))
	for i in 3:
		var angle: float = -20.0 + i * 20.0
		var vel: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(angle)) * bullet_speed * 1.25
		var b: Bullet = _spawn_bullet(spawn_pos, vel, bullet_color.lightened(0.4 if charge_level < 1.0 else 0.75), zap_dmg, 1.2)
		if b:
			_chain_electric(b, 2)

func _chain_electric(b: Bullet, chains: int) -> void:
	b.hit_target.connect(func(hit_pos: Vector2):
		var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
		var chained: int = 0
		for e in enemies:
			if is_instance_valid(e) and e is Node2D and chained < chains:
				var enemy_node: Node2D = e as Node2D
				var dist: float = hit_pos.distance_to(enemy_node.global_position)
				if dist < 260.0 and dist > 20.0:
					var arc_dir: Vector2 = (enemy_node.global_position - hit_pos).normalized()
					_spawn_bullet(hit_pos, arc_dir * bullet_speed * 1.3, bullet_color.lightened(0.5), int(damage * 0.6), 0.75)
					chained += 1
	)
