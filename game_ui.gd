extends CanvasLayer

# --- 1. UI 노드 참조 ---
@onready var xp_bar: ProgressBar = $BaseUI/XPBar
@onready var hp_bar: ProgressBar = $BaseUI/HPBar
@onready var level_label: Label = $BaseUI/LevelLabel
@onready var level_up_menu: PanelContainer = $LevelUpMenu
@onready var option1: Button = $LevelUpMenu/VBoxContainer/Option1
@onready var option2: Button = $LevelUpMenu/VBoxContainer/Option2
@onready var option3: Button = $LevelUpMenu/VBoxContainer/Option3

@onready var time_label: Label = $BaseUI/TimeLabel
@onready var result_menu: PanelContainer = $ResultMenu
@onready var result_title: Label = $ResultMenu/VBoxContainer/ResultTitle
@onready var result_detail: Label = $ResultMenu/VBoxContainer/ResultDetail
@onready var restart_button: Button = $ResultMenu/VBoxContainer/RestartButton

# --- 2. 프리로드 및 내장 변수 ---
@export var blade_scene: PackedScene = preload("res://blade_manager.tscn")
@export var target_win_time: float = 300.0 # 이 시간동안 버티면 승리!

var time_elapsed: float = 0.0
var game_ended: bool = false
var player_ref: CharacterBody2D = null

# --- 3. 확장성 높은 아이템 데이터베이스 시스템 ---
const WP_BLADE = "blade"
const WP_GUN = "gun"
const PS_HP = "passive_hp"
const PS_SPEED = "passive_speed"

# 새로운 무기/패시브가 생기면 이 딕셔너리에 한 줄만 추가하면 됩니다.
var item_db = {
	WP_BLADE: {
		"name": "blade",
		"desc": "crah enemy with blade",
		"type": "weapon",
		"max_level": 5
	},
	WP_GUN: {
		"name": "gun",
		"desc": "fasten gun",
		"type": "weapon",
		"max_level": 5
	},
	PS_HP: {
		"name": "health",
		"desc": "max hp +20",
		"type": "passive",
		"max_level": 5
	},
	PS_SPEED: {
		"name": "feet",
		"desc": "speed +30",
		"type": "passive",
		"max_level": 5
	}
}

# 플레이어가 현재 보유한 아이템들의 레벨 저장소 (예: {"blade": 1, "passive_hp": 2})
var player_inventory = {}


# --- 4. 라이프사이클 함수 ---
func _ready() -> void:
	add_to_group("ui")
	
	# [중요] 게임이 일시정지(paused) 상태여도 이 UI 노드는 멈추지 않고 입력을 받도록 설정
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 다시 시작 버튼 시그널 연결
	if restart_button:
		restart_button.pressed.connect(_on_restart_button_pressed)
	
	# 플레이어 참조 가져오기 및 예외 안전 처리
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_ref = players[0]
	else:
		call_deferred("_find_player_delayed")

func _find_player_delayed() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_ref = players[0]

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


# --- 5. 플레이어 스탯 연동 기능 ---
func update_hp(current: int, max_hp: int) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = current

func update_xp(current: int, max_xp: int) -> void:
	xp_bar.max_value = max_xp
	xp_bar.value = current

func update_level(level: int) -> void:
	level_label.text = "LV. " + str(level)


# --- 6. 핵심: 랜덤 레벨업 시퀀스 시스템 ---
func show_level_up_menu() -> void:
	# 1. 등장 가능한 아이템 후보 필터링 (최대 레벨에 도달하지 않은 아이템만 추림)
	var available_items = []
	for item_id in item_db.keys():
		var current_lvl = player_inventory.get(item_id, 0)
		if current_lvl < item_db[item_id]["max_level"]:
			available_items.append(item_id)
	
	# 2. 만약 모든 무기/패시브가 만렙이라 업그레이드할 게 없다면 메뉴를 열지 않고 재개
	if available_items.size() == 0:
		get_tree().paused = false
		return
		
	# 3. 무작위로 셔플 후 최대 3개의 무작위 선택지 확정
	available_items.shuffle()
	var selected_options = []
	for i in range(min(3, available_items.size())):
		selected_options.append(available_items[i])
		
	# 4. 선택된 데이터를 기반으로 버튼 바인딩 및 텍스트 갱신
	setup_option_button(option1, selected_options, 0)
	setup_option_button(option2, selected_options, 1)
	setup_option_button(option3, selected_options, 2)
	
	# 5. UI를 띄우고 게임 일시정지
	level_up_menu.visible = true
	get_tree().paused = true

