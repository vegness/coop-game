-- build_wheat.lua
-- 密集芦苇丛（藏身用，必须能完全遮住小鸡）144x124 像素，4 帧摆动
-- 贴图 = 世界尺寸 x2，故世界尺寸 72x62（小鸡约 51x51，可完全覆盖）
-- 每帧噪点用固定种子重置，保证 4 帧纹理一致、只有摆动位移变化（避免闪烁）

local DIR = "E:/deskbox/我的桌面/try_game/game/tools/artgen/mech/"
local W, H = 144, 124
local GROUND = 123      -- 丛体底部所在行（对应地面）
local X0, X1 = 16, 127  -- 丛体左右边界
local TOP_BASE = 26     -- 丛顶基准行
local TOPMOST = TOP_BASE - 14
local SWAY = { 0, 5, 0, -5 }

local function hex(s)
  return app.pixelColor.rgba(
    tonumber(s:sub(2, 3), 16), tonumber(s:sub(4, 5), 16), tonumber(s:sub(6, 7), 16), 255)
end

local C = {
  outline = hex("#2d1b2e"),
  soil = hex("#8f6239"), soilDark = hex("#7a5230"),
  top = hex("#8bc34a"), mid = hex("#5f9b2b"), bot = hex("#2b5314"),
  stem = hex("#3b6b1c"), hi = hex("#a8d95f"),
  leafA = hex("#9ed45b"), leafB = hex("#3f7020"),
  ear1 = hex("#e0b842"), ear2 = hex("#f2d57a"), ear3 = hex("#c2902f"),
}

local function mix(a, b, t)
  local ar = app.pixelColor.rgbaR(a); local ag = app.pixelColor.rgbaG(a); local ab = app.pixelColor.rgbaB(a)
  local br = app.pixelColor.rgbaR(b); local bg = app.pixelColor.rgbaG(b); local bb = app.pixelColor.rgbaB(b)
  return app.pixelColor.rgba(
    math.floor(ar + (br - ar) * t + 0.5),
    math.floor(ag + (bg - ag) * t + 0.5),
    math.floor(ab + (bb - ab) * t + 0.5), 255)
end

local function px(img, x, y, c)
  if x >= 0 and x < W and y >= 0 and y < H then img:drawPixel(x, y, c) end
end

local function fill(img, x1, y1, x2, y2, c)
  for y = y1, y2 do for x = x1, x2 do px(img, x, y, c) end end
end

-- 摆动位移：根部 0，越往上位移越大
local function dx_at(y, s)
  local t = (GROUND - y) / (GROUND - TOPMOST)
  if t < 0 then t = 0 end
  if t > 1 then t = 1 end
  local v = s * (t ^ 1.7)
  return (v >= 0) and math.floor(v + 0.5) or math.ceil(v - 0.5)
end

-- 丛顶参差轮廓（固定，4 帧共用）
local topY = {}
do
  math.randomseed(20260901)
  for x = X0 - 12, X1 + 12 do topY[x] = TOP_BASE + math.random(-5, 9) end
  for _ = 1, 2 do
    local cp = {}
    for x = X0 - 12, X1 + 12 do cp[x] = topY[x] end
    for x = X0 - 11, X1 + 11 do
      topY[x] = math.floor((cp[x - 1] + cp[x] + cp[x + 1]) / 3 + 0.5)
    end
  end
  for x = X0 - 11, X1 + 11 do
    topY[x] = math.floor(TOP_BASE + (topY[x] - TOP_BASE) * 1.7 + 0.5)
  end
end

local function top_at(x)
  local k = x
  if k < X0 - 11 then k = X0 - 11 end
  if k > X1 + 11 then k = X1 + 11 end
  return topY[k]
end

