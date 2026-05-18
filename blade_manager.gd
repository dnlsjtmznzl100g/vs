extends Node2D

@export var rotation_speed: float = 3.0 # 회전 속도

func _process(delta: float) -> void:
	# 매 프레임마다 라디안 각도를 더해 회전시킵니다.
	rotation += rotation_speed * delta
