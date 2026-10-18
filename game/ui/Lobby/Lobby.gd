# Lobby.gd
# 多人联机大厅 - 只负责联机连接阶段
# 功能：创建房间 / IP 加入 / 玩家列表 / 返回主菜单
# 连接成功后：主机点击"进入模式选择"，各端经 RPC 同步进入 ModeSelect
extends Control

# ============================================================
# 配色（与主菜单一致的温暖木质玩具风）
# ============================================================
const OUT := Color8(92, 61, 46)                 # #5C3D2E 深棕
const C_ORANGE := Color8(255, 140, 66)          # #FF8C42 亮橙
const C_BEIGE := Color8(245, 230, 211)          # #F5E6D3 暖米
const C_PEACH_HOVER := Color8(255, 184, 140)    # #FFB88C 桃色悬停
const C_GRAY := Color8(217, 207, 193)           # 禁用灰米

# ============================================================
# UI 引用
# ============================================================
@onready var lobby_title: Label = $VBoxContainer/LobbyTitle
@onready var status_label: Label = $VBoxContainer/RoomPanel/RoomVBox/StatusLabel
@onready var ip_input: LineEdit = $VBoxContainer/RoomPanel/RoomVBox/IPRow/IPInput
@onready var create_btn: Button = $VBoxContainer/RoomPanel/RoomVBox/BtnRow/CreateBtn
@onready var join_btn: Button = $VBoxContainer/RoomPanel/RoomVBox/BtnRow/JoinBtn
@onready var player_list: VBoxContainer = $VBoxContainer/PlayerList
@onready var enter_mode_btn: Button = $VBoxContainer/EnterModeBtn
@onready var hint_label: Label = $VBoxContainer/HintLabel
@onready var back_btn: Button = $VBoxContainer/BackBtn

# ============================================================
# 数据
# ============================================================
## 网络后端选择：false=ENet（开发期本地/局域网测试）；true=Steam（正式环境）
@export var use_steam: bool = false

var font_zh: FontFile


# ============================================================
# 生命周期
# ============================================================
func _ready() -> void:
	GameManager._switch_state(GameManager.GameState.LOBBY)
	GameManager.is_online = true

	# 仅在首次进入时初始化网络后端；从模式选择返回时连接仍在，禁止重置
	# （否则新 backend 无 peer，is_network_connected() 恒 false，UI 会误判未连接）
	if MultiplayerManager.backend == null:
		MultiplayerManager.set_network_backend(SteamBackend.new() if use_steam else ENetBackend.new())

	# 连接网络事件（防重复 connect：从模式选择返回会再次 _ready）
	_connect_net_signals()

	_load_fonts()
	_connect_buttons()
	_refresh_ui()


func _connect_net_signals() -> void:
	if not MultiplayerManager.player_connected.is_connected(_on_player_connected):
		MultiplayerManager.player_connected.connect(_on_player_connected)
	if not MultiplayerManager.player_disconnected.is_connected(_on_player_disconnected):
		MultiplayerManager.player_disconnected.connect(_on_player_disconnected)
	if not MultiplayerManager.server_disconnected.is_connected(_on_server_disconnected):
		MultiplayerManager.server_disconnected.connect(_on_server_disconnected)


func _load_fonts() -> void:
	font_zh = load("res://res/fonts/fusion-pixel-12px-proportional-zh_hans.ttf") as FontFile
	if font_zh:
		lobby_title.add_theme_font_override("font", font_zh)
		status_label.add_theme_font_override("font", font_zh)
		hint_label.add_theme_font_override("font", font_zh)
	lobby_title.add_theme_font_size_override("font_size", 24)
	lobby_title.add_theme_color_override("font_color", C_ORANGE)
	lobby_title.add_theme_color_override("font_outline_color", OUT)
	lobby_title.add_theme_constant_override("outline_size", 4)
	status_label.add_theme_color_override("font_color", OUT)


