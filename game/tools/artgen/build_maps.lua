-- Build 5 themed battle maps, 1200x200 each, same 3-layer convention as jungle
local OUT = "E:/deskbox/我的桌面/try_game/game/tools/artgen/out/"

local function col(t) return Color{r=t[1],g=t[2],b=t[3]} end

local function makeSprite(palCols)
  local spr = Sprite(1200, 200, ColorMode.RGB)
  local pal = Palette(#palCols)
  for i,c in ipairs(palCols) do pal:setColor(i-1, col(c)) end
  spr:setPalette(pal)
  spr.layers[1].name = "bg"
  local lp = spr:newLayer(); lp.name = "platforms"
  local ld = spr:newLayer(); ld.name = "decor"
  return spr, Image(spr.spec), Image(spr.spec), Image(spr.spec), lp, ld
end

local function rect(img,x1,y1,x2,y2,c)
  for y=y1,y2 do for x=x1,x2 do img:drawPixel(x,y,c) end end
end

local function ell(img,x1,y1,x2,y2,c)
  local cx=(x1+x2)/2; local cy=(y1+y2)/2
  local rx=math.max((x2-x1)/2,0.5); local ry=math.max((y2-y1)/2,0.5)
  for y=y1,y2 do
    for x=x1,x2 do
      local dx=(x-cx)/rx; local dy=(y-cy)/ry
      if dx*dx+dy*dy <= 1.05 then img:drawPixel(x,y,c) end
    end
  end
end

local function ellOutline(img,x1,y1,x2,y2,c)
  local cx=(x1+x2)/2; local cy=(y1+y2)/2
  local rx=(x2-x1)/2; local ry=(y2-y1)/2
  for y=y1,y2 do
    for x=x1,x2 do
      local dx=(x-cx)/rx; local dy=(y-cy)/ry
      local d=dx*dx+dy*dy
      if d<=1.05 and d>=0.72 then img:drawPixel(x,y,c) end
    end
  end
end

local function outlineRect(img,c)
  for x=0,1199 do img:drawPixel(x,0,c); img:drawPixel(x,199,c) end
  for y=0,199 do img:drawPixel(0,y,c); img:drawPixel(1199,y,c) end
end

local function saveMap(spr,bg,plat,deco,lp,ld,name)
  spr:newCel(spr.layers[1],1,bg)
  spr:newCel(lp,1,plat)
  spr:newCel(ld,1,deco)
  spr:saveAs(OUT..name..".aseprite")
  spr:saveCopyAs(OUT..name.."_preview.png")
  print("built "..name)
end

---------------------------------------------------------------
-- 1) sky_arena  -- KnockOut: no walls at all, fall = out
---------------------------------------------------------------
local function skyArena()
  local P = {
    {191,233,250},{158,216,240},{126,195,224},{255,255,255},{207,232,244},
    {168,212,232},{255,213,79},{126,210,106},{185,138,90},{143,98,56},{240,250,255}
  }
  local spr,bg,plat,deco,lp,ld = makeSprite(P)
  local skyTop,skyLow,skyDeep = col(P[1]),col(P[2]),col(P[3])
  local cloud,cloudSh,cloudDk = col(P[4]),col(P[5]),col(P[6])
  local sun,grass,dirt,dirtDk,spark = col(P[7]),col(P[8]),col(P[9]),col(P[10]),col(P[11])

  rect(bg,0,0,1199,99,skyTop)
  rect(bg,0,100,1199,159,skyLow)
  rect(bg,0,160,1199,199,skyDeep)
  ell(bg,1070,16,1160,66,sun)
  ell(bg,1090,26,1140,56,col{255,236,150})

  local function puff(img,x,y,s,c)
    ell(img,x,y,x+18*s,y+8*s,c)
    ell(img,x+10*s,y-4*s,x+30*s,y+6*s,c)
    ell(img,x+24*s,y,x+42*s,y+9*s,c)
  end
  puff(bg,60,36,2.2,cloudSh)
  puff(bg,380,22,1.6,cloudSh)
  puff(bg,680,40,2.0,cloudSh)
  puff(bg,920,76,1.4,cloudSh)

  -- central main island
  rect(plat,480,148,720,164,dirt)
  ell(plat,468,148,492,164,dirt)
  ell(plat,708,148,732,164,dirt)
  rect(plat,468,148,732,153,grass)
  ell(plat,468,148,492,153,grass)
  ell(plat,708,148,732,153,grass)
  rect(plat,560,165,640,167,dirtDk)
  rect(plat,585,168,615,170,dirtDk)

  -- cloud platforms
  local function cloudPlat(x1,y1,x2,y2)
    rect(plat,x1,y1,x2,y2,cloud)
    ell(plat,x1-6,y1,x1+2,y2,cloud)
    ell(plat,x2-2,y1,x2+6,y2,cloud)
    rect(plat,x1-6,y2-2,x2+6,y2,cloudSh)
    ell(plat,x1-4,y2-3,x1+2,y2,cloudSh)
    ell(plat,x2-2,y2-3,x2+4,y2,cloudSh)
  end
  cloudPlat(196,112,344,126)
  cloudPlat(856,112,1004,126)
  cloudPlat(430,56,544,68)
  cloudPlat(656,56,770,68)
  cloudPlat(40,88,128,100)
  cloudPlat(1072,88,1160,100)

  -- birds + sparkles
  local function bird(x,y)
    deco:drawPixel(x,y,cloudDk)
    deco:drawPixel(x+1,y-1,cloudDk)
    deco:drawPixel(x+2,y,cloudDk)
  end
  bird(300,70); bird(660,44); bird(900,92)
  math.randomseed(7)
  for i=1,24 do
    deco:drawPixel(math.random(20,1180),math.random(20,170),spark)
  end

  saveMap(spr,bg,plat,deco,lp,ld,"sky_arena")
