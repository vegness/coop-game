-- 机制组件美术生成器（解耦版）
-- 规格：贴图 = 世界尺寸 ×2，组件 tscn 内 Sprite2D scale=0.5（与 movingfloor 一致）
local DIR = "E:/deskbox/我的桌面/try_game/game/tools/artgen/mech/"
local PC = app.pixelColor

local function hex(s)
  return PC.rgba(tonumber(s:sub(2, 3), 16), tonumber(s:sub(4, 5), 16),
                 tonumber(s:sub(6, 7), 16), 255)
end
local function px(img, x, y, c) img:drawPixel(x, y, c) end
local function fill(img, x1, y1, x2, y2, c)
  for y = y1, y2 do for x = x1, x2 do img:drawPixel(x, y, c) end end
end
local function disc(img, cx, cy, r, c)
  for y = cy - r, cy + r do
    for x = cx - r, cx + r do
      if (x - cx) ^ 2 + (y - cy) ^ 2 <= r * r then img:drawPixel(x, y, c) end
    end
  end
end
local function ellip(img, cx, cy, rx, ry, c)
  for y = cy - ry, cy + ry do
    for x = cx - rx, cx + rx do
      if ((x - cx) / rx) ^ 2 + ((y - cy) / ry) ^ 2 <= 1 then img:drawPixel(x, y, c) end
    end
  end
end

math.randomseed(20260901)

-- name: 输出文件名；frames: 帧数（>1 时逐帧调用 drawFn(img, frameIndex) 并导出多张 png）
local function build(name, w, h, frames, drawFn)
  local spr = Sprite(w, h, ColorMode.RGB)
  local layer = spr.layers[1]
  layer.name = "art"
  frames = frames or 1
  for f = 1, frames do
    if f > 1 then spr:newFrame() end
    local img = Image(w, h)
    drawFn(img, f - 1)
    spr:newCel(layer, f, img)
    if frames > 1 then
      img:saveAs(DIR .. name .. "_" .. (f - 1) .. ".png")
    end
  end
  app.command.SaveFile { filename = DIR .. name .. ".aseprite" }
  if frames == 1 then
    local out = Image(w, h)
    out:drawSprite(spr, 1)
    out:saveAs(DIR .. name .. ".png")
  end
  spr:close()
  print("done: " .. name)
end

local OUTLINE = hex("#2d1b2e")

--------------------------------------------------------------------
-- 1. platform 静态悬浮平台（草顶石木台）200x40
--------------------------------------------------------------------
local function draw_platform(img, f)
  fill(img, 0, 0, 199, 39, hex("#8d6e4a"))
  -- 草顶
  fill(img, 0, 0, 199, 7, hex("#2e7d32"))
  for x = 0, 199 do
    local d = 7 + math.floor(math.sin(x * 0.15) * 1.5)
    fill(img, x, 7, x, d, hex("#2e7d32"))
    if x % 3 == 0 then px(img, x, d - 1, hex("#4caf50")) end
    if x % 7 == 0 then px(img, x, 0, hex("#7cc94f")) end
  end
  -- 石身纹理
  for i = 1, 220 do
    px(img, math.random(0, 199), 10 + math.random(0, 24), hex("#75593c"))
  end
  fill(img, 0, 32, 199, 39, hex("#5d4530"))
  -- 描边
  fill(img, 0, 0, 0, 39, OUTLINE) fill(img, 199, 0, 199, 39, OUTLINE)
  fill(img, 0, 39, 199, 39, OUTLINE)
  fill(img, 0, 0, 199, 0, hex("#1f5c24"))
end

