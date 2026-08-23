class_name WeaponLightning
extends WeaponBase
## WeaponLightning — high-voltage electric discharge that chains between hostiles.
## Super Charge: Thunder God Judgment — 5 piercing lightning bolts chaining to 8 hostiles.

func _do_fire(spawn_pos: Vector2) -> void:
	var b: Bullet = _spawn_bullet(spawn_pos, Vector2.RIGHT * bullet_speed * 1.15, bullet_color, damage, 1.1, "lightning")
	if b:
		_chain_electric(b, 2)

func _do_charge_fire(spawn_pos: Vector2, charge_level: float) -> void:
	var bolt_count: int = 3 if charge_level < 0.6 else (4 if charge_level < 1.0 else 5)
	var raw_dmg: float = damage * lerpf(1.6, 2.7, charge_level)
	var zap_dmg: int = max(1, int(raw_dmg * get_charge_tier_multiplier(charge_level) * get_charge_damage_scale()))
	var zap_size: float = lerpf(1.2, 2.0, charge_level)
	var chains: int = 3 if charge_level < 1.0 else 8

	var angles: Array = [-30.0, -15.0, 0.0, 15.0, 30.0]
	for i in bolt_count:
		var angle: float = float(angles[i % angles.size()])
		var vel: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(angle)) * (bullet_speed * 1.3)
		var b: Bullet = _spawn_bullet(spawn_pos, vel, bullet_color.lightened(0.4 if charge_level < 1.0 else 0.85), zap_dmg, zap_size, "lightning", 1, charge_level >= 1.0)
		if b:
			_chain_electric(b, chains)

func _chain_electric(b: Bullet, chains: int) -> void:
	b.hit_target.connect(func(hit_pos: Vector2):
		var tree := get_tree()
		if tree == null:
			return
		var targets: Array = []
		targets.append_array(tree.get_nodes_in_group("enemies"))
		targets.append_array(tree.get_nodes_in_group("bosses"))
		var chained: int = 0
		for t in targets:
			if is_instance_valid(t) and t is Node2D and not t.is_queued_for_deletion() and chained < chains:
				var target_node: Node2D = t as Node2D
				var dist: float = hit_pos.distance_to(target_node.global_position)
				if dist < 320.0 and dist > 20.0:
					var arc_dir: Vector2 = (target_node.global_position - hit_pos).normalized()
					_spawn_bullet(hit_pos, arc_dir * bullet_speed * 1.35, bullet_color.lightened(0.6), int(damage * 0.75), 0.85, "lightning")
					chained += 1
	)
