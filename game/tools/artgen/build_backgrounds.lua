-- 纯背景版地图生成器：不含任何机制实体（平台/球门/掩体/墙等）
-- 机制实体后续由 mechanisms/ 独立组件场景承载
local W, H = 1200, 200
local DIR = "E:/deskbox/我的桌面/try_game/game/temp/"

local function hex(s)
  return app.pixelColor.rgba(
    tonumber(s:sub(2, 3), 16),
    tonumber(s:sub(4, 5), 16),
    tonumber(s:sub(6, 7), 16), 255)
end

local PC = app.pixelColor

local function px(img, x, y, c)
  if x >= 1 and x <= W and y >= 1 and y <= H then img:drawPixel(x, y, c) end
end

local function fill(img, x1, y1, x2, y2, c)
  for y = y1, y2 do
    for x = x1, x2 do img:drawPixel(x, y, c) end
  end
end

local function disc(img, cx, cy, r, c)
  for y = cy - r, cy + r do
    for x = cx - r, cx + r do
      if (x - cx) ^ 2 + (y - cy) ^ 2 <= r * r then px(img, x, y, c) end
    end
  end
end

local function ring(img, cx, cy, r, c)
  for y = cy - r, cy + r do
    for x = cx - r, cx + r do
      local d = math.sqrt((x - cx) ^ 2 + (y - cy) ^ 2)
      if d >= r - 1 and d <= r then px(img, x, y, c) end
    end
  end
end

local function border(img, c, t)
  t = t or 12
  fill(img, 1, 1, W, t, c)
  fill(img, 1, H - t + 1, W, H, c)
  fill(img, 1, 1, t, H, c)
  fill(img, W - t + 1, 1, W, H, c)
end

-- 简单垂直渐变（分段插值）
local function vgrad(img, y1, y2, c1, c2, x1, x2)
  x1, x2 = x1 or 1, x2 or W
  local n = y2 - y1
  local r1, g1, b1 = PC.rgbaR(c1), PC.rgbaG(c1), PC.rgbaB(c1)
  local r2, g2, b2 = PC.rgbaR(c2), PC.rgbaG(c2), PC.rgbaB(c2)
  for y = y1, y2 do
    local t = (y - y1) / math.max(1, n)
    local c = PC.rgba(
      math.floor(r1 + (r2 - r1) * t),
      math.floor(g1 + (g2 - g1) * t),
      math.floor(b1 + (b2 - b1) * t), 255)
    for x = x1, x2 do img:drawPixel(x, y, c) end
  end
end

math.randomseed(20260901)

local function build(name, drawBg, drawDeco)
  local spr = Sprite(W, H, ColorMode.RGB)
  local lbg = spr.layers[1]
  lbg.name = "bg"
  local ldeco = spr:newLayer()
  ldeco.name = "decor"

  local ibg = Image(W, H)
  drawBg(ibg)
  spr:newCel(lbg, 1, ibg)

  local ideco = Image(W, H)
  if drawDeco then drawDeco(ideco) end
  spr:newCel(ldeco, 1, ideco)

  app.command.SaveFile { filename = DIR .. name .. ".aseprite" }

  local out = Image(W, H)
  out:drawSprite(spr, 1)
  out:saveAs(DIR .. name .. "_preview.png")
  spr:close()
  print("done: " .. name)
end

