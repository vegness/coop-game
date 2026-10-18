# Chicken_Co-op 项目长期记忆

## 环境与工具
- Godot mono 4.6.1：`E:\godot\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64_console.exe`（项目纯 GDScript）
- headless 验证：`<godot> --headless --path E:\desktop\try_game\game --quit-after 300 <scene>`；导入 `--import`；截图 `--write-movie .preview/x.png` 必须窗口模式（headless+write-movie 会 C++ 崩溃）
- 设计文档：`E:\desktop\try_game\框架.md`、`规范.md`；`doc/联机解耦开发指导文档.md`；新增 `doc/多人模式与对战开发文档.md`
- 🪲 Aseprite MCP：中文路径乱码；draw_pixels/draw_grid/draw_shape/preview 对 1 帧精灵全报 "frame 1 out of range"（服务端 bug）→ 可靠方案：`E:\Aseprite\aseprite.exe -b --script x.lua` 程序化绘制后 saveAs。**已验证：Aseprite CLI 在中文路径下读写正常**（只有 MCP 才乱码）。注意 Lua 用 `app.pixelColor.rgba(r,g,b,a)` + 分量取色（无 Color{}.r），数学用 `^` 不用 `math.pow`
- 像素美术生成脚本全部归位 `game/tools/artgen/`（含 README.md）：build_backgrounds.lua→输出 temp/；build_mech_art.lua、build_bush.lua→输出 mech/；compose_bush.py(PIL)→输出 verify/；历史脚本→输出 out/。**禁止把中间产物放 C 盘临时目录**（用户明确要求）
- bush（原 wheat）藏身草丛贴图须密实且 ≥ 世界 56×56（鸡 51×51）；当前 144×124 / scale=0.5 → 世界 72×62；4 帧共用种子只改摆动避免闪烁。简化版（v2）= 7 束圆润草团组成，u^4 曲线避免尖锐山尖，主体中绿 #4caf50 + 顶亮 #a5d66a + 底暗 #2e7d32 + 描边 #1e4a1a
- 对战地图：全部集中在 game/temp/，**纯背景版**（6 张 1200×200，仅 bg/decor 两层，不含任何机制实体）；平台/球门/掩体/墙等机制组件按解耦原则后续在 mechanisms/ 做独立场景（规划含 platform_rot 旋转平台等），见 temp/地图说明.md；生成走 Aseprite CLI+Lua（build_backgrounds.lua）

## 关键约定（必须遵守）
- GDScript 警告视为错误：避免 Variant 推断（用 maxf/minf/显式类型）、避免覆盖原生方法（如 is_network_connected）
- 玩家 = scenes/chick.tscn（ChickPlayer.gd extends ChickenBase）；6 色 blue/green/pink/red/white/yellow，动画名 stop/run/jump/down；640x640 帧图 scale=0.08
- 关卡路径：新 `levels/%02d/level_%02d.tscn`（tscn/gd 同名小写），旧 `levels/Level_%02d/Level_%02d.tscn` 兜底；SpawnPoint1-4 由 LevelBase 自动查找
- **地图必须放 tscn 手放碰撞体**，禁代码生成地形（_build_tilemap 类）；脚本只做运行时逻辑（ExitArea/复活/通关）
- 坐标标准空间 x∈[0,W] y∈[0,720] 地面顶 y=656；Aseprite 8000x1800 背景 scale=0.4；碰撞 `(user_px+center)*0.4`
- 双 res：项目 res/ 目录 = `res://res/...`（chick/fonts），非 res/ 用单 res://
- tscn 节点块内与文件首行禁 `#` 注释（Godot 4.6 解析器吞节点/级联失败），首行必须是 `[gd_scene`
- 按钮重量：蛋 0.5、鸡 1.0；Trigger require_weight 0.5=1蛋 / 1.0=1鸡或2蛋
- @export Node 引用须 NodePath + `_ready` get_node_or_null 解析（tscn 写 NodePath 引用会解析成 nil）
- MultiplayerSpawner 子节点必须显式命名（X_N），否则 "@类名@N" 保留名报错
- Area2D 回调内改碰撞状态用 set_deferred/call_deferred（防 flushing queries 丢变更）

