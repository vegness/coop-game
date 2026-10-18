-- 普通草丛 bush v2：7 束叶片组合，每束有外轮廓 + 顶部叶尖 + 束间留暗缝
-- 尺寸 144x124（世界 72x62），4 帧摆动
local OUT = "E:/deskbox/我的桌面/try_game/game/tools/artgen/mech/"
local W, H = 144, 124
local GROUND = H - 1

local function rgba(r, g, b, a) return app.pixelColor.rgba(r, g, b, a or 255) end
local function hexc(s)
  return rgba(tonumber(s:sub(2, 3), 16), tonumber(s:sub(4, 5), 16), tonumber(s:sub(6, 7), 16), 255)
end

local C_OUTLINE = hexc("#1e4a1a")
local C_DARK    = hexc("#2e7d32")
local C_MID     = hexc("#4caf50")
local C_LIGHT   = hexc("#7cc94f")
local C_HI      = hexc("#a5d66a")

-- 7 束草丛（束中心 x，束宽，束高）—— 圆润矮丘，避免尖锐山尖
local CLUSTERS = {
  { cx = 18,  bw = 22, bh = 36, lean = -0.5 },
  { cx = 42,  bw = 24, bh = 52, lean = -0.2 },
  { cx = 64,  bw = 24, bh = 64, lean =  0.1 },
  { cx = 86,  bw = 26, bh = 70, lean = -0.1 },
  { cx = 108, bw = 22, bh = 60, lean =  0.2 },
  { cx = 128, bw = 22, bh = 46, lean =  0.3 },
  { cx = 142, bw = 16, bh = 30, lean =  0.4 },
}

-- 计算每列的"最高点"（用于遮挡验证和摆动位移）
local TOPS = {}
for x = 0, W - 1 do TOPS[x] = GROUND end
for _, c in ipairs(CLUSTERS) do
  for x = c.cx - c.bw, c.cx + c.bw do
    if x >= 0 and x < W then
      local u = (x - c.cx) / c.bw
      if u < -1 then u = -1 end
      if u > 1 then u = 1 end
      local top = GROUND - math.floor(c.bh * (1 - u * u) + 0.5)
      -- 顶部加叶尖（每个束中心加 1-2 片更高叶尖）
      if math.abs(u) < 0.2 then top = top - 3 end
      if top < TOPS[x] then TOPS[x] = top end
    end
  end
end

-- 在每列做"高度变化"：束中心 1-2px 叶尖突起 + 整列下边沿
local function clusterTop(c, x)
  local u = (x - c.cx) / c.bw
  if u < -1 then u = -1 end
  if u > 1 then u = 1 end
  -- u^4 圆润曲线（边缘柔软、中央稍平），避免尖锐山顶
  local top = GROUND - math.floor(c.bh * (1 - u * u * u * u) + 0.5)
  return top
end

-- 生成基础贴图（不摆动），返回 Image
local function build_base()
  local img = Image(W, H)
  img:clear()
  math.randomseed(1337)

  -- 1) 每束主体实心（圆润拱形，无额外叶尖）
  for _, c in ipairs(CLUSTERS) do
    for x = c.cx - c.bw, c.cx + c.bw do
      if x >= 0 and x < W then
        local top = clusterTop(c, x)
        for y = top, GROUND do
          if y >= 0 and y < H then img:drawPixel(x, y, C_MID) end
        end
      end
    end
  end

  -- 2) 顶部高光带（每列顶部 4-6px 范围）
  for x = 0, W - 1 do
    local top = TOPS[x]
    for y = top, top + 5 do
      if y >= 0 and y < H then
        local px0 = img:getPixel(x, y)
        if app.pixelColor.rgbaA(px0) > 0 then
          if y == top then img:drawPixel(x, y, C_HI)
          elseif y == top + 1 then img:drawPixel(x, y, C_LIGHT)
          elseif y == top + 2 then img:drawPixel(x, y, C_LIGHT)
          end
        end
      end
    end
  end

  -- 3) 底部暗部（每列底部 12px）
  for x = 0, W - 1 do
    local top = TOPS[x]
    for y = GROUND - 12, GROUND do
      if y >= top and y < H then
        local px0 = img:getPixel(x, y)
        if app.pixelColor.rgbaA(px0) > 0 then img:drawPixel(x, y, C_DARK) end
      end
    end
  end

  -- 4) 中间主体分片深浅纹：每隔 6-9 列做一道稍深的纵向线（叶片暗示）
  math.randomseed(9001)
  for x = 0, W - 1 do
    if math.random() < 0.25 then
      local top = TOPS[x]
      for y = top + 6, GROUND - 14 do
        local px0 = img:getPixel(x, y)
        if app.pixelColor.rgbaA(px0) > 0 and img:getPixel(x, y) == C_MID then
          img:drawPixel(x, y, C_DARK)
        end
      end
    end
  end

  -- 5) 描边（深绿）：凡实心像素上方/左/右相邻空像素处补描边
  local solid = {}
  for x = 0, W - 1 do
    solid[x] = {}
    for y = 0, H - 1 do
      solid[x][y] = app.pixelColor.rgbaA(img:getPixel(x, y)) > 0
    end
  end
  for x = 0, W - 1 do
    for y = 0, H - 1 do
      if not solid[x][y] then
        local above = (y > 0) and solid[x][y - 1]
        local left  = (x > 0) and solid[x - 1][y]
        if above or left then img:drawPixel(x, y, C_OUTLINE) end
      end
    end
  end
  return img
end

-- 摆动采样：底部 0、顶部 amp*t^1.7
local function build_frame(baseImg, amp)
  local out = Image(W, H)
  out:clear()
  for y = 0, H - 1 do
    local t = (GROUND - y) / (GROUND - 0)
    if t < 0 then t = 0 end
    if t > 1 then t = 1 end
    local dx = amp * (t ^ 1.7)
    for x = 0, W - 1 do
      local sx = math.floor(x - dx + 0.5)
      if sx >= 0 and sx < W then
        local c = baseImg:getPixel(sx, y)
        if app.pixelColor.rgbaA(c) > 0 then out:drawPixel(x, y, c) end
      end
    end
  end
  return out
end

-- 主流程
local base = build_base()
local sp = Sprite(W, H, ColorMode.RGB)
sp.filename = OUT .. "bush.aseprite"
local layer = sp.layers[1]
layer.name = "bush"
local amps = { 0.0, 1.4, 0.0, -1.4 }
for f = 1, 4 do
  if f > 1 then sp:newEmptyFrame() end
  local fr = sp.frames[f]
  sp:newCel(layer, fr, build_frame(base, amps[f]), Point(0, 0))
  fr.duration = 0.13
end
sp:saveAs(OUT .. "bush.aseprite")

-- 导出 4 帧 png（每帧独立重新画，避免 cel API 差异）
for f = 1, 4 do
  local one = Sprite(W, H, ColorMode.RGB)
  one:newCel(one.layers[1], one.frames[1], build_frame(base, amps[f]), Point(0, 0))
  one:saveAs(OUT .. "bush_" .. (f - 1) .. ".png")
  one:close()
end

print("bush v2 done: " .. W .. "x" .. H)
