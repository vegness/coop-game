# GameManager.gd
# 全局游戏状态管理器（AutoLoad 单例）
# 管理游戏流程、关卡切换、玩家状态等全局逻辑
extends Node

# ============================================================
# 游戏状态枚举
# ============================================================
enum GameState {
	MAIN_MENU,
	LOBBY,
	PLAYING,
	PAUSED,
	LEVEL_COMPLETE,
	GAME_OVER
}

enum GameMode {
	SINGLE_TUTORIAL,  # 单人教程
	MULTI_COOP,       # 多人合作
	MULTI_VS          # 多人对战
}

# ============================================================
# 游戏全局属性
# ============================================================
var current_state: GameState = GameState.MAIN_MENU
var current_mode: GameMode = GameMode.SINGLE_TUTORIAL
var current_level_id: int = 0
var player_count: int = 1
var is_online: bool = false

## 当前对战玩法（BattleTypes.Type；-1=未选择）
var current_battle_type: int = -1

## 混合模式选中的玩法组合（Array[BattleTypes.Type]，由 BattleDirector 读取）
var mixed_battle_types: Array = []

# 单人模式选中的小鸡颜色（多人时由 MultiplayerManager.player_colors 管理）
var selected_color: String = "yellow"

# 单人流程来源标记：选角页 → 选关页（LevelSelect 返回按钮据此决定回选角还是主菜单）
var from_character_select: bool = false

# 关卡解锁状态（0=未解锁, 1=已通关）
var level_unlock_state: Dictionary = {}

# 玩家数据
var players: Array = []  # Array[PlayerData]


# ============================================================
# 生命周期
# ============================================================
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_initialize_unlock_state()
	# MultiplayerManager 在 autoload 顺序上晚于本节点，需等全部 autoload 就绪后再绑定断线信号
	_connect_net_signals.call_deferred()


func _connect_net_signals() -> void:
	if not MultiplayerManager.server_disconnected.is_connected(_on_server_lost):
		MultiplayerManager.server_disconnected.connect(_on_server_lost)
	if not MultiplayerManager.player_disconnected.is_connected(_on_peer_lost):
		MultiplayerManager.player_disconnected.connect(_on_peer_lost)


# ============================================================
# 游戏流程控制
# ============================================================
func start_single_player() -> void:
	current_mode = GameMode.SINGLE_TUTORIAL
	player_count = 1
	is_online = false
	_switch_state(GameState.PLAYING)
	_load_level(1)


func start_multiplayer() -> void:
	current_mode = GameMode.MULTI_COOP
	is_online = true
	_switch_state(GameState.LOBBY)
	# 由 Lobby 界面处理具体联机逻辑


# ============================================================
# 多人模式选择界面流转（ModeSelect / BattleModeSelect / Lobby）
# 说明：进入这些界面时网络保持连接；断开统一走 return_to_main_menu
# ============================================================

## 进入多人模式选择（多人闯关 / 多人对战）
func start_mode_select() -> void:
	_switch_state(GameState.LOBBY)
	get_tree().change_scene_to_file("res://ui/ModeSelect/ModeSelect.tscn")


## 进入对战玩法选择（BattleModeSelect）
func start_battle_mode_select() -> void:
	_switch_state(GameState.LOBBY)
	get_tree().change_scene_to_file("res://ui/BattleModeSelect/BattleModeSelect.tscn")


## 返回联机大厅（保持连接）
func goto_lobby() -> void:
	_switch_state(GameState.LOBBY)
	get_tree().change_scene_to_file("res://ui/Lobby/Lobby.tscn")


## 进入对战玩法场景（场景由关卡作者创建于 battle/<type>/<type>.tscn）
## 场景缺失时回玩法选择并告警（不中断联机）
func start_battle(battle_type: int) -> void:
	current_mode = GameMode.MULTI_VS
	current_battle_type = battle_type
	var path: String = BattleTypes.get_scene_path(battle_type)
	if path.is_empty() or not ResourceLoader.exists(path):
		push_warning("[GameManager] 对战玩法「%s」场景未创建：%s（请将关卡放入该路径）" \
			% [BattleTypes.get_type_name(battle_type), path])
		start_battle_mode_select()
		return
	_switch_state(GameState.PLAYING)
	get_tree().change_scene_to_file(path)


