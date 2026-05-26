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
	# 무기 및 피격 판정을 위한 그룹 등록
	add_to_group("player")
	
	# 자동 무기 타이머 연결
	$WeaponTimer.timeout.connect(_on_weapon_timer_timeout)
	
	# 초기 UI 세팅 (UI의 _ready 연산이 완료된 후 안전하게 호출)
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
	
	# [★ 최후의 순간이동 방지 코드 ★]
	# 내가 죽어 사라지기 전에 나를 밀어붙이던 몹들과의 물리 관계를 완전히 끊어버립니다.
	collision_layer = 0
	collision_mask = 0
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)
	
	# UI에 게임오버 알림
	if ui and ui.has_method("end_game"):
		ui.end_game(false) 
		
	# 완전히 삭제하기 전 1프레임 미뤄서 안전하게 트리에서 제거
	queue_free()

func _on_weapon_timer_timeout() -> void:
	var targets = $DetectionArea.get_overlapping_bodies()
	var closest_enemy: Node2D = null
	var min_distance: float = INF

	for target in targets:
		if is_instance_valid(target) and target.is_in_group("enemy"):
			var distance = global_position.distance_to(target.global_position)
			if distance < min_distance:
				min_distance = distance
				closest_enemy = target

	if is_instance_valid(closest_enemy):
		shoot_at(closest_enemy.global_position)

func shoot_at(target_position: Vector2) -> void:
	if bullet_scene == null: return
	
	# [확장 팁] 나중에 총알도 오브젝트 풀링을 도입한다면 이 부분을 ObjectPooler.get_bullet() 형태로 바꿀 수 있습니다.
	var bullet = bullet_scene.instantiate()
	bullet.global_position = global_position
	bullet.direction = (target_position - global_position).normalized()
	
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
			ui.show_level_up_menu() # 일시정지 및 카드 선택 UI 호출
		
		ui.update_xp(current_xp, xp_to_next_level)