-- ============ 1. jungle 丛林（纯背景） ============
local C_JUNG = {
  border = hex("#0d2410"), base = hex("#17521e"), silh = hex("#0f3d15"),
  silh2 = hex("#123a14"), vine = hex("#2e5d2a"), ground = hex("#4a3220"),
  grass = hex("#2e7d32"), grassHi = hex("#4caf50"), tuft = hex("#7cc94f"),
  flowerY = hex("#ffd54f"), flowerO = hex("#ff8a65"), flowerP = hex("#f7aef8")
}
build("jungle",
  function(img)
    border(img, C_JUNG.border)
    fill(img, 13, 13, W - 12, 174, C_JUNG.base)
    -- 顶部叶层：平缓波状剪影（不再用大圆丛，给藤蔓留干净背景）
    fill(img, 13, 13, W - 12, 26, C_JUNG.silh)
    for x = 13, W - 12 do
      local d = 26 + math.floor(math.sin(x * 0.02) * 3 + math.sin(x * 0.047) * 2)
      fill(img, x, 26, x, d, C_JUNG.silh)
      if math.sin(x * 0.031) > 0.55 then px(img, x, d + 1, hex("#0c3310")) end
    end
    -- 底部灌木剪影（贴地面上方）
    for x = 13, W - 12, 14 do
      local r = 4 + math.random(0, 4)
      disc(img, x, 175, r, C_JUNG.silh2)
    end
    -- 地面
    fill(img, 13, 175, W - 12, H - 12, C_JUNG.ground)
    fill(img, 13, 175, W - 12, 177, C_JUNG.grass)
    for x = 13, W - 12, 3 do
      if math.random() < 0.30 then px(img, x, 174, C_JUNG.tuft) end
      if math.random() < 0.12 then px(img, x, 175, C_JUNG.grassHi) end
    end
    for i = 1, 80 do
      px(img, 13 + math.random(0, W - 25), 180 + math.random(0, 6), hex("#3d2417"))
    end
  end,
  function(img)
    -- 垂藤（摆动曲线，从叶层下缘伸出，与叶层衔接）
    for i, vx in ipairs({ 120, 260, 420, 580, 730, 880, 1030, 1120 }) do
      local len = 35 + (i * 13) % 60
      local x = vx
      for y = 26, 26 + len do
        px(img, x, y, C_JUNG.vine)
        if y % 3 == 0 then x = x + (math.sin(y * 0.25 + i) > 0 and 1 or -1) end
        if y % 14 == 0 then px(img, x - 1, y, C_JUNG.vine) px(img, x + 1, y, C_JUNG.vine) end
      end
      px(img, x, 27 + len, C_JUNG.flowerY)
    end
    -- 花点缀
    for i = 1, 12 do
      local fx = 30 + math.random(0, W - 60)
      local fy = 30 + math.random(0, 130)
      local fc = (i % 3 == 0) and C_JUNG.flowerP or ((i % 2 == 0) and C_JUNG.flowerO or C_JUNG.flowerY)
      px(img, fx, fy, fc) px(img, fx + 1, fy, fc)
      px(img, fx, fy + 1, fc) px(img, fx + 1, fy + 1, fc)
    end
  end)

-- ============ 2. sky_arena 云端（纯背景，无边框） ============
local C_SKY = { c1 = hex("#7ec8e8"), c2 = hex("#aee3f5"), c3 = hex("#dff2fb"),
                c4 = hex("#f4fbfe"), cloud = hex("#ffffff"), far = hex("#d8eff9"),
                sea = hex("#dff2fb"), seaHi = hex("#ffffff"), sun = hex("#fff3b0") }
build("sky_arena",
  function(img)
    vgrad(img, 1, 70, C_SKY.c1, C_SKY.c2)
    vgrad(img, 71, 140, C_SKY.c2, C_SKY.c3)
    vgrad(img, 141, H, C_SKY.c3, C_SKY.c4)
    -- 太阳（右上）
    disc(img, 1080, 45, 20, C_SKY.sun)
    ring(img, 1080, 45, 25, hex("#eef7d8"))
  end,
  function(img)
    -- 远景云
    for _, cl in ipairs({ { 150, 40, 22 }, { 420, 70, 18 }, { 700, 35, 24 },
                          { 950, 90, 16 }, { 300, 110, 15 } }) do
      disc(img, cl[1], cl[2], cl[3], C_SKY.far)
      disc(img, cl[1] + cl[3], cl[2] + 3, cl[3] - 5, C_SKY.far)
      disc(img, cl[1] - cl[3], cl[2] + 4, cl[3] - 6, C_SKY.far)
      fill(img, cl[1] - cl[3] - 6, cl[2], cl[1] + cl[3] + 6, cl[2] + cl[3] - 4, C_SKY.far)
    end
    -- 主云（更白更近）
    for _, cl in ipairs({ { 220, 90, 20 }, { 560, 60, 26 }, { 860, 110, 18 }, { 1040, 150, 15 } }) do
      disc(img, cl[1], cl[2], cl[3], C_SKY.cloud)
      disc(img, cl[1] + cl[3] + 4, cl[2] + 4, cl[3] - 6, C_SKY.cloud)
      disc(img, cl[1] - cl[3] - 2, cl[2] + 5, cl[3] - 7, C_SKY.cloud)
      fill(img, cl[1] - cl[3] - 8, cl[2], cl[1] + cl[3] + 10, cl[2] + cl[3] - 3, C_SKY.cloud)
    end
    -- 底部云海
    for x = 1, W do
      local wave = math.floor(math.sin(x * 0.02) * 3 + math.sin(x * 0.05) * 2)
      fill(img, x, 186 + wave, x, H, C_SKY.sea)
      if (x + 100) % 90 < 30 then px(img, x, 185 + wave, C_SKY.seaHi) end
    end
  end)

