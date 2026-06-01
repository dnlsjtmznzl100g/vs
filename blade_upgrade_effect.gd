extends UpgradeEffectResource
class_name BladeUpgradeEffect

@export var rotation_speed_bonus: float = 1.5
@export var blade_scene: PackedScene


func apply(player, ui, level):
	print("BladeEffect 호출됨! level=", level)
	if level == 1:

		if blade_scene != null:

			var blade = blade_scene.instantiate()
			blade.name = "BladeManager"

			player.add_child(blade)

	else:

		var blade_mgr = player.get_node_or_null("BladeManager")

		if blade_mgr:

			blade_mgr.rotation_speed += rotation_speed_bonus
