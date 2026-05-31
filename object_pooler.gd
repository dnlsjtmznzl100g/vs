extends Node

@export_group("몬스터 풀 설정")
@export var enemy_scene: PackedScene = preload("res://enemy.tscn")
@export var enemy_pool_size: int = 300
var enemy_pool: Array[Node2D] = []

@export_group("총알 풀 설정")
@export var bullet_scene: PackedScene = preload("res://bullet.tscn") 
@export var bullet_pool_size: int = 200 # 동시에 화면에 존재할 수 있는 최대 총알 수
var bullet_pool: Array[Area2D] = []

# 격리 구역 좌표 (플레이어가 절대 갈 수 없는 초원격지)
const QUARANTINE_POSITION = Vector2(-99999, -99999)

func _ready() -> void:
	# 풀러 자체는 일시정지(Pause) 중에도 리소스 정산 등을 처리할 수 있도록 ALWAYS 유지
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 대량 인스턴스화로 인한 첫 프레임 버벅임(Stuttering) 방지를 위해 지연 호출
	call_deferred("_initialize_pools")

# 모든 오브젝트 풀을 초기화합니다.
func _initialize_pools() -> void:
	_initialize_enemy_pool()
	_initialize_bullet_pool()

# 1. 몬스터 풀 초기화
func _initialize_enemy_pool() -> void:
	for i in range(enemy_pool_size):
		var enemy = enemy_scene.instantiate()
		enemy.global_position = QUARANTINE_POSITION
		enemy.visible = false
		# 중요: 풀 내부에 대기하는 동안 무빙 및 충돌 연산을 완전히 얼립니다.
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(enemy)
		enemy_pool.append(enemy)
	print("✅ 몬스터 오브젝트 풀 초기화 완료! 개수: ", enemy_pool_size)

# 2. 총알 풀 초기화
func _initialize_bullet_pool() -> void:
	for i in range(bullet_pool_size):
		var bullet = bullet_scene.instantiate()
		bullet.global_position = QUARANTINE_POSITION
		bullet.visible = false
		# 총알 역시 대기하는 동안 가동되지 않도록 연산을 끕니다.
		bullet.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(bullet)
		bullet_pool.append(bullet)
	print("✅ 총알 오브젝트 풀 초기화 완료! 개수: ", bullet_pool_size)


# ==========================================
# 🔄 몬스터 대여 및 반납 인터페이스
# ==========================================
func get_enemy() -> Node2D:
	for enemy in enemy_pool:
		# DISABLED 상태로 잠들어 있는 안전한 몬스터 탐색
		if is_instance_valid(enemy) and enemy.process_mode == Node.PROCESS_MODE_DISABLED:
			
			# [★ 버그 해결의 핵심 ★] 꺼내기 직전 enemy 내부의 HP, 플래그, 물리 레이어를 리셋
			if enemy.has_method("reset_enemy"):
				enemy.reset_enemy()

			enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
			enemy.visible = true

			EnemyManager.register_enemy(enemy)

			return enemy
			
	# 예외 처리: 300마리가 모두 출격하여 풀이 부족할 때 동적 신규 생성
	var new_enemy = enemy_scene.instantiate()
	new_enemy.global_position = QUARANTINE_POSITION
	add_child(new_enemy)
	enemy_pool.append(new_enemy)
	
	if new_enemy.has_method("reset_enemy"):
		new_enemy.reset_enemy()
		
	new_enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
	EnemyManager.register_enemy(new_enemy)
	return new_enemy

func return_enemy(enemy: Node2D) -> void:
	if is_instance_valid(enemy):
		EnemyManager.register_enemy(enemy)
		
		# 반납 즉시 격리 구역으로 순간이동시켜 플레이어와의 물리적 마찰을 원천 차단
		enemy.global_position = QUARANTINE_POSITION
		enemy.visible = false
		# 연산 및 물리 히트박스를 동결 상태(DISABLED)로 전환
		enemy.process_mode = Node.PROCESS_MODE_DISABLED


# ==========================================
# 🔄 총알 대여 및 반납 인터페이스
# ==========================================
# 무기 매니저가 총알을 발사할 때 위치와 조준 방향을 넘겨주며 호출합니다.
func get_bullet(start_position: Vector2, direction: Vector2) -> Area2D:
	for bullet in bullet_pool:
		if is_instance_valid(bullet) and bullet.process_mode == Node.PROCESS_MODE_DISABLED:
			
			# [★ 버그 해결의 핵심 ★] 꺼내기 직전 bullet 내부의 위치, 방향, 물리 레이어를 리셋
			if bullet.has_method("reset_bullet"):
				bullet.reset_bullet(start_position, direction)
				
			bullet.process_mode = Node.PROCESS_MODE_PAUSABLE
			return bullet

	# 예외 처리: 화면에 총알이 200발 이상 꽉 찼을 때 임시 동적 생성
	var new_bullet = bullet_scene.instantiate()
	new_bullet.global_position = QUARANTINE_POSITION
	add_child(new_bullet)
	bullet_pool.append(new_bullet)
	
	if new_bullet.has_method("reset_bullet"):
		new_bullet.reset_bullet(start_position, direction)
		
	new_bullet.process_mode = Node.PROCESS_MODE_PAUSABLE
	return new_bullet

func return_bullet(bullet: Area2D) -> void:
	if is_instance_valid(bullet):
		# 반납 즉시 격리 구역으로 이동 후 연산 동결
		bullet.global_position = QUARANTINE_POSITION
		bullet.visible = false
		bullet.process_mode = Node.PROCESS_MODE_DISABLED