func _connect_buttons() -> void:
	create_btn.pressed.connect(_on_create_room)
	join_btn.pressed.connect(_on_join_room)
	enter_mode_btn.pressed.connect(_on_enter_mode_select)
	back_btn.pressed.connect(_on_back)
	_apply_button_style(create_btn)
	_apply_button_style(join_btn)
	_apply_button_style(enter_mode_btn)
	_apply_button_style(back_btn)


func _apply_button_style(btn: Button) -> void:
	if font_zh:
		btn.add_theme_font_override("font", font_zh)
	btn.add_theme_font_size_override("font_size", 15)
	btn.add_theme_stylebox_override("normal", _make_stylebox(C_BEIGE, OUT, 3))
	btn.add_theme_stylebox_override("hover", _make_stylebox(C_PEACH_HOVER, OUT, 3))
	btn.add_theme_stylebox_override("pressed", _make_stylebox(C_ORANGE, OUT, 3))
	btn.add_theme_stylebox_override("disabled", _make_stylebox(C_GRAY, Color8(160, 148, 130), 3))
	btn.add_theme_color_override("font_color", OUT)
	btn.add_theme_color_override("font_disabled_color", Color8(150, 138, 120))


func _make_stylebox(bg: Color, border: Color, border_w: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = border_w
	sb.border_width_right = border_w
	sb.border_width_top = border_w
	sb.border_width_bottom = border_w
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	return sb


# ============================================================
# 房间操作（新架构：MultiplayerManager）
# ============================================================
func _on_create_room() -> void:
	var err := MultiplayerManager.create_room(4)
	if err == OK:
		status_label.text = "房间已创建，你是主机"
		_refresh_ui()
	else:
		status_label.text = "创建房间失败（错误码 %d）" % err


func _on_join_room() -> void:
	var ip := ip_input.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"
	var err := MultiplayerManager.join_room(ip)
	if err == OK:
		status_label.text = "正在连接 %s ..." % ip
	else:
		status_label.text = "连接失败（错误码 %d）" % err


# ============================================================
# 进入模式选择（主机权威，RPC 广播各端同步切换）
# ============================================================
@rpc("any_peer", "call_local", "reliable")
func _goto_mode_select() -> void:
	GameManager.start_mode_select()


func _on_enter_mode_select() -> void:
	if not MultiplayerManager.is_server():
		return
	_goto_mode_select.rpc()


# ============================================================
# 网络事件
# ============================================================
func _on_player_connected(peer_id: int) -> void:
	status_label.text = "玩家 %d 加入房间" % peer_id
	_refresh_ui()


func _on_player_disconnected(peer_id: int) -> void:
	status_label.text = "玩家 %d 离开房间" % peer_id
	_refresh_ui()


func _on_server_disconnected() -> void:
	status_label.text = "与主机断开连接"
	_refresh_ui()


# ============================================================
# UI 刷新
# ============================================================
func _refresh_ui() -> void:
	var is_server: bool = MultiplayerManager.is_server()
	var connected: bool = MultiplayerManager.is_network_connected()

	create_btn.disabled = connected
	join_btn.disabled = connected
	# 进入模式选择：仅主机且已连接可用
	enter_mode_btn.disabled = not (connected and is_server)

	if not connected:
		status_label.text = "未连接"
	_update_player_list()


func _update_player_list() -> void:
	for child in player_list.get_children():
		child.queue_free()

	var my_id := MultiplayerManager.get_my_id()
	if my_id > 0:
		var me := Label.new()
		me.text = "玩家 %d（我）" % my_id
		if font_zh:
			me.add_theme_font_override("font", font_zh)
		me.add_theme_color_override("font_color", C_ORANGE)
		player_list.add_child(me)

	for peer_id in MultiplayerManager.get_peers():
		var p := Label.new()
		p.text = "玩家 %d" % peer_id
		if font_zh:
			p.add_theme_font_override("font", font_zh)
		p.add_theme_color_override("font_color", OUT)
		player_list.add_child(p)


# ============================================================
# 返回主菜单（断开网络）
# ============================================================
func _on_back() -> void:
	MultiplayerManager.disconnect_network()
	GameManager.return_to_main_menu()
