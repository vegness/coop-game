# CharacterSelect.gd
# 角色选择页（单人 + 多人）
# 单人：1 个槽位，←→ 切换 6 种颜色，点开始直接进关卡
# 多人：按房间人数动态生成槽位，RPC 同步颜色/准备，全部就绪后主机开始
# 温暖木质玩具风（与主菜单/Lobby 一致）
extends Control

# ============================================================
# 配色
# ============================================================
const OUT := Color8(92, 61, 46)                 # 深棕描边
const C_ORANGE := Color8(255, 140, 66)          # 亮橙
const C_BEIGE := Color8(245, 230, 211)          # 暖米
const C_PEACH_HOVER := Color8(255, 184, 140)    # 桃色悬停
const C_GRAY := Color8(217, 207, 193)           # 禁用灰米

const SLOT_SCENE: PackedScene = preload("res://ui/character_select/PlayerSlot.tscn")

# ============================================================
# UI 引用
# ============================================================
@onready var title_label: Label = $Center/VBox/TitleLabel
@onready var hint_label: Label = $Center/VBox/HintLabel
@onready var slots_row: HBoxContainer = $Center/VBox/SlotsRow
@onready var back_btn: Button = $Center/VBox/BottomRow/BackBtn
@onready var start_btn: Button = $Center/VBox/BottomRow/StartBtn

# ============================================================
# 状态
# ============================================================
var is_multiplayer: bool = false
var my_peer_id: int = 1
var slots: Dictionary = {}  # peer_id -> PlayerSlot
var blink_tween: Tween


# ============================================================
# 生命周期
# ============================================================
func _ready() -> void:
	is_multiplayer = GameManager.is_online
	_load_fonts()
	_setup_ui()
	if is_multiplayer:
		_setup_multiplayer()
	else:
		_setup_single()


func _unhandled_input(event: InputEvent) -> void:
	# 键盘操作：A/D 切换自己槽位的颜色；空格 = 单人开始 / 多人准备（切换）
	var my_slot: PlayerSlot = slots.get(my_peer_id) if slots.has(my_peer_id) else null
	if my_slot == null:
		return
	if event.is_action_pressed("move_left"):
		my_slot.cycle_color(-1)
		_mark_handled()
	elif event.is_action_pressed("move_right"):
		my_slot.cycle_color(1)
		_mark_handled()
	elif event.is_action_pressed("ui_accept"):
		if is_multiplayer:
			my_slot.toggle_ready()
		else:
			_on_start_pressed()
		_mark_handled()


func _mark_handled() -> void:
	var vp := get_viewport()
	if vp:
		vp.set_input_as_handled()


func _setup_ui() -> void:
	$Background.color = Color8(255, 254, 245)  # 奶油白底
	title_label.add_theme_color_override("font_color", C_ORANGE)
	title_label.add_theme_color_override("font_outline_color", OUT)
	title_label.add_theme_constant_override("outline_size", 5)
	hint_label.add_theme_color_override("font_color", OUT)
	_apply_button_style(back_btn)
	_apply_button_style(start_btn)
	back_btn.pressed.connect(_on_back_pressed)
	start_btn.pressed.connect(_on_start_pressed)


# ============================================================
# 单人模式
# ============================================================
func _setup_single() -> void:
	my_peer_id = 1
	MultiplayerManager.player_colors = {}
	title_label.text = "选择你的小鸡"
	hint_label.text = "A / D 切换颜色 · 空格确认"
	var slot := _add_slot(my_peer_id, true, false)
	slot.set_single_mode()
	start_btn.text = "选择关卡"
	start_btn.disabled = false


# ============================================================
# 多人模式
# ============================================================
func _setup_multiplayer() -> void:
	my_peer_id = MultiplayerManager.get_my_id()
	title_label.text = "选择你的小鸡"
	hint_label.text = "A / D 切换颜色 · 空格准备 · 全部就绪后主机开始"
	start_btn.visible = MultiplayerManager.is_server()

	# 自己 + 已连接 peers
	_add_slot(my_peer_id, true, MultiplayerManager.is_server())
	for pid in MultiplayerManager.get_peers():
		if not slots.has(pid):
			_add_slot(pid, false, MultiplayerManager.is_host_peer(pid))

	MultiplayerManager.player_connected.connect(_on_player_connected)
	MultiplayerManager.player_disconnected.connect(_on_player_disconnected)
	_check_all_ready()


func _add_slot(p_peer_id: int, p_local: bool, p_host: bool) -> PlayerSlot:
	var slot: PlayerSlot = SLOT_SCENE.instantiate()
	slots_row.add_child(slot)  # 先入树（触发 _ready / @onready），再 setup
	slot.setup(p_peer_id, p_local, p_host, _get_default_color(p_peer_id))
	slots[p_peer_id] = slot
	slot.color_changed.connect(_on_slot_color_changed)
	slot.ready_toggled.connect(_on_slot_ready_toggled)
	slot.play_enter_anim()
	return slot


func _get_default_color(pid: int) -> String:
	# 自己：沿用上次选择（单人时的 selected_color）；他人默认 yellow
	if pid == my_peer_id:
		return GameManager.selected_color if GameManager.selected_color in PlayerSlot.COLORS else "yellow"
	return "yellow"


