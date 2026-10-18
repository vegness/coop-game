# EventBus.gd
# 全局事件总线（AutoLoad 单例）
# 使用 signal 解耦模块间通信，避免直接引用耦合
extends Node

# ============================================================
# 游戏流程信号
# ============================================================
signal game_state_changed(old_state: int, new_state: int)
signal game_paused()
signal game_resumed()

# 关卡
signal level_loaded(level_id: int)
signal level_completed(level_id: int)
signal level_restarted()

# ============================================================
# 玩家信号
# ============================================================
signal player_spawned(player_node: Node)
signal player_died(player_id: int)
signal player_revived(player_id: int)
signal player_fell_off(player_id: int)  # 掉出地图

# 蛋
signal egg_laid(egg_node: Node, owner_id: int)
signal egg_destroyed(egg_node: Node)

# ============================================================
# 收集物信号
# ============================================================
signal golden_egg_collected(player_id: int)
signal feather_collected(player_id: int)

# ============================================================
# 机关信号
# ============================================================
signal pressure_plate_activated(plate_node: Node)
signal pressure_plate_deactivated(plate_node: Node)
signal door_opened(door_id: String)
signal door_closed(door_id: String)

# ============================================================
# 联机信号
# ============================================================
signal host_created()
signal joined_game()
signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal connection_failed(reason: String)
