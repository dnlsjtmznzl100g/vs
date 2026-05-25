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
@export var target_win_time: float = 300.0

var time_elapsed: float = 0.0
var game_ended: bool = false
var is_blade_evolved: bool = false # 진화 중복 방지 플래그

# [개선] 안전한 플레이어 참조 게터 (Getter)
var player_ref: CharacterBody2D:
	get:
		if not is_instance_valid(player_ref):
			var players = get_tree().get_nodes_in_group("player")
			if players.size() > 0:
				player_ref = players[0]
		return player_ref

# --- 3. 아이템 데이터베이스 (레벨별 설명 데이터 구조화) ---
const WP_BLADE = "blade"
const WP_GUN = "gun"
const PS_HP = "passive_hp"
const PS_SPEED = "passive_speed"

var item_db = {
	WP_BLADE: {
		"name": "궤도 칼날",
		"type": "weapon",
		"max_level": 5,
		"descriptions": ["주변을 도는 칼날을 소환합니다.", "회전 속도가 50% 빨라집니다.", "회전 속도가 50% 빨라집니다.", "회전 속도가 50% 빨라집니다.", "회전 속도가 50% 빨라집니다."]
	},
	WP_GUN: {
		"name": "자동 권총",
		"type": "weapon",
		"max_level": 5,
		"descriptions": ["가까운 적에게 총알을 쏩니다.", "연사 속도가 증가합니다.", "연사 속도가 증가합니다.", "연사 속도가 증가합니다.", "연사 속도가 증가합니다."]
	},
	PS_HP: {
		"name": "체력 증강",
		"type": "passive",
		"max_level": 5,
		"descriptions": ["최대 체력이 20 증가합니다."] # 레벨 공통 혹은 최대 레벨까지만
	},
	PS_SPEED: {
		"name": "가벼운 발걸음",
		"type": "passive",
		"max_level": 5,
		"descriptions": ["이동 속도가 30 증가합니다."]
	}
}

var player_inventory = {}

# --- 4. 라이프사이클 함수 ---
func _ready() -> void:
	add_to_group("ui")
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if restart_button:
		restart_button.pressed.connect(_on_restart_button_pressed)

func _process(delta: float) -> void:
	if game_ended: return
	
	time_elapsed += delta
	var minutes: int = int(time_elapsed) / 60
	var seconds: int = int(time_elapsed) % 60
	time_label.text = "%02d:%02d" % [minutes, seconds]
	
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
	var available_items = []
	for item_id in item_db.keys():
		var current_lvl = player_inventory.get(item_id, 0)
		if current_lvl < item_db[item_id]["max_level"]:
			available_items.append(item_id)
	
	if available_items.size() == 0:
		get_tree().paused = false
		return
		
	available_items.shuffle()
	var selected_options = []
	for i in range(min(3, available_items.size())):
		selected_options.append(available_items[i])
		
	setup_option_button(option1, selected_options, 0)
	setup_option_button(option2, selected_options, 1)
	setup_option_button(option3, selected_options, 2)
	
	level_up_menu.visible = true
	get_tree().paused = true

func setup_option_button(button: Button, options: Array, index: int) -> void:
	if index >= options.size():
		button.visible = false
		return
		
	button.visible = true
	var item_id = options[index]
	var item_info = item_db[item_id]
	var next_level = player_inventory.get(item_id, 0) + 1
	
	# [개선] 하드코딩 제거: DB의 descriptions 배열에서 인덱스에 맞게 가져옴 (방어 코드 포함)
	var desc_array: Array = item_info.get("descriptions", ["효과가 강화됩니다."])
	var description = desc_array[min(next_level - 1, desc_array.size() - 1)]
		
	button.text = "[%s Lv.%d]\n%s" % [item_info["name"], next_level, description]
	
	if button.pressed.is_connected(_on_item_selected):
		button.pressed.disconnect(_on_item_selected)
	button.pressed.connect(_on_item_selected.bind(item_id))

func _on_item_selected(item_id: String) -> void:
	if player_ref == null: return # 게터를 통해 안전하게 검사됨
	
	player_inventory[item_id] = player_inventory.get(item_id, 0) + 1
	var current_lvl = player_inventory[item_id]
	
	match item_id:
		WP_BLADE:
			if current_lvl == 1:
				if blade_scene != null:
					var new_blade = blade_scene.instantiate()
					new_blade.name = "BladeManager" 
					player_ref.add_child(new_blade)
			else:
				var blade_mgr = player_ref.get_node_or_null("BladeManager")
				if blade_mgr:
					blade_mgr.rotation_speed += 1.5
					
		WP_GUN:
			var gun_timer = player_ref.get_node_or_null("WeaponTimer")
			if gun_timer:
				gun_timer.wait_time = max(0.15, gun_timer.wait_time - 0.15)
				
		PS_HP:
			player_ref.max_health += 20
			player_ref.current_health += 20
			update_hp(player_ref.current_health, player_ref.max_health)
			
		PS_SPEED:
			player_ref.speed += 30.0

	# [개선] 진화 조건 체크 (중복 방지 플래그 추가)
	if not is_blade_evolved and player_inventory.get(WP_BLADE, 0) == 5 and player_inventory.get(PS_HP, 0) == 5:
		is_blade_evolved = true
		trigger_evolution()

	level_up_menu.visible = false
	get_tree().paused = false

func trigger_evolution() -> void:
	print("🔥 [조합 성공] 피의 칼날 폭풍으로 무기가 진화합니다! 🔥")

# --- 7. 게임 종료 및 리스타트 로직 ---
func end_game(is_win: bool) -> void:
	game_ended = true
	get_tree().paused = true
	
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
	get_tree().paused = false
	get_tree().reload_current_scene()