end

---------------------------------------------------------------
-- 2) eggball_stadium -- EggBall: symmetric goals + net
---------------------------------------------------------------
local function eggballStadium()
  local P = {
    {34,86,40},{74,160,68},{99,200,79},{88,188,70},{244,255,242},
    {138,90,51},{106,70,38},{223,240,208},{255,213,79},{255,110,92},{53,120,48}
  }
  local spr,bg,plat,deco,lp,ld = makeSprite(P)
  local outline,wall,pitch,stripe,white = col(P[1]),col(P[2]),col(P[3]),col(P[4]),col(P[5])
  local wood,woodDk,net,yellow,red,bgDeep = col(P[6]),col(P[7]),col(P[8]),col(P[9]),col(P[10]),col(P[11])

  -- pitch with mow stripes
  rect(bg,12,12,1187,187,pitch)
  for x=12,1187,160 do rect(bg,x,12,math.min(x+79,1187),175,stripe) end

  -- stadium wall border
  rect(plat,0,0,1199,11,wall)
  rect(plat,0,188,1199,199,wall)
  rect(plat,0,0,11,199,wall)
  rect(plat,1188,0,1199,199,wall)
  outlineRect(plat,outline)
  rect(plat,12,12,1187,13,white) -- top rail

  -- field markings
  rect(plat,12,170,1187,171,white)          -- touch line
  rect(plat,598,14,601,169,white)           -- center line
  ellOutline(plat,545,122,655,168,white)    -- center circle
  rect(plat,599,169,600,170,white)          -- kick-off spot

  -- goals
  local function goalLeft()
    rect(plat,12,114,74,116,wood)          -- crossbar
    rect(plat,72,116,74,175,wood)          -- front post
    rect(plat,12,118,71,175,net)           -- net area
    for x=12,71,6 do rect(plat,x,118,x,175,woodDk) end
    for y=118,175,6 do rect(plat,12,y,71,y,woodDk) end
    rect(plat,12,118,12,175,woodDk)
  end
  local function goalRight()
    rect(plat,1126,114,1188,116,wood)
    rect(plat,1126,116,1128,175,wood)
    rect(plat,1129,118,1188,175,net)
    for x=1129,1188,6 do rect(plat,x,118,x,175,woodDk) end
    for y=118,175,6 do rect(plat,1129,y,1188,y,woodDk) end
    rect(plat,1188,118,1188,175,woodDk)
  end
  goalLeft(); goalRight()

  -- floating obstacles
  rect(plat,370,86,464,95,wood)
  rect(plat,370,86,464,87,white)
  rect(plat,736,86,830,95,wood)
  rect(plat,736,86,830,87,white)

  -- corner flags
  local function flag(x)
    rect(deco,x,150,x,168,white)
    rect(deco,x+1,150,x+6,154,red)
  end
  flag(20); flag(1179)

  -- accents
  deco:drawPixel(300,40,yellow); deco:drawPixel(301,40,yellow)
  deco:drawPixel(880,44,red);    deco:drawPixel(881,44,red)

  saveMap(spr,bg,plat,deco,lp,ld,"eggball_stadium")
