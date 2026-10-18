# BattleModeSelect.gd
# 对战玩法选择（多人对战入口）—— 轮播式布局
# 上：预览图框（battle/<type>/preview.png，缺失时程序占位色+玩法名）
# 中：选择栏（◀ 一次展示一个玩法 ▶，循环切换；点击玩法名开始）
# 下：混合模式按钮（勾选 ≥2 种玩法）+ 返回模式选择
# 解耦：玩法枚举/路径映射走 BattleTypes；场景切换走 GameManager；开始仅主机（RPC 广播）
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
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var preview_box: PanelContainer = $VBoxContainer/PreviewBox
@onready var preview_image: TextureRect = $VBoxContainer/PreviewBox/PreviewImage
@onready var placeholder: Control = $VBoxContainer/PreviewBox/Placeholder
@onready var placeholder_bg: ColorRect = $VBoxContainer/PreviewBox/Placeholder/PlaceholderBg
@onready var placeholder_name: Label = $VBoxContainer/PreviewBox/Placeholder/PlaceholderName
@onready var placeholder_desc: Label = $VBoxContainer/PreviewBox/Placeholder/PlaceholderDesc
@onready var prev_btn: Button = $VBoxContainer/SelectRow/PrevBtn
@onready var mode_btn: Button = $VBoxContainer/SelectRow/ModeBtn
@onready var next_btn: Button = $VBoxContainer/SelectRow/NextBtn
@onready var mixed_btn: Button = $VBoxContainer/MixedBtn
@onready var back_btn: Button = $VBoxContainer/BackBtn
@onready var mixed_panel: PanelContainer = $MixedPanel
@onready var mixed_check_list: VBoxContainer = $MixedPanel/MixedVBox/MixedCheckList
@onready var mixed_confirm_btn: Button = $MixedPanel/MixedVBox/MixedBtnRow/MixedConfirmBtn
@onready var mixed_cancel_btn: Button = $MixedPanel/MixedVBox/MixedBtnRow/MixedCancelBtn

var font_zh: FontFile

## 轮播玩法列表（不含混合模式）
var _single_types: Array[int] = BattleTypes.get_single_types()
var _current_index: int = 0


# ============================================================
# 生命周期
# ============================================================
func _ready() -> void:
	GameManager._switch_state(GameManager.GameState.LOBBY)
	_load_fonts()
	_connect_buttons()
	_populate_mixed_list()
	_update_preview()
	_refresh_ui()


func _load_fonts() -> void:
	font_zh = load("res://res/fonts/fusion-pixel-12px-proportional-zh_hans.ttf") as FontFile
	if font_zh:
		title_label.add_theme_font_override("font", font_zh)
		hint_label.add_theme_font_override("font", font_zh)
		status_label.add_theme_font_override("font", font_zh)
		placeholder_name.add_theme_font_override("font", font_zh)
		placeholder_desc.add_theme_font_override("font", font_zh)
		mixed_btn.add_theme_font_override("font", font_zh)
		back_btn.add_theme_font_override("font", font_zh)
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_color_override("font_color", C_ORANGE)
	title_label.add_theme_color_override("font_outline_color", OUT)
	title_label.add_theme_constant_override("outline_size", 4)
	status_label.add_theme_color_override("font_color", C_ORANGE)
	placeholder_name.add_theme_color_override("font_color", OUT)
	placeholder_name.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.6))
	placeholder_name.add_theme_constant_override("outline_size", 4)
	placeholder_desc.add_theme_color_override("font_color", OUT)


func _connect_buttons() -> void:
	prev_btn.pressed.connect(_on_prev)
	next_btn.pressed.connect(_on_next)
	mode_btn.pressed.connect(_on_mode_pressed)
	mixed_btn.pressed.connect(_on_mixed_pressed)
	back_btn.pressed.connect(_on_back)
	mixed_confirm_btn.pressed.connect(_on_mixed_confirm)
	mixed_cancel_btn.pressed.connect(_on_mixed_cancel)
	_apply_button_style(prev_btn, 16)
	_apply_button_style(next_btn, 16)
	_apply_button_style(mode_btn, 18)
	_apply_button_style(mixed_btn, 15)
	_apply_button_style(back_btn, 15)
	_apply_button_style(mixed_confirm_btn, 14)
	_apply_button_style(mixed_cancel_btn, 14)


func _apply_button_style(btn: Button, font_size: int) -> void:
	if font_zh:
		btn.add_theme_font_override("font", font_zh)
	btn.add_theme_font_size_override("font_size", font_size)
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
	sb.border_width_left = 3
	sb.border_width_right = 3
	sb.border_width_top = 3
	sb.border_width_bottom = 3
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	return sb


