extends Node

@export var enemy_scene: PackedScene = preload("res://enemy.tscn")
@export var pool_size: int = 300 # 미리 생성해둘 몬스터 개수

# 비활성화된 몬스터들을 담아둘 배열 (주머니)
var enemy_pool: Array[Node2D] = []

# 격리 구역 좌표 (플레이어가 절대 갈 수 없는 초원격지)
const QUARANTINE_POSITION = Vector2(-99999, -99999)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_initialize_pool")

# 1. 게임 시작 시 몬스터를 미리 대량 생산해서 숨겨둡니다.
func _initialize_pool() -> void:
	for i in range(pool_size):
		var enemy = enemy_scene.instantiate()
		
		# [버그 수정] 생성되자마자 (0,0)이 아닌 우주 저 멀리 격리 구역으로 보냅니다.
		enemy.global_position = QUARANTINE_POSITION
		
		# 중요: 몬스터를 보이지 않고, 물리/프로세스 연산을 완전히 끕니다.
		enemy.visible = false
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		
		# 풀러의 자식으로 넣어 관리합니다.
		add_child(enemy)
		enemy_pool.append(enemy)
	print("✅ 몬스터 오브젝트 풀 초기화 완료! 개수: ", pool_size)

# 2. 스포너가 몬스터를 요청할 때 호출하는 함수
func get_enemy() -> Node2D:
	for enemy in enemy_pool:
		if is_instance_valid(enemy) and enemy.process_mode == Node.PROCESS_MODE_DISABLED:
			
			# 부모(Always)의 상태를 상속받지 않고, 일반적인 일시정지 규칙(Pausable)을 따르도록 설정
			enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
			enemy.visible = true
			return enemy
			
	# 만약 풀이 부족해서 새로 생성하는 예외 코드 부분
	var new_enemy = enemy_scene.instantiate()
	
	# [버그 수정] 임시 추가 생성 시에도 겹침 방지를 위해 격리 좌표 적용
	new_enemy.global_position = QUARANTINE_POSITION
	new_enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
	
	add_child(new_enemy)
	enemy_pool.append(new_enemy)
	return new_enemy

# 3. 몬스터가 죽었을 때 queue_free 대신 풀로 돌려보내는 함수
func return_enemy(enemy: Node2D) -> void:
	if is_instance_valid(enemy):
		# [버그 수정] 죽어서 반납되는 순간 즉시 격리 구역으로 다시 유배 보냅니다.
		# 이렇게 해야 다음 스폰 전까지 플레이어를 밀어내지 않습니다.
		enemy.global_position = QUARANTINE_POSITION
		
		# 상태를 다시 꺼둡니다.
		enemy.visible = false
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		
		# 혹시 모르니 속도나 상태를 초기화하는 함수를 enemy 내부에서 호출
		if enemy.has_method("reset_status"):
			enemy.reset_status()
