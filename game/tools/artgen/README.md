# 像素美术生成脚本集（tools/artgen/）

全部走 **Aseprite CLI + Lua 程序化绘制**，不用 Aseprite MCP（MCP 有中文路径乱码 + 单帧精灵绘制报 "frame 1 out of range" 两个坑，见文末）。

## 快速开始

```bash
ASE="/e/Aseprite/aseprite.exe"

# 1) 6 张对战背景 → 输出到 game/temp/
"$ASE" -b --script "E:\deskbox\我的桌面\try_game\game\tools\artgen\build_backgrounds.lua"

# 2) 机制组件贴图 → 输出到 tools/artgen/mech/
"$ASE" -b --script "E:\deskbox\我的桌面\try_game\game\tools\artgen\build_mech_art.lua"

# 3) 单独重画草丛 bush → 输出到 tools/artgen/mech/
"$ASE" -b --script "E:\deskbox\我的桌面\try_game\game\tools\artgen\build_bush.lua"

# 4) 草丛遮挡验证（PIL 合成图）→ 输出到 tools/artgen/verify/
"C:\Users\50416\.workbuddy\binaries\python\versions\3.13.12\python.exe" \
  "E:\deskbox\我的桌面\try_game\game\tools\artgen\compose_bush.py"
```

> ✅ 已验证：**中文路径下 Aseprite CLI 可正常读写**，脚本可直接放在项目 `tools/artgen/` 下运行。

## 脚本清单

| 脚本 | 状态 | 输出位置 | 说明 |
| --- | --- | --- | --- |
| `build_backgrounds.lua` | ✅ 主力 | `game/temp/` | 6 张对战背景（1200×200，纯背景版，bg/decor 两层）。确定性随机，重跑输出与现有文件 md5 一致 |
| `build_mech_art.lua` | ✅ 主力 | `tools/artgen/mech/` | 8 类机制组件贴图（platform / platform_stone / platform_rot / goal / haystack / wall / pit / start_flag） |
| `build_bush.lua` | ✅ 主力 | `tools/artgen/mech/` | 草丛藏身点 bush，7 束圆润草团 + 4 帧摆动（144×124 → 世界 72×62） |
| `compose_bush.py` | ✅ 主力 | `tools/artgen/verify/` | PIL 合成遮挡验证图：51×51 紫红鸡身占位是否被 bush 完全盖住 |
| `build_wheat.lua` | 🗄 历史 | `mech/` | 芦苇丛旧版（已由 bush 取代），保留供对比 |
| `compose_test.lua` | 🗄 历史 | `verify/` | 芦苇丛版遮挡验证（Aseprite Lua 实现，已被 compose_bush.py 取代） |
| `build_maps.lua` | 🗄 历史 | `out/` | 第 1 版 5 张玩法导向地图（**含机制实体**，已废弃，仅留档） |
| `build_jungle.lua` | 🗄 历史 | `out/` | 第 1 版丛林地图（含平台，已废弃，仅留档） |

## 目录结构

```
tools/artgen/
├── README.md
├── *.lua / *.py          生成脚本
├── mech/                 组件贴图输出（.aseprite 源文件 + .png）
├── verify/               遮挡/合成验证图
└── out/                  历史脚本输出（避免污染根目录）
```

## 产物如何进入游戏

脚本只产出**贴图**，进入游戏需手动拷到 `mechanisms/<组件名>/` 并建 tscn：

```
mechanisms/bush/
├── bush.aseprite / bush_0..3.png    ← 从 tools/artgen/mech/ 拷入
├── bush.gd                          ← 手写逻辑
└── bush.tscn                        ← 手放碰撞体，根 scale=0.5
```

拷完记得跑一次导入：
```bash
"E:/godot/Godot_v4.6.1-stable_mono_win64/Godot_v4.6.1-stable_mono_win64_console.exe" --headless --import
```

## 改参数速查

| 想改什么 | 改哪里 |
| --- | --- |
| 草丛束数 / 高低 / 宽窄 | `build_bush.lua` 顶部 `CLUSTERS` 数组（`cx`/`bw`/`bh`） |
| 草丛摆动幅度 | `build_bush.lua` 的 `amps = { 0.0, 1.4, 0.0, -1.4 }` |
| 草丛配色 | `build_bush.lua` 的 `C_OUTLINE`/`C_DARK`/`C_MID`/`C_LIGHT`/`C_HI` |
| 背景配色 / 装饰密度 | `build_backgrounds.lua` 中各主题的 `C_XXX` 色表与噪点循环次数 |

## Aseprite Lua 踩坑备忘

1. **颜色不能用 `Color{}` 的 `.r` 字段插值** → 用 `app.pixelColor.rgba(r,g,b,a)` 生成整型像素，`app.pixelColor.rgbaA(c)` 取 alpha
2. **没有 `math.pow`** → 用 `^` 运算符（如 `t ^ 1.7`）
3. **导出多帧 png**：`sprite.cels`/`frame.layers` 都不可用，最稳的是每帧 `Sprite(w,h)` 新建 → `newCel` → `saveAs` → `close`
4. **`sp:setPalette()` 不接受 `Color` 对象**（要 `Palette`），删掉这行即可
5. **新建 sprite 只有 1 帧**，加帧用 `sp:newEmptyFrame()`

## Aseprite MCP 的两个已知坑（所以改用 CLI）

1. **中文路径乱码**：路径含非 ASCII（如 `我的桌面`）传给 MCP 会被转成 GBK 乱码报 File not found
2. **绘制类工具全挂**：`create_canvas`/`add_layer`/`rename_layer`/`export` 正常，但 `draw_pixels`/`draw_grid`/`draw_shape`/`preview` 对单帧精灵一律报 `frame 1 out of range`，传 `frame=0` 又被 1-based 校验拒绝
