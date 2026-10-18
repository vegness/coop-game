-- compose_test.lua (简化版：纯像素绘制)
local wheat_path = "E:/deskbox/我的桌面/try_game/game/tools/artgen/mech/wheat_0.png"
local chick_path = "E:\\deskbox\\我的桌面\\try_game\\game\\res\\chick\\blue\\stop\\1.png"
local OUT = "E:/deskbox/我的桌面/try_game/game/tools/artgen/verify/wheat_cover_test.png"

local wheat = app.open(wheat_path)
local chick = app.open(chick_path)
local Ww, Hw = wheat.width, wheat.height
local Wc, Hc = chick.width, chick.height

local SCALE = 0.08
local cw = math.floor(Wc * SCALE + 0.5)
local ch = math.floor(Hc * SCALE + 0.5)

local padding = 14
local labelH = 16
local W = padding + Ww + cw + padding
local H = labelH + padding + Hw + padding

local out = Sprite(W, H, ColorMode.RGBA)
local layer = out.layers[1]
layer.name = "test"
local img = Image(W, H)

local function px(x, y, c)
  if x >= 0 and x < W and y >= 0 and y < H then img:drawPixel(x, y, c) end
end

-- 天空蓝底
local sky = app.pixelColor.rgba(135, 206, 235, 255)
for y = 0, H - 1 do for x = 0, W - 1 do px(x, y, sky) end end

-- 标题条
local titleBg = app.pixelColor.rgba(45, 27, 46, 255)
for y = 0, labelH - 1 do for x = 0, W - 1 do px(x, y, titleBg) end end
local titleFg = app.pixelColor.rgba(240, 240, 240, 255)
-- 简易 "WHEAT" 风格条带（不用真字体）
for i, c in ipairs({ 1, 1, 0, 1, 1, 0, 1, 1 }) do
  for x = 4 + (i - 1) * 12, 12 + (i - 1) * 12 do for y = 4, labelH - 5 do px(x, y, titleFg) end end
end

-- 地面线
local groundY = labelH + padding + Hw - 1
local groundCol = app.pixelColor.rgba(45, 27, 46, 255)
for x = 0, W - 1 do px(x, groundY + 1, groundCol) end

-- 小鸡参考（亮紫红 51x51 矩形）—— 先画，作为被遮挡物
local chickFill = app.pixelColor.rgba(220, 50, 200, 255)
local chickEdge = app.pixelColor.rgba(45, 27, 46, 255)
local chickY = labelH + padding + Hw - ch
local chickX = padding + math.floor((Ww - cw) / 2 + 0.5)
-- 鸡身填充（先内部后描边，避免描边被覆盖）
for y = chickY + 1, chickY + ch - 2 do
  for x = chickX + 1, chickX + cw - 2 do px(x, y, chickFill) end
end
for x = chickX, chickX + cw - 1 do
  px(x, chickY, chickEdge)
  px(x, chickY + ch - 1, chickEdge)
end
for y = chickY, chickY + ch - 1 do
  px(chickX, y, chickEdge)
  px(chickX + cw - 1, y, chickEdge)
end

-- wheat 像素 —— 后画，作为前景遮挡
local wheatImg = wheat.cels[1].image
local oxW = padding
local oyW = labelH + padding
for y = 0, Hw - 1 do
  for x = 0, Ww - 1 do
    local c = wheatImg:getPixel(x, y)
    if app.pixelColor.rgbaA(c) > 0 then img:drawPixel(oxW + x, oyW + y, c) end
  end
end

out:newCel(layer, 1, img)
img:saveAs(OUT)
print("saved test:", OUT, "size:", W, "x", H)
out:close()
wheat:close()
chick:close()