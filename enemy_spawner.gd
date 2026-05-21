extends Node2D

# [설정] 스폰할 적 씬과 보석 씬 (인스펙터에서 변경 가능)
@export var enemy_scene: PackedScene = preload("res://enemy.tscn")

# [설정] 플레이어 기준 스폰 거리 (화면 해상도 1152x648 기준, 750~800이 화면 바로 밖입니다)
@export var spawn_radius: float = 750.0

# [난이도 조절 변수]
var base_spawn_count: int = 3      # 게임 시작 시 한 번에 스폰되는 적의 수
var spawn_count_multiplier: float = 0.1 # 10초마다 추가로 스폰될 적의 수 계산용
var elapsed_time: float = 0.0      # 게임 시작 후 흐른 시간

var player: CharacterBody2D = null
@onready var spawn_timer: Timer = $SpawnTimer

func _ready() -> void:
	# 1. 플레이어 찾기 ("player" 그룹 이용)
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
		
	# 2. 타이머 신호 연결
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)

func _process(delta: float) -> void:
	# 게임 시간을 계속 누적 (난이도 상승용)
	elapsed_time += delta

func _on_spawn_timer_timeout() -> void:
	# 플레이어가 죽었거나 없으면 스폰하지 않음
	if player == null:
		# 혹시 플레이어가 뒤늦게 생성되거나 부활할 경우를 대비해 재탐색
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
		else:
			return

	# 현재 시간에 맞춰 스폰할 마리 수 계산 (예: 60초가 지나면 기본 2마리 + 6마리 = 총 8마리 스폰)
	var current_spawn_count = base_spawn_count + int(elapsed_time * spawn_count_multiplier)
	
	for i in range(current_spawn_count):
		spawn_enemy_outside_screen()

func spawn_enemy_outside_screen() -> void:
	if enemy_scene == null:
		return
		
	# 1. 몬스터 인스턴스 생성
	var enemy = enemy_scene.instantiate()
	
	# 2. 플레이어 주변 화면 밖의 랜덤 위치 계산 (원형 스폰 원리)
	var random_angle = randf_range(0, 2 * PI)
	var spawn_direction = Vector2(cos(random_angle), sin(random_angle))
	var spawn_position = player.global_position + (spawn_direction * spawn_radius)
	
	# 3. 몬스터 위치 설정
	enemy.global_position = spawn_position
	
	# 4. 메인 씬에 안전하게 적 추가 (enemy.gd의 die() 방식과 통일)
	get_tree().current_scene.call_deferred("add_child", enemy)
