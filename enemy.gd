extends CharacterBody2D

@export_group("능력치 세팅")
@export var max_hp: int = 20
@export var speed: float = 120.0
@export var damage: int = 10

@export_group("드롭 아이템")
@export var gem_scene: PackedScene = preload("res://gem.tscn")

var health: int = max_hp
var is_dead: bool = false
var player: CharacterBody2D = null
var attack_cooldown: float = 0.0 # 공격 쿨타임 타이머

func _ready() -> void:
	add_to_group("enemy")
	_find_player()

func _physics_process(delta: float) -> void:
	# 사망했거나 플레이어가 없으면 즉시 리턴 (풀 안에서 대기할 때 CPU 자원 소모 0%)
	if is_dead or not is_instance_valid(player):
		return

	# 매 프레임 쿨타임 차감
	if attack_cooldown > 0:
		attack_cooldown -= delta

	# 플레이어 추적 및 속도 설정
	var direction = (player.global_position - global_position).normalized()
	velocity = direction * speed
	
	# 방향에 따른 스프라이트 좌우 반전 (세련된 삼항 연산 스타일)
	if direction.x != 0:
		$Sprite2D.flip_h = (direction.x < 0)

	move_and_slide()
	
	# 쿨타임이 끝났을 때만 플레이어 타격 체크 (불필요한 충돌 순회 방지)
	if attack_cooldown <= 0:
		_check_player_collision()

# 플레이어 충돌 및 공격 처리 함수
func _check_player_collision() -> void:
	var collision_count = get_slide_collision_count()
	if collision_count == 0: return
	
	for i in range(collision_count):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if is_instance_valid(collider) and collider.is_in_group("player"):
			if collider.has_method("take_damage"):
				collider.take_damage(damage)
				# 1초 동안 공격 봉인 (연타 버그 방지)
				attack_cooldown = 1.0 
				break # 한 프레임에 중복 타격 방지

# 데미지를 받을 때 호출되는 함수
func take_damage(amount: int) -> void:
	if is_dead: return
	
	health -= amount
	if health <= 0:
		die()

# ★ 순간이동 버그를 원천 차단하는 사망 로직 ★
func die() -> void:
	if is_dead: return
	is_dead = true
	
	# [버그 해결 핵심] 풀러의 격리 좌표로 유배 가기 전, 즉시 물리 레이어 장부를 파괴합니다.
	# 추가로 _physics_process 연산도 즉시 꺼서 찰나의 프레임 버그를 차단합니다.
	set_physics_process(false)
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	$CollisionShape2D.set_deferred("disabled", true) # 안전을 위한 2중 잠금
	
	# 사망 위치에 보석(경험치) 드롭
	if gem_scene != null:
		var gem = gem_scene.instantiate()
		gem.global_position = global_position
		# 메인 씬 트리에 안전하게 추가
		get_tree().current_scene.call_deferred("add_child", gem)
		
	# 오브젝트 풀러로 반납 처리
	var pooler = get_node_or_null("/root/ObjectPooler")
	if pooler and pooler.has_method("return_enemy"):
		pooler.return_enemy(self)
	else:
		# 혹시 풀러가 없는 독립 테스트 상황이라면 메모리 해제
		queue_free()

# ★ 오브젝트 풀에서 다시 꺼내질 때 호출되는 초기화 함수 ★
func reset_enemy() -> void:
	# 1. 능력치, 플래그, 타이머까지 완벽하게 태초의 상태로 복구
	health = max_hp
	is_dead = false
	attack_cooldown = 0.0 # 때리다 죽은 몹이 부활 시 공격 쿨타임이 밀리는 버그 방지
	visible = true
	velocity = Vector2.ZERO
	
	# 2. [물리 레이어 완벽 복구] 기획 문서 v1.1 매트릭스 준수
	# Layer 2 (Enemy), Mask 1 (Player 본체 감지 및 밀치기)
	collision_layer = 2
	collision_mask = 1
	$CollisionShape2D.set_deferred("disabled", false)
	
	# 3. 플레이어 재탐색 후 물리 프로세스 재가동
	_find_player()
	set_physics_process(true)

# 플레이어 탐색 서브 함수
func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	player = players[0] if players.size() > 0 else null
