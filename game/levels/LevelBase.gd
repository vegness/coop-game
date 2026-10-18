# LevelBase.gd
# 关卡抽象基类
# 包含：关卡元数据、玩家生成逻辑、目标系统接口
extends Node2D
class_name LevelBase

# ============================================================
# 关卡目标类型枚举
# ============================================================
enum GoalType {
	REACH_EXIT,      # 到达出口
	COLLECT_EGGS,    # 收集金蛋
	DESTROY_TARGET,  # 破坏目标
	SURVIVE,         # 限时存活
	ESCORT           # 护送物体
}

# ============================================================
# 关卡配置（子类在 _ready 中设置）
# ============================================================
@export var level_id: int = 0
@export var level_name: String = ""
@export var chapter_theme: String = ""
@export var forced_chicken_type: String = ""  # 强制鸡类型路径
@export var goal_type: GoalType = GoalType.REACH_EXIT
@export var goal_target_count: int = 1
@export var time_limit: float = 0.0  # 0 = 无时间限制
@export var player_spawn_points: Array[Marker2D] = []

# ============================================================
# 运行时状态
# ============================================================
var current_goal_progress: int = 0
var elapsed_time: float = 0.0
var is_level_complete: bool = false
var is_level_failed: bool = false

# 玩家引用
var players: Array[ChickenBase] = []


# ============================================================
# 生命周期
# ============================================================
func _ready() -> void:
	EventBus.level_loaded.emit(level_id)
	_setup_level()
	_spawn_players()
	_on_level_ready()
	# 联机关卡就绪握手：主机广播"关卡就绪"，各端收到后小鸡才开始输入/物理。
	# 关键：同步器在状态无变化时不发送数据，就绪握手保证同步数据不会早于
	# 对端节点创建到达（否则 MultiplayerSynchronizer 路径缓存永久损坏 → 远端小鸡冻结）
	# ⚠️ 联机/主机判断必须走 MultiplayerManager（后端无关）：
	#   1) Godot 4.6 单机也有 OfflineMultiplayerPeer，multiplayer.has_multiplayer_peer() 恒 true
	#   2) multiplayer.is_server() 实现是 get_unique_id()==1，Steam 下主机 id 非 1 会失效
	if MultiplayerManager.is_network_connected():
		if MultiplayerManager.is_server():
			MultiplayerManager.notify_level_ready.rpc()
		elif MultiplayerManager.level_ready_received:
			_notify_players_ready()
	else:
		# 单机（无联机后端或未连接）：不握手，直接解锁小鸡
		_notify_players_ready()


## 收到主机"关卡就绪"广播（由 MultiplayerManager 调用）：解锁本端所有小鸡
func _on_network_level_ready() -> void:
	_notify_players_ready()


func _notify_players_ready() -> void:
	for ch in players:
		if ch.has_method("set_play_ready"):
			ch.set_play_ready(true)


func _physics_process(delta: float) -> void:
	if is_level_complete or is_level_failed:
		return

	# 限时检测
	if time_limit > 0:
		elapsed_time += delta
		if elapsed_time >= time_limit:
			_check_goal_completion()

	_check_goal_condition()
	_on_level_process(delta)


