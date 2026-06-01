extends UpgradeEffectResource
class_name HPUpgradeEffect

@export var hp_per_level := 20

func apply(player, ui, level):

	player.max_health += hp_per_level
	player.current_health += hp_per_level

	ui.update_hp(
		player.current_health,
		player.max_health
	)