-- ============ 3. eggball_stadium 球场看台（纯背景） ============
local C_STAD = { border = hex("#1e2a44"), stand = hex("#4a6b9e"), sep = hex("#31456b"),
                 fence = hex("#22314f"), rail = hex("#c9d4e8"),
                 lawn1 = hex("#3f9e44"), lawn2 = hex("#4caf50"),
                 adBg = hex("#f5f7fa"), cBlue = hex("#5bc0eb"), cYellow = hex("#f4d35e"),
                 cPink = hex("#f7aef8"), cOrange = hex("#ff8a65") }
build("eggball_stadium",
  function(img)
    border(img, C_STAD.border)
    -- 观众席（噪点观众）
    fill(img, 13, 13, W - 12, 148, C_STAD.stand)
    for i = 1, 9000 do
      local x = 13 + math.random(0, W - 26)
      local y = 13 + math.random(0, 134)
      local r = math.random()
      local c = (r < 0.25) and C_STAD.cBlue or ((r < 0.5) and C_STAD.cYellow
        or ((r < 0.72) and C_STAD.cPink or ((r < 0.85) and C_STAD.cOrange or hex("#5d7db3"))))
      px(img, x, y, c)
    end
    -- 看台分隔线
    fill(img, 13, 52, W - 12, 53, C_STAD.sep)
    fill(img, 13, 102, W - 12, 103, C_STAD.sep)
    -- 白色过道
    for _, ax in ipairs({ 150, 450, 750, 1050 }) do
      fill(img, ax, 13, ax + 5, 148, C_STAD.sep)
      fill(img, ax + 1, 13, ax + 4, 148, hex("#8fa3c7"))
    end
    -- 围栏带
    fill(img, 13, 149, W - 12, 174, C_STAD.fence)
    fill(img, 13, 150, W - 12, 150, C_STAD.rail)
    for x = 13, W - 12, 24 do fill(img, x, 151, x + 1, 174, C_STAD.sep) end
    -- 草坪（割草条纹）
    fill(img, 13, 175, W - 12, H - 12, C_STAD.lawn1)
    for x = 13, W - 12, 80 do fill(img, x, 175, x + 39, H - 12, C_STAD.lawn2) end
    for x = 13, W - 12, 5 do if math.random() < 0.2 then px(img, x, 174, hex("#5fc464")) end end
  end,
  function(img)
    -- 广告板点缀（围栏上彩块）
    local cols = { C_STAD.cBlue, C_STAD.cYellow, C_STAD.cPink, C_STAD.cOrange }
    for i, ax in ipairs({ 60, 240, 420, 600, 780, 960, 1120 }) do
      fill(img, ax, 158, ax + 40, 168, cols[(i - 1) % 4 + 1])
      fill(img, ax, 158, ax + 40, 159, hex("#ffffff"))
    end
  end)

-- ============ 4. cave_race 水晶洞（纯背景） ============
local C_CAVE = { border = hex("#1a0f2b"), base = hex("#241539"), stal = hex("#170d26"),
                 ground = hex("#3a2a52"), groundHi = hex("#524072"), groundSpk = hex("#6a5690"),
                 crys1 = hex("#7c5cff"), crys2 = hex("#4dd0e1"), crysHi = hex("#e0f7fa"),
                 spore = hex("#9ad7ff") }