# ============================================================
# 轮播：预览 + 当前玩法
# ============================================================
func _current_type() -> int:
	return _single_types[_current_index]


## 更新预览框与玩法名（有 preview.png 显示图片，否则程序占位）
func _update_preview() -> void:
	var t: int = _current_type()
	mode_btn.text = BattleTypes.get_type_name(t)
	placeholder_bg.color = BattleTypes.get_type_color(t)
	placeholder_name.text = BattleTypes.get_type_name(t)
	placeholder_desc.text = BattleTypes.get_type_desc(t)
	if BattleTypes.has_preview(t):
		preview_image.texture = load(BattleTypes.get_preview_path(t)) as Texture2D
		preview_image.show()
		placeholder.hide()
	else:
		preview_image.hide()
		placeholder.show()
	status_label.text = ""


func _on_prev() -> void:
	# 循环：一直向左可绕回末尾（回到当前模式的下一个）
	_current_index = (_current_index - 1 + _single_types.size()) % _single_types.size()
	_update_preview()


func _on_next() -> void:
	_current_index = (_current_index + 1) % _single_types.size()
	_update_preview()


# ============================================================
# 开始玩法（点击玩法名/预览，主机权威 + RPC 广播）
# ============================================================
@rpc("any_peer", "call_local", "reliable")
func _goto_battle(battle_type: int) -> void:
	GameManager.start_battle(battle_type)


@rpc("any_peer", "call_local", "reliable")
func _goto_mixed(types: Array) -> void:
	GameManager.mixed_battle_types = types
	GameManager.start_battle(BattleTypes.Type.MIXED)


@rpc("any_peer", "call_local", "reliable")
func _goto_mode_select() -> void:
	GameManager.start_mode_select()


func _on_mode_pressed() -> void:
	if not MultiplayerManager.is_server():
		status_label.text = "等待主机选择玩法……"
		return
	var t: int = _current_type()
	if not BattleTypes.has_scene(t):
		var path: String = BattleTypes.get_scene_path(t)
		status_label.text = "「%s」玩法关卡尚未创建（%s/），请先制作关卡" \
			% [BattleTypes.get_type_name(t), path.get_base_dir()]
		return
	status_label.text = ""
	_goto_battle.rpc(t)


# ============================================================
# 混合模式（勾选 ≥2 种玩法）
# ============================================================
func _populate_mixed_list() -> void:
	for child in mixed_check_list.get_children():
		child.queue_free()
	for t in _single_types:
		var cb := CheckBox.new()
		cb.text = BattleTypes.get_type_name(t)
		cb.set_meta("type", t)
		if font_zh:
			cb.add_theme_font_override("font", font_zh)
		mixed_check_list.add_child(cb)


func _on_mixed_pressed() -> void:
	if not MultiplayerManager.is_server():
		return
	status_label.text = ""
	mixed_panel.show()


func _on_mixed_confirm() -> void:
	if not MultiplayerManager.is_server():
		return
	var selected: Array = []
	for child in mixed_check_list.get_children():
		if child is CheckBox and (child as CheckBox).button_pressed:
			selected.append((child as CheckBox).get_meta("type"))
	if selected.size() < 2:
		status_label.text = "混合模式至少选择 2 种玩法"
		return
	mixed_panel.hide()
	if not BattleTypes.has_scene(BattleTypes.Type.MIXED):
		var path: String = BattleTypes.get_scene_path(BattleTypes.Type.MIXED)
		status_label.text = "混合模式场景尚未创建（%s/），请先制作关卡" % path.get_base_dir()
		return
	_goto_mixed.rpc(selected)


func _on_mixed_cancel() -> void:
	mixed_panel.hide()


func _on_back() -> void:
	if not MultiplayerManager.is_server():
		return
	mixed_panel.hide()
	_goto_mode_select.rpc()


# ============================================================
# UI 刷新
# ============================================================
func _refresh_ui() -> void:
	var is_server: bool = MultiplayerManager.is_server()
	# 开始/混合/返回仅主机；箭头浏览所有端可用（本地预览，无副作用）
	mode_btn.disabled = not is_server
	mixed_btn.disabled = not is_server
	back_btn.disabled = not is_server
	if is_server:
		hint_label.text = "你是主机：◀▶ 浏览玩法，点击玩法名开始"
	else:
		hint_label.text = "等待主机选择玩法……（可用 ◀▶ 浏览预览）"
