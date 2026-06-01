extends CanvasLayer

@export var item_resources: Array[ItemDataResource]

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
var unlocked_evolutions = {}

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

var item_db = {}

var evolution_db = {

	"blood_blade": {

		"name": "피의 칼날 폭풍",

		"requirements": {
			WP_BLADE: 5,
			PS_HP: 5
		}
	}
}

var player_inventory = {}

# --- 4. 라이프사이클 함수 ---
func _ready() -> void:

	add_to_group("ui")
	process_mode = Node.PROCESS_MODE_ALWAYS

	for item in item_resources:
		item_db[item.item_id] = item

	print(item_db.keys())

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
		if current_lvl < item_db[item_id].max_level:
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
	var item_info: ItemDataResource = item_db[item_id]

	var next_level = player_inventory.get(item_id, 0) + 1

	var desc_array = item_info.descriptions

	if desc_array.is_empty():
		desc_array = ["효과가 강화됩니다."]

	var description = desc_array[
		min(next_level - 1, desc_array.size() - 1)
	]

	button.text = "[%s Lv.%d]\n%s" % [
		item_info.display_name,
		next_level,
		description
	]

	if button.pressed.is_connected(_on_item_selected):
		button.pressed.disconnect(_on_item_selected)

	button.pressed.connect(
		_on_item_selected.bind(item_id)
	)

func _check_evolutions() -> void:

	for evo_id in evolution_db.keys():

		if unlocked_evolutions.has(evo_id):
			continue

		var evo_data = evolution_db[evo_id]
		var requirements = evo_data["requirements"]

		var can_evolve = true

		for item_id in requirements.keys():

			var required_level = requirements[item_id]

			if player_inventory.get(item_id, 0) < required_level:

				can_evolve = false
				break

		if can_evolve:

			unlocked_evolutions[evo_id] = true
			trigger_evolution(evo_id)
			
func _on_item_selected(item_id: String) -> void:
	if player_ref == null: return # 게터를 통해 안전하게 검사됨
	
	player_inventory[item_id] = player_inventory.get(item_id, 0) + 1
	var current_lvl = player_inventory[item_id]
	
	print("선택된 아이템:", item_id)

	var item_info: ItemDataResource = item_db[item_id]

	print("item_info:", item_info)
	print("effect_resource:", item_info.effect_resource)
	if item_info.effect_resource:
		item_info.effect_resource.apply(
			player_ref,
			self,
			current_lvl
		)
	# [개선] 진화 조건 체크 (중복 방지 플래그 추가)
	_check_evolutions()
	level_up_menu.visible = false
	get_tree().paused = false

func trigger_evolution(evo_id: String) -> void:

	match evo_id:

		"blood_blade":

			print("🔥 피의 칼날 폭풍 진화! 🔥")
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