build("cave_race",
  function(img)
    border(img, C_CAVE.border)
    fill(img, 13, 13, W - 12, 174, C_CAVE.base)
    -- 顶部钟乳石剪影
    for x = 13, W - 12, 16 do
      local len = 8 + math.random(0, 26)
      local w = 4 + math.random(0, 5)
      for dy = 0, len do
        local ww = math.max(1, math.floor(w * (1 - dy / len)))
        fill(img, x - ww, 13 + dy, x + ww, 13 + dy, C_CAVE.stal)
      end
    end
    -- 底部岩层纹理
    fill(img, 13, 175, W - 12, H - 12, C_CAVE.ground)
    fill(img, 13, 175, W - 12, 177, C_CAVE.groundHi)
    for i = 1, 90 do
      px(img, 13 + math.random(0, W - 26), 180 + math.random(0, 6), C_CAVE.groundSpk)
    end
  end,
  function(img)
    -- 水晶簇（菱形晶柱 + 亮缘 + 白尖高光 + 岩基座）
    local function crystal(cx, cy, w, h, c, cEdge)
      -- cy 为晶体底部
      for dy = 0, h do
        local ww = math.max(1, math.floor(w * (1 - dy / h)))
        fill(img, cx - ww, cy - dy, cx + ww, cy - dy, c)
      end
      -- 左缘受光亮边
      for dy = 0, h do
        local ww = math.max(1, math.floor(w * (1 - dy / h)))
        px(img, cx - ww, cy - dy, cEdge)
      end
      -- 中央竖向反光
      for dy = 2, math.floor(h * 0.55) do
        px(img, cx + 1, cy - dy, cEdge)
      end
      -- 顶尖白高光
      fill(img, cx - 1, cy - h, cx + 1, cy - h + 2, C_CAVE.crysHi)
      px(img, cx, cy - h - 1, C_CAVE.crysHi)
    end
    local function cluster(cx, cy, s)
      -- 岩石基座
      disc(img, cx, cy, s + 3, hex("#1c1030"))
      fill(img, cx - s - 3, cy, cx + s + 3, cy + 3, hex("#1c1030"))
      -- 主晶体 + 两侧副晶体（高低错落）
      crystal(cx, cy, s, s * 3, C_CAVE.crys1, hex("#a58aff"))
      crystal(cx - s - 3, cy + 1, math.max(2, math.floor(s * 0.6)), s * 2, C_CAVE.crys2, hex("#8ef0e8"))
      crystal(cx + s + 4, cy, math.max(2, math.floor(s * 0.5)), s + math.floor(s * 0.8), C_CAVE.crys2, hex("#8ef0e8"))
      crystal(cx + math.floor(s * 0.5), cy + 1, math.max(1, math.floor(s * 0.35)), s, C_CAVE.crys1, hex("#a58aff"))
    end
    for i, pos in ipairs({ { 100, 66 }, { 300, 106, }, { 520, 60 }, { 740, 116 },
                           { 920, 76 }, { 1100, 126 } }) do
      cluster(pos[1], pos[2], 9 + (i * 4) % 7)
    end
    -- 萤光孢子
    for i = 1, 45 do
      px(img, 20 + math.random(0, W - 40), 20 + math.random(0, 145), C_CAVE.spore)
    end
  end)

-- ============ 5. farm_peckmole 麦田黄昏（纯背景） ============
local C_FARM = { border = hex("#4a3418"), sky1 = hex("#f7c873"), sky2 = hex("#eda05f"),
                 sun = hex("#fdeab5"), hay = hex("#b0813a"), hayDk = hex("#96702f"),
                 field = hex("#c9982f"), stalk = hex("#a67c2e"), ear = hex("#e3bd45"),
                 ground = hex("#7a5230"), groundHi = hex("#8f6239"), stone = hex("#6a4526"),
                 bird = hex("#7a5230") }
