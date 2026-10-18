# LevelClear.gd
# 通关画面（CanvasLayer 弹窗）
# - 监听 EventBus.level_completed 自动显示
# - 显示内容：标题、3 颗星、用时、得分、3 个按钮（下一关/重试/返回选关）
# - 点击弹窗区域/按钮外：跳选关界面（用户需求"点击一下鼠标跳选关"）
# - 配色严格按用户规范：暖米底 + 淡桃棕粗边框 + 深棕描边 + 亮橙标题 + 柠檬黄星 + 三色按钮
# 解耦：只通过 GameManager / EventBus 与游戏逻辑交互
extends CanvasLayer

# === 用户规范配色（const 常量便于阅读）===
const C_CREAM: Color = Color8(255, 254, 245)         # #FFFEF5 暖白（弹窗底）
const C_PEACH: Color = Color8(255, 212, 163)         # #FFD4A3 淡桃棕（粗边框/遮罩）
const C_BEIGE: Color = Color8(245, 230, 211)         # #F5E6D3 暖米（弹窗内填充）
const C_BROWN: Color = Color8(92, 61, 46)            # #5C3D2E 深棕（描边/文字）
const C_ORANGE: Color = Color8(255, 140, 66)         # #FF8C42 亮橙（标题/下一关）
const C_YELLOW: Color = Color8(244, 211, 94)         # #F4D35E 柠檬黄（星星）
const C_BLUE: Color = Color8(91, 192, 235)           # #5BC0EB 天蓝（重试）
const C_PINK: Color = Color8(247, 174, 248)          # #F7AEF8 柔粉（返回）

const FONT_EN: Font = preload("res://res/fonts/PressStart2P-Regular.ttf")
const FONT_ZH: Font = preload("res://res/fonts/fusion-pixel-12px-proportional-zh_hans.ttf")

# 装饰素材（主菜单已有：chick 多色 png + egg.png）
const CHICK_TEX: Dictionary = {
	"yellow": preload("res://res/ui/MainMenu/assets/chick/yellow.png"),
	"blue": preload("res://res/ui/MainMenu/assets/chick/blue.png"),
	"green": preload("res://res/ui/MainMenu/assets/chick/green.png"),
	"pink": preload("res://res/ui/MainMenu/assets/chick/pink.png"),
}
const EGG_TEX: Texture2D = preload("res://res/ui/MainMenu/assets/egg/egg.png")

# 关卡用时（GameManager 切到 LEVEL_COMPLETE 时记录）
var _elapsed: float = 0.0

# 装饰动画 tween（关掉时 kill）
var _tweens: Array[Tween] = []


func _ready() -> void:
	# 初始隐藏：监听 level_completed 后再显示
	visible = false
	EventBus.level_completed.connect(_on_level_completed)
	# 按钮信号连接
	var next_btn := $Dialog/Inner/Buttons/NextBtn as Button
	var retry_btn := $Dialog/Inner/Buttons/RetryBtn as Button
	var back_btn := $Dialog/Inner/Buttons/BackBtn as Button
	if next_btn != null:
		next_btn.pressed.connect(_on_next_pressed)
	if retry_btn != null:
		retry_btn.pressed.connect(_on_retry_pressed)
	if back_btn != null:
		back_btn.pressed.connect(_on_back_pressed)


# 关卡完成事件：记录用时、刷新数据、显示
func _on_level_completed(_level_id: int) -> void:
	var level := get_tree().current_scene
	if level != null and level is LevelBase:
		_elapsed = (level as LevelBase).elapsed_time
	_refresh_data()
	show()
	_play_decor_animations()


# 刷新标题/数据/星星文本
func _refresh_data() -> void:
	# 数据：当前用时（从 LevelBase.elapsed_time 读取）
	var lbl_time := $Dialog/Inner/Data/TimeLabel as Label
	lbl_time.text = "TIME  %s" % _format_time(_elapsed)
	# 占位分数（暂给 0 满分 3 星；后续可接计分系统）
	var lbl_score := $Dialog/Inner/Data/ScoreLabel as Label
	lbl_score.text = "SCORE  %d" % int(_elapsed <= 30.0)  # 占位：30s 内算 1 分
	# 星星：先全满（3 颗黄实心 ★）
	for star in $Dialog/Inner/Stars.get_children():
		(star as Label).modulate = C_YELLOW


# 装饰小鸡/蛋的弹跳 + 摇摆动画
func _play_decor_animations() -> void:
	_kill_tweens()
	# 弹窗边缘小鸡轻微上下浮动
	for i in 3:
		var chick := $Dialog.get_node_or_null("DecorChick%d" % (i + 1)) as TextureRect
		if chick == null:
			continue
		var tw := create_tween().set_loops()
		tw.tween_property(chick, "position:y", chick.position.y - 6.0, 0.6).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(chick, "position:y", chick.position.y + 6.0, 0.6).set_ease(Tween.EASE_IN_OUT)
		_tweens.append(tw)
	# 弹跳蛋
	for i in 2:
		var egg := $Dialog.get_node_or_null("DecorEgg%d" % (i + 1)) as TextureRect
		if egg == null:
			continue
		var tw := create_tween().set_loops()
		tw.tween_property(egg, "position:y", egg.position.y - 8.0, 0.5).set_ease(Tween.EASE_OUT)
		tw.tween_property(egg, "position:y", egg.position.y + 8.0, 0.5).set_ease(Tween.EASE_IN)
		_tweens.append(tw)


func _kill_tweens() -> void:
	for t in _tweens:
		if t != null and t.is_valid():
			t.kill()
	_tweens.clear()


# === 输入处理：点击鼠标跳选关（用户需求）===
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# 点击按钮的事件会被 Button 自身先处理（Godot UI 事件冒泡），
		# 此处作为兜底：点空白处直接跳选关。
		var handled := _was_button_clicked(event.position)
		if not handled:
			_go_to_level_select()


# 检测点击位置是否落在任一按钮上（避免吞掉按钮点击）
func _was_button_clicked(pos: Vector2) -> bool:
	for btn in $Dialog/Inner/Buttons.get_children():
		if btn is Button and (btn as Button).get_global_rect().has_point(pos):
			return true
	return false


# === 按钮回调（由 tscn 的 pressed 信号连接）===
func _on_next_pressed() -> void:
	# 切下一关：GameManager.next_level；如没有下一关则跳选关
	if GameManager.current_level_id < 8:
		GameManager.next_level()
	else:
		_go_to_level_select()


func _on_retry_pressed() -> void:
	GameManager.restart_level()


func _on_back_pressed() -> void:
	_go_to_level_select()


func _go_to_level_select() -> void:
	# 多人下：LevelSelect 不会加载联机，回到主流程前保持 GameManager.is_online 不变（不强断）
	get_tree().change_scene_to_file("res://ui/LevelSelect/LevelSelect.tscn")


# mm:ss 格式
func _format_time(sec: float) -> String:
	var m: int = int(sec) / 60
	var s: int = int(sec) % 60
	return "%02d:%02d" % [m, s]
