# LevelSelect.gd
# 关卡选择 - 温暖木质玩具风（白底 + 淡桃棕 + 深棕描边）
# 卡片网格：编号 + 像素缩略图 + 糖果色星星（已解锁）/ 棕色锁（未解锁）
extends Control

# —— 严格配色（用户规范）——
const OUT := Color8(92, 61, 46)                 # #5C3D2E 深棕描边
const C_CREAM := Color8(255, 254, 245)          # #FFFEF5 奶油白
const C_PEACH := Color8(255, 212, 163)          # #FFD4A3 淡桃棕
const C_BEIGE := Color8(245, 230, 211)          # #F5E6D3 暖米
const C_ORANGE := Color8(255, 140, 66)          # #FF8C42 亮橙
const C_PEACH_HOVER := Color8(255, 184, 140)    # #FFB88C 桃色悬停
const C_GRAY := Color8(217, 207, 193)           # #D9CFC1 未解锁灰米
const C_GRAY_BORDER := Color8(160, 148, 130)    # 未解锁描边
const CANDY_STARS: Array[Color] = [             # 糖果色星星（评分点缀）
	Color8(244, 211, 94),   # 柠檬黄
	Color8(247, 174, 248),  # 泡泡糖粉
	Color8(91, 192, 235),   # 天蓝
	Color8(122, 229, 130),  # 薄荷绿
]

const LEVEL_COUNT: int = 8
const MAX_COLUMNS: int = 4

@onready var title_label: Label = $Root/Window/Inner/VBox/TitleLabel
@onready var chapter_tabs: HBoxContainer = $Root/Window/Inner/VBox/ChapterTabs
@onready var grid: GridContainer = $Root/Window/Inner/VBox/GridContainer
@onready var hint_label: Label = $Root/Window/Inner/VBox/Footer/HintLabel
@onready var back_btn: Button = $BackBtn

var font_zh: FontFile
var font_en: FontFile
var star_textures: Array[Texture2D] = []
var lock_texture: Texture2D


func _ready() -> void:
	# 多人选关属于进行中流程（PLAYING）；单人选关保持原 MAIN_MENU 状态
	if GameManager.is_online:
		GameManager._switch_state(GameManager.GameState.PLAYING)
	else:
		GameManager._switch_state(GameManager.GameState.MAIN_MENU)
	_load_fonts()
	_build_icons()
	_setup_title()
	_build_chapter_tabs()
	_build_cards()
	_setup_decor_chick()
	_setup_back_btn()
	back_btn.pressed.connect(_on_back)
	_update_hint()
	_setup_multiplayer_mode()


# ============================================================
# 字体
# ============================================================
func _load_fonts() -> void:
	font_zh = load("res://res/fonts/fusion-pixel-12px-proportional-zh_hans.ttf") as FontFile
	font_en = load("res://res/fonts/PressStart2P-Regular.ttf") as FontFile


func _setup_title() -> void:
	# 标题：亮橙 + 深棕描边
	if font_en:
		title_label.add_theme_font_override("font", font_en)
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", C_ORANGE)
	title_label.add_theme_color_override("font_outline_color", OUT)
	title_label.add_theme_constant_override("outline_size", 5)

	if font_zh:
		hint_label.add_theme_font_override("font", font_zh)
	hint_label.add_theme_font_size_override("font_size", 13)
	hint_label.add_theme_color_override("font_color", OUT)


# ============================================================
# 像素图标：糖果星 / 棕色锁
# ============================================================
func _build_icons() -> void:
	for c in CANDY_STARS:
		star_textures.append(_make_pixel_star(c))
	lock_texture = _make_pixel_lock()


# 7x7 菱形像素星
func _make_pixel_star(color: Color) -> ImageTexture:
	var img := Image.create(7, 7, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(7):
		for x in range(7):
			if absi(x - 3) + absi(y - 3) <= 3:
				img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)