-- 变体：石质平台（洞穴主题）
local function draw_platform_stone(img, f)
  fill(img, 0, 0, 199, 39, hex("#7a8296"))
  -- 顶部苔层
  fill(img, 0, 0, 199, 5, hex("#4c7a3a"))
  for x = 0, 199 do
    local d = 5 + math.floor(math.sin(x * 0.12) * 1.5)
    fill(img, x, 5, x, d, hex("#4c7a3a"))
    if x % 5 == 0 then px(img, x, 0, hex("#6ba34d")) end
  end
  -- 石块分缝
  for y = 12, 34, 11 do
    fill(img, 0, y, 199, y, hex("#5d6474"))
    local off = (y / 11) % 2 == 0 and 0 or 22
    for x = off, 199, 44 do fill(img, x, y, x, y + 10, hex("#5d6474")) end
  end
  for i = 1, 120 do px(img, math.random(0, 199), 10 + math.random(0, 24), hex("#8f97a8")) end
  fill(img, 0, 33, 199, 39, hex("#59606f"))
  fill(img, 0, 0, 0, 39, OUTLINE) fill(img, 199, 0, 199, 39, OUTLINE)
  fill(img, 0, 39, 199, 39, OUTLINE)
end

--------------------------------------------------------------------
-- 2. platform_rot 旋转平台 160x32（中心轴 + 转向箭头）
--------------------------------------------------------------------
local function draw_platform_rot(img, f)
  fill(img, 0, 0, 159, 31, hex("#a9793f"))
  fill(img, 0, 0, 159, 2, hex("#c99552"))
  fill(img, 0, 27, 159, 31, hex("#6f4a22"))
  -- 木纹
  for y = 5, 26, 5 do fill(img, 0, y, 159, y, hex("#8a5f30")) end
  -- 中心轴盘
  disc(img, 80, 16, 9, hex("#37474f"))
  disc(img, 80, 16, 7, hex("#cfd8e3"))
  disc(img, 80, 16, 3, hex("#37474f"))
  -- 转向箭头（两端小三角）
  for _, ax in ipairs({ 22, 138 }) do
    local dir = (ax == 22) and 1 or -1
    for i = 0, 5 do
      for j = -i, i do px(img, ax + dir * i, 16 + j, hex("#f4d35e")) end
    end
  end
  -- 描边
  fill(img, 0, 0, 159, 0, OUTLINE) fill(img, 0, 31, 159, 31, OUTLINE)
  fill(img, 0, 0, 0, 31, OUTLINE) fill(img, 159, 0, 159, 31, OUTLINE)
end

--------------------------------------------------------------------
-- 3. goal 球门 120x140（右侧半开门，左侧用 flip_h 镜像）
--------------------------------------------------------------------
local function draw_goal(img, f)
  fill(img, 0, 0, 119, 139, hex("#b9d8ea"))       -- 网后阴影
  -- 网面
  for y = 12, 139, 10 do fill(img, 12, y, 108, y, hex("#dfe7ef")) end
  for x = 12, 108, 10 do fill(img, x, 12, x, 139, hex("#dfe7ef")) end
  for y = 12, 139, 10 do
    for x = 12, 108, 10 do px(img, x, y, hex("#f4f1de")) end
  end
  -- 门柱与横梁（糖果条纹）
  fill(img, 0, 0, 119, 11, hex("#f4f1de"))
  fill(img, 96, 0, 119, 139, hex("#f4f1de"))
  for y = 0, 139, 16 do
    fill(img, 96, y, 119, y + 7, hex("#ff8a65"))
    if y < 12 then fill(img, 0, 0, 119, 0, hex("#ff8a65")) end
  end
  for x = 0, 119, 16 do fill(img, x, 0, x + 7, 11, hex("#ff8a65")) end
  -- 描边
  fill(img, 0, 0, 119, 0, OUTLINE) fill(img, 0, 0, 0, 11, OUTLINE)
  fill(img, 0, 11, 95, 11, OUTLINE) fill(img, 119, 0, 119, 139, OUTLINE)
  fill(img, 96, 0, 96, 139, OUTLINE) fill(img, 96, 139, 119, 139, OUTLINE)
end

