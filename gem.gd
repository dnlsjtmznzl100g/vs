extends Area2D

@export var xp_amount: int = 10
@export var magnet_speed: float = 300.0
@export var magnet_radius: float = 120.0

var player: CharacterBody2D = null
var is_being_collected: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
	var players = get_tree().get_nodes_in_group("player")
	player = players[0] if players.size() > 0 else null

func _physics_process(delta: float) -> void:
	if is_being_collected or not is_instance_valid(player): 
		return
		
	var distance = global_position.distance_to(player.global_position)
	
	if distance < magnet_radius:
		# 중심부에 너무 가까워지면 강제 흡수
		if distance <= 15.0:
			_absorb_gem(player)
			return
			
		global_position = global_position.move_toward(player.global_position, magnet_speed * delta)

func _on_body_entered(body: Node2D) -> void:
	if is_being_collected: return
	if body.is_in_group("player"):
		_absorb_gem(body)

# 순간이동 버그를 완벽히 차단하는 흡수 함수
func _absorb_gem(target_player: Node2D) -> void:
	is_being_collected = true
	
	# [★ 순간이동 버그 해결의 핵심 키 ★]
	# 충돌체만 끄면 고도 엔진이 다음 프레임에 반영하므로, 그 찰나에 플레이어를 밀어냅니다.
	# 아예 보석의 물리 레이어와 마스크를 즉시 0(비활성화)으로 만들어서
	# 물리 엔진이 이 보석을 "없는 존재"로 취급하게 만듭니다.
	collision_layer = 0
	collision_mask = 0
	$CollisionShape2D.set_deferred("disabled", true) 
	
	# 경험치 정산
	if target_player.has_method("gain_xp"):
		target_player.gain_xp(xp_amount)
		
	queue_free()
