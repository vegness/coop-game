# generate_level_tileset.gd - 程序化生成工厂主题像素 tileset（炸弹工坊）
# 运行：godot --headless --path <project> --script res://tools/generate_level_tileset.gd
# 产出：res/levels/tilesets/factory_tileset.png（64x32，8 个 16x16 tile）
# tile 索引（4x2 网格）：0=metal_floor 1=brick_wall 2=pipe_h 3=pipe_v
#                        4=conveyor 5=gear 6=steel_beam 7=flag
extends SceneTree

const SAVE_PATH := "E:/desktop/try_game/game/res/levels/tilesets/factory_tileset.png"
const OUT := Color8(58, 40, 30)      # 深棕描边

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("E:/desktop/try_game/game/res/levels/tilesets")
	var img := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_draw_tile(img, 0, 0, _metal_floor)
	_draw_tile(img, 1, 0, _brick_wall)
	_draw_tile(img, 2, 0, _pipe_h)
	_draw_tile(img, 3, 0, _pipe_v)
	_draw_tile(img, 0, 1, _conveyor)
	_draw_tile(img, 1, 1, _gear)
	_draw_tile(img, 2, 1, _steel_beam)
	_draw_tile(img, 3, 1, _flag)
	img.save_png(SAVE_PATH)
	print("FACTORY TILESET SAVED -> ", SAVE_PATH)
	quit()


func _draw_tile(img: Image, tx: int, ty: int, painter: Callable) -> void:
	var o := Vector2i(tx * 16, ty * 16)
	painter.call(img, o)


func px(img: Image, o: Vector2i, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < 16 and y < 16:
		img.set_pixel(o.x + x, o.y + y, c)


func rect(img: Image, o: Vector2i, rx: int, ry: int, rw: int, rh: int, c: Color) -> void:
	for y in range(ry, ry + rh):
		for x in range(rx, rx + rw):
			px(img, o, x, y, c)


# ---- tile 0: 金属地砖 ----
func _metal_floor(img: Image, o: Vector2i) -> void:
	rect(img, o, 0, 0, 16, 16, Color8(138, 155, 168))
	rect(img, o, 0, 0, 16, 2, Color8(186, 200, 210))
	rect(img, o, 0, 14, 16, 2, Color8(92, 107, 118))
	px(img, o, 2, 2, Color8(66, 80, 90))
	px(img, o, 13, 2, Color8(66, 80, 90))
	px(img, o, 2, 13, Color8(66, 80, 90))
	px(img, o, 13, 13, Color8(66, 80, 90))


# ---- tile 1: 砖墙（错缝红砖） ----
func _brick_wall(img: Image, o: Vector2i) -> void:
	rect(img, o, 0, 0, 16, 16, Color8(181, 103, 63))
	var mortar := Color8(122, 69, 48)
	for row in range(4):
		rect(img, o, 0, row * 4, 16, 1, mortar)
		var offset := 8 if row % 2 == 1 else 0
		px(img, o, (offset + 8) % 16, row * 4 + 2, mortar)
		px(img, o, (offset + 8) % 16, row * 4 + 3, mortar)


# ---- tile 2: 水平管道（橙） ----
func _pipe_h(img: Image, o: Vector2i) -> void:
	for y in range(2, 14):
		var dy := absf(y - 7.5)
		var half := sqrt(maxf(0.0, 6.0 * 6.0 - dy * dy))
		for x in range(16):
			if absf(x - 7.5) <= half:
				px(img, o, x, y, Color8(224, 122, 63))
	rect(img, o, 0, 4, 16, 1, Color8(246, 176, 116))
	rect(img, o, 0, 12, 16, 1, Color8(168, 84, 40))
	# 管口端盖
	rect(img, o, 0, 2, 2, 12, Color8(120, 90, 70))
	rect(img, o, 14, 2, 2, 12, Color8(120, 90, 70))


# ---- tile 3: 垂直管道 ----
func _pipe_v(img: Image, o: Vector2i) -> void:
	for x in range(2, 14):
		var dx := absf(x - 7.5)
		var half := sqrt(maxf(0.0, 6.0 * 6.0 - dx * dx))
		for y in range(16):
			if absf(y - 7.5) <= half:
				px(img, o, x, y, Color8(224, 122, 63))
	rect(img, o, 4, 0, 1, 16, Color8(246, 176, 116))
	rect(img, o, 12, 0, 1, 16, Color8(168, 84, 40))
	rect(img, o, 2, 0, 12, 2, Color8(120, 90, 70))
	rect(img, o, 2, 14, 12, 2, Color8(120, 90, 70))


# ---- tile 4: 传送带（黑底黄斜纹） ----
func _conveyor(img: Image, o: Vector2i) -> void:
	rect(img, o, 0, 0, 16, 16, Color8(58, 58, 58))
	for y in range(0, 16, 4):
		rect(img, o, 0, y, 16, 2, Color8(232, 197, 71))
	rect(img, o, 0, 0, 16, 1, Color8(40, 40, 40))
	rect(img, o, 0, 15, 16, 1, Color8(40, 40, 40))


# ---- tile 5: 齿轮 ----
func _gear(img: Image, o: Vector2i) -> void:
	var c := Vector2(7.5, 7.5)
	for y in range(16):
		for x in range(16):
			var p := Vector2(x + 0.5, y + 0.5)
			var d := p.distance_to(c)
			var ang := atan2(p.y - c.y, p.x - c.x)
			var is_tooth := sin(ang * 4.0) > 0.45
			if d <= 4.5 or (d <= 7.5 and is_tooth):
				px(img, o, x, y, Color8(154, 165, 173))
			elif d <= 8.0 and is_tooth:
				px(img, o, x, y, OUT)
	for y in range(16):
		for x in range(16):
			if Vector2(x + 0.5, y + 0.5).distance_to(c) <= 1.5:
				px(img, o, x, y, Color8(70, 84, 94))


# ---- tile 6: 钢梁（平台） ----
func _steel_beam(img: Image, o: Vector2i) -> void:
	rect(img, o, 0, 0, 16, 16, Color8(126, 142, 153))
	rect(img, o, 0, 0, 16, 2, Color8(174, 188, 198))
	rect(img, o, 0, 14, 16, 2, Color8(88, 102, 112))
	px(img, o, 2, 2, Color8(66, 80, 90))
	px(img, o, 13, 2, Color8(66, 80, 90))
	px(img, o, 2, 13, Color8(66, 80, 90))
	px(img, o, 13, 13, Color8(66, 80, 90))


# ---- tile 7: 终点旗 ----
func _flag(img: Image, o: Vector2i) -> void:
	# 旗杆
	rect(img, o, 3, 1, 2, 14, Color8(120, 105, 90))
	# 旗面（红黄三角）
	for y in range(1, 8):
		var w := y
		rect(img, o, 5, y, w, 1, Color8(232, 92, 92) if y < 5 else Color8(232, 197, 71))
	# 底座
	rect(img, o, 1, 14, 6, 2, Color8(92, 82, 72))
