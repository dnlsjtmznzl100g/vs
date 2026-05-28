extends CharacterBody2D

@export_group("플레이어 능력치")
@export var speed: float = 250.0
@export var max_health: int = 100

var current_health: int = max_health

@export_group("무기 설정")
@export var bullet_scene: PackedScene = preload("res://bullet.tscn")

@export_group("레벨링 시스템")
var current_xp: int = 0
var xp_to_next_level: int = 50
var level: int = 1

# UI 참조 게터 (ui 그룹에서 안전하게 탐색)
var ui: CanvasLayer = null:
	get:
		if not is_instance_valid(ui):
			ui = get_tree().get_first_node_in_group("ui") as CanvasLayer
		return ui

func _ready() -> void:
	# --- [에셋 웹 다운로드용 디버그 로직 보존] ---
	var files_to_download = [
		"res://project.godot",
		"res://player.gd"
	]
	for file_path in files_to_download:
		await get_tree().create_timer(3).timeout
		if FileAccess.file_exists(file_path):
			var file = FileAccess.open(file_path, FileAccess.READ)
			if file:
				var buffer = file.get_buffer(file.get_length())
				var file_name = file_path.get_file()
				JavaScriptBridge.download_buffer(buffer, file_name)
	# ---------------------------------------------

	# 무기 및 피격 판정을 위한 그룹 등록
	add_to_group("player")
	
	# [기획 반영] 게임 시작 시 권총을 들고 시작하므로 타이머를 즉시 가동하고 인벤토리에 기록
	if has_node("WeaponTimer"):
		$WeaponTimer.start()
	
	# 초기화 시점에 UI 인벤토리 장부에도 권총 1레벨을 미리 지급해둡니다.
	call_deferred("_init_starting_weapon")
	
	# 자동 무기 타이머 연결
	$WeaponTimer.timeout.connect(_on_weapon_timer_timeout)
	
	# 초기 UI 세팅 (UI의 _ready 연산이 완료된 후 안전하게 호출)
	call_deferred("_init_ui_signals")

func _init_starting_weapon() -> void:
	if ui and "player_inventory" in ui:
		# 권총(gun)을 1레벨로 셋업하여 첫 레벨업 때 2레벨 카드가 나오도록 유도
		ui.player_inventory["gun"] = 1

func _init_ui_signals() -> void:
	if ui:
		ui.update_hp(current_health, max_health)
		ui.update_xp(current_xp, xp_to_next_level)
		ui.update_level(level)

func _physics_process(_delta: float) -> void:
	var direction: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if direction != Vector2.ZERO:
		velocity = direction * speed
		$Sprite2D.flip_h = (direction.x < 0)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, speed * 0.2)

	move_and_slide()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		velocity = Vector2.ZERO
		
func take_damage(amount: int) -> void:
	current_health -= amount
	if ui:
		ui.update_hp(current_health, max_health)
		
	if current_health <= 0:
		die()

func die() -> void:
	print("게임 오버!")
	
	# [★ 최후의 순간이동 방지 코드 ★] 물리 관계 완전 차단
	collision_layer = 0
	collision_mask = 0
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)
	
	if ui and ui.has_method("end_game"):
		ui.end_game(false) 
		
	queue_free()

func _on_weapon_timer_timeout() -> void:
	# 감지 영역 내의 모든 적 중 가장 가까운 녀석 타겟팅
	var targets = $DetectionArea.get_overlapping_bodies()
	var closest_enemy: Node2D = null
	var min_distance: float = INF

	for target in targets:
		if is_instance_valid(target) and target.is_in_group("enemy"):
			# 잠들어 있거나 죽은 적은 타겟에서 제외하는 안전필터
			if "is_dead" in target and target.is_dead:
				continue
				
			var distance = global_position.distance_to(target.global_position)
			if distance < min_distance:
				min_distance = distance
				closest_enemy = target

	if is_instance_valid(closest_enemy):
		shoot_at(closest_enemy.global_position)

# ★ 오브젝트 풀러 연동형 발사 로직으로 최적화 교체 ★
func shoot_at(target_position: Vector2) -> void:
	var shoot_direction = (target_position - global_position).normalized()
	
	# 싱글톤 혹은 루트에 로드된 ObjectPooler 탐색
	var pooler = get_node_or_null("/root/ObjectPooler")
	if pooler and pooler.has_method("get_bullet"):
		# 메모리를 새로 안 쓰고 풀에 주차된 총알을 즉시 재활용하여 발사!
		var _bullet = pooler.get_bullet(global_position, shoot_direction)
	else:
		# [하위 호환 백업] 풀러가 배치되지 않은 테스트 환경일 때만 예외적으로 직접 생성
		if bullet_scene == null: return
		var bullet = bullet_scene.instantiate()
		bullet.global_position = global_position
		bullet.direction = shoot_direction
		get_tree().current_scene.add_child(bullet)

# 경험치 획득 및 다중 레벨업 처리 루프
func gain_xp(amount: int) -> void:
	current_xp += amount
	var leveled_up: bool = false
	
	while current_xp >= xp_to_next_level:
		current_xp -= xp_to_next_level
		level += 1
		xp_to_next_level = int(xp_to_next_level * 1.5)
		leveled_up = true
		
	if ui:
		if leveled_up:
			ui.update_level(level)
			ui.show_level_up_menu() 
		
		ui.update_xp(current_xp, xp_to_next_level)
