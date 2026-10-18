-- Build jungle battle map 1200x200 (×0.4 -> 480x80)
local spr = Sprite(1200, 200, ColorMode.RGB)

local C = {
  outline = Color{r=15,  g=46,  b=18},
  bg      = Color{r=23,  g=82,  b=30},
  sil     = Color{r=15,  g=61,  b=21},
  border  = Color{r=46,  g=93,  b=42},
  body    = Color{r=46,  g=125, b=50},
  shadow  = Color{r=27,  g=58,  b=18},
  grass   = Color{r=76,  g=175, b=80},
  tuft    = Color{r=124, g=201, b=79},
  vine    = Color{r=102, g=187, b=106},
  yellow  = Color{r=255, g=213, b=79},
  orange  = Color{r=255, g=138, b=101},
}

-- palette for the file
local pal = Palette(12)
local cols = {
  {0,0,0},{15,46,18},{23,82,30},{15,61,21},{46,93,42},{46,125,50},
  {27,58,18},{76,175,80},{124,201,79},{102,187,106},{255,213,79},{255,138,101}
}
for i,c in ipairs(cols) do pal:setColor(i-1, Color{r=c[1],g=c[2],b=c[3]}) end
spr:setPalette(pal)

-- layers (bottom -> top)
spr.layers[1].name = "bg"
local layPlat = spr:newLayer(); layPlat.name = "platforms"
local layDeco = spr:newLayer(); layDeco.name = "decor"

local imgBg   = Image(spr.spec)
local imgPlat = Image(spr.spec)
local imgDeco = Image(spr.spec)

local function rect(img,x1,y1,x2,y2,c)
  for y=y1,y2 do
    for x=x1,x2 do img:drawPixel(x,y,c) end
  end
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

-------------- BG: interior + leaf silhouettes --------------
rect(imgBg,12,12,1187,187,C.bg)
-- canopy silhouettes hanging from top
ell(imgBg,40,6,320,52,C.sil)
ell(imgBg,420,4,700,40,C.sil)
ell(imgBg,880,6,1160,54,C.sil)
ell(imgBg,300,10,470,44,C.sil)
ell(imgBg,720,10,900,46,C.sil)
-- undergrowth silhouettes at bottom
ell(imgBg,20,140,200,190,C.sil)
ell(imgBg,1000,140,1180,190,C.sil)
ell(imgBg,500,152,700,192,C.sil)
ell(imgBg,240,160,380,192,C.sil)
ell(imgBg,820,160,960,192,C.sil)

-------------- PLATFORMS: border + ground + floating bars --------------
-- border 12px
rect(imgPlat,0,0,1199,11,C.border)
rect(imgPlat,0,188,1199,199,C.border)
rect(imgPlat,0,0,11,199,C.border)
rect(imgPlat,1188,0,1199,199,C.border)
-- outer 1px dark outline
for x=0,1199 do
  imgPlat:drawPixel(x,0,C.outline); imgPlat:drawPixel(x,199,C.outline)
end
for y=0,199 do
  imgPlat:drawPixel(0,y,C.outline); imgPlat:drawPixel(1199,y,C.outline)
end
-- inner rim shadow where border meets interior
rect(imgPlat,12,12,1187,13,C.shadow)
rect(imgPlat,12,186,1187,187,C.shadow)
rect(imgPlat,12,12,13,187,C.shadow)
rect(imgPlat,1186,12,1187,187,C.shadow)

-- ground
rect(imgPlat,12,176,1187,177,C.grass)
rect(imgPlat,12,178,1187,187,C.body)

