extends Node2D

# [설정] 청크로 사용할 거대한 바닥 이미지 씬이나 텍스처
# 프로토타입 단계이므로, 인스펙터에서 res://assets/Enemy.png 같은 아무 이미지나 
# 큼직한 바닥용 이미지(예: 1000x1000 너비)를 지정하면 됩니다.
@export var background_texture: Texture2D = preload("res://Player.png") # 우선 임시 지정
@export var chunk_size: Vector2 = Vector2(1024, 1024) # 배경 이미지의 실제 가로세로 픽셀 크기

var player: CharacterBody2D = null
var chunks: Array[Sprite2D] = []

# 플레이어가 현재 위치한 청크의 그리드 좌표 (예: 0,0 또는 1,-2)
var current_chunk_coord: Vector2i = Vector2i.ZERO

func _ready() -> void:
	# 플레이어 그룹에서 가져오기
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
		
	# 1. 3x3 형태(총 9개)의 배경 청크 스프라이트를 동적으로 생성하여 배치합니다.
	for x in range(-1, 2):
		for y in range(-1, 2):
			var sprite = Sprite2D.new()
			sprite.texture = background_texture
			sprite.centered = true
			
			# 격자 모양으로 나란히 위치 지정
			var spawn_pos = Vector2(x * chunk_size.x, y * chunk_size.y)
			sprite.global_position = spawn_pos
			
			add_child(sprite)
			chunks.append(sprite)

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player): return
	
	# 2. 플레이어가 현재 어떤 청크 좌표에 있는지 실시간 연산
	var player_coord_x = round(player.global_position.x / chunk_size.x)
	var player_coord_y = round(player.global_position.y / chunk_size.y)
	var new_coord = Vector2i(player_coord_x, player_coord_y)
	
	# 3. 플레이어가 다른 청크 구역으로 넘어갔다면, 모든 청크의 위치를 재배치합니다.
	if new_coord != current_chunk_coord:
		current_chunk_coord = new_coord
		update_chunk_positions()

# 청크들을 플레이어 중심으로 재정렬하는 핵심 함수
func update_chunk_positions() -> void:
	for chunk in chunks:
		# 청크의 현재 위치를 그리드 좌표로 환산
		var chunk_coord_x = round(chunk.global_position.x / chunk_size.x)
		var chunk_coord_y = round(chunk.global_position.y / chunk_size.y)
		
		# 플레이어의 현재 청크 좌표와의 거리 차이 계산
		var diff_x = chunk_coord_x - current_chunk_coord.x
		var diff_y = chunk_coord_y - current_chunk_coord.y
		
		# [핵심 텔레포트 로직] 
		# 만약 거리가 너무 멀어졌다면(1칸 초과), 반대편(플레이어의 앞길)으로 순간이동 시킵니다.
		if diff_x < -1: chunk.global_position.x += chunk_size.x * 3
		elif diff_x > 1: chunk.global_position.x -= chunk_size.x * 3
			
		if diff_y < -1: chunk.global_position.y += chunk_size.y * 3
		elif diff_y > 1: chunk.global_position.y -= chunk_size.y * 3
		
		if is_instance_valid(player):
			player.force_update_transform()