# ============================================================
# 玩家生成
# ============================================================
func _spawn_players() -> void:
	var chicken_scene: PackedScene
	if forced_chicken_type != "":
		chicken_scene = load(forced_chicken_type)
	else:
		# 默认使用基础 Chicken
		chicken_scene = preload("res://player/ChickenBase.tscn")

	# 联机判定：用 MultiplayerManager（后端无关）。
	# ⚠️ 不能依赖 multiplayer.has_multiplayer_peer()——Godot 4.6 单机也注入 OfflineMultiplayerPeer，
	#    恒 true；单机若误判联机，my_peer_id 会取到 0（backend 为空）导致小鸡 authority=0 不可控。
	var online: bool = MultiplayerManager.is_network_connected()
	var my_peer_id: int = MultiplayerManager.get_my_id() if online else 1

	# 本端需要生成的小鸡列表：
	#   单机：GameManager.player_count 只（player_id = 1..N）
	#   多人：所有 peer（自己 + 连接中的 peers）。每端都按相同顺序生成相同列表，
	#         保证各端节点路径一致 → MultiplayerSynchronizer 才能互相同步位置。
	#         每只鸡的 authority = 对应 peer，各自端处理自己鸡的物理。
	var player_ids: Array[int] = []
	if online:
		player_ids.append(my_peer_id)
		for pid in MultiplayerManager.get_peers():
			player_ids.append(pid)
		player_ids.sort()
	else:
		for i in range(GameManager.player_count):
			player_ids.append(i + 1)

	for i in range(player_ids.size()):
		var pid: int = player_ids[i]
		var spawn_pos: Vector2 = _get_spawn_position(i)
		var chicken: ChickenBase = chicken_scene.instantiate()
		# 确定性命名（替代 Godot 的 @类名@序号 自动重命名）：
		# 各端按相同顺序生成 → 节点路径一致 → 同步器/RPC 才能按路径路由
		chicken.name = "Chick_%d" % pid
		chicken.global_position = spawn_pos
		chicken.player_id = pid
		if online:
			# 小鸡 authority = 对应玩家（本机处理自己小鸡的输入/物理）
			chicken.set_multiplayer_authority(pid, false)
			# 同步器 NetSync 占位 authority=0：就绪握手解锁前无人发送。
			# 关键：MultiplayerSynchronizer 注册时会立即发送一次初始状态，
			# 若接收端关卡节点尚未创建，其路径缓存会永久损坏（表现为远端小鸡永远冻结）。
			# 占位 0 使同步器不发送（没有任何 peer 的 id 是 0），
			# 等关卡就绪广播后由 ChickenBase.set_play_ready 恢复为 pid 才开始同步。
			var net_sync := chicken.get_node_or_null("NetSync") as MultiplayerSynchronizer
			if net_sync != null:
				net_sync.set_multiplayer_authority(0)
		# 按角色选择页选的颜色生成对应小鸡（默认 yellow）
		if chicken.has_method("set_chicken_color"):
			var color: String = MultiplayerManager.player_colors.get(pid, "yellow")
			chicken.set_chicken_color(color)
		add_child(chicken)
		players.append(chicken)
		EventBus.player_spawned.emit(chicken)


func _get_spawn_position(index: int) -> Vector2:
	if index < player_spawn_points.size():
		return player_spawn_points[index].global_position
	# 自动查找场景中的 SpawnPoint / SpawnPoint1 / SpawnPoint2 ... 标记
	var spawn := get_node_or_null("SpawnPoint") as Marker2D
	if spawn != null:
		return spawn.global_position
	var numbered_spawn := get_node_or_null("SpawnPoint%d" % (index + 1)) as Marker2D
	if numbered_spawn != null:
		return numbered_spawn.global_position
	# 默认偏移生成
	return Vector2(200 + index * 50, 400)


# ============================================================
# 目标系统
# ============================================================
func _check_goal_condition() -> void:
	match goal_type:
		GoalType.REACH_EXIT:
			_check_reach_exit()
		GoalType.COLLECT_EGGS:
			_check_collect_eggs()
		GoalType.DESTROY_TARGET:
			_check_destroy_target()
		GoalType.SURVIVE:
			_check_survive()
		GoalType.ESCORT:
			_check_escort()


func _check_reach_exit() -> void:
	# 由 ExitArea 的 body_entered 信号处理
	pass


func _check_collect_eggs() -> void:
	if current_goal_progress >= goal_target_count:
		_complete_level()


func _check_destroy_target() -> void:
	if current_goal_progress >= goal_target_count:
		_complete_level()


func _check_survive() -> void:
	if elapsed_time >= time_limit and not is_level_failed:
		_complete_level()


func _check_escort() -> void:
	# 由护送目标检测区域处理
	pass


func _check_goal_completion() -> void:
	if is_level_complete:
		return
	_complete_level()


# ============================================================
# 关卡完成/失败
# ============================================================
func _complete_level() -> void:
	if is_level_complete:
		return
	is_level_complete = true
	EventBus.level_completed.emit(level_id)
	_on_level_complete()


func _fail_level() -> void:
	if is_level_failed:
		return
	is_level_failed = true
	_on_level_fail()


# ============================================================
# 目标进度更新（由机关/收集物调用）
# ============================================================
func add_goal_progress(amount: int = 1) -> void:
	current_goal_progress += amount


# ============================================================
# 虚方法（子类重写）
# ============================================================
func _setup_level() -> void:
	pass

func _on_level_ready() -> void:
	pass

func _on_level_process(_delta: float) -> void:
	pass

func _on_level_complete() -> void:
	pass

func _on_level_fail() -> void:
	pass