-- floating platforms {x1, y1, x2} bar height 10
local plats = {
  {120,40,260},{480,40,640},{860,40,1000},
  {60,95,180},{320,95,440},{700,95,820},{1040,95,1140},
  {180,148,280},{520,148,620},{940,148,1040},
}
for _,p in ipairs(plats) do
  local x1,y1,x2 = p[1],p[2],p[3]
  rect(imgPlat,x1,y1,x2,y1+9,C.body)
  rect(imgPlat,x1,y1,x2,y1+1,C.grass)     -- grass top
  rect(imgPlat,x1,y1+9,x2,y1+9,C.shadow)  -- underside shadow
  -- hanging moss strands
  rect(imgPlat,x1+10,y1+10,x1+10,y1+12,C.shadow)
  rect(imgPlat,math.floor((x1+x2)/2),y1+10,math.floor((x1+x2)/2),y1+11,C.shadow)
end

-------------- DECOR: vines / bushes / tufts / leaves / flowers --------------
math.randomseed(42)

-- hanging vine with wiggle + leaf pairs
local function vine(x, len, phase)
  for i=0,len-1 do
    local wob = math.floor(1.4*math.sin((i+phase)/4.5))
    imgDeco:drawPixel(x+wob, 12+i, C.vine)
    if i % 18 == 9 then
      local d = (math.floor((i+phase)/18)%2==0) and -1 or 1
      rect(imgDeco, x+wob+d, 12+i, x+wob+d*2, 12+i+1, C.grass)
    end
  end
  imgDeco:drawPixel(x, 12+len, C.tuft)
end
vine(150,95,0); vine(310,70,3); vine(520,105,1)
vine(760,85,2); vine(905,95,4); vine(1100,65,5)

-- canopy danglers (leaf bunches)
local function dangler(x)
  rect(imgDeco,x,12,x+5,18,C.body)
  rect(imgDeco,x+1,19,x+4,24,C.body)
  rect(imgDeco,x+2,25,x+3,28,C.grass)
  imgDeco:drawPixel(x+2,29,C.shadow)
end
dangler(380); dangler(645); dangler(835)

-- bushes along the ground
for bx=60,1180,150 do
  ell(imgDeco,bx-34,168,bx+34,186,C.body)
end
for bx=135,1180,300 do
  ell(imgDeco,bx-18,173,bx+18,181,C.grass)
end

-- grass tufts above ground line (sparse, short)
for x=12,1187 do
  local r = math.random()
  if r < 0.22 then imgDeco:drawPixel(x,175,C.tuft)
  elseif r < 0.40 then imgDeco:drawPixel(x,175,C.grass) end
  if r > 0.90 then imgDeco:drawPixel(x,174,C.tuft) end
  if r > 0.98 then imgDeco:drawPixel(x,173,C.grass) end
end

-- big leaves poking from side borders
local function leftLeaf(y)
  for i=0,12 do imgDeco:drawPixel(12+i, y-math.floor(i/3), C.grass) end
  for i=0,8  do imgDeco:drawPixel(12+i, y+math.floor(i/3), C.body)  end
end
local function rightLeaf(y)
  for i=0,12 do imgDeco:drawPixel(1187-i, y-math.floor(i/3), C.grass) end
  for i=0,8  do imgDeco:drawPixel(1187-i, y+math.floor(i/3), C.body)  end
end
leftLeaf(30); leftLeaf(66); leftLeaf(100); leftLeaf(134)
rightLeaf(48); rightLeaf(82); rightLeaf(116); rightLeaf(150)

-- candy flowers
local flowers = {
  {70,170},{230,168},{390,171},{560,169},{760,170},{920,168},{1090,170},
  {150,39},{530,39},{915,39},{130,94},{770,94},{240,147},{990,147}
}
for i,f in ipairs(flowers) do
  local c = (i%2==0) and C.orange or C.yellow
  imgDeco:drawPixel(f[1],f[2],c)
  imgDeco:drawPixel(f[1]+1,f[2],c)
end

-- attach images to layers
spr:newCel(spr.layers[1], 1, imgBg)
spr:newCel(layPlat, 1, imgPlat)
spr:newCel(layDeco, 1, imgDeco)

spr:saveAs("E:/deskbox/我的桌面/try_game/game/tools/artgen/out/jungle.aseprite")
spr:saveCopyAs("E:/deskbox/我的桌面/try_game/game/tools/artgen/out/jungle.png")
print("jungle map built")
