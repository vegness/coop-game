# generate_menu_assets.gd - 程序化生成主菜单像素风美术资源
# 运行：godot --headless --path <project> --script res://tools/generate_menu_assets.gd
# 产出：res/ui/MainMenu/assets/ 下 PNG（可重跑）
extends SceneTree

const OUT := Color8(45, 27, 46)         # #2D1B2E 深紫黑描边
const SAVE_DIR := "E:/desktop/try_game/game/res/ui/MainMenu/assets"
const SKY_TOP := Color8(224, 247, 250)  # #E0F7FA 浅天蓝
const SKY_BOT := Color8(255, 248, 231)  # #FFF8E7 淡鹅黄
const GROUND := Color8(122, 229, 130)   # #7AE582 薄荷绿地面
const ORANGE := Color8(255, 140, 66)    # #FF8C42
const BLUE := Color8(91, 192, 235)      # #5BC0EB
const PINK := Color8(247, 174, 248)     # #F7AEF8
const YELLOW := Color8(244, 211, 94)    # #F4D35E
const RED := Color8(255, 94, 98)
const WHITE := Color8(255, 252, 245)


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	_generate_bg()
	_generate_cloud()
	_generate_egg()
	_generate_feather()
	_generate_chick("chick_green", Color8(122, 229, 130))
	_generate_chick("chick_blue", Color8(91, 192, 235))
	_generate_chick("chick_pink", Color8(247, 174, 248))
	_generate_chick("chick_yellow", Color8(244, 211, 94))
	print("MENU ASSETS GENERATED -> ", SAVE_DIR)
	quit()


func save(img: Image, name: String) -> void:
	img.save_png(SAVE_DIR + "/" + name)
	print("saved ", name)


func set_px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


# 像素圆（实心 + 1px 描边）
func fill_circle(img: Image, cx: float, cy: float, r: float, fill: Color, outline: Color) -> void:
	var x0 := floori(cx - r - 1)
	var x1 := ceili(cx + r + 1)
	var y0 := floori(cy - r - 1)
	var y1 := ceili(cy + r + 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var d: float = Vector2(x + 0.5, y + 0.5).distance_to(Vector2(cx, cy))
			if d <= r + 0.5:
				set_px(img, x, y, outline if d > r - 0.5 else fill)


# 像素矩形（1px 描边）
func fill_rect(img: Image, rx: int, ry: int, rw: int, rh: int, fill: Color, outline: Color) -> void:
	for y in range(ry, ry + rh):
		for x in range(rx, rx + rw):
			var edge: bool = x == rx or x == rx + rw - 1 or y == ry or y == ry + rh - 1
			set_px(img, x, y, outline if edge else fill)


# 1. 背景：天蓝→鹅黄渐变（16px 色带量化）+ 底部薄荷绿地面
func _generate_bg() -> void:
	var img := Image.create(1280, 720, false, Image.FORMAT_RGBA8)
	for y in range(720):
		var c: Color
		if y >= 600:
			c = GROUND
		else:
			var band := y / 16
			var total := 600.0 / 16.0
			var t := clampf(band / total, 0.0, 1.0)
			c = Color(
				lerpf(SKY_TOP.r, SKY_BOT.r, t),
				lerpf(SKY_TOP.g, SKY_BOT.g, t),
				lerpf(SKY_TOP.b, SKY_BOT.b, t))
		img.fill_rect(Rect2i(0, y, 1280, 1), c)
	# 地平线描边
	img.fill_rect(Rect2i(0, 599, 1280, 1), OUT)
	save(img, "bg.png")


# 2. 云朵：白色像素圆叠成
func _generate_cloud() -> void:
	var img := Image.create(96, 44, false, Image.FORMAT_RGBA8)
	fill_circle(img, 24, 30, 12, WHITE, WHITE)
	fill_circle(img, 40, 22, 16, WHITE, WHITE)
	fill_circle(img, 58, 28, 13, WHITE, WHITE)
	fill_circle(img, 72, 32, 9, WHITE, WHITE)
	# 底部切平
	for y in range(40, 44):
		img.fill_rect(Rect2i(0, y, 96, 1), Color(0, 0, 0, 0))
	save(img, "cloud.png")


# 3. 像素蛋：白色椭圆 + 彩色斑点
func _generate_egg() -> void:
	var img := Image.create(36, 44, false, Image.FORMAT_RGBA8)
	var cx := 18.0
	var cy := 24.0
	for y in range(2, 42):
		for x in range(2, 34):
			var dx: float = (x + 0.5 - cx) / 11.0
			var dy: float = (y + 0.5 - cy) / 14.0
			var d := dx * dx + dy * dy
			if d <= 1.0:
				# 描边判定：边缘一圈
				var edge: bool = d > 0.82
				set_px(img, x, y, OUT if edge else WHITE)
	# 斑点
	fill_rect(img, 10, 14, 4, 4, PINK, PINK)
	fill_rect(img, 22, 26, 4, 4, BLUE, BLUE)
	fill_rect(img, 14, 32, 4, 4, YELLOW, YELLOW)
	save(img, "egg.png")


# 4. 金色羽毛
func _generate_feather() -> void:
	var img := Image.create(44, 40, false, Image.FORMAT_RGBA8)
	# 羽片椭圆（金）
	var cx := 22.0
	var cy := 16.0
	for y in range(1, 34):
		for x in range(1, 43):
			var dx: float = (x + 0.5 - cx) / 19.0
			var dy: float = (y + 0.5 - cy) / 13.0
			var d := dx * dx + dy * dy
			if d <= 1.0:
				var edge: bool = d > 0.82
				set_px(img, x, y, OUT if edge else YELLOW)
	# 羽轴（深金竖线）
	img.fill_rect(Rect2i(21, 4, 3, 26), Color8(232, 163, 61))
	# 羽管（底部小三角）
	img.fill_rect(Rect2i(21, 30, 3, 8), OUT)
	save(img, "feather.png")


# 5. 圆滚滚像素小鸡（48x48）
func _generate_chick(name: String, body: Color) -> void:
	var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	var wing: Color = body.lightened(0.12)
	# 身体
	fill_circle(img, 24, 27, 14, body, OUT)
	# 肚皮
	fill_circle(img, 24, 32, 8, WHITE, WHITE)
	# 翅膀
	fill_circle(img, 14, 29, 5, wing, OUT)
	# 眼睛（2 个黑块）
	img.fill_rect(Rect2i(17, 23, 4, 5), OUT)
	img.fill_rect(Rect2i(28, 23, 4, 5), OUT)
	# 嘴
	fill_rect(img, 20, 31, 9, 5, ORANGE, OUT)
	# 鸡冠
	img.fill_rect(Rect2i(18, 7, 4, 5), RED)
	img.fill_rect(Rect2i(22, 5, 4, 5), RED)
	img.fill_rect(Rect2i(26, 7, 4, 5), RED)
	img.fill_rect(Rect2i(18, 6, 4, 1), OUT)
	img.fill_rect(Rect2i(22, 4, 4, 1), OUT)
	img.fill_rect(Rect2i(26, 6, 4, 1), OUT)
	# 脚
	fill_rect(img, 15, 42, 6, 4, ORANGE, OUT)
	fill_rect(img, 28, 42, 6, 4, ORANGE, OUT)
	save(img, name + ".png")
