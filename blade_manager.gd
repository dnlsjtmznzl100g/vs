extends Node2D

@export var rotation_speed: float = 3.0 # 회전 속도

# 1. ⚠️ 여기에 이 한 줄을 추가해 주면 인스펙터 창과 UI에서 인식이 가능해져!
@export var damage: int = 15 # 칼날 기본 데미지

func _ready() -> void:
	# 자식 노드(Blade1, Blade2 등)들을 순회하며 충돌 시그널을 자동으로 연결
	for child in get_children():
		if child is Area2D:
			child.body_entered.connect(_on_blade_body_entered)

func _process(delta: float) -> void:
	# 매 프레임마다 라디안 각도를 더해 회전시킵니다.
	rotation += rotation_speed * delta

# 2. 칼날이 적과 부딪혔을 때 데미지를 주는 로직
func _on_blade_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy") and body.has_method("take_damage"):
		body.take_damage(damage) # 이제 위의 damage 변수를 정상적으로 참조해!
