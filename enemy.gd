extends CharacterBody2D

@export var speed: float = 80.0
@export var max_hp: int = 50
@export var health: int = 50
@export var damage: int = 10

var player: CharacterBody2D = null

func _ready() -> void:
	# 중요! 2단계 무기 시스템이 인식할 수 있도록 "enemy" 그룹에 추가합니다.
	add_to_group("enemy")
	
	# 플레이어 찾기 ("player" 그룹에 속한 첫 번째 노드를 가져옵니다)
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func _physics_process(delta: float) -> void:
	if player != null:
		# 플레이어가 있는 방향 계산
		var direction = (player.global_position - global_position).normalized()
		
		# 플레이어를 향해 이동 속도 설정
		velocity = direction * speed
		
		# 좌우 방향에 따라 스프라이트 반전
		if direction.x < 0:
			$Sprite2D.flip_h = true
		elif direction.x > 0:
			$Sprite2D.flip_h = false
			
		# 이동 및 충돌 처리
		move_and_slide()
		
		# 플레이어와 닿아있다면 데미지를 주기 위한 체크
		check_player_collision()

func _notification(what: int) -> void:
	# 게임 전체가 일시정지(Paused) 상태로 진입하는 순간을 감지합니다.
	if what == NOTIFICATION_PAUSED:
		# 물리 이동 속도를 완전히 제로로 만들어 플레이어를 밀어내지 못하게 합니다.
		velocity = Vector2.ZERO
		
	# 레벨업 창이 닫히고 게임이 재개(Unpaused)되는 순간을 감지합니다.
	elif what == NOTIFICATION_UNPAUSED:
		# 필요하다면 여기서 플레이어 방향을 다시 계산하도록 AI 타이머를 깨우거나
		# 조작을 초기화할 수 있습니다. (기본적으론 velocity만 초기화해도 충분합니다.)
		pass
		
# 플레이어와 물리적으로 부딪혔을 때 데미지를 주는 로직
func check_player_collision() -> void:
	# move_and_slide() 이후 발생한 모든 충돌 정보를 확인
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		# 부딪힌 대상이 플레이어라면 데미지 함수 호출
		if collider.is_in_group("player") and collider.has_method("take_damage"):
			collider.take_damage(damage)
			# 뱀서류는 보통 닿자마자 적이 사라지지 않고 지속 데미지를 주지만, 
			# 기초 단계이므로 우선 한 번 부딪히면 적이 사라지게 처리합니다.
			queue_free() 

# 2단계의 총알 스크립트가 호출할 함수
func take_damage(amount: int) -> void:
	health -= amount
	print("적 체력: ", health)
	
	# 데미지 받았을 때 깜빡이는 연출 등을 여기에 넣으면 좋습니다.
	
	if health <= 0:
		die()

@export var gem_scene: PackedScene = preload("res://gem.tscn") # 보석 씬 경로 확인!


func die() -> void:
	# 죽기 전에 보석 생성
	if gem_scene != null:
		var gem = gem_scene.instantiate()
		gem.global_position = global_position
		get_tree().current_scene.call_deferred("add_child", gem) # 안전하게 씬에 추가
		
	if get_node_or_null("/root/ObjectPooler"): # Autoload 확인
		get_node("/root/ObjectPooler").return_enemy(self)
	else:
		queue_free()
