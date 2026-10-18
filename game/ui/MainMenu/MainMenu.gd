# MainMenu.gd
# 主菜单 - 温暖木质玩具风（白底 + 淡桃棕 + 深棕描边，PICO PARK 基调）
extends Control

# —— 严格配色（用户规范）——
const OUT := Color8(92, 61, 46)                 # #5C3D2E 深棕描边
const C_BG := Color8(255, 254, 245)             # #FFFEF5 奶油白背景
const C_PEACH := Color8(255, 212, 163)          # #FFD4A3 淡桃棕
const C_BEIGE := Color8(245, 230, 211)          # #F5E6D3 暖米按钮
const C_PEACH_HOVER := Color8(255, 184, 140)    # #FFB88C 桃色悬停
const C_ORANGE := Color8(255, 140, 66)          # #FF8C42 亮橙

const CHICK_COLORS: Array[Color] = [
	Color(0.478, 0.898, 0.510),   # 薄荷绿 #7AE582
	Color(0.357, 0.753, 0.922),   # 天蓝   #5BC0EB
	Color(0.969, 0.682, 0.973),   # 泡泡糖粉 #F7AEF8
	Color(0.957, 0.827, 0.369),   # 柠檬黄 #F4D35E
]

const CHICK_NAMES: Array[String] = ["green", "blue", "pink", "yellow"]
const CHICK_ROTATIONS: Array[float] = [-0.18, 0.14, -0.10, 0.16]  # 每只小鸡有不同角度

@onready var decor_layer: Control = $DecorLayer
@onready var title_en: Label = $Center/VBox/TitleEn
@onready var title_zh: Label = $Center/VBox/TitleZh
@onready var buttons_vbox: VBoxContainer = $Center/VBox/ButtonsPanel/ButtonsVBox
@onready var chick_row: HBoxContainer = $ChickRow

var font_en: FontFile
var font_zh: FontFile


func _ready() -> void:
	GameManager._switch_state(GameManager.GameState.MAIN_MENU)
	$Background.z_index = -5   # 背景放最底，避免遮挡装饰物
	_load_fonts()
	_setup_titles()
	_setup_buttons()
	_setup_decorations()
	_setup_chicks()
	_connect_signals()


# ============================================================
# 字体加载
# ============================================================
func _load_fonts() -> void:
	font_en = load("res://res/fonts/PressStart2P-Regular.ttf") as FontFile
	font_zh = load("res://res/fonts/fusion-pixel-12px-proportional-zh_hans.ttf") as FontFile


# ============================================================
# 标题（英文 + 中文）
# ============================================================
func _setup_titles() -> void:
	# 英文标题：Press Start 2P，亮橙 + 深棕粗描边
	if font_en:
		title_en.add_theme_font_override("font", font_en)
	title_en.add_theme_font_size_override("font_size", 48)
	title_en.add_theme_color_override("font_color", C_ORANGE)
	title_en.add_theme_color_override("font_outline_color", OUT)
	title_en.add_theme_constant_override("outline_size", 8)

	# 中文副标题：fusion-pixel 深棕字 + 深棕描边（配合暖色）
	if font_zh:
		title_zh.add_theme_font_override("font", font_zh)
	title_zh.add_theme_font_size_override("font_size", 24)
	title_zh.add_theme_color_override("font_color", OUT)
	title_zh.add_theme_color_override("font_outline_color", Color8(255, 254, 245))
	title_zh.add_theme_constant_override("outline_size", 3)



# ============================================================
# 按钮：糖果色描边样式
# ============================================================
func _setup_buttons() -> void:
	for btn in buttons_vbox.get_children():
		if btn is Button:
			_apply_button_style(btn)


