extends Node2D

# [설정] 스폰할 적 씬
@export var enemy_scene: PackedScene = preload("res://enemy.tscn")

# [설정] 플레이어 기준 스폰 거리
@export var spawn_radius: float = 750.0

# [난이도 조절 변수]
@export var base_spawn_interval: float = 2.0  # 시작 스폰 주기 (초)
@export var min_spawn_interval: float = 0.4   # 최대로 빨라질 수 있는 스폰 주기 제한
var base_spawn_count: int = 3
var spawn_count_multiplier: float = 0.05       # 마리 수 증가 폭을 살짝 완화

var elapsed_time: float = 0.0

# 안전한 플레이어 참조 게터 (player.gd와 통일성 유지)
var player: CharacterBody2D = null:
	get:
		if not is_instance_valid(player):
			var players = get_tree().get_nodes_in_group("player")
			if players.size() > 0:
				player = players[0]
			else:
				player = null
		return player

@onready var spawn_timer: Timer = $SpawnTimer

func _ready() -> void:
	# 초기 타이머 설정 및 시작
	spawn_timer.wait_time = base_spawn_interval
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	spawn_timer.start()

func _process(delta: float) -> void:
	elapsed_time += delta
	
	# 난이도 조절: 시간에 비례하여 스폰 타이머 주기를 점진적으로 감소시킴 (더 자주 스폰하게)
	# 예: 100초 흐르면 원래 2초에서 점차 줄어들어 min_spawn_interval에 수렴
	var new_interval = max(min_spawn_interval, base_spawn_interval - (elapsed_time * 0.005))
	if spawn_timer.wait_time != new_interval:
		spawn_timer.wait_time = new_interval

func _on_spawn_timer_timeout() -> void:
	# 게터를 통해 플레이어 생존 여부 안전 검사 (죽었으면 스폰 중단)
	if player == null:
		return

	# 현재 시간에 맞춰 한 번에 스폰할 마리 수 계산
	var current_spawn_count = base_spawn_count + int(elapsed_time * spawn_count_multiplier)
	
	# 프레임 드랍 방지를 위해 대량 스폰 시 시차를 두고 스폰하거나 차례대로 생성
	for i in range(current_spawn_count):
		spawn_enemy_outside_screen()

func spawn_enemy_outside_screen() -> void:
	if enemy_scene == null or player == null:
		return
		
	var enemy = ObjectPooler.get_enemy()
	
	# 원형 스폰 좌표 연산
	var random_angle = randf_range(0, 2 * PI)
	var spawn_direction = Vector2(cos(random_angle), sin(random_angle))
	
	# [팁] 반지름에 미세한 무작위 오차(randf_range(-50, 50))를 주면 일렬로 이쁘게 스폰되는 대신 자연스러운 무리가 형성됨
	var final_radius = spawn_radius + randf_range(-50.0, 50.0)
	var spawn_position = player.global_position + (spawn_direction * final_radius)
	
	enemy.global_position = spawn_position
	enemy.force_update_transform()
