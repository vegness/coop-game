# PlayerSlot.gd
# 角色选择槽位组件（class_name PlayerSlot）
# 像素风：暖米底 + 深棕描边，小鸡预览（AnimatedSprite2D）+ 左右切换箭头 + 准备按钮
# 信号 color_changed / ready_toggled 由 CharacterSelect 监听并 RPC 广播
class_name PlayerSlot
extends PanelContainer

# ============================================================
# 信号
# ============================================================
signal color_changed(peer_id: int, color_name: String)
signal ready_toggled(peer_id: int, is_ready: bool)

# ============================================================
# 常量
# ============================================================
const COLORS: Array[String] = ["blue", "green", "pink", "red", "white", "yellow"]
const CHICK_DIR := "res://res/chick/"
const PREVIEW_BASE_SCALE := 0.1  # 640px 大图 → 64px 预览

# 配色（温暖木质风）
const OUT := Color8(92, 61, 46)             # 深棕描边
const C_BG := Color8(245, 230, 211)         # 暖米底
const C_READY := Color8(122, 229, 130)      # 薄荷绿（准备）
const C_PEACH := Color8(255, 212, 163)      # 淡桃棕
const C_PEACH_HOVER := Color8(255, 184, 140)  # 桃色悬停
const C_ORANGE := Color8(255, 140, 66)      # 亮橙

# ============================================================
# 槽位数据
# ============================================================
var peer_id: int = 0
var is_local: bool = false
var is_host: bool = false
var is_single_mode: bool = false
var color_name: String = "yellow"
var is_ready: bool = false

# ============================================================
# UI 引用
# ============================================================
@onready var name_label: Label = $Margin/VBox/TopRow/NameLabel
@onready var crown_label: Label = $Margin/VBox/TopRow/CrownLabel
@onready var preview: AnimatedSprite2D = $Margin/VBox/PreviewArea/Preview
@onready var left_btn: Button = $Margin/VBox/ArrowRow/LeftBtn
@onready var right_btn: Button = $Margin/VBox/ArrowRow/RightBtn
@onready var ready_btn: Button = $Margin/VBox/ReadyBtn
@onready var ready_text: Label = $Margin/VBox/PreviewArea/ReadyText


# ============================================================
# 生命周期
# ============================================================
func _ready() -> void:
	left_btn.pressed.connect(_on_left)
	right_btn.pressed.connect(_on_right)
	ready_btn.pressed.connect(_on_ready_pressed)
	_style_buttons()
	_update_border()


# 初始化槽位（CharacterSelect 动态实例化后调用）
func setup(p_peer_id: int, p_local: bool, p_host: bool, color: String) -> void:
	peer_id = p_peer_id
	is_local = p_local
	is_host = p_host
	if color in COLORS:
		color_name = color

	var suffix := "（你）" if p_local else ""
	name_label.text = "玩家 %d%s" % [p_peer_id, suffix]
	crown_label.visible = p_host
	# 非本机槽位：隐藏箭头/准备按钮，仅展示对方当前颜色
	left_btn.visible = p_local
	right_btn.visible = p_local
	ready_btn.visible = p_local and not is_single_mode
	_update_preview()


# 单人模式：隐藏准备按钮与皇冠
func set_single_mode() -> void:
	is_single_mode = true
	ready_btn.visible = false
	crown_label.visible = false


# 槽位弹入动画（modulate + scale，容器布局下安全）
func play_enter_anim() -> void:
	modulate.a = 0.0
	scale = Vector2(0.85, 0.85)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.22)
	tween.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), 0.22) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


# ============================================================
# 外部同步（收到 RPC，不触发信号）
# ============================================================
func set_color(color: String) -> void:
	if color in COLORS and color != color_name:
		color_name = color
		_update_preview()
		_bounce_anim()


func set_ready(r: bool) -> void:
	is_ready = r
	ready_btn.text = "取消准备" if is_ready else "准备"
	ready_btn.add_theme_color_override("font_color", Color(1, 1, 1) if is_ready else OUT)
	_update_border()
	if is_ready:
		_show_ready_text()


func get_color() -> String:
	return color_name


# ============================================================
# 本地交互（按钮）
# ============================================================
func _on_left() -> void:
	cycle_color(-1)


func _on_right() -> void:
	cycle_color(1)


# 公开：外部（键盘 A/D 等）切换颜色
func cycle_color(dir: int) -> void:
	var idx := COLORS.find(color_name)
	idx = (idx + dir + COLORS.size()) % COLORS.size()
	color_name = COLORS[idx]
	_update_preview()
	_bounce_anim()
	color_changed.emit(peer_id, color_name)


# 公开：外部（键盘空格等）切换准备状态
func toggle_ready() -> void:
	_on_ready_pressed()


func _on_ready_pressed() -> void:
	is_ready = not is_ready
	ready_btn.text = "取消准备" if is_ready else "准备"
	ready_btn.add_theme_color_override("font_color", Color(1, 1, 1) if is_ready else OUT)
	_update_border()
	if is_ready:
		_show_ready_text()
	ready_toggled.emit(peer_id, is_ready)


# ============================================================
# 预览与动画
# ============================================================
func _update_preview() -> void:
	var frames := SpriteFrames.new()
	frames.add_animation("stop")
	frames.set_animation_loop("stop", true)
	frames.set_animation_speed("stop", 5.0)
	for idx in [1, 2, 3]:
		var tex := load("%s%s/stop/%d.png" % [CHICK_DIR, color_name, idx]) as Texture2D
		if tex:
			frames.add_frame("stop", tex)
	preview.sprite_frames = frames
	preview.play("stop")


# 切换颜色弹跳反馈（基于基础缩放）
func _bounce_anim() -> void:
	preview.scale = Vector2(PREVIEW_BASE_SCALE * 0.94, PREVIEW_BASE_SCALE * 0.94)
	var tween := create_tween()
	tween.tween_property(preview, "scale", Vector2(PREVIEW_BASE_SCALE * 1.14, PREVIEW_BASE_SCALE * 1.14), 0.1) \
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(preview, "scale", Vector2(PREVIEW_BASE_SCALE, PREVIEW_BASE_SCALE), 0.1) \
		.set_ease(Tween.EASE_IN)


# READY! 飘字（预览上方，上移淡出）
func _show_ready_text() -> void:
	ready_text.visible = true
	ready_text.modulate.a = 1.0
	ready_text.position.y = -16.0
	var tween := create_tween()
	tween.tween_property(ready_text, "position:y", -42.0, 0.9).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ready_text, "modulate:a", 0.0, 0.7)
	tween.tween_callback(func() -> void: ready_text.visible = false)


# ============================================================
# 样式
# ============================================================
func _update_border() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_BG
	sb.border_color = C_READY if is_ready else OUT
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	add_theme_stylebox_override("panel", sb)


func _style_buttons() -> void:
	for btn in [left_btn, right_btn, ready_btn]:
		btn.add_theme_font_size_override("font_size", 16)
		btn.add_theme_color_override("font_color", OUT)
		btn.add_theme_color_override("font_hover_color", OUT)
		var sb := StyleBoxFlat.new()
		sb.bg_color = C_PEACH
		sb.border_color = OUT
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("normal", sb)
		var hb := sb.duplicate() as StyleBoxFlat
		hb.bg_color = C_PEACH_HOVER
		btn.add_theme_stylebox_override("hover", hb)
		var pb := sb.duplicate() as StyleBoxFlat
		pb.bg_color = C_ORANGE
		btn.add_theme_stylebox_override("pressed", pb)