## 多人同步引擎事实（查源码确认，联机排查必读）
- Synchronizer 不跟随根 authority：小鸡 `set_multiplayer_authority(pid,false)` + NetSync 占位 authority=0，就绪握手后 `set_play_ready` 恢复（LevelBase._spawn_players 已实现）
- spawn() 返回 Node（非 authority 返回 null 静默）；spawn_path 自动同步仅 spawner authority 触发；scene_file_path 须在 _spawnable_scenes
- 单机也有 OfflineMultiplayerPeer → 区分单机/联机用 `MultiplayerManager.is_network_connected()`，勿用 has_multiplayer_peer()
- ENet 客机 id 是随机大数，仅主机恒 1；主机判断用 `MultiplayerManager.is_server()` / `is_host_peer(pid)`（勿用 multiplayer.is_server() 与 pid==1）
- 同步器注册即发初始状态 + 路径缓存永久损坏 → 必须"关卡就绪握手"：主机广播 notify_level_ready（autoload 上 any_peer+call_local）前 NetSync authority=0 占位，否则远端小鸡永久冻结
- 蛋同步：生成仅 spawner authority（主机）；客机 request_egg_spawn.rpc 广播 + 主机 guard（勿硬编码 rpc_id(1)）；EggNet_N 命名；碎蛋 any_peer+call_local 幂等广播；销毁仅 authority queue_free（防 ERR_UNAUTHORIZED 竞态）
- RPC 模式：全端执行 @rpc("any_peer","call_local") 不加 guard（发起端 is_server guard）；仅主机执行 @rpc("any_peer","call_remote") + 方法内 is_server guard；@rpc("authority") Steam 下会被拒
- ⚠️ disconnect_network() 必须恢复 OfflineMultiplayerPeer（置 null → unique_id 返 0 → spawner 权限失效 → "多人退出后单机不下蛋"）+ 同时 backend.reset()。回归：tools/diag_egg.gd
- 解耦红线：player/levels/ui/mechanisms/collectibles 禁止直接 multiplayer.xxx 原生调用，一律走 MultiplayerManager.get_peers()/is_network_connected()/get_my_id()/is_server()/is_host_peer()。回归：tools/diag_host_level.gd

## 机制库（mechanisms/，坑位速查）
- movingfloor：condition_met 计数 → 满足 required_conditions 移向 target / 否则回 home（多按钮 AND 门）
- fan：HazardArea 碰本体死 + WindArea 气流 + max_blow_y 硬顶；🪲 AnimatedSprite2D 未播动画不显示 → deactivate/_ready 分支显式 animation="spin"+stop()；底座 Polygon2D 防第一帧太淡
- spike_2：HazardArea 须比刺体向上多 8~10px 余量（(16,10) size(32,22)），否则鸡能站刺上不死
- door：clip_y 裁剪；crush 判定 = 鸡体 AABB ∩ 门 AABB 相交（防与门下 moving floor 重叠误杀）
- portal：单/多人双 Area 检测，3帧/5帧连续防抖
- EggBase 出界销毁 x>4000（level1 宽 3200）；level2 宽 4800 须改 x>5000
- 🪲 子类覆盖 _on_landed 必须 super._on_landed()（否则 last_landed_position 恒 ZERO，复活点失效，如 InfiniteChicken）

## 主菜单像素美术
- 字体：Press Start 2P（英文）+ fusion-pixel 12px zh_hans（中文），res://res/fonts/
- 资源 res://ui/MainMenu/assets/（tools/generate_menu_assets.gd 可重跑）；色板 #E0F7FA→#FFF8E7 + 地面 #7AE582 + 强调 #FF8C42 #5BC0EB #F7AEF8 #F4D35E + 描边 #2D1B2E
- 渲染顺序：Background.z_index=-5 垫底
- PNG 尺寸：level2.png 12000x1800（×0.4=4800x720）；Fan_8 8×32x16；Spike_10 10×32x32（刺体 y=7..21）

## UI 流程（2026-08-26 规划，文档先行代码未动）
- 新主菜单两按钮：**单人硬行 / 多人模式**
- 多人模式 → 联机大厅（IP 连接：创建/加入）→ 多人模式选择（多人闯关 / 多人对战）
- 其余接口暂时不变；详细见 `doc/多人模式与对战开发文档.md`
