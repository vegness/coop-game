# level_01.gd
# 第一关：炸弹工坊（手绘关卡）
# 布局（×0.4 映射到项目标准坐标 x∈[0,3200] y∈[0,720]）：
#   出生 → 左地 → 跨坑桥 → 高墙 + 平台 → 右地 → 终点 Portal（传送门）
# 教学点：跳跃、下蛋反冲、蛋垫脚、踩蛋、S 俯冲、机关（尖刺已就位）
#
# ⚠️ 联机解耦：本脚本不直接调用 MultiplayerManager.is_server()，
#    关卡就绪握手由父类 LevelBase._ready 统一处理；蛋同步走场景中的 MultiplayerSpawner
#    （自定义 spawn_function 注入各端一致的位置/命名）；通关判定通过 MultiplayerManager
#    间接判断单/多人，与文档 §4 一致。
extends LevelBase

# ============================================================
# 关卡配置
# ============================================================
var camera_bounds: Rect2 = Rect2(0, 0, 3200, 720)
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


# ============================================================
# 关卡构建
# ============================================================
func _setup_level() -> void:
	portal = get_node_or_null("Portal") as Portal

	var egg_spawner := get_node_or_null("Eggs/EggSpawner") as MultiplayerSpawner
	if egg_spawner != null:
		egg_spawner.spawn_function = _spawn_egg_net


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
# 每帧：掉坑复活 + 通关判定（传送门）
# ============================================================
func _on_level_process(_delta: float) -> void:
	# 1) 掉坑复活
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
