extends Area2D

@export var xp_amount: int = 10
@export var magnet_speed: float = 300.0

var player: CharacterBody2D = null
var is_being_collected: bool = false

func _ready() -> void:
	# 플레이어가 보석을 먹었는지 감지할 시그널 연결
	body_entered.connect(_on_body_entered)
	
	# 플레이어 미리 찾기
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func _physics_process(delta: float) -> void:
	# (자석 효과) 플레이어와 거리가 가까워지면 플레이어 쪽으로 이동
	if player != null and !is_being_collected:
		var distance = global_position.distance_to(player.global_position)
		if distance < 100.0: # 100픽셀 이내로 들어오면 끌려감
			global_position = global_position.move_toward(player.global_position, magnet_speed * delta)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and !is_being_collected:
		is_being_collected = true
		# 플레이어에게 경험치 지급 (이 함수는 잠시 후 플레이어 스크립트에 만들 예정)
		if body.has_method("gain_xp"):
			body.gain_xp(xp_amount)
		queue_free() # 보석 삭제
