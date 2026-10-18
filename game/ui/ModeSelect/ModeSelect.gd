# ModeSelect.gd
# 多人模式选择（联机连接成功后进入）
# 功能：多人闯关（走既有合作链路）/ 多人对战（进玩法选择）/ 返回大厅
# 解耦：场景切换走 GameManager；按钮仅主机可用（主机权威 + RPC 广播各端同步）
extends Control

# ============================================================
# 配色（与主菜单一致）
# ============================================================
const OUT := Color8(92, 61, 46)                 # #5C3D2E 深棕
const C_ORANGE := Color8(255, 140, 66)          # #FF8C42 亮橙
const C_BEIGE := Color8(245, 230, 211)          # #F5E6D3 暖米
const C_PEACH_HOVER := Color8(255, 184, 140)    # #FFB88C 桃色悬停
const C_GRAY := Color8(217, 207, 193)           # 禁用灰米

# ============================================================
# UI 引用
# ============================================================
@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var hint_label: Label = $VBoxContainer/HintLabel
@onready var coop_btn: Button = $VBoxContainer/Panel/ModeVBox/CoopBtn
@onready var vs_btn: Button = $VBoxContainer/Panel/ModeVBox/VsBtn
@onready var back_btn: Button = $VBoxContainer/Panel/ModeVBox/BackBtn

var font_zh: FontFile


func _ready() -> void:
	GameManager._switch_state(GameManager.GameState.LOBBY)
	_load_fonts()
	_connect_buttons()
	_refresh_ui()


func _load_fonts() -> void:
	font_zh = load("res://res/fonts/fusion-pixel-12px-proportional-zh_hans.ttf") as FontFile
	if font_zh:
		title_label.add_theme_font_override("font", font_zh)
		hint_label.add_theme_font_override("font", font_zh)
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", C_ORANGE)
	title_label.add_theme_color_override("font_outline_color", OUT)
	title_label.add_theme_constant_override("outline_size", 4)


func _connect_buttons() -> void:
	coop_btn.pressed.connect(_on_coop)
	vs_btn.pressed.connect(_on_vs)
	back_btn.pressed.connect(_on_back)
	_apply_button_style(coop_btn)
	_apply_button_style(vs_btn)
	_apply_button_style(back_btn)


func _apply_button_style(btn: Button) -> void:
	if font_zh:
		btn.add_theme_font_override("font", font_zh)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_stylebox_override("normal", _make_stylebox(C_BEIGE, OUT))
	btn.add_theme_stylebox_override("hover", _make_stylebox(C_PEACH_HOVER, OUT))
	btn.add_theme_stylebox_override("pressed", _make_stylebox(C_ORANGE, OUT))
	btn.add_theme_stylebox_override("disabled", _make_stylebox(C_GRAY, Color8(160, 148, 130)))
	btn.add_theme_color_override("font_color", OUT)
	btn.add_theme_color_override("font_disabled_color", Color8(150, 138, 120))


func _make_stylebox(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = 4
	sb.border_width_right = 4
	sb.border_width_top = 4
	sb.border_width_bottom = 4
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	return sb


# ============================================================
# 模式选择（主机权威，RPC 广播各端同步切换场景）
# ============================================================
@rpc("any_peer", "call_local", "reliable")
func _goto_character_select() -> void:
	GameManager.current_mode = GameManager.GameMode.MULTI_COOP
	GameManager.start_character_select()


@rpc("any_peer", "call_local", "reliable")
func _goto_battle_mode_select() -> void:
	GameManager.start_battle_mode_select()


@rpc("any_peer", "call_local", "reliable")
func _goto_lobby() -> void:
	GameManager.goto_lobby()


func _on_coop() -> void:
	if not MultiplayerManager.is_server():
		return
	_goto_character_select.rpc()


func _on_vs() -> void:
	if not MultiplayerManager.is_server():
		return
	_goto_battle_mode_select.rpc()


func _on_back() -> void:
	if not MultiplayerManager.is_server():
		return
	_goto_lobby.rpc()


# ============================================================
# UI 刷新
# ============================================================
func _refresh_ui() -> void:
	var is_server: bool = MultiplayerManager.is_server()
	coop_btn.disabled = not is_server
	vs_btn.disabled = not is_server
	back_btn.disabled = not is_server
	if is_server:
		hint_label.text = "你是主机，请选择模式（全员同步进入）"
	else:
		hint_label.text = "等待主机选择模式……"
