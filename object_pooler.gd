extends Node

@export var enemy_scene: PackedScene = preload("res://enemy.tscn")
@export var pool_size: int = 300 # 미리 생성해둘 몬스터 개수

# 비활성화된 몬스터들을 담아둘 배열 (주머니)
var enemy_pool: Array[Node2D] = []

func _ready() -> void:
	# 게임이 시작되자마자 씬이 멈춰도 풀러는 준비할 수 있도록 설정
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_initialize_pool")

# 1. 게임 시작 시 몬스터를 미리 대량 생산해서 숨겨둡니다.
func _initialize_pool() -> void:
	for i in range(pool_size):
		var enemy = enemy_scene.instantiate()
		
		# 중요: 몬스터를 보이지 않고, 물리/프로세스 연산을 완전히 끕니다.
		enemy.visible = false
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		
		# 풀러의 자식으로 넣어 관리합니다.
		add_child(enemy)
		enemy_pool.append(enemy)
	print("✅ 몬스터 오브젝트 풀 초기화 완료! 개수: ", pool_size)

# 2. 스포너가 몬스터를 요청할 때 호출하는 함수
# object_pooler.gd 의 get_enemy() 함수 내부 수정

func get_enemy() -> Node2D:
	for enemy in enemy_pool:
		if is_instance_valid(enemy) and enemy.process_mode == Node.PROCESS_MODE_DISABLED:
			
			# [기존] enemy.process_mode = Node.PROCESS_MODE_INHERIT
			# 부모(Always)의 상태를 상속받지 않고, 일반적인 일시정지 규칙(Pausable)을 따르도록 설정합니다!
			enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
			
			enemy.visible = true
			return enemy
			
	# 만약 풀이 부족해서 새로 생성하는 예외 코드 부분도 똑같이 수정해 줍니다.
	var new_enemy = enemy_scene.instantiate()
	new_enemy.process_mode = Node.PROCESS_MODE_PAUSABLE # 여기도 추가!
	add_child(new_enemy)
	enemy_pool.append(new_enemy)
	return new_enemy

# 3. 몬스터가 죽었을 때 queue_free 대신 풀로 돌려보내는 함수
func return_enemy(enemy: Node2D) -> void:
	if is_instance_valid(enemy):
		# 상태를 다시 꺼둡니다.
		enemy.visible = false
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		# 혹시 모르니 속도나 상태를 초기화하는 함수를 enemy 내부에서 호출해주면 좋습니다.
		if enemy.has_method("reset_status"):
			enemy.reset_status()