# 9x11 棕色小锁
func _make_pixel_lock() -> ImageTexture:
	var img := Image.create(9, 11, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# 锁梁（拱形）
	for x in range(1, 8):
		img.set_pixel(x, 0, OUT)
	img.set_pixel(2, 1, OUT)
	img.set_pixel(6, 1, OUT)
	img.set_pixel(2, 2, OUT)
	img.set_pixel(6, 2, OUT)
	# 锁体（浅棕填充 + 深棕描边）
	var body := Color8(196, 168, 138)
	for y in range(3, 11):
		for x in range(9):
			var edge: bool = x == 0 or x == 8 or y == 3 or y == 10
			img.set_pixel(x, y, OUT if edge else body)
	# 锁孔
	for y in range(5, 8):
		for x in range(3, 6):
			img.set_pixel(x, y, OUT)
	return ImageTexture.create_from_image(img)


# 64x32 单色像素缩略图（地形剪影）
func _make_thumbnail(unlocked: bool) -> ImageTexture:
	var img := Image.create(72, 40, false, Image.FORMAT_RGBA8)
	var ground := OUT if unlocked else C_GRAY_BORDER
	var platform := C_PEACH if unlocked else Color8(190, 178, 160)
	var flag := C_ORANGE if unlocked else C_GRAY_BORDER
	img.fill(C_CREAM if unlocked else Color8(236, 230, 216))
	# 地平线
	img.fill_rect(Rect2i(0, 32, 72, 3), ground)
	# 平台
	img.fill_rect(Rect2i(8, 26, 20, 4), platform)
	img.fill_rect(Rect2i(44, 20, 20, 4), platform)
	# 终点旗
	img.fill_rect(Rect2i(64, 24, 3, 8), ground)
	img.fill_rect(Rect2i(64, 19, 8, 4), flag)
	return ImageTexture.create_from_image(img)


# ============================================================
# 章节标签
# ============================================================
func _build_chapter_tabs() -> void:
	var chapters: Array[String] = ["第一章", "第二章", "第三章"]
	for i in range(chapters.size()):
		var tab := Button.new()
		tab.text = chapters[i]
		tab.disabled = i != 0
		tab.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if i == 0 else Control.CURSOR_ARROW
		if font_zh:
			tab.add_theme_font_override("font", font_zh)
		tab.add_theme_font_size_override("font_size", 14)
		tab.add_theme_color_override("font_color", OUT)
		if i == 0:
			# 激活章节：淡桃棕底 + 深棕描边
			tab.add_theme_stylebox_override("normal", _make_stylebox(C_PEACH, OUT, 2, 8))
			tab.add_theme_stylebox_override("hover", _make_stylebox(C_PEACH_HOVER, OUT, 2, 8))
			tab.add_theme_stylebox_override("pressed", _make_stylebox(C_ORANGE, OUT, 2, 8))
		else:
			# 未开放章节：灰米禁用
			tab.add_theme_stylebox_override("disabled", _make_stylebox(C_GRAY, C_GRAY_BORDER, 2, 8))
			tab.add_theme_color_override("font_disabled_color", Color8(150, 138, 120))
		chapter_tabs.add_child(tab)


# ============================================================
# 关卡卡片网格
# ============================================================
func _build_cards() -> void:
	grid.columns = MAX_COLUMNS
	for i in range(1, LEVEL_COUNT + 1):
		# 多人合作：全部关卡可玩（不受单人解锁进度限制）
		var unlocked: bool = GameManager.is_level_unlocked(i) if not GameManager.is_online else true
		var card := Button.new()
		card.custom_minimum_size = Vector2(170, 158)
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if unlocked else Control.CURSOR_ARROW
		card.disabled = not unlocked
		card.focus_mode = Control.FOCUS_NONE
		if unlocked:
			card.add_theme_stylebox_override("normal", _make_stylebox(C_BEIGE, OUT, 3, 10))
			card.add_theme_stylebox_override("hover", _make_stylebox(C_CREAM, C_ORANGE, 5, 10))
			card.add_theme_stylebox_override("pressed", _make_stylebox(C_PEACH, OUT, 3, 10))
		else:
			card.add_theme_stylebox_override("disabled", _make_stylebox(C_GRAY, C_GRAY_BORDER, 3, 10))

		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 6)
		card.add_child(box)

		# 编号
		var num := Label.new()
		num.text = str(i)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if font_en:
			num.add_theme_font_override("font", font_en)
		num.add_theme_font_size_override("font_size", 30)
		num.add_theme_color_override("font_color", OUT if unlocked else C_GRAY_BORDER)
		num.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
		box.add_child(num)

		# 缩略图
		var thumb := TextureRect.new()
		thumb.texture = _make_thumbnail(unlocked)
		thumb.custom_minimum_size = Vector2(108, 40)
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(thumb)

		# 底部行：已解锁 = 3 颗糖果星；未解锁 = 棕色锁
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 4)
		box.add_child(row)
		if unlocked:
			for s in range(3):
				var star := TextureRect.new()
				star.texture = star_textures[s % star_textures.size()]
				star.custom_minimum_size = Vector2(16, 16)
				star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				star.mouse_filter = Control.MOUSE_FILTER_IGNORE
				row.add_child(star)
		else:
			var lock := TextureRect.new()
			lock.texture = lock_texture
			lock.custom_minimum_size = Vector2(16, 18)
			lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(lock)

		var level_id := i
		card.pressed.connect(func() -> void: _on_level_selected(level_id))
		grid.add_child(card)