--------------------------------------------------------------------
-- 4. haystack 草垛掩体 160x120（顶部开洞 = 探头点）
--------------------------------------------------------------------
local function draw_haystack(img, f)
  fill(img, 0, 0, 159, 119, hex("#c9a227"))
  -- 圆顶轮廓（上方削角）
  ellip(img, 80, 46, 78, 46, hex("#c9a227"))
  for y = 0, 46 do
    local halfw = math.floor(78 * math.sqrt(math.max(0, 1 - ((46 - y) / 46) ^ 2)))
    fill(img, 80 - halfw, y, 80 + halfw, y, hex("#c9a227"))
  end
  fill(img, 2, 46, 157, 119, hex("#c9a227"))
  -- 干草纹理
  for i = 1, 900 do
    local hx = 4 + math.random(0, 151)
    local hy = 10 + math.random(0, 104)
    local len = 2 + math.random(0, 4)
    for k = 0, len do px(img, hx + k, hy + math.floor(k / 2), hex("#a8851f")) end
  end
  for i = 1, 200 do px(img, 4 + math.random(0, 151), 12 + math.random(0, 100), hex("#e0bd4a")) end
  -- 顶部开洞（探头口）
  ellip(img, 80, 30, 26, 13, hex("#3b2a12"))
  ellip(img, 80, 30, 22, 10, hex("#241a0b"))
  for a = 0, 359, 3 do
    local rx, ry = 26, 13
    local x = 80 + math.floor(math.cos(math.rad(a)) * rx)
    local y = 30 + math.floor(math.sin(math.rad(a)) * ry)
    px(img, x, y, hex("#e0bd4a"))
  end
  -- 底部阴影与描边
  fill(img, 2, 112, 157, 119, hex("#8a6d18"))
  for y = 0, 119 do
    for _, xx in ipairs({ 1, 158 }) do
      if img:getPixel(xx, y) ~= 0 or y > 40 then px(img, xx, y, hex("#4a3418")) end
    end
  end
end

--------------------------------------------------------------------
-- 5. wheat 麦丛 100x80（4 帧摆动，小鸡进出时播放）
--------------------------------------------------------------------
local function draw_wheat(img, f)
  local sway = { 0, 4, 0, -4 }   -- 4 帧摆动位移
  local s = sway[f + 1]
  fill(img, 0, 0, 99, 79, 0)      -- 透明底
  -- 底部土
  fill(img, 10, 74, 89, 79, hex("#8f6239"))
  for x = 10, 89 do if math.random() < 0.3 then px(img, x, 74, hex("#7a5230")) end end
  -- 麦秆
  local stalks = { 18, 30, 42, 50, 58, 70, 82 }
  for i, bx in ipairs(stalks) do
    local hh = 40 + ((i * 7) % 16)
    local top = 79 - hh
    local bend = s * ((79 - top) / 60) * (1 + (i % 3) * 0.25)
    for dy = 0, hh - 6 do
      local t = dy / hh
      local x = bx + math.floor(bend * t * t)
      local y = 79 - dy
      px(img, x, y, hex("#c9982f"))
      px(img, x + 1, y, hex("#a67c2e"))
    end
    -- 麦穗
    local ex = bx + math.floor(bend)
    local ey = top + 5
    ellip(img, ex, ey, 3, 6, hex("#e3bd45"))
    ellip(img, ex, ey - 5, 2, 3, hex("#f2d57a"))
    for k = 1, 3 do
      px(img, ex - 2 + math.random(0, 4), ey - 2 + math.random(0, 8), hex("#c9982f"))
    end
  end
end