local function draw_wheat(img, f)
  math.randomseed(7777)  -- 每帧重置，保证纹理一致、只有摆动变化
  local s = SWAY[f + 1]

  -- 1 底部土带（两侧露出，营造"从土里长出"）
  fill(img, 4, 114, W - 5, GROUND, C.soil)
  for x = 4, W - 5 do
    if math.random() < 0.35 then px(img, x, 114 + math.random(0, 2), C.soilDark) end
  end
  fill(img, 4, GROUND, W - 5, GROUND, C.outline)

  -- 2 丛体主体：逐行填充，保证 100% 实心不透明（完全遮挡）
  local span = GROUND - TOPMOST
  for y = TOPMOST, GROUND do
    local dx = dx_at(y, s)
    local t = (y - TOPMOST) / span
    local base = (t < 0.45) and mix(C.top, C.mid, t / 0.45) or mix(C.mid, C.bot, (t - 0.45) / 0.55)
    for x = X0, X1 do
      if y >= topY[x] then
        local c = base
        local n = math.random()
        if n < 0.12 then c = mix(c, C.stem, 0.40)
        elseif n > 0.90 then c = mix(c, C.hi, 0.32) end
        if y > GROUND - 8 then c = mix(c, C.bot, 0.45) end
        px(img, x + dx, y, c)
      end
    end
  end

  -- 3 暗色竖茎（质感）
  for x = X0 + 2, X1 - 1, 4 do
    for y = topY[x], GROUND do px(img, x + dx_at(y, s), y, mix(C.stem, C.bot, 0.25)) end
  end

  -- 4 亮色高光茎
  for x = X0 + 4, X1 - 1, 7 do
    for y = topY[x] + 3, GROUND - 4 do px(img, x + dx_at(y, s), y, mix(C.hi, C.mid, 0.25)) end
  end

  -- 5 斜向叶片（交错填满，进一步加密）
  for _ = 1, 170 do
    local bx = X0 + math.random(0, X1 - X0)
    local by = topY[bx] + math.random(0, math.max(1, GROUND - topY[bx] - 2))
    local dir = (math.random() < 0.5) and 1 or -1
    local dy = (math.random() < 0.5) and 1 or -1
    local len = 5 + math.random(0, 9)
    local c = (math.random() < 0.55) and C.leafA or C.leafB
    for k = 0, len do
      local yy = by + math.floor(k * dy * 0.7)
      local xx = bx + dir * k
      local srcx = xx - dx_at(yy, s)
      if yy >= top_at(srcx) and yy <= GROUND - 1 then px(img, xx, yy, c) end
    end
  end

  -- 6 顶部麦穗（伸出丛顶轮廓之上）
  for x = X0 + 3, X1 - 3, 5 do
    if math.random() < 0.78 then
      local y0 = topY[x]
      local hh = 8 + math.random(0, 12)
      local bend = (math.random() < 0.5) and 1 or -1
      local x0 = x + dx_at(y0, s)
      for k = 0, hh do
        px(img, x0 + math.floor(bend * k * 0.35), y0 - k, mix(C.ear3, C.ear1, 0.4))
      end
      local ex = x0 + math.floor(bend * hh * 0.35)
      local ey = y0 - hh + 3
      for dy = -6, 3 do
        local ww = math.max(0, math.floor(2.6 * (1 - math.abs(dy) / 7)))
        for ddx = -ww, ww do px(img, ex + ddx, ey + dy, (dy < -2) and C.ear2 or C.ear1) end
      end
      px(img, ex, ey - 6, C.ear2)
    end
  end
end

--------------------------------------------------------------------
local spr = Sprite(W, H, ColorMode.RGB)
local layer = spr.layers[1]
layer.name = "art"
for f = 1, 4 do
  if f > 1 then spr:newFrame() end
  local img = Image(W, H)
  draw_wheat(img, f - 1)
  spr:newCel(layer, f, img)
  img:saveAs(DIR .. "wheat_" .. (f - 1) .. ".png")
end
app.command.SaveFile { filename = DIR .. "wheat.aseprite" }
spr:close()
print("done: wheat dense 144x124 x4")