func _make_stylebox(bg: Color, border: Color, border_w: int, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = border_w
	sb.border_width_right = border_w
	sb.border_width_top = border_w
	sb.border_width_bottom = border_w
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	return sb


# ============================================================
# 小像素鸡（坐在网格旁）
# ============================================================
func _setup_decor_chick() -> void:
	var tex := load("res://res/ui/MainMenu/assets/chick/green.png") as Texture2D
	if tex == null:
		return
	var chick := TextureRect.new()
	chick.texture = tex
	chick.custom_minimum_size = Vector2(110, 110)
	chick.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chick.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chick.position = Vector2(960, 470)
	chick.rotation = -0.22
	add_child(chick)
	var tween := create_tween().set_loops()
	tween.tween_property(chick, "position:y", 462.0, 0.9).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(chick, "position:y", 478.0, 0.9).set_ease(Tween.EASE_IN_OUT)


func _setup_back_btn() -> void:
	if font_zh:
		back_btn.add_theme_font_override("font", font_zh)
	back_btn.add_theme_font_size_override("font_size", 16)
	back_btn.add_theme_stylebox_override("normal", _make_stylebox(C_BEIGE, OUT, 3, 10))
	back_btn.add_theme_stylebox_override("hover", _make_stylebox(C_PEACH_HOVER, OUT, 3, 10))
	back_btn.add_theme_stylebox_override("pressed", _make_stylebox(C_ORANGE, OUT, 3, 10))
	back_btn.add_theme_color_override("font_color", OUT)
	back_btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	# 从角色选择页进入时，返回按钮语义为"返回选角"（方便换角色）
	if GameManager.from_character_select:
		back_btn.text = "返回选角"


# ============================================================
# 多人模式：主机选关广播，客机等待
# ============================================================
func _setup_multiplayer_mode() -> void:
	if not GameManager.is_online:
		return
	var is_host: bool = MultiplayerManager.is_server()
	back_btn.visible = is_host
	if is_host:
		back_btn.text = "返回选角"
		hint_label.text = "点击选择关卡，所有玩家将同步进入"
	else:
		# 客机：等待主机选择，卡片禁用
		hint_label.text = "等待主机选择关卡..."
		for card in grid.get_children():
			card.disabled = true


func _update_hint() -> void:
	if GameManager.is_online:
		return  # 多人提示由 _setup_multiplayer_mode 设置
	var unlocked_count := 0
	for i in range(1, LEVEL_COUNT + 1):
		if GameManager.is_level_unlocked(i):
			unlocked_count += 1
	hint_label.text = "已解锁 %d / %d 关" % [unlocked_count, LEVEL_COUNT]


# ============================================================
# 交互
# ============================================================
func _on_level_selected(level_id: int) -> void:
	if GameManager.is_online:
		# 仅主机可发起（客机卡片已禁用）
		if not MultiplayerManager.is_server():
			return
		var color_dict: Dictionary = MultiplayerManager.player_colors.duplicate()
		_start_game_with_colors.rpc(color_dict, level_id)
		return
	GameManager.current_mode = GameManager.GameMode.SINGLE_TUTORIAL
	GameManager.player_count = 1
	GameManager.is_online = false
	GameManager.start_level(level_id)


# 多人进关卡：所有端各自加载关卡（发起端为主机选关点击，已由 _on_level_selected 的
# is_server guard 保证；any_peer + call_local 后端无关，Steam 下同样可用）
@rpc("any_peer", "call_local", "reliable")
func _start_game_with_colors(color_dict: Dictionary, level_id: int) -> void:
	MultiplayerManager.player_colors = color_dict
	GameManager.start_level(level_id)


func _on_back() -> void:
	if GameManager.is_online:
		# 仅主机可发起；广播回选角（各端保持联机状态）
		if not MultiplayerManager.is_server():
			return
		_back_to_character_select.rpc()
		return
	# 从角色选择页进入：返回选角页（方便换角色）；否则回主菜单
	if GameManager.from_character_select:
		GameManager.from_character_select = false
		get_tree().change_scene_to_file("res://ui/character_select/CharacterSelect.tscn")
	else:
		get_tree().change_scene_to_file("res://ui/MainMenu/MainMenu.tscn")


@rpc("any_peer", "call_local", "reliable")
func _back_to_character_select() -> void:
	get_tree().change_scene_to_file("res://ui/character_select/CharacterSelect.tscn")
