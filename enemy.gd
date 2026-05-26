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

func _ready() -> void:
	add_to_group("enemy")
	_find_player()
var attack_cooldown: float = 0.0 # 공격 쿨타임 타이머

func _physics_process(delta: float) -> void:
	if is_dead or not is_instance_valid(player):
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# [추가] 매 프레임 쿨타임 차감
	if attack_cooldown > 0:
		attack_cooldown -= delta

	var direction = (player.global_position - global_position).normalized()
	velocity = direction * speed
	
	if direction.x < 0:
		$Sprite2D.flip_h = true
	elif direction.x > 0:
		$Sprite2D.flip_h = false

	move_and_slide()
	
	# 쿨타임이 0 이하일 때만 플레이어 타격 체크
	if attack_cooldown <= 0:
		_check_player_collision()

func _check_player_collision() -> void:
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if is_instance_valid(collider) and collider.is_in_group("player"):
			if collider.has_method("take_damage"):
				collider.take_damage(damage)
				# [★ 핵심 ★] 한 번 때렸으므로 1초 동안 공격 봉인 (원하는 쿨타임 초 설정)
				attack_cooldown = 1.0 
				break # 한 프레임에 여러 번 때리는 것 방지

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
	
	# [버그 해결 핵심] 풀러의 격리 좌표(-99999, -99999)로 날아가기 전,
	# 현재 프레임에서 즉시 물리 레이어 장부를 파괴합니다.
	# 이렇게 해야 찰나의 순간에 플레이어를 튕겨내는 물리 버그가 발생하지 않습니다.
	collision_layer = 0
	collision_mask = 0
	$CollisionShape2D.set_deferred("disabled", true)
	
	# 사망 위치에 보석(경험치) 드롭
	if gem_scene != null:
		var gem = gem_scene.instantiate()
		gem.global_position = global_position
		# 메인 씬 트리에 안전하게 추가
		get_tree().current_scene.call_deferred("add_child", gem)
		
	# 오브젝트 풀러로 반납 처리
	if get_node_or_null("/root/ObjectPooler"):
		get_node("/root/ObjectPooler").return_enemy(self)
	else:
		# 혹시 풀러가 없는 독립 테스트 상황이라면 메모리 해제
		queue_free()

# ★ 오브젝트 풀에서 다시 꺼내질 때 호출되는 초기화 함수 ★
func reset_enemy() -> void:
	# 1. 능력치 및 플래그 초기화
	health = max_hp
	is_dead = false
	visible = true
	
	# 2. [물리 레이어 완벽 복구] 
	# Layer 2 (Enemy), Mask 1 (Player 본체 감지 및 밀치기)
	collision_layer = 2
	collision_mask = 1
	$CollisionShape2D.set_deferred("disabled", false)
	
	# 3. 프로세스 재가동 및 플레이어 재탐색
	set_physics_process(true)
	_find_player()

func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	player = players[0] if players.size() > 0 else null
