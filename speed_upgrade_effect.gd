extends UpgradeEffectResource
class_name SpeedUpgradeEffect

@export var speed_per_level := 30.0

func apply(player, ui, level):

	player.speed += speed_per_level
