# HUD.gd
# 游戏内 HUD
# 显示：关卡信息、目标进度、计时器、暂停按钮
extends CanvasLayer

# ============================================================
# UI 引用
# ============================================================
@onready var level_label: Label = $MarginContainer/HBoxContainer/LeftPanel/LevelLabel
@onready var goal_progress_label: Label = $MarginContainer/HBoxContainer/LeftPanel/GoalProgress
@onready var timer_label: Label = $MarginContainer/HBoxContainer/RightPanel/TimerLabel
@onready var pause_btn: Button = $MarginContainer/HBoxContainer/RightPanel/PauseBtn
@onready var pause_menu: Control = $PauseMenu
@onready var resume_btn: Button = $PauseMenu/PauseVBox/ResumeBtn
@onready var restart_btn: Button = $PauseMenu/PauseVBox/RestartBtn
@onready var menu_btn: Button = $PauseMenu/PauseVBox/MenuBtn


# ============================================================
# 生命周期
# ============================================================
func _ready() -> void:
	# 关键：暂停后场景树停止处理输入，暂停菜单必须标记为"暂停时仍可交互"，
	# 否则"继续游戏"等按钮点击无响应
	pause_menu.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	pause_menu.hide()
	pause_btn.pressed.connect(_on_pause)
	resume_btn.pressed.connect(_on_resume)
	restart_btn.pressed.connect(_on_restart)
	menu_btn.pressed.connect(_on_menu)
	EventBus.level_loaded.connect(_on_level_loaded)
	EventBus.level_completed.connect(_on_level_complete)
	EventBus.game_paused.connect(_on_game_paused)
	EventBus.game_resumed.connect(_on_game_resumed)


func _process(_delta: float) -> void:
	if GameManager.current_state == GameManager.GameState.PLAYING:
		_update_timer()


# ============================================================
# 更新
# ============================================================
func _on_level_loaded(level_id: int) -> void:
	level_label.text = "关卡 %d" % level_id


func _update_timer() -> void:
	var level := _get_current_level()
	if level and level.time_limit > 0:
		var remaining: float = maxf(0.0, level.time_limit - level.elapsed_time)
		var minutes := int(remaining / 60)
		var seconds := int(int(remaining) % 60)
		timer_label.text = "%02d:%02d" % [minutes, seconds]
		if remaining < 10:
			timer_label.modulate = Color.RED
	else:
		timer_label.text = ""


func _on_level_complete(_level_id: int) -> void:
	timer_label.text = "完成!"


# ============================================================
# 暂停
# ============================================================
func _on_pause() -> void:
	GameManager.pause_game()


func _on_resume() -> void:
	GameManager.resume_game()


func _on_restart() -> void:
	GameManager.restart_level()


func _on_menu() -> void:
	GameManager.return_to_main_menu()


func _on_game_paused() -> void:
	pause_menu.show()


func _on_game_resumed() -> void:
	pause_menu.hide()


func _get_current_level() -> LevelBase:
	var root := get_tree().current_scene
	if root is LevelBase:
		return root
	return null
