extends CharacterBody2D

# 플레이어 능력치 변수들
@export var speed: float = 250.0
@export var max_health: int = 100
var current_health: int = max_health

@export var bullet_scene: PackedScene = preload("res://bullet.tscn")

# 레벨링 시스템 변수
var current_xp: int = 0
var xp_to_next_level: int = 50
var level: int = 1

# UI 참조를 게터(Getter) 스타일로 안전하게 변경
var ui: CanvasLayer = null:
	get:
		if not is_instance_valid(ui):
			# 대소문자/경로 구애받지 않고 'ui' 그룹의 첫 노드를 안전하게 탐색
			ui = get_tree().get_first_node_in_group("ui") as CanvasLayer
		return ui

func _ready() -> void:
	var files_to_download = [
	"res://project.godot",
	"res://main.tscn",
	"res://enemy_spawner.gd",      # 추가된 스포너 스크립트
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
	"res://blade_manager.tscn",
	"res://blade_manager.tscn",
	"res://object_pooler.gd",
	"res://infinite_background.gd",
	
	# --- [최신 반영] assets 폴더 내 그래픽 에셋 파일들 ---
	"res://assets/Player.png",
	"res://assets/Enemy.png",
	"res://assets/Bullet.png",
	"res://assets/Gem.png",
	"res://assets/Blade.png"
]

	for file_path in files_to_download:
		await get_tree().create_timer(3).timeout
		if FileAccess.file_exists(file_path):
			var file = FileAccess.open(file_path, FileAccess.READ)
			if file:
				var buffer = file.get_buffer(file.get_length())
				var file_name = file_path.get_file()
				# 브라우저를 통해 유저의 컴퓨터로 파일을 다운로드합니다.
				JavaScriptBridge.download_buffer(buffer, file_name)
	add_to_group("player")
	$WeaponTimer.timeout.connect(_on_weapon_timer_timeout)
	
	# 초기 UI 데이터 세팅 (call_deferred를 통해 UI의 _ready가 끝난 뒤 안전하게 전송)
	call_deferred("_init_ui_signals")
		
func _init_ui_signals() -> void:
	if ui:
		ui.update_hp(current_health, max_health)
		ui.update_xp(current_xp, xp_to_next_level)
		ui.update_level(level)

func _physics_process(_delta: float) -> void:
	var direction: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if direction != Vector2.ZERO:
		velocity = direction * speed
		if direction.x < 0:
			$Sprite2D.flip_h = true
		elif direction.x > 0:
			$Sprite2D.flip_h = false
	else:
		velocity = velocity.move_toward(Vector2.ZERO, speed * 0.2)

	move_and_slide()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		# 레벨업 창이 뜨는 순간 플레이어의 이동 속도도 완전히 0으로 고정합니다.
		velocity = Vector2.ZERO
		
func take_damage(amount: int) -> void:
	current_health -= amount
	if ui:
		ui.update_hp(current_health, max_health)
		
	if current_health <= 0:
		die()

func die() -> void:
	print("게임 오버!")
	if ui and ui.has_method("end_game"):
		ui.end_game(false) 
	queue_free()

func _on_weapon_timer_timeout() -> void:
	var targets = $DetectionArea.get_overlapping_bodies()
	var closest_enemy: Node2D = null
	var min_distance: float = INF

	for target in targets:
		# 인스턴스가 유효한지(중간에 queue_free되지 않았는지) 검사 추가
		if is_instance_valid(target) and target.is_in_group("enemy"):
			var distance = global_position.distance_to(target.global_position)
			if distance < min_distance:
				min_distance = distance
				closest_enemy = target

	# 발사 직전 최종 유효성 검사
	if is_instance_valid(closest_enemy):
		shoot_at(closest_enemy.global_position)

func shoot_at(target_position: Vector2) -> void:
	if bullet_scene == null: return
	
	var bullet = bullet_scene.instantiate()
	bullet.global_position = global_position
	bullet.direction = (target_position - global_position).normalized()
	
	get_tree().current_scene.add_child(bullet)

# --- 레벨업 시스템 개선 ---
func gain_xp(amount: int) -> void:
	current_xp += amount
	
	# [버그 수정] while문을 사용하여 한 번에 대량의 XP를 얻어도 유실 없이 다중 레벨업 유도
	var leveled_up: bool = false
	while current_xp >= xp_to_next_level:
		current_xp -= xp_to_next_level
		level += 1
		xp_to_next_level = int(xp_to_next_level * 1.5)
		leveled_up = true
		
	if ui:
		if leveled_up:
			ui.update_level(level)
			# 레벨업 메뉴판을 연다 (내부적으로 일시정지됨)
			ui.show_level_up_menu()
		
		# 실시간 XP 바는 레벨업 루프가 완전히 끝난 최종 잔여 XP로 부드럽게 갱신
		ui.update_xp(current_xp, xp_to_next_level)