end

---------------------------------------------------------------
-- 3) cave_race -- Race: start left, portal right, pits
---------------------------------------------------------------
local function caveRace()
  local P = {
    {27,19,48},{36,26,56},{26,18,44},{122,106,138},{86,72,104},
    {58,48,76},{110,231,231},{224,110,231},{126,210,106},{255,255,255},{255,213,79}
  }
  local spr,bg,plat,deco,lp,ld = makeSprite(P)
  local outline,bgc,bgDeep,stoneL,stoneM = col(P[1]),col(P[2]),col(P[3]),col(P[4]),col(P[5])
  local stoneD,cyan,magenta,green,white,glow = col(P[6]),col(P[7]),col(P[8]),col(P[9]),col(P[10]),col(P[11])
  local pit = col{12,8,22}

  -- background
  rect(bg,12,12,1187,187,bgc)
  rect(bg,12,130,1187,187,bgDeep)
  ell(bg,150,60,340,120,stoneD)
  ell(bg,520,40,700,100,stoneD)
  ell(bg,880,70,1080,130,stoneD)

  -- side/top walls
  rect(plat,0,0,11,199,stoneM)
  rect(plat,1188,0,1199,199,stoneM)
  rect(plat,0,0,1199,11,stoneM)
  outlineRect(plat,outline)
  for y=20,190,12 do
    rect(plat,0,y,11,y,stoneD)
    rect(plat,1188,y,1199,y,stoneD)
  end

  -- stalactites
  math.randomseed(11)
  local xs = {40,120,210,300,390,470,560,650,740,830,920,1010,1100,1160}
  for _,x in ipairs(xs) do
    local h = math.random(6,16)
    for i=0,h do
      plat:drawPixel(x,12+i,stoneL)
      if i < h-3 then plat:drawPixel(x+1,12+i,stoneM) end
    end
  end

  -- ground segments with pits between
  local segs = {{12,220},{280,470},{540,760},{830,1000},{1060,1187}}
  for _,s in ipairs(segs) do
    rect(plat,s[1],168,s[2],187,stoneM)
    rect(plat,s[1],168,s[2],170,stoneL)
    rect(plat,s[1],184,s[2],187,stoneD)
  end
  -- pit darkness in gaps
  rect(bg,221,176,279,187,pit)
  rect(bg,471,176,539,187,pit)
  rect(bg,761,176,829,187,pit)
  rect(bg,1001,176,1059,187,pit)

  -- step platforms
  rect(plat,500,128,568,138,stoneM); rect(plat,500,128,568,130,stoneL)
  rect(plat,600,100,668,110,stoneM); rect(plat,600,100,668,102,stoneL)
  rect(plat,350,122,410,132,stoneM); rect(plat,350,122,410,124,stoneL)
  rect(plat,860,132,930,142,stoneM); rect(plat,860,132,930,134,stoneL)

  -- start flag
  rect(deco,40,140,41,167,white)
  rect(deco,42,140,58,150,green)

  -- finish portal
  ell(deco,1096,124,1174,184,cyan)
  ell(deco,1112,138,1158,170,white)
  ell(deco,1124,146,1146,162,glow)

  -- crystals
  local function crystal(x,y,c)
    deco:drawPixel(x,y,c)
    deco:drawPixel(x,y-1,c)
    deco:drawPixel(x,y-2,c)
    deco:drawPixel(x-1,y,c)
    deco:drawPixel(x+1,y,c)
  end
  crystal(90,167,cyan);   crystal(96,167,magenta)
  crystal(330,167,magenta); crystal(430,167,cyan)
  crystal(700,167,cyan);  crystal(900,167,magenta)
  crystal(1030,167,cyan); crystal(180,167,magenta)
  crystal(260,11,cyan);   crystal(620,11,magenta)

  saveMap(spr,bg,plat,deco,lp,ld,"cave_race")