# 进入角色选择页（单人：主菜单直进；多人：Lobby 主机广播后各端进入）
func start_character_select() -> void:
	_switch_state(GameState.PLAYING)
	get_tree().change_scene_to_file("res://ui/character_select/CharacterSelect.tscn")


# 单人流程：角色选择 → 关卡选择（选完关再进关卡）
func start_level_select() -> void:
	_switch_state(GameState.PLAYING)
	get_tree().change_scene_to_file("res://ui/LevelSelect/LevelSelect.tscn")


func start_level(level_id: int) -> void:
	current_level_id = level_id
	_switch_state(GameState.PLAYING)
	_load_level(level_id)


func complete_level() -> void:
	_unlock_level(current_level_id)
	_switch_state(GameState.LEVEL_COMPLETE)
	EventBus.level_completed.emit(current_level_id)


func next_level() -> void:
	current_level_id += 1
	if current_level_id > 8:
		_switch_state(GameState.GAME_OVER)
		return
	_load_level(current_level_id)


func restart_level() -> void:
	# 重开前先恢复时间流速与状态，否则新关卡仍停留在暂停
	get_tree().paused = false
	_switch_state(GameState.PLAYING)
	_load_level(current_level_id)


func return_to_main_menu() -> void:
	# 回主菜单前先恢复时间流速，否则新场景无法交互
	get_tree().paused = false
	# 联机状态下统一断开网络（幂等：重复调用安全）。
	# 覆盖三条路径：① 客机断线强制回主菜单 ② 暂停菜单"主菜单"按钮 ③ 选角页返回
	if is_online:
		leave_network()
	# 重置联机状态（防止"多人→主菜单→单人"时选角页残留多人模式）
	is_online = false
	_switch_state(GameState.MAIN_MENU)
	get_tree().change_scene_to_file("res://ui/MainMenu/MainMenu.tscn")


func pause_game() -> void:
	if current_state == GameState.PLAYING:
		_switch_state(GameState.PAUSED)
		get_tree().paused = true
		EventBus.game_paused.emit()


func resume_game() -> void:
	if current_state == GameState.PAUSED:
		_switch_state(GameState.PLAYING)
		get_tree().paused = false
		EventBus.game_resumed.emit()


# ============================================================
# 关卡管理
# ============================================================
func _load_level(level_id: int) -> void:
	# 新约定：res://levels/%02d/level_%02d.tscn；老约定（res://levels/Level_%02d/Level_%02d.tscn）兜底兼容
	var new_path: String = "res://levels/%02d/level_%02d.tscn" % [level_id, level_id]
	var old_path: String = "res://levels/Level_%02d/Level_%02d.tscn" % [level_id, level_id]
	if ResourceLoader.exists(new_path):
		get_tree().change_scene_to_file(new_path)
	elif ResourceLoader.exists(old_path):
		get_tree().change_scene_to_file(old_path)
	else:
		push_error("[GameManager] 关卡 %d 不存在（新路径 %s / 旧路径 %s）" % [level_id, new_path, old_path])


func _unlock_level(level_id: int) -> void:
	level_unlock_state[level_id] = 1
	save_progress()


# ============================================================
# 存档系统
# ============================================================
func _initialize_unlock_state() -> void:
	for i in range(1, 9):
		level_unlock_state[i] = 0
	level_unlock_state[1] = 1  # 第一章默认解锁
	load_progress()


func save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "unlock_state", level_unlock_state)
	config.save("user://save_data.cfg")


func load_progress() -> void:
	var config := ConfigFile.new()
	var err := config.load("user://save_data.cfg")
	if err == OK:
		for i in range(1, 9):
			level_unlock_state[i] = config.get_value("progress", "unlock_state", {}).get(i, 0)


func is_level_unlocked(level_id: int) -> bool:
	return level_unlock_state.get(level_id, 0) == 1


# ============================================================
# 内部辅助
# ============================================================
func _switch_state(new_state: GameState) -> void:
	var old_state := current_state
	current_state = new_state
	EventBus.game_state_changed.emit(old_state, new_state)