# ============================================================
# 槽位信号 → RPC 广播
# ============================================================
func _on_slot_color_changed(p_peer_id: int, color: String) -> void:
	if is_multiplayer:
		_sync_player_color.rpc(p_peer_id, color)


func _on_slot_ready_toggled(p_peer_id: int, r: bool) -> void:
	if is_multiplayer:
		_sync_player_ready.rpc(p_peer_id, r)


# ============================================================
# RPC 同步（any_peer + call_local：本机也立即生效）
# ============================================================
@rpc("any_peer", "call_local", "reliable")
func _sync_player_color(p_peer_id: int, color: String) -> void:
	if slots.has(p_peer_id):
		slots[p_peer_id].set_color(color)


@rpc("any_peer", "call_local", "reliable")
func _sync_player_ready(p_peer_id: int, r: bool) -> void:
	if slots.has(p_peer_id):
		slots[p_peer_id].set_ready(r)
	_check_all_ready()


# 多人：主机广播进入关卡选择界面（各端各自加载 LevelSelect 场景）。
# 关卡选择界面选关后再广播进关卡。
# 不能用 @rpc("authority")：场景节点默认 authority=1，Steam 下主机 unique_id 是
# Steam ID 映射值 ≠ 1，authority 型 RPC 会被拒绝；any_peer 才后端无关。
@rpc("any_peer", "call_local", "reliable")
func _goto_level_select(color_dict: Dictionary) -> void:
	MultiplayerManager.player_colors = color_dict
	GameManager.start_level_select()


# ============================================================
# 主机：全部就绪检查
# ============================================================
func _check_all_ready() -> void:
	if not MultiplayerManager.is_server():
		return
	if slots.is_empty():
		return

	var all_ready: bool = true
	if slots.size() > 1:
		for pid in slots:
			if not slots[pid].is_ready:
				all_ready = false
				break

	start_btn.disabled = not all_ready
	start_btn.text = "开始游戏" if all_ready else "等待就绪..."
	# 就绪时闪烁提示
	if blink_tween:
		blink_tween.kill()
		blink_tween = null
	if all_ready:
		blink_tween = create_tween().set_loops()
		blink_tween.tween_property(start_btn, "modulate:a", 0.6, 0.35)
		blink_tween.tween_property(start_btn, "modulate:a", 1.0, 0.35)
	else:
		start_btn.modulate.a = 1.0


# ============================================================
# 开始 / 返回
# ============================================================
func _on_start_pressed() -> void:
	if is_multiplayer:
		# 仅主机可发起
		if not MultiplayerManager.is_server():
			return
		var color_dict: Dictionary = {}
		for pid in slots:
			color_dict[pid] = slots[pid].get_color()
		_goto_level_select.rpc(color_dict)
	else:
		# 单人：记录颜色 → 进入关卡选择界面（选完关再进关卡）
		var color: String = slots.get(1).get_color() if slots.has(1) else "yellow"
		MultiplayerManager.player_colors = {1: color}
		GameManager.selected_color = color
		GameManager.from_character_select = true
		GameManager.start_level_select()


func _on_back_pressed() -> void:
	# 多人：回模式选择（网络保持连接）；单人：回主菜单
	if GameManager.is_online:
		GameManager.start_mode_select()
	else:
		GameManager.return_to_main_menu()


# ============================================================
# 网络事件（多人）
# ============================================================
func _on_player_connected(pid: int) -> void:
	if not slots.has(pid):
		_add_slot(pid, false, MultiplayerManager.is_host_peer(pid))
	_check_all_ready()


func _on_player_disconnected(pid: int) -> void:
	if slots.has(pid):
		slots[pid].queue_free()
		slots.erase(pid)
		_check_all_ready()


# ============================================================
# 字体 & 按钮样式（与主菜单一致）
# ============================================================
func _load_fonts() -> void:
	var font_zh := load("res://res/fonts/fusion-pixel-12px-proportional-zh_hans.ttf") as FontFile
	var font_en := load("res://res/fonts/PressStart2P-Regular.ttf") as FontFile
	if font_en:
		title_label.add_theme_font_override("font", font_en)
	title_label.add_theme_font_size_override("font_size", 30)
	if font_zh:
		hint_label.add_theme_font_override("font", font_zh)
		back_btn.add_theme_font_override("font", font_zh)
		start_btn.add_theme_font_override("font", font_zh)
	hint_label.add_theme_font_size_override("font_size", 16)
	back_btn.add_theme_font_size_override("font_size", 18)
	start_btn.add_theme_font_size_override("font_size", 18)


func _apply_button_style(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _make_stylebox(C_BEIGE, OUT))
	btn.add_theme_stylebox_override("hover", _make_stylebox(C_PEACH_HOVER, OUT))
	btn.add_theme_stylebox_override("pressed", _make_stylebox(C_ORANGE, OUT))
	btn.add_theme_stylebox_override("disabled", _make_stylebox(C_GRAY, Color8(160, 148, 130)))
	btn.add_theme_color_override("font_color", OUT)
	btn.add_theme_color_override("font_hover_color", OUT)
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_disabled_color", Color8(150, 138, 120))


func _make_stylebox(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	return sb
