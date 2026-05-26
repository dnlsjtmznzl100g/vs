extends Node2D

@export_group("스폰 설정")
@export var enemy_scene: PackedScene = preload("res://enemy.tscn")
@export var spawn_radius: float = 750.0

@export_group("난이도 조절")
@export var base_spawn_interval: float = 2.0  # 시작 스폰 주기 (초)
@export var min_spawn_interval: float = 0.4   # 최대로 빨라질 수 있는 스폰 주기 제한
@export var base_spawn_count: int = 3
@export var spawn_count_multiplier: float = 0.05 # 시간당 마리 수 증가 폭

var elapsed_time: float = 0.0
var player: CharacterBody2D = null

@onready var spawn_timer: Timer = $SpawnTimer

func _ready() -> void:
	# 초기 플레이어 참조 확보
	_find_player()
	
	# 타이머 초기화 및 시작
	spawn_timer.wait_time = base_spawn_interval
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	spawn_timer.start()

func _process(delta: float) -> void:
	# 난이도 계산용 시간 측정만 수행 (매 프레임 타이머 변경 처리는 삭제)
	elapsed_time += delta

func _on_spawn_timer_timeout() -> void:
	# 플레이어 검증 (없으면 새로 찾고, 죽었으면 스폰 패스)
	if not is_instance_valid(player):
		_find_player()
		if player == null: return

	# 1. 스폰 시점에서 "다음 스폰 주기"를 딱 한 번만 계산 (중복 연산 제거)
	var next_interval = max(min_spawn_interval, base_spawn_interval - (elapsed_time * 0.005))
	spawn_timer.wait_time = next_interval

	# 2. 현재 시간에 맞춰 한 번에 스폰할 마리 수 계산
	var current_spawn_count = base_spawn_count + int(elapsed_time * spawn_count_multiplier)
	
	# 3. 계산된 마리 수만큼 스폰 루프 실행
	for i in range(current_spawn_count):
		spawn_enemy_outside_screen()

func spawn_enemy_outside_screen() -> void:
	# ObjectPooler에서 준비된 적 인스턴스 가져오기
	var enemy = ObjectPooler.get_enemy()
	if enemy == null: return
	
	# 1. 외곽 원형 좌표 연산부터 먼저 수행
	var random_angle = randf_range(0, 2 * PI)
	var spawn_direction = Vector2(cos(random_angle), sin(random_angle))
	var final_radius = spawn_radius + randf_range(-50.0, 50.0)

	# 2. 트리에 붙이기 '전에' 위치를 좌표로 미리 강제 지정!
	enemy.global_position = player.global_position + (spawn_direction * final_radius)

	# 3. 위치가 완벽히 잡힌 상태에서 트리에 안전하게 진입
	if enemy.get_parent() == null:
		get_parent().add_child(enemy)

	enemy.force_update_transform()
	if enemy.has_method("reset_enemy"):
		enemy.reset_enemy()

func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	player = players[0] if players.size() > 0 else null