end

---------------------------------------------------------------
-- 4) farm_peckmole -- PeckMole: hay bunkers with peek holes
---------------------------------------------------------------
local function farmPeckmole()
  local P = {
    {58,36,23},{255,238,194},{138,90,51},{107,68,38},{224,176,85},
    {185,138,58},{242,207,107},{106,176,76},{255,255,255},{154,106,58},
    {255,214,120},{43,28,18}
  }
  local spr,bg,plat,deco,lp,ld = makeSprite(P)
  local outline,sky,soil,soilDk,hay = col(P[1]),col(P[2]),col(P[3]),col(P[4]),col(P[5])
  local hayDk,wheat,green,white,fence,sun,hole = col(P[6]),col(P[7]),col(P[8]),col(P[9]),col(P[10]),col(P[11]),col(P[12])

  rect(bg,12,12,1187,187,sky)
  ell(bg,40,20,130,60,sun)
  ell(bg,940,120,1180,187,col{214,190,130})
  ell(bg,20,130,240,187,col{214,190,130})

  -- fence border
  rect(plat,0,0,1199,11,fence)
  rect(plat,0,188,1199,199,fence)
  rect(plat,0,0,11,199,fence)
  rect(plat,1188,0,1199,199,fence)
  outlineRect(plat,outline)
  for x=0,1199,24 do
    plat:drawPixel(x,0,outline); plat:drawPixel(x,199,outline)
  end

  -- soil ground
  rect(plat,12,178,1187,187,soil)
  rect(plat,12,176,1187,177,soilDk)
  math.randomseed(23)
  for x=16,1183,5 do
    if math.random() < 0.35 then
      plat:drawPixel(x,175,wheat)
      if math.random() < 0.5 then plat:drawPixel(x,174,wheat) end
    end
  end

  -- hay mounds with peek holes
  local mounds = {{150,148},{320,136},{490,148},{660,136},{830,148},{1000,136}}
  for _,m in ipairs(mounds) do
    local x,topY = m[1],m[2]
    ell(plat,x-46,topY,x+46,182,hay)
    local cy=(topY+182)/2; local ry=(182-topY)/2
    for yy=topY+6,180,7 do
      local dy=(yy-cy)/ry
      local w=math.floor(40*math.sqrt(math.max(0,1-dy*dy)))
      if w>2 then rect(plat,x-w,yy,x+w,yy,hayDk) end
    end
    ell(plat,x-7,topY-5,x+7,topY+3,hole)
    if x%2==0 then
      deco:drawPixel(x,topY-7,white)
      deco:drawPixel(x+2,topY-6,white)
    end
  end

  -- wheat sheaves + leaves decor
  local spots = {{70,170},{240,172},{560,171},{740,170},{910,172},{1100,171}}
  for _,s in ipairs(spots) do
    deco:drawPixel(s[1],s[2],wheat); deco:drawPixel(s[1],s[2]-1,wheat)
    deco:drawPixel(s[1]+3,s[2],green)
  end

  saveMap(spr,bg,plat,deco,lp,ld,"farm_peckmole")