# 버튼의 텍스트를 세팅하고 아이템 고유 ID를 바인딩하는 헬퍼 함수
func setup_option_button(button: Button, options: Array, index: int) -> void:
	# 만약 남은 후보 아이템이 3개 미만이라 인덱스를 벗어나면 해당 버튼은 숨김 처리
	if index >= options.size():
		button.visible = false
		return
		
	button.visible = true
	var item_id = options[index]
	var item_info = item_db[item_id]
	var next_level = player_inventory.get(item_id, 0) + 1
	
	# 텍스트 동적 변경 (특수 연출: 칼날 습득/강화에 따른 동적 설명 대응 가능)
	var description = item_info["desc"]
	if item_id == WP_BLADE and next_level > 1:
		description = "회전하는 칼날의 회전 속도가 50% 빨라집니다."
		
	button.text = "[%s Lv.%d]\n%s" % [item_info["name"], next_level, description]
	
	# 중요: 버튼에 걸려있던 이전 시그널 연결을 안전하게 초기화한 후 새로 동적 바인딩(.bind) 처리
	if button.pressed.is_connected(_on_item_selected):
		button.pressed.disconnect(_on_item_selected)
	button.pressed.connect(_on_item_selected.bind(item_id))


# 사용자가 무작위 버튼 중 하나를 클릭했을 때 호출되는 핵심 보상 함수
func _on_item_selected(item_id: String) -> void:
	if player_ref == null: return
	
	# 1. 인벤토리 내 해당 아이템 레벨 1 증가
	if not player_inventory.has(item_id):
		player_inventory[item_id] = 1
	else:
		player_inventory[item_id] += 1
		
	var current_lvl = player_inventory[item_id]
	
	# 2. 아이템 고유 ID에 따른 실제 스탯 및 무기 메커니즘 적용
	match item_id:
		WP_BLADE:
			if current_lvl == 1:
				# 최초 획득 시: 플레이어 자식 노드로 BladeManager 인스턴스 부착
				if blade_scene != null:
					var new_blade = blade_scene.instantiate()
					new_blade.name = "BladeManager" 
					player_ref.add_child(new_blade)
					print("새 무기: 공전하는 칼날 장착!")
			else:
				# 레벨업 강화 시: 칼날 매니저를 찾아 속도 증가
				var blade_mgr = player_ref.get_node_or_null("BladeManager")
				if blade_mgr:
					blade_mgr.rotation_speed += 1.5
					print("칼날 속도 강화! 현재 속도 증가량: ", current_lvl)
					
		WP_GUN:
			# 기본 권총 타이머를 찾아 발사 딜레이 속도를 줄임 (더 빨리 쏨)
			var gun_timer = player_ref.get_node_or_null("WeaponTimer")
			if gun_timer:
				gun_timer.wait_time = max(0.15, gun_timer.wait_time - 0.15)
				print("권총 연사 속도 업그레이드! 현재 딜레이: ", gun_timer.wait_time)
				
		PS_HP:
			player_ref.max_health += 20
			player_ref.current_health += 20
			update_hp(player_ref.current_health, player_ref.max_health)
			
		PS_SPEED:
			player_ref.speed += 30.0

	# 3. 궁극의 조합(진화) 무기 체크 예시 코드
	# 조건: 칼날 5레벨(만렙) 과 체력 증가 5레벨(만렙) 동시 달성 시 발생
	if player_inventory.get(WP_BLADE, 0) == 5 and player_inventory.get(PS_HP, 0) == 5:
		trigger_evolution()

	# 4. 메뉴판을 닫고 일시정지를 풀어 게임을 재개
	level_up_menu.visible = false
	get_tree().paused = false


# 조합 무기 진화 발동 로직 (예시)
func trigger_evolution() -> void:
	print("🔥 [조합 성공] 피의 칼날 폭풍으로 무기가 진화합니다! 🔥")
	# 이 자리에 기존 무기를 지우거나 진화형 이펙트를 켜는 코드를 추가하면 궁극기 완성!


# --- 7. 게임 종료 및 리스타트 로직 ---
func end_game(is_win: bool) -> void:
	game_ended = true
	get_tree().paused = true # 게임 일시정지
	
	var minutes: int = int(time_elapsed) / 60
	var seconds: int = int(time_elapsed) % 60
	
	if is_win:
		result_title.text = "VICTORY!"
		result_detail.text = "축하합니다! %02d분 %02d초 동안 생존했습니다." % [minutes, seconds]
	else:
		result_title.text = "GAME OVER"
		result_detail.text = "패배했습니다... (%02d분 %02d초 생존)" % [minutes, seconds]
		
	result_menu.visible = true

func _on_restart_button_pressed() -> void:
	get_tree().paused = false # 일시정지 해제
	get_tree().reload_current_scene() # 현재 메인 씬 재시작
