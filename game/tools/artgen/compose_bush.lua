-- bush 遮挡验证：把 bush 贴图叠在 51x51 紫红小鸡占位上，看是否完全遮住
local bushPath = "E:/deskbox/我的桌面/try_game/game/tools/artgen/mech/bush_0.png"
local outPath = "E:/deskbox/我的桌面/try_game/game/tools/artgen/verify/bush_cover_test.png"

local function pngSize(p)
  local f = io.open(p, "rb")
  f:seek(16)
  local b = f:read(8)
  f:close()
  return string.unpack(">I4", b, 1)
end
local function pngDim(p)
  local f = io.open(p, "rb")
  f:seek(16)
  local w = string.unpack(">I4", f:read(4), 1)
  local h = string.unpack(">I4", f:read(4), 1)
  f:close()
  return w, h
end
-- 直接用 Aseprite 打开源 .aseprite，访问第一帧首图层的 cel
local bushSprite = app.open(bushPath)
local bushImg = bushSprite.frames[1].layers[1].cel.image
local W, H = bushImg.width, bushImg.height
bushSprite:close()

-- 合成画布：上下左右各 padding=20，顶部留标题
local PAD = 20
local LABEL = 16
local W2 = W + PAD * 2
local H2 = H + PAD * 2 + LABEL
local canvas = Image(W2, H2, ColorMode.RGB)
canvas:clear(app.pixelColor.rgba(245, 247, 250, 255))

-- 标签：占位 "小鸡 51x51"
local LABEL_Y = 6
local function putPixelSafe(img, x, y, c)
  if x >= 0 and x < img.width and y >= 0 and y < img.height then img:drawPixel(x, y, c) end
end
-- 极简标签（用白底黑字几笔近似）
local function putTextRow(img, x0, y0, text, color)
  local px = color
  local ink = app.pixelColor.rgba(20, 20, 30, 255)
  local cur = x0
  for i = 1, #text do
    local ch = text:sub(i, i)
    local w = 3
    for dx = 0, w - 1 do putPixelSafe(img, cur + dx, y0, ink) end
    cur = cur + w + 1
  end
end
putTextRow(canvas, 4, LABEL_Y, "BUSH 144x124 (world 72x62)", app.pixelColor.rgba(0, 0, 0, 255))

-- 先画 51x51 紫红小鸡占位（左下贴 ground）
local cw, ch = 51, 51
local ox = PAD + math.floor((W - cw) / 2)
local oy = PAD + LABEL + (H - ch) - 2   -- 鸡身贴 ground，下边对齐 bush 下边
local chickFill = app.pixelColor.rgba(220, 50, 200, 255)
local chickEdge = app.pixelColor.rgba(45, 27, 46, 255)
for x = ox, ox + cw - 1 do
  putPixelSafe(canvas, x, oy, chickEdge)
  putPixelSafe(canvas, x, oy + ch - 1, chickEdge)
end
for y = oy, oy + ch - 1 do
  putPixelSafe(canvas, ox, y, chickEdge)
  putPixelSafe(canvas, ox + cw - 1, y, chickEdge)
end
for y = oy + 1, oy + ch - 2 do
  for x = ox + 1, ox + cw - 2 do putPixelSafe(canvas, x, y, chickFill) end
end

-- 再画 bush 贴图覆盖（这是关键测试：bush 透不透明？是否完全遮住）
for y = 0, H - 1 do
  for x = 0, W - 1 do
    local c = bushImg:getPixel(x, y)
    if app.pixelColor.rgbaA(c) > 0 then
      putPixelSafe(canvas, PAD + x, PAD + LABEL + y, c)
    end
  end
end

-- 画出 51x51 鸡身轮廓虚线（描红），便于肉眼确认是否有漏空
local markR = app.pixelColor.rgba(255, 0, 0, 255)
for x = ox, ox + cw - 1, 3 do
  putPixelSafe(canvas, x, oy, markR)
  putPixelSafe(canvas, x, oy + ch - 1, markR)
end
for y = oy, oy + ch - 1, 3 do
  putPixelSafe(canvas, ox, y, markR)
  putPixelSafe(canvas, ox + cw - 1, y, markR)
end

-- 保存
local out = Sprite(canvas.width, canvas.height, ColorMode.RGB)
out:newCel(out.layers[1], out.frames[1], canvas, Point(0, 0))
out:saveAs(outPath)
out:close()
print("cover test ok: " .. outPath)