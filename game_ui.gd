extends CanvasLayer

@onready var xp_bar: ProgressBar = $BaseUI/XPBar
@onready var hp_bar: ProgressBar = $BaseUI/HPBar
@onready var level_label: Label = $BaseUI/LevelLabel
@onready var level_up_menu: PanelContainer = $LevelUpMenu
@onready var option1: Button = $LevelUpMenu/VBoxContainer/Option1
@onready var option2: Button = $LevelUpMenu/VBoxContainer/Option2
@onready var option3: Button = $LevelUpMenu/VBoxContainer/Option3

@export var blade_scene: PackedScene = preload("res://blade_manager.tscn")

@onready var time_label: Label = $BaseUI/TimeLabel
@onready var result_menu: PanelContainer = $ResultMenu
@onready var result_title: Label = $ResultMenu/VBoxContainer/ResultTitle
@onready var result_detail: Label = $ResultMenu/VBoxContainer/ResultDetail
@onready var restart_button: Button = $ResultMenu/VBoxContainer/RestartButton

var time_elapsed: float = 0.0
var game_ended: bool = false
@export var target_win_time: float = 300.0 # 이 시간동안 버티면 승리!
var player_ref: CharacterBody2D = null

func _ready() -> void:
	add_to_group("ui")
	
	# 버튼 클릭 시그널 연결
	option1.pressed.connect(_on_option_selected.bind(1))
	option2.pressed.connect(_on_option_selected.bind(2))
	option3.pressed.connect(_on_option_selected.bind(3))
	
	# 플레이어 참조 가져오기
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_ref = players[0]

# 체력 바 업데이트 함수
func update_hp(current: int, max_hp: int) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = current

# 경험치 바 업데이트 함수
func update_xp(current: int, max_xp: int) -> void:
	xp_bar.max_value = max_xp
	xp_bar.value = current

# 레벨 텍스트 업데이트 함수
func update_level(level: int) -> void:
	level_label.text = "LV. " + str(level)

func show_level_up_menu() -> void:
	option1.text = "[1] hp +20 (heal)"
	option2.text = "[2] speed +30"
	
	# 플레이어가 이미 칼날을 가지고 있는지 체크해서 텍스트를 다르게 표시합니다.
	if player_ref != null and player_ref.has_node("BladeManager"):
		option3.text = "[3] Circle blade upgrade (speed +50%)"
	else:
		option3.text = "[3] new Weapon!!: Circle blade"
	
	level_up_menu.visible = true
	get_tree().paused = true

# 기존 _on_option_selected(option_index) 함수 내부 수정
func _on_option_selected(option_index: int) -> void:
	if player_ref == null: return
	
	match option_index:
		1:
			player_ref.max_health += 20
			player_ref.current_health += 20
			update_hp(player_ref.current_health, player_ref.max_health)
		2:
			player_ref.speed += 30.0
		3:
			# 3번을 선택했을 때: 무기가 없으면 새로 주고, 있으면 강화합니다.
			if player_ref.has_node("BladeManager"):
				# 이미 무기가 있다면 회전 속도 강화
				var blade_mgr = player_ref.get_node("BladeManager")
				blade_mgr.rotation_speed += 1.5
				print("칼날 속도 강화!")
			else:
				# 무기가 없다면 새로 생성하여 플레이어의 자식으로 추가!
				if blade_scene != null:
					var new_blade = blade_scene.instantiate()
					# 이름을 확실하게 고정해두어야 다음 레벨업 때has_node()로 찾을 수 있습니다.
					new_blade.name = "BladeManager" 
					player_ref.add_child(new_blade)
					print("새 무기: 공전하는 칼날 장착 완료!")
	
	level_up_menu.visible = false
	get_tree().paused = false

func _process(delta: float) -> void:
	if game_ended: return
	
	# 1. 시간 누적 및 타이머 텍스트 갱신
	time_elapsed += delta
	var minutes: int = int(time_elapsed) / 60
	var seconds: int = int(time_elapsed) % 60
	time_label.text = "%02d:%02d" % [minutes, seconds]
	
	# 2. 지정된 시간 동안 버텼는지 체크 (승리 조건)
	if time_elapsed >= target_win_time:
		end_game(true)

# 게임 종료 처리 함수 (is_win이 true면 승리, false면 패배)
func end_game(is_win: bool) -> void:
	game_ended = true
	get_tree().paused = true # 게임 일시정지
	
	var minutes: int = int(time_elapsed) / 60
	var seconds: int = int(time_elapsed) % 60
	
	if is_win:
		result_title.text = "VICTORY!"
		result_detail.text = "congratulation! %02dmin %02dsec survive." % [minutes, seconds]
	else:
		result_title.text = "GAME OVER"
		result_detail.text = "you lose... (%02dmin %02dsec survived)" % [minutes, seconds]
		
	result_menu.visible = true

# 다시 시작 버튼 로직
func _on_restart_button_pressed() -> void:
	get_tree().paused = false # 일시정지 풀기
	get_tree().reload_current_scene() # 현재 메인 씬을 처음부터 다시 로드!