func _make_stylebox(bg: Color, border: Color, border_w: int = 4, radius: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = border_w
	sb.border_width_right = border_w
	sb.border_width_top = border_w
	sb.border_width_bottom = border_w
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	return sb


func _apply_button_style(btn: Button) -> void:
	# 暖米底 + 深棕描边；悬停桃色高亮；按下亮橙白字
	btn.add_theme_stylebox_override("normal", _make_stylebox(C_BEIGE, OUT))
	btn.add_theme_stylebox_override("hover", _make_stylebox(C_PEACH_HOVER, OUT))
	btn.add_theme_stylebox_override("pressed", _make_stylebox(C_ORANGE, OUT))
	btn.add_theme_stylebox_override("focus", _make_stylebox(C_PEACH_HOVER, OUT, 6))
	if font_zh:
		btn.add_theme_font_override("font", font_zh)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", OUT)
	btn.add_theme_color_override("font_hover_color", OUT)
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_outline_color", OUT)
	btn.add_theme_constant_override("outline_size", 3)


# ============================================================
# 装饰：少量点缀（白底留白为主，点缀色用量极少）
# ============================================================
func _setup_decorations() -> void:
	var egg: Texture2D = load("res://res/ui/MainMenu/assets/egg/egg.png") as Texture2D
	var feather_paths: Dictionary = {
		"blue":   load("res://res/ui/MainMenu/assets/feather/feather_blue.png"),
		"orange": load("res://res/ui/MainMenu/assets/feather/feather_orange.png"),
		"purple": load("res://res/ui/MainMenu/assets/feather/feather_purple.png"),
		"red":    load("res://res/ui/MainMenu/assets/feather/feather_red.png"),
	}
	if egg == null:
		return

	# ---- 3 个蛋：边缘点缀，旋转 + 浮动 ----
	var egg_layout: Array = [
		{"pos": Vector2(170, 300),  "scale": 1.70, "rot": -0.35, "amp": 10.0, "dur": 2.0, "delay": 0.0},
		{"pos": Vector2(1090, 290), "scale": 1.55, "rot":  0.30, "amp": 12.0, "dur": 2.4, "delay": 0.6},
		{"pos": Vector2(95, 480),   "scale": 1.35, "rot":  0.45, "amp":  9.0, "dur": 1.8, "delay": 0.3},
	]
	for e in egg_layout:
		var node := _add_decoration(egg, e["pos"], e["scale"], 0.0)
		if node:
			node.rotation = e["rot"]
			_start_float(node, e["amp"], e["dur"], e["delay"])

	# ---- 3 根羽毛：点缀色少量，斜飞 + 浮动 + 摆动 ----
	var feather_layout: Array = [
		{"color": "blue",   "pos": Vector2(250, 500),  "scale": 0.09,  "rot": -0.60, "amp":  8.0, "dur": 1.8, "delay": 0.0, "wamp": 0.25, "wdur": 2.2, "wdelay": 0.0},
		{"color": "orange", "pos": Vector2(1030, 480), "scale": 0.08,  "rot":  0.70, "amp": 10.0, "dur": 2.0, "delay": 0.4, "wamp": 0.30, "wdur": 2.4, "wdelay": 0.5},
		{"color": "red",    "pos": Vector2(1120, 220), "scale": 0.075, "rot": -0.90, "amp": 11.0, "dur": 2.0, "delay": 0.2, "wamp": 0.25, "wdur": 2.5, "wdelay": 0.8},
	]
	for f in feather_layout:
		var tex: Texture2D = feather_paths.get(f["color"])
		if tex == null:
			continue
		var node := _add_decoration(tex, f["pos"], f["scale"], 0.0)
		if node:
			node.rotation = f["rot"]
			_start_float(node, f["amp"], f["dur"], f["delay"])
			_start_wobble(node, f["wamp"], f["wdur"], f["wdelay"])


func _add_decoration(tex: Texture2D, pos: Vector2, scale_val: float, drift_speed: float) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.position = pos
	tr.scale = Vector2(scale_val, scale_val)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.z_index = 1   # 直接挂到 MainMenu，在 Background(-5) 之上、Center(0) 之后绘制
	add_child(tr)     # 绕过 DecorLayer 容器（DecorLayer 在 Center 之前绘制会导致装饰物被按钮覆盖）
	if drift_speed > 0.0:
		_start_drift(tr, drift_speed)
	return tr


func _start_drift(node: Control, speed: float) -> void:
	var base_x: float = node.position.x
	var tween := create_tween().set_loops()
	tween.tween_property(node, "position:x", base_x + 60.0, 6.0 / speed).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "position:x", base_x - 60.0, 12.0 / speed).set_ease(Tween.EASE_IN_OUT)


