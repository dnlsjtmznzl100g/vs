extends Node

var active_enemies: Array = []

func register_enemy(enemy: Node) -> void:
	if enemy not in active_enemies:
		active_enemies.append(enemy)

func unregister_enemy(enemy: Node) -> void:
	active_enemies.erase(enemy)
	
func get_nearest_enemy(position: Vector2) -> Node2D:
	var nearest = null
	var nearest_dist = INF

	for enemy in active_enemies:
		if enemy.is_dead:
			continue

		var dist = position.distance_squared_to(enemy.global_position)

		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy

	return nearest
