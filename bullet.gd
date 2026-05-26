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
	# 안전 검사: 이미 처리 중이거나 노드가 유효하지 않으면 패스
	if not is_instance_valid(body): return
	
	# 부딪힌 대상이 "enemy" 그룹에 속해 있다면
	if body.is_in_group("enemy"):
		
		# [★ 가끔 생기는 순간이동 버그를 잡는 최후의 핵심 코드 ★]
		# 데미지를 계산하고 몹이 죽기 '전'에 총알의 물리 레이어를 즉시 0으로 만듭니다.
		# 이렇게 하면 몹이 죽으면서 레벨업 창을 띄우느라 게임이 일시정지되어도,
		# 총알은 이미 물리 세계에서 완벽히 증발했기 때문에 플레이어를 절대 밀어내지 못합니다.
		collision_layer = 0
		collision_mask = 0
		if has_node("CollisionShape2D"):
			$CollisionShape2D.set_deferred("disabled", true)
		
		# 물리 차단을 먼저 끝낸 후, 안전하게 적에게 데미지 전달
		if body.has_method("take_damage"):
			body.take_damage(damage)
			
		# 총알 삭제
		queue_free()