func _start_float(node: Control, amp: float, dur: float, delay: float = 0.0) -> void:
	var base_y: float = node.position.y
	var tween := create_tween().set_loops()
	tween.tween_interval(delay)
	tween.tween_property(node, "position:y", base_y - amp, dur * 0.5).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "position:y", base_y, dur * 0.5).set_ease(Tween.EASE_IN_OUT)


func _start_wobble(node: Control, amp: float, dur: float, delay: float = 0.0) -> void:
	var base_rot: float = node.rotation
	var tween := create_tween().set_loops()
	tween.tween_interval(delay)
	tween.tween_property(node, "rotation", base_rot + amp, dur * 0.5).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "rotation", base_rot - amp, dur * 0.5).set_ease(Tween.EASE_IN_OUT)


# ============================================================
# 底部彩色小鸡（程序生成 + 跳跃动画）
# ============================================================
func _setup_chicks() -> void:
	for i in range(CHICK_NAMES.size()):
		var tex_path: String = "res://res/ui/MainMenu/assets/chick/" + CHICK_NAMES[i] + ".png"
		var tex := load(tex_path) as Texture2D
		if tex == null:
			continue
		var chick := TextureRect.new()
		chick.texture = tex
		chick.custom_minimum_size = Vector2(144, 144)
		chick.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		chick.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		chick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chick.rotation = CHICK_ROTATIONS[i]
		# 粉色(2)/黄色(3) 左右翻转（围绕中心翻转，避免位置偏移）
		if i == 2 or i == 3:
			chick.pivot_offset = chick.custom_minimum_size / 2.0
			chick.scale.x = -1.0
		chick_row.add_child(chick)

		# 跳跃动画（每只不同相位 + 不同幅度）
		var amp: float = 18.0 + (i * 2.0)
		var dur: float = 0.45 + i * 0.08
		var base_y: float = chick.position.y
		var tween := create_tween().set_loops()
		tween.tween_interval(i * 0.15)
		tween.tween_property(chick, "position:y", base_y - amp, dur * 0.5).set_ease(Tween.EASE_OUT)
		tween.tween_property(chick, "position:y", base_y, dur * 0.5).set_ease(Tween.EASE_IN)


# ============================================================
# 按钮回调（单人硬行 / 多人模式 / 设置 / 退出）
# ============================================================
func _connect_signals() -> void:
	$Center/VBox/ButtonsPanel/ButtonsVBox/SingleBtn.pressed.connect(_on_single_player)
	$Center/VBox/ButtonsPanel/ButtonsVBox/MultiBtn.pressed.connect(_on_multi_player)
	$Center/VBox/ButtonsPanel/ButtonsVBox/SettingsBtn.pressed.connect(_on_settings)
	$Center/VBox/ButtonsPanel/ButtonsVBox/QuitBtn.pressed.connect(_on_quit)


func _on_single_player() -> void:
	# 单人硬行：先进角色选择页（选完颜色进关卡）；确保联机状态已重置
	GameManager.is_online = false
	GameManager.start_character_select()


func _on_multi_player() -> void:
	# 多人模式：先进联机大厅（IP 连接），连接成功后进入模式选择（ModeSelect）
	GameManager.start_multiplayer()
	get_tree().change_scene_to_file("res://ui/Lobby/Lobby.tscn")


func _on_settings() -> void:
	# 设置：暂无设置页，保留按钮占位（后续接入音量/画面设置）
	pass


func _on_quit() -> void:
	get_tree().quit()