# ============================================================
# 联机断线处理
# 客机视角：主机退出 → 全屏"主机连接已丢失"遮罩 → 强制回主菜单
# 主机视角：客机退出 → 顶部 toast 提示（游戏继续）
# 挂在 GameManager（autoload 全场景存活）：关卡/选角/选关任一界面都能响应
# ============================================================

## 客机：与主机断开（ENet 客户端被动检测到服务器断开）
func _on_server_lost() -> void:
	if not is_online:
		return
	# 主动退出（返回按钮/回主菜单）会短暂置 _leaving_room：
	# 若引擎在断开后补发 server_disconnected，此时直接忽略，避免误弹"主机丢失"遮罩
	if _leaving_room:
		return
	_show_disconnect_overlay("主机连接已丢失")
	_leave_timer = get_tree().create_timer(1.8)
	_leave_timer.timeout.connect(_force_leave_after_disconnect)


## 主动离开房间：断开网络但抑制"主机丢失"处理（标志延迟 1s 清除，覆盖引擎补发信号的窗口）
var _leaving_room: bool = false

func leave_network() -> void:
	_leaving_room = true
	MultiplayerManager.disconnect_network()
	get_tree().create_timer(1.0).timeout.connect(func() -> void: _leaving_room = false)


func _force_leave_after_disconnect() -> void:
	if not is_online:
		return
	_hide_disconnect_overlay()
	return_to_main_menu()


## 主机：某个玩家断开
func _on_peer_lost(peer_id: int) -> void:
	if not is_online or not MultiplayerManager.is_server():
		return
	# 关卡内：清理该玩家的小鸡副本（避免死小鸡留在场上）
	var scene := get_tree().current_scene
	if scene is LevelBase:
		for ch in scene.players:
			if ch.player_id == peer_id:
				scene.players.erase(ch)
				ch.queue_free()
				break
	_show_toast("玩家 %d 连接已丢失" % peer_id)


# ============================================================
# 断线 UI（动态创建，挂在 root 下不随 change_scene 释放）
# ============================================================
var _disconnect_overlay: CanvasLayer = null
var _leave_timer: SceneTreeTimer = null

func _show_disconnect_overlay(text: String) -> void:
	if _disconnect_overlay == null:
		_disconnect_overlay = CanvasLayer.new()
		_disconnect_overlay.layer = 100
		get_tree().root.add_child(_disconnect_overlay)
		var panel := ColorRect.new()
		panel.color = Color(0, 0, 0, 0.6)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		_disconnect_overlay.add_child(panel)
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.add_theme_font_size_override("font_size", 28)
		label.add_theme_color_override("font_color", Color8(255, 255, 255))
		label.add_theme_color_override("font_outline_color", Color8(40, 24, 16))
		label.add_theme_constant_override("outline_size", 6)
		var font_zh := load("res://res/fonts/fusion-pixel-12px-proportional-zh_hans.ttf") as FontFile
		if font_zh:
			label.add_theme_font_override("font", font_zh)
		_disconnect_overlay.add_child(label)
		_disconnect_overlay.set_meta("label", label)
	else:
		_disconnect_overlay.show()
		(_disconnect_overlay.get_meta("label") as Label).text = text


func _hide_disconnect_overlay() -> void:
	if _disconnect_overlay:
		_disconnect_overlay.hide()


# ============================================================
# 顶部 toast（短提示，2.5s 自动淡出）
# ============================================================
var _toast_label: Label = null
var _toast_tween: Tween = null

func _show_toast(text: String) -> void:
	if _toast_label == null:
		var layer := CanvasLayer.new()
		layer.layer = 90
		get_tree().root.add_child(layer)
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = Vector2(0, 60)
		label.size = Vector2(1280, 40)
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", Color8(255, 120, 90))
		label.add_theme_color_override("font_outline_color", Color8(40, 24, 16))
		label.add_theme_constant_override("outline_size", 4)
		var font_zh := load("res://res/fonts/fusion-pixel-12px-proportional-zh_hans.ttf") as FontFile
		if font_zh:
			label.add_theme_font_override("font", font_zh)
		layer.add_child(label)
		_toast_label = label
	_toast_label.text = text
	_toast_label.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.5)
