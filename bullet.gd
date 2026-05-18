extends Area2D

@export var speed: float = 400.0
@export var damage: int = 25
var direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
	# 투사체가 무언가와 부딪혔을 때 발동하는 시그널 연결
	body_entered.connect(_on_body_entered)
	
	# 5초 뒤에 자동으로 총알 삭제 (화면 밖으로 나간 총알 정리)
	await get_tree().create_timer(5.0).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	# 지정된 방향으로 매 프레임 이동
	position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	# 부딪힌 대상이 "enemy" 그룹에 속해 있고, take_damage 함수가 있다면
	if body.is_in_group("enemy") and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free() # 적과 부딪히면 총알 삭제
		