--------------------------------------------------------------------
-- 6. wall 立墙 64x200（砖石，垂墙复用同图旋转）
--------------------------------------------------------------------
local function draw_wall(img, f)
  fill(img, 0, 0, 63, 199, hex("#7a8296"))
  local bh, bw = 20, 32
  for row = 0, 9 do
    local y0 = row * bh
    local off = (row % 2 == 0) and 0 or -bw / 2
    for col = -1, 2 do
      local x0 = off + col * bw
      fill(img, math.max(0, x0), math.max(0, y0 + 2), math.min(63, x0 + bw - 2),
           math.min(199, y0 + bh - 2), hex("#8f97a8"))
    end
    fill(img, 0, y0, 63, y0 + 1, hex("#5d6474"))
  end
  for i = 1, 200 do px(img, math.random(0, 63), math.random(0, 199), hex("#6b7382")) end
  -- 顶部苔草
  for x = 0, 63 do
    if math.random() < 0.45 then
      px(img, x, 0, hex("#4caf50")) px(img, x, 1, hex("#3f9e44"))
    end
  end
  -- 底部加重
  fill(img, 0, 192, 63, 199, hex("#5a616f"))
  -- 侧描边
  fill(img, 0, 0, 0, 199, OUTLINE) fill(img, 63, 0, 63, 199, OUTLINE)
  fill(img, 0, 199, 63, 199, OUTLINE)
end

--------------------------------------------------------------------
-- 7. pit 断坑 200x60（两侧石沿 + 中央深渊）
--------------------------------------------------------------------
local function draw_pit(img, f)
  fill(img, 0, 0, 199, 59, hex("#1a1420"))
  -- 深渊渐变
  for y = 0, 59 do
    local t = y / 59
    local c = PC.rgba(
      math.floor(26 - 16 * t), math.floor(20 - 12 * t), math.floor(32 - 20 * t), 255)
    fill(img, 18, y, 181, y, c)
  end
  for i = 1, 150 do px(img, 18 + math.random(0, 163), math.random(0, 59), hex("#2b2334")) end
  -- 两侧石沿
  for _, x0 in ipairs({ 0, 182 }) do
    fill(img, x0, 0, x0 + 17, 59, hex("#6a5a48"))
    fill(img, x0, 0, x0 + 17, 3, hex("#8a7760"))
    for i = 1, 90 do
      px(img, x0 + math.random(0, 17), 4 + math.random(0, 54), hex("#574a3b"))
    end
    fill(img, x0, 56, x0 + 17, 59, hex("#4a3f31"))
  end
  -- 上沿暗边
  fill(img, 0, 0, 199, 0, hex("#2d1b2e"))
  fill(img, 18, 0, 181, 1, hex("#0f0b16"))
end

--------------------------------------------------------------------
-- 8. start_flag 起点旗 60x160
--------------------------------------------------------------------
local function draw_start_flag(img, f)
  -- 底座
  ellip(img, 12, 152, 14, 7, hex("#7a8296"))
  ellip(img, 12, 150, 11, 5, hex("#9aa4b5"))
  -- 杆
  fill(img, 8, 20, 15, 156, hex("#cfd8e3"))
  fill(img, 8, 20, 9, 156, hex("#f4f1de"))
  fill(img, 15, 20, 15, 156, hex("#7a8296"))
  disc(img, 12, 18, 4, hex("#f4d35e"))
  -- 旗面（波浪）
  for y = 24, 60 do
    local wave = math.floor(math.sin((y - 24) * 0.28) * 3)
    local x1 = 16
    local x2 = 52 + wave
    for x = x1, x2 do
      local band = ((y - 24) / 6) % 2 < 1
      px(img, x, y, band and hex("#ff8a65") or hex("#f4f1de"))
    end
  end
  -- 旗面描边
  for y = 24, 60 do
    local wave = math.floor(math.sin((y - 24) * 0.28) * 3)
    px(img, 52 + wave, y, OUTLINE)
  end
  fill(img, 16, 24, 51, 24, OUTLINE)
  fill(img, 16, 60, 51, 60, OUTLINE)
end

--------------------------------------------------------------------
build("platform", 200, 40, 1, draw_platform)
build("platform_stone", 200, 40, 1, draw_platform_stone)
build("platform_rot", 160, 32, 1, draw_platform_rot)
build("goal", 120, 140, 1, draw_goal)
build("haystack", 160, 120, 1, draw_haystack)
build("wheat", 100, 80, 4, draw_wheat)
build("wall", 64, 200, 1, draw_wall)
build("pit", 200, 60, 1, draw_pit)
build("start_flag", 60, 160, 1, draw_start_flag)

print("all mech art done")
