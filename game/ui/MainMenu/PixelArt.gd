# PixelArt.gd
# 主菜单糖果像素风装饰图生成器（PICO PARK 风格）
# 全部程序化生成：圆滚滚彩色小鸡 / 像素蛋 / 金色羽毛 / 简约云朵
# 画风：16位像素、锐利深紫黑描边(#2D1B2E)、平涂色块
class_name PixelArt
extends RefCounted

const OUTLINE_COLOR := Color("#2D1B2E")
const BEAK_COLOR := Color("#FFB347")
const COMB_COLOR := Color("#FF6B6B")


# ============================================================
# 圆滚滚像素小鸡（32x32 逻辑像素）
# body_color：身体主色；wing_color：翅膀色
# ============================================================
static func make_pixel_chick(body_color: Color, wing_color: Color) -> ImageTexture:
	var size := 32
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# 身体（带 1px 深色描边）
	_draw_circle(img, Vector2(16, 21), 11.0, OUTLINE_COLOR)
	_draw_circle(img, Vector2(16, 21), 10.0, body_color)

	# 翅膀（身体侧面，略深于身体）
	_draw_circle(img, Vector2(10, 23), 4.5, OUTLINE_COLOR)
	_draw_circle(img, Vector2(11, 23), 3.5, wing_color)

	# 头（带描边）
	_draw_circle(img, Vector2(16, 10), 6.0, OUTLINE_COLOR)
	_draw_circle(img, Vector2(16, 10), 5.0, body_color)

	# 鸡冠（头顶三撮红）
	img.set_pixel(13, 3, COMB_COLOR)
	img.set_pixel(14, 3, COMB_COLOR)
	img.set_pixel(16, 2, COMB_COLOR)
	img.set_pixel(16, 3, COMB_COLOR)
	img.set_pixel(18, 3, COMB_COLOR)
	img.set_pixel(19, 3, COMB_COLOR)

	# 眼睛（黑眼 + 白色高光）
	img.set_pixel(14, 9, OUTLINE_COLOR)
	img.set_pixel(18, 9, OUTLINE_COLOR)
	img.set_pixel(15, 8, Color.WHITE)
	img.set_pixel(19, 8, Color.WHITE)

	# 喙（橙色小三角）
	img.set_pixel(15, 14, BEAK_COLOR)
	img.set_pixel(16, 14, BEAK_COLOR)
	img.set_pixel(17, 14, BEAK_COLOR)
	img.set_pixel(14, 15, BEAK_COLOR)
	img.set_pixel(18, 15, BEAK_COLOR)

	# 脚（橙色小方块）
	img.set_pixel(13, 30, BEAK_COLOR)
	img.set_pixel(14, 30, BEAK_COLOR)
	img.set_pixel(18, 30, BEAK_COLOR)
	img.set_pixel(19, 30, BEAK_COLOR)
	img.set_pixel(12, 31, BEAK_COLOR)
	img.set_pixel(20, 31, BEAK_COLOR)

	return ImageTexture.create_from_image(img)


# ============================================================
# 像素蛋（24x32）
# ============================================================
static func make_pixel_egg(egg_color: Color, spot_color: Color) -> ImageTexture:
	var img := Image.create(24, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# 蛋形椭圆（带描边）
	_draw_ellipse(img, Vector2(12, 16), Vector2(11, 14), OUTLINE_COLOR)
	_draw_ellipse(img, Vector2(12, 16), Vector2(10, 13), egg_color)

	# 斑点（深色）
	img.set_pixel(9, 12, spot_color)
	img.set_pixel(14, 18, spot_color)
	img.set_pixel(11, 23, spot_color)
	img.set_pixel(16, 11, spot_color)

	# 高光（左上角浅色）
	img.set_pixel(7, 8, Color.WHITE)
	img.set_pixel(8, 9, Color.WHITE)

	return ImageTexture.create_from_image(img)


# ============================================================
# 金色羽毛（32x24）
# ============================================================
static func make_pixel_feather() -> ImageTexture:
	var img := Image.create(32, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# 羽翼主体（金色椭圆 + 黑边）
	_draw_ellipse(img, Vector2(16, 12), Vector2(15, 10), OUTLINE_COLOR)
	_draw_ellipse(img, Vector2(16, 12), Vector2(14, 9), Color("#F4D35E"))

	# 羽轴（中轴线，深棕）
	for y in range(4, 21):
		img.set_pixel(16, y, Color("#8A5A00"))
	img.set_pixel(15, 4, Color("#8A5A00"))
	img.set_pixel(17, 4, Color("#8A5A00"))

	# 羽枝纹理（两侧短横线，深金）
	for y in range(6, 18):
		if y % 2 == 0:
			img.set_pixel(11, y, Color("#C99700"))
			img.set_pixel(21, y, Color("#C99700"))
		else:
			img.set_pixel(8, y, Color("#C99700"))
			img.set_pixel(24, y, Color("#C99700"))

	return ImageTexture.create_from_image(img)


# ============================================================
# 简约像素云朵（64x28，白色平涂、无描边）
# ============================================================
static func make_pixel_cloud() -> ImageTexture:
	var img := Image.create(64, 28, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	_draw_circle(img, Vector2(18, 18), 8.0, Color.WHITE)
	_draw_circle(img, Vector2(32, 13), 10.0, Color.WHITE)
	_draw_circle(img, Vector2(46, 18), 8.0, Color.WHITE)

	# 底部拉平 + 浅阴影
	for x in range(8, 57):
		img.set_pixel(x, 25, Color.WHITE)
		img.set_pixel(x, 26, Color("#E3F2FB"))

	return ImageTexture.create_from_image(img)


# ============================================================
# 内部工具：像素圆 / 像素椭圆
# ============================================================
static func _draw_circle(img: Image, center: Vector2, radius: float, color: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var r2 := radius * radius
	for y in range(h):
		for x in range(w):
			var dx := float(x) - center.x
			var dy := float(y) - center.y
			if dx * dx + dy * dy <= r2:
				img.set_pixel(x, y, color)


static func _draw_ellipse(img: Image, center: Vector2, radius: Vector2, color: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var rx2 := radius.x * radius.x
	var ry2 := radius.y * radius.y
	for y in range(h):
		for x in range(w):
			var dx := float(x) - center.x
			var dy := float(y) - center.y
			if (dx * dx) / rx2 + (dy * dy) / ry2 <= 1.0:
				img.set_pixel(x, y, color)
