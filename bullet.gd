extends Area2D

@export var speed: float = 400.0
@export var damage: int = 25

var direction: Vector2 = Vector2.RIGHT
var lifetime: float = 0.0
const MAX_LIFETIME: float = 5.0 # 5초 뒤 화면 밖으로 나간 것으로 간주하고 자동 반납

func _ready() -> void:
	# 투사체가 몬스터와 부딪혔을 때 발동하는 시그널 연결 (최초 1번만 연결하면 재사용 시에도 유지됨)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	# 1. 지정된 방향으로 매 프레임 이동
	position += direction * speed * delta
	
	# 2. [★ 안전장치 ★] 시간 누적식 자동 반납 (await 타이머 제거로 크래시 원천 차단)
	lifetime += delta
	if lifetime >= MAX_LIFETIME:
		_despawn_bullet()

func _on_body_entered(body: Node2D) -> void:
	if not is_instance_valid(body): return
	
	if body.is_in_group("enemy"):
		# [중복 타격 방지] 이미 물리 레이어가 0으로 꺼진 총알(반납 처리 중)이라면 연산 패스
		if collision_layer == 0: return
		
		# [★ 순간이동 버그 해결의 핵심 ★]
		# 데미지를 계산하고 몹이 죽기 '전'에 총알의 물리 레이어 장부를 즉시 파괴합니다.
		collision_layer = 0
		collision_mask = 0
		if has_node("CollisionShape2D"):
			$CollisionShape2D.set_deferred("disabled", true)
		
		# 물리 차단을 먼저 완전히 끝낸 후, 안전하게 적에게 데미지 전달
		if body.has_method("take_damage"):
			body.take_damage(damage)
			
		# 총알을 메모리에서 지우지 않고 풀로 반납
		_despawn_bullet()

# ★ 메모리를 해제(queue_free)하지 않고 풀러로 안전하게 돌려보내는 함수 ★
func _despawn_bullet() -> void:
	# 풀 안에 잠들어 있는 동안 무빙이나 추가 충돌 연산을 하지 않도록 물리 프로세스 정지
	set_physics_process(false)
	visible = false
	
	# 싱글톤 또는 루트에 등록된 ObjectPooler 탐색 후 반납
	var pooler = get_node_or_null("/root/ObjectPooler")
	if pooler and pooler.has_method("return_bullet"):
		pooler.return_bullet(self)
	else:
		# 혹시 풀러가 없는 독립 테스트 상황(F6으로 총알 씬만 실행 등)이라면 메모리 해제하여 에러 방지
		queue_free()

# ★ 오브젝트 풀러(ObjectPooler)에서 이 총알을 재활용할 때 호출하는 초기화 함수 ★
func reset_bullet(start_position: Vector2, shoot_direction: Vector2) -> void:
	# 1. 발사 위치 및 조준 방향, 생존 시간 초기화
	global_position = start_position
	direction = shoot_direction.normalized()
	lifetime = 0.0
	
	# 2. 그래픽 시각화 및 물리 레이어 완벽 복구 (기획 문서 v1.1 매트릭스 준수)
	# Layer 4 (Bullet), Mask 2 (Enemy 본체만 인지하여 타격)
	visible = true
	collision_layer = 4
	collision_mask = 2
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", false)
		
	# 3. 모든 준비가 끝난 후 물리 프로세스 재가동
	set_physics_process(true)
