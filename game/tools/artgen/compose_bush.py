# bush 遮挡验证：把 bush_0.png 叠在 51x51 紫红小鸡占位上，看是否完全遮住
from PIL import Image, ImageDraw

bush_path = r"E:/deskbox/我的桌面/try_game/game/tools/artgen/mech/bush_0.png"
out_path = r"E:/deskbox/我的桌面/try_game/game/tools/artgen/verify/bush_cover_test.png"

bush = Image.open(bush_path).convert("RGBA")
W, H = bush.size
PAD = 20
LABEL = 16
canvas = Image.new("RGB", (W + PAD * 2, H + PAD * 2 + LABEL), (245, 247, 250))
d = ImageDraw.Draw(canvas)

# 标签
d.text((4, 4), "BUSH 144x124 (world 72x62)", fill=(20, 20, 30))

# 51x51 紫红小鸡占位（贴 bush 下边）
cw = ch = 51
ox = PAD + (W - cw) // 2
oy = PAD + LABEL + (H - ch) - 2
d.rectangle([ox, oy, ox + cw - 1, oy + ch - 1], outline=(45, 27, 46), fill=(220, 50, 200))

# 把 bush 贴图叠上去
canvas.paste(bush, (PAD, PAD + LABEL), bush)

# 红虚线描出鸡身轮廓（4 px 一段）
for x in range(ox, ox + cw, 3):
    d.point((x, oy), fill=(255, 0, 0))
    d.point((x, oy + ch - 1), fill=(255, 0, 0))
for y in range(oy, oy + ch, 3):
    d.point((ox, y), fill=(255, 0, 0))
    d.point((ox + cw - 1, y), fill=(255, 0, 0))

canvas.save(out_path)
print("cover test ok:", out_path)