end

---------------------------------------------------------------
-- 5) night_maze -- ImposterChicken: sight blockers everywhere
---------------------------------------------------------------
local function nightMaze()
  local P = {
    {13,10,26},{28,21,51},{36,27,64},{245,240,208},{255,255,255},
    {74,67,102},{52,46,77},{47,77,58},{66,110,80},{255,154,77},
    {143,122,224},{90,82,120}
  }
  local spr,bg,plat,deco,lp,ld = makeSprite(P)
  local outline,bgc,hill,moon,white = col(P[1]),col(P[2]),col(P[3]),col(P[4]),col(P[5])
  local stone,stoneD,bushD,bushL,pump,wisp,stoneL = col(P[6]),col(P[7]),col(P[8]),col(P[9]),col(P[10]),col(P[11]),col(P[12])

  rect(bg,12,12,1187,187,bgc)
  -- moon + stars
  ell(bg,60,20,124,58,moon)
  bg:drawPixel(85,35,stoneD); bg:drawPixel(100,44,stoneD)
  math.randomseed(99)
  for i=1,40 do
    local x=math.random(140,1180); local y=math.random(14,110)
    if math.random() < 0.8 then bg:drawPixel(x,y,white)
    else bg:drawPixel(x,y,wisp) end
  end
  -- hills
  ell(bg,120,150,420,210,hill)
  ell(bg,360,160,640,214,hill)
  ell(bg,600,150,900,210,hill)
  ell(bg,860,160,1160,214,hill)

  -- border walls
  rect(plat,0,0,1199,11,stoneD)
  rect(plat,0,188,1199,199,stoneD)
  rect(plat,0,0,11,199,stoneD)
  rect(plat,1188,0,1199,199,stoneD)
  outlineRect(plat,outline)

  -- ground
  rect(plat,12,176,1187,187,stone)
  rect(plat,12,176,1187,177,stoneL)

  -- brick walls: ground-up blockers
  local function wallUp(x1,y1,x2,y2)
    rect(plat,x1,y1,x2,y2,stone)
    for y=y1+6,y2,9 do rect(plat,x1,y,x2,y,stoneD) end
    rect(plat,x1,y1,x2,y1+1,stoneL)
  end
  wallUp(200,110,212,175)
  wallUp(480,84,492,175)
  wallUp(760,110,772,175)
  wallUp(1000,95,1012,175)
  -- hanging walls
  wallUp(340,12,352,78)
  wallUp(620,12,632,58)
  wallUp(900,12,912,68)

  -- bushes at wall bases
  local bushes = {{150,168,240,187},{430,170,530,187},{700,168,800,187},{930,170,1030,187},{60,170,140,187},{1060,170,1160,187}}
  for _,b in ipairs(bushes) do
    ell(deco,b[1],b[2],b[3],b[4],bushD)
    ell(deco,b[1]+14,b[2]+8,b[3]-26,b[4]-3,bushL)
  end

  -- pumpkins
  local pks = {{250,171},{560,171},{820,171},{1060,171},{40,171}}
  for _,p in ipairs(pks) do
    rect(deco,p[1],p[2],p[1]+2,p[2]+2,pump)
    deco:drawPixel(p[1]+1,p[2]-1,bushL)
  end
  -- wisps
  deco:drawPixel(300,60,wisp); deco:drawPixel(301,60,wisp)
  deco:drawPixel(680,90,wisp); deco:drawPixel(1000,50,wisp)

  saveMap(spr,bg,plat,deco,lp,ld,"night_maze")
end

skyArena()
eggballStadium()
caveRace()
farmPeckmole()
nightMaze()
print("all maps built")
