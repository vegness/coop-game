# level_02.gd
# 第二关（新版）：机关大杂烩（手绘关卡 level2.png，12000x1800 → ×0.4 = 4800x720）
# 布局（世界坐标 x∈[0,4800] y∈[0,720] 地面顶 y=656）：
#   左地[0..1196] → 大坑 → 中地[2380..3716]（风扇+高柱） → 刺坑 → 右地[4612..4800] → Portal
# 机关：
#   1. 左地 4 按钮（600/766/933/1100, 655）→ AND → MovingFloor 从原位(2200,475) 向左移动到 x=1280 停，
#      否则向右回原位（当且仅当四个按钮全部被按下）
#   2. 风扇（2600,655）：两按钮（2450,655 地面 / 3050,260 柱顶）任一按下 → 转动出上升气流，
#      吹鸡到 y=200 封顶；碰风扇本体即死（回 last_landed_position）
#   3. 门（2090,260）：柱顶按钮（2750,260）踩下 → 门升起（门按钮用 linked_mechanisms 联动，无需代码）
#   4. 刺坑 [3715..4600]×720：28 根 spike_2 紧密排列；刺高 14px < 蛋高 28px → 踩蛋过河
#   5. Portal（4700,600）通关（复用第一关判定）
#
# ⚠️ 联机解耦：本脚本不直接调用 MultiplayerManager.is_server()，
#    关卡就绪握手由父类 LevelBase._ready 统一处理；蛋同步走场景中的 MultiplayerSpawner
#    （自定义 spawn_function 注入各端一致的位置/命名）；通关判定通过 MultiplayerManager
#     间接判断单/多人，与文档 §4 一致。
extends LevelBase

# ============================================================
# 关卡配置
# ============================================================
var camera_bounds: Rect2 = Rect2(0, 0, 4800, 720)
var spawn_position: Vector2 = Vector2(200, 632)
const FALL_Y_THRESHOLD: float = 820.0

# 通关判定：连续 N 帧满足才触发 _complete_level（防一帧进入误触）
const SINGLE_REQUIRE_FRAMES: int = 3
const MULTI_REQUIRE_FRAMES: int = 5


# ============================================================
# 运行时引用
# ============================================================
var portal: Portal

# MultiplayerSpawner 蛋生成序号：各端按相同顺序执行 spawn_function → 名字一致
var _egg_net_counter: int = 0

# 通关判定连续帧计数
var _single_in_frames: int = 0
var _multi_in_frames: int = 0

# 风扇按钮计数（OR 语义：任一按下风扇即转，全部松开才停）
var _fan_button_count: int = 0


# ============================================================
# 关卡构建
# ============================================================
func _setup_level() -> void:
	portal = get_node_or_null("Portal") as Portal

	var egg_spawner := get_node_or_null("Eggs/EggSpawner") as MultiplayerSpawner
	if egg_spawner != null:
		egg_spawner.spawn_function = _spawn_egg_net

	# 机关间零引用：全部在此信号连接（唯一耦合点）。
	# ① 4 个按钮 → 移动地板（AND：condition_met 内部计数，全按下才向左移动）
	var floor := get_node_or_null("MovingFloor") as MovingFloor
	var btn_names := ["Button1", "Button2", "Button3", "Button4"]
	for n in btn_names:
		var btn := get_node_or_null(n) as Trigger
		if btn != null and floor != null:
			btn.pressed.connect(floor.condition_met.bind(true))
			btn.released.connect(floor.condition_met.bind(false))

	# ② 2 个按钮 → 风扇（OR：任一按下即转；都松开才停，避免单机死锁）
	var fan := get_node_or_null("Fan") as Fan
	var fan_btns := ["FanButtonGround", "FanButtonPillar"]
	for n in fan_btns:
		var btn := get_node_or_null(n) as Trigger
		if btn != null and fan != null:
			btn.pressed.connect(_on_fan_btn_pressed)
			btn.released.connect(_on_fan_btn_released)

	# ③ 门按钮通过 trigger 的 linked_mechanisms 自动联动（tscn 里配 NodePath("../Door")）


# MultiplayerSpawner 的自定义生成函数
func _spawn_egg_net(data: Dictionary) -> Node:
	var egg := (load("res://player/EggBase.tscn") as PackedScene).instantiate() as EggBase
	egg.global_position = data.get("pos", Vector2.ZERO)
	if data.has("owner"):
		egg.set_owner_id(data.get("owner", -1))
	egg.name = "EggNet_%d" % _egg_net_counter
	_egg_net_counter += 1
	var ignore_path: String = data.get("ignore_chicken", "")
	if ignore_path != "":
		var chicken := get_node_or_null(ignore_path) as ChickenBase
		if chicken != null and egg.has_method("set_ignore_player"):
			egg.set_ignore_player(chicken)
	return egg


# ============================================================
# 风扇按钮（OR 语义）
# ============================================================
func _on_fan_btn_pressed() -> void:
	_fan_button_count += 1
	var fan := get_node_or_null("Fan") as Fan
	if fan != null and _fan_button_count > 0:
		fan.activate()


func _on_fan_btn_released() -> void:
	_fan_button_count = maxi(0, _fan_button_count - 1)
	var fan := get_node_or_null("Fan") as Fan
	if fan != null and _fan_button_count <= 0:
		fan.deactivate()


# ============================================================
# 每帧：掉坑复活 + 通关判定（传送门）
# ============================================================
func _on_level_process(_delta: float) -> void:
	# 1) 掉坑复活（含刺坑：掉进去要么碰刺判死、要么跌出地图判死）
	for ch in players:
		if ch == null or ch.is_dead:
			continue
		if ch.global_position.y > FALL_Y_THRESHOLD:
			var respawn_pos: Vector2 = ch.last_landed_position
			if respawn_pos == Vector2.ZERO:
				respawn_pos = spawn_position
			ch.revive(respawn_pos)
			EventBus.player_fell_off.emit(ch.player_id)

	# 2) 通关判定（传送门）。单/多人用不同范围：单人小范围（SingleCheck）内任一鸡即可；
	#    多人大范围（MultiCheck）内所有玩家都在才通关（防边缘抖动）。
	if is_level_complete or is_level_failed or portal == null:
		return
	var online: bool = MultiplayerManager.is_network_connected()
	if online:
		if _all_players_in(portal.in_multi):
			_multi_in_frames += 1
			if _multi_in_frames >= MULTI_REQUIRE_FRAMES:
				_complete_level()
		else:
			_multi_in_frames = 0
	else:
		if portal.in_single.size() >= 1:
			_single_in_frames += 1
			if _single_in_frames >= SINGLE_REQUIRE_FRAMES:
				_complete_level()
		else:
			_single_in_frames = 0


# 所有玩家 pid 都在给定列表内（多人通关判定）
func _all_players_in(arr: Array[int]) -> bool:
	if players.is_empty():
		return false
	for ch in players:
		if ch == null:
			continue
		if ch.player_id not in arr:
			return false
	return true