build("farm_peckmole",
  function(img)
    border(img, C_FARM.border)
    vgrad(img, 13, 140, C_FARM.sky1, C_FARM.sky2)
    -- 低垂夕阳
    disc(img, 220, 128, 26, C_FARM.sun)
    ring(img, 220, 128, 31, hex("#fae3ae"))
    -- 远景麦垛剪影
    for _, h in ipairs({ { 480, 150, 22 }, { 560, 152, 16 }, { 900, 148, 24 }, { 990, 152, 15 } }) do
      disc(img, h[1], h[2], h[3], C_FARM.hay)
      fill(img, h[1] - h[3], h[2], h[1] + h[3], 174, C_FARM.hay)
      fill(img, h[1] - h[3], h[2], h[1] + h[3], h[2] + 2, C_FARM.hayDk)
    end
    -- 麦田带：纯远景色块（麦丛是藏身机制组件，后续在 mechanisms/ 单独做，不烘焙进背景）
    fill(img, 13, 141, W - 12, 174, C_FARM.field)
    fill(img, 13, 141, W - 12, 145, hex("#d4a435"))
    fill(img, 13, 146, W - 12, 158, C_FARM.field)
    fill(img, 13, 159, W - 12, 174, hex("#bd8d2a"))
    for i = 1, 120 do
      px(img, 13 + math.random(0, W - 26), 146 + math.random(0, 26), hex("#b5862a"))
    end
    -- 地面
    fill(img, 13, 175, W - 12, H - 12, C_FARM.ground)
    fill(img, 13, 175, W - 12, 177, C_FARM.groundHi)
    for i = 1, 70 do
      px(img, 13 + math.random(0, W - 26), 180 + math.random(0, 6), C_FARM.stone)
    end
  end,
  function(img)
    -- 飞鸟
    for _, b in ipairs({ { 700, 50 }, { 740, 42 }, { 780, 55 } }) do
      px(img, b[1], b[2], C_FARM.bird) px(img, b[1] + 1, b[2] + 1, C_FARM.bird)
      px(img, b[1] + 2, b[2], C_FARM.bird)
    end
  end)

-- ============ 6. night_maze 月夜（纯背景） ============
local C_NIGHT = { border = hex("#0b1120"), base1 = hex("#16203a"), base2 = hex("#101a30"),
                  moon = hex("#f4f1de"), crater = hex("#ded9c3"), halo = hex("#2a3860"),
                  star = hex("#f4f1de"), tree = hex("#0d1526"),
                  ground = hex("#1f2c4a"), groundHi = hex("#2a3b63"), moss = hex("#35507a"),
                  firefly = hex("#f7d794") }
build("night_maze",
  function(img)
    border(img, C_NIGHT.border)
    vgrad(img, 13, 130, C_NIGHT.base1, C_NIGHT.base2)
    fill(img, 13, 131, W - 12, 174, C_NIGHT.base2)
    -- 月亮 + 光晕
    ring(img, 950, 48, 30, C_NIGHT.halo)
    ring(img, 950, 48, 26, C_NIGHT.halo)
    disc(img, 950, 48, 20, C_NIGHT.moon)
    disc(img, 944, 42, 4, C_NIGHT.crater)
    disc(img, 956, 54, 3, C_NIGHT.crater)
    -- 星星
    for i = 1, 55 do
      px(img, 20 + math.random(0, W - 40), 16 + math.random(0, 110), C_NIGHT.star)
    end
    for _, s in ipairs({ { 180, 40 }, { 420, 70 }, { 640, 30 }, { 1100, 90 } }) do
      px(img, s[1], s[2], C_NIGHT.star)
      px(img, s[1] - 1, s[2], C_NIGHT.star) px(img, s[1] + 1, s[2], C_NIGHT.star)
      px(img, s[1], s[2] - 1, C_NIGHT.star) px(img, s[1], s[2] + 1, C_NIGHT.star)
    end
    -- 远处灌木剪影
    for x = 13, W - 12, 18 do
      local r = 5 + math.random(0, 5)
      disc(img, x, 175, r, C_NIGHT.tree)
    end
    -- 地面
    fill(img, 13, 175, W - 12, H - 12, C_NIGHT.ground)
    fill(img, 13, 175, W - 12, 177, C_NIGHT.groundHi)
    for x = 13, W - 12, 6 do
      if math.random() < 0.25 then px(img, x, 178, C_NIGHT.moss) end
    end
  end,
  function(img)
    -- 萤火
    for i = 1, 16 do
      local fx = 30 + math.random(0, W - 60)
      local fy = 90 + math.random(0, 70)
      px(img, fx, fy, C_NIGHT.firefly)
      px(img, fx + 1, fy, C_NIGHT.firefly)
    end
  end)

print("all backgrounds done")
