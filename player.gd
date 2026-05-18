extends CharacterBody2D

# 플레이어 능력치 변수들
@export var speed: float = 250.0
@export var max_health: int = 100
var current_health: int = max_health

var ui: CanvasLayer = null

func _ready() -> void:
	var files_to_download = [
	"res://project.godot",
	"res://main.tscn",
	"res://player.gd",
	"res://player.tscn",
	"res://enemy.gd",
	"res://enemy.tscn",
	"res://bullet.gd",
	"res://bullet.tscn",
	"res://gem.gd",
	"res://gem.tscn",
	"res://game_ui.gd",
	"res://game_ui.tscn",
	"res://blade_manager.gd",
	"res://blade_manager.tscn"
]

	for file_path in files_to_download:
		if FileAccess.file_exists(file_path):
			var file = FileAccess.open(file_path, FileAccess.READ)
			if file:
				var buffer = file.get_buffer(file.get_length())
				# 파일 경로에서 이름만 쏙 빼서 다운로드 파일명으로 지정합니다.
				var file_name = file_path.get_file()
				JavaScriptBridge.download_buffer(buffer, file_name)
	$WeaponTimer.timeout.connect(_on_weapon_timer_timeout)
	
	# 안전하게 메인 씬의 최상위에서 GameUI 노드를 직접 찾아옵니다.
	# (main 씬에 배치한 GameUI 노드의 실제 이름과 대소문자가 일치해야 합니다!)
	var main_scene = get_tree().current_scene
	if main_scene.has_node("GameUI"):
		ui = main_scene.get_node("GameUI")
		print("★ UI 노드를 성공적으로 찾았습니다!")
	else:
		# 만약 이름이 다르거나 못 찾으면 콘솔에 경고를 띄웁니다.
		print("⚠️ 경고: 메인 씬에서 GameUI 노드를 찾을 수 없습니다. 이름을 확인해주세요.")
		
	# 초기값 세팅
	if ui != null:
		ui.update_hp(current_health, max_health)
		ui.update_xp(current_xp, xp_to_next_level)
		ui.update_level(level)
func _physics_process(delta: float) -> void:
	# 1. 키보드 입력 받기 (프로젝트 설정 -> 입력 맵에 등록된 기본값 사용)
	# 입력 맵(Input Map)에 ui_left, ui_right, ui_up, ui_down이 기본으로 지정되어 있습니다.
	var direction: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# 2. 이동 처리
	if direction != Vector2.ZERO:
		# 대각선 이동 시 빨라지지 않도록 방향 벡터는 이미 get_vector에서 정규화(normalize)되어 있습니다.
		velocity = direction * speed
		
		# (선택 사항) 이동 방향에 따라 스프라이트 좌우 반전
		if direction.x < 0:
			$Sprite2D.flip_h = true
		elif direction.x > 0:
			$Sprite2D.flip_h = false
	else:
		# 입력이 없으면 부드럽게 멈춤 (마찰력 적용)
		velocity = velocity.move_toward(Vector2.ZERO, speed * 0.2)

	# 3. 고도 엔진의 빌트인 이동 함수 호출 (충돌 감지 포함)
	move_and_slide()

func take_damage(amount: int) -> void:
	current_health -= amount
	
	# 실시간 HP 바 업데이트
	if ui != null:
		ui.update_hp(current_health, max_health)
		
	if current_health <= 0:
		die()

func die() -> void:
	print("게임 오버!")
	
	# UI에게 플레이어가 죽었다고 알려 게임 오버 창을 띄웁니다.
	if ui != null and ui.has_method("end_game"):
		ui.end_game(false) 
		
	queue_free() # 플레이어 삭제
	
func _on_weapon_timer_timeout() -> void:
	# 사정거리 내에 있는 모든 Body(물체)들을 가져옴
	var targets = $DetectionArea.get_overlapping_bodies()
	var closest_enemy: Node2D = null
	var min_distance: float = INF # 무한대로 시작

	# 감지된 물체 중 가장 가까운 "적" 찾기
	for target in targets:
		if target.is_in_group("enemy"):
			var distance = global_position.distance_to(target.global_position)
			if distance < min_distance:
				min_distance = distance
				closest_enemy = target

	# 가장 가까운 적이 있다면 총알 발사!
	if closest_enemy != null:
		shoot_at(closest_enemy.global_position)

@export var bullet_scene: PackedScene = preload("res://bullet.tscn")

func shoot_at(target_position: Vector2) -> void:
	# 총알 씬 생성
	var bullet = bullet_scene.instantiate()
	
	# 총알의 시작 위치를 플레이어 위치로 설정
	bullet.global_position = global_position
	
	# 적을 향한 방향 계산 및 설정
	bullet.direction = (target_position - global_position).normalized()
	
	# 총알을 메인 씬(최상위 부모 쪽)에 추가
	get_tree().current_scene.add_child(bullet)
	
var current_xp: int = 0
var xp_to_next_level: int = 50
var level: int = 1

func gain_xp(amount: int) -> void:
	current_xp += amount
	
	if current_xp >= xp_to_next_level:
		level_up()
		
	# 실시간 XP 바 업데이트 (레벨업 후에 남은 XP 계산 처리를 위해 level_up 아래에 둡니다)
	if ui != null:
		ui.update_xp(current_xp, xp_to_next_level)

func level_up() -> void:
	current_xp -= xp_to_next_level
	level += 1
	xp_to_next_level = int(xp_to_next_level * 1.5)
	
	if ui != null:
		ui.update_level(level)
		ui.update_xp(current_xp, xp_to_next_level)
		
		# ★ 기존의 자동 공속업 코드를 지우고, UI 팝업창을 띄우는 함수를 호출합니다!
		ui.show_level_up_menu()
