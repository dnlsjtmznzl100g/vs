extends UpgradeEffectResource
class_name GunRateUpgradeEffect

@export var fire_rate_bonus := 0.15

func apply(player,ui, level):

	var timer = player.get_node_or_null("WeaponTimer")

	if timer:
		timer.wait_time = max(
			0.15,
			timer.wait_time - fire_rate_bonus
		)
