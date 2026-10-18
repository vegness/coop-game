# multiplayer_manager.gd
# 全局网络管理单例（AutoLoad）
# 游戏逻辑层唯一接触的网络入口：不认识 ENet / Steam，只持有 NetworkBackend 接口
extends Node

# ═══════════════════════════════════════════
# 信号
# ═══════════════════════════════════════════

## 有玩家连接（包括自己连接成功时）
signal player_connected(peer_id: int)
## 有玩家断开
signal player_disconnected(peer_id: int)
## 与主机断开（客机专属）
signal server_disconnected
## 网络后端切换完成
signal backend_changed(backend_name: String)

# ═══════════════════════════════════════════
# 属性
# ═══════════════════════════════════════════

## 当前注入的网络后端
var backend: NetworkBackend:
	get:
		return _backend
	set(value):
		_backend = value
		backend_changed.emit(value.get_backend_name() if value else "None")

var _backend: NetworkBackend
var _current_peer: MultiplayerPeer

## 玩家颜色表（peer_id -> 颜色名，如 {1: "yellow", 2: "red"}）
## 角色选择页收集、进入关卡前由主机写入，关卡生成小鸡时读取
var player_colors: Dictionary = {}


# ═══════════════════════════════════════════
# 生命周期
# ═══════════════════════════════════════════

func _ready() -> void:
	# 监听 Godot 原生多人事件
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)


# ═══════════════════════════════════════════
# 后端注入（由具体实现类调用）
# ═══════════════════════════════════════════

## 设置当前 MultiplayerPeer（由 ENetBackend / SteamBackend 调用）
func set_peer(peer: MultiplayerPeer) -> void:
	_current_peer = peer
	multiplayer.multiplayer_peer = peer


## 手动切换网络后端（通常在主菜单初始化时调用）
func set_network_backend(new_backend: NetworkBackend) -> void:
	backend = new_backend
	print("[MultiplayerManager] 网络后端已切换为: %s" % backend.get_backend_name())


# ═══════════════════════════════════════════
# 游戏逻辑层 API（与后端无关）
# ═══════════════════════════════════════════

## 创建房间
func create_room(max_players: int = 4) -> Error:
	if backend == null:
		push_error("[MultiplayerManager] 未设置网络后端")
		return ERR_UNCONFIGURED
	return backend.create_host(max_players)


## 加入房间
## @param address: ENet 用 IP；Steam 用 Lobby ID 字符串
func join_room(address: String = "") -> Error:
	if backend == null:
		push_error("[MultiplayerManager] 未设置网络后端")
		return ERR_UNCONFIGURED
	return backend.join_host(address)


## 获取本机 Peer ID（1=主机，>1=客机，0=离线；Steam 下为映射值）
func get_my_id() -> int:
	if backend:
		return backend.get_peer_id()
	return 0


## 获取已连接的其他 peer 列表（单机/未连接返回空数组）
## 游戏逻辑层不直接读 multiplayer.get_peers()，统一走本封装（后端无关）
func get_peers() -> Array[int]:
	var result: Array[int] = []
	if not is_network_connected():
		return result
	for pid in multiplayer.get_peers():
		result.append(int(pid))
	return result


## 是否为主机（通过后端 _is_host 标志判断，不依赖 peer_id）
func is_server() -> bool:
	if backend:
		return backend.is_host()
	return false


## 指定 peer 是否为房主（房间创建者；后端无关）
## 禁止游戏逻辑层硬编码 peer_id == 1——ENet 下成立，Steam 下主机 id 是映射值
func is_host_peer(peer_id: int) -> bool:
	if backend == null:
		return false
	return backend.get_host_peer_id() == peer_id


## 是否已连接
## 注意：不能命名 is_connected()，会覆盖 Object 原生方法（警告视为错误）
func is_network_connected() -> bool:
	if backend:
		return backend.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
	return false


## 断开连接并清理
func disconnect_network() -> void:
	if _current_peer:
		_current_peer.close()
		_current_peer = null
	# 重置后端内部状态（清 peer 引用 + 主机标志），避免"多人→主菜单→单人"残留主机身份
	if backend:
		backend.reset()
	# ⚠️ 必须恢复 OfflineMultiplayerPeer 而非置 null：
	#   Godot 4.6 中 multiplayer_peer=null 时 get_unique_id() 返回 0（并每次报错），
	#   而关卡节点（MultiplayerSpawner 等）的 authority 是 1，is_multiplayer_authority() 恒 false
	#   → spawner.spawn() 返回 null → "多人模式退出后进单人，按 K 不下蛋"。
	#   恢复默认离线 peer 后 unique_id=1 与节点 authority 匹配，单机行为与从未联机一致。
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	print("[MultiplayerManager] 网络已断开")


# ═══════════════════════════════════════════
# 下蛋请求转发（客机 → 主机）
# 放在 autoload 上：RPC 目标节点"永远存在"，避免关卡切换瞬间
# 主机端小鸡节点尚未生成导致 RPC 直接丢失（蛋完全不出现）
# ═══════════════════════════════════════════
var _pending_egg_spawns: Array = []  # [[pos: Vector2, owner: int, path: NodePath], ...]

## 客机请求主机代为生成蛋（仅主机执行；蛋随后由关卡的 EggSpawner 广播到所有端）
@rpc("any_peer", "call_remote", "reliable")
func request_egg_spawn(egg_pos: Vector2, owner_id: int, chicken_path: NodePath) -> void:
	if not is_server():
		return
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_setup_level"):
		_do_spawn_egg(scene, egg_pos, owner_id, chicken_path)
	else:
		# 关卡尚未就绪（两端几乎同时进关卡时的竞态窗口）：排队，待关卡 ready 后补发
		_pending_egg_spawns.append([egg_pos, owner_id, chicken_path])
		if _pending_egg_spawns.size() == 1:
			_flush_pending_egg_spawns()


## 等待关卡就绪后补发排队的下蛋请求（最多等 10s，避免关卡永不加载时死循环）
func _flush_pending_egg_spawns() -> void:
	var waited: float = 0.0
	while _pending_egg_spawns.size() > 0 and waited < 10.0:
		var scene := get_tree().current_scene
		if scene != null and scene.has_method("_setup_level"):
			for spawn in _pending_egg_spawns:
				_do_spawn_egg(scene, spawn[0], spawn[1], spawn[2])
			_pending_egg_spawns.clear()
			return
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	if _pending_egg_spawns.size() > 0:
		push_warning("[MultiplayerManager] 关卡 10s 未就绪，丢弃 %d 个下蛋请求" % _pending_egg_spawns.size())
		_pending_egg_spawns.clear()


## 在关卡上通过 EggSpawner 生成蛋（仅主机/spawner authority 调用，spawner.spawn 广播所有端）
func _do_spawn_egg(scene: Node, egg_pos: Vector2, owner_id: int, chicken_path: NodePath) -> void:
	var eggs_container: Node = scene.get_node_or_null("Eggs")
	if eggs_container == null:
		return
	var spawner: MultiplayerSpawner = eggs_container.get_node_or_null("EggSpawner")
	if spawner == null or not spawner.spawn_function.is_valid():
		return
	var spawned: Node = spawner.spawn({
		"pos": egg_pos,
		"owner": owner_id,
		"ignore_chicken": str(chicken_path),
	})
	if spawned != null:
		EventBus.egg_laid.emit(spawned, owner_id)


# ═══════════════════════════════════════════
# 关卡就绪握手
# 目的：保证所有端关卡节点创建完成后才开始同步。同步器在状态无变化时不发送数据，
#       就绪握手确保同步数据不会早于对端节点创建到达——
#       否则 MultiplayerSynchronizer 的路径缓存会永久损坏（表现为远端小鸡永远冻结）
# ═══════════════════════════════════════════
## 本端是否已收到"关卡就绪"广播（单机无意义，恒 false 也不影响——单机不走该逻辑）
var level_ready_received: bool = false

## 主机广播关卡就绪（各端收到后解锁关卡内小鸡的输入/物理）
## ⚠️ 不能用 @rpc("authority")：本节点（autoload）authority 恒为 1，
##    Steam 下主机 unique_id 是 Steam ID 映射值 ≠ 1，authority 型 RPC 会被拒绝
##    → 就绪握手失效 → 同步器早发初始状态 → 远端小鸡永久冻结。
##    any_peer + call_local 后端无关；发起端仅主机（LevelBase._ready 的 is_server 分支）。
@rpc("any_peer", "call_local", "reliable")
func notify_level_ready() -> void:
	level_ready_received = true
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_on_network_level_ready"):
		scene._on_network_level_ready()


# ═══════════════════════════════════════════
# 内部事件转发
# ═══════════════════════════════════════════

func _on_peer_connected(peer_id: int) -> void:
	print("[MultiplayerManager] 玩家连接: %d" % peer_id)
	player_connected.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	print("[MultiplayerManager] 玩家断开: %d" % peer_id)
	player_disconnected.emit(peer_id)


func _on_server_disconnected() -> void:
	print("[MultiplayerManager] 与主机断开连接")
	server_disconnected.emit()


func _on_connected_to_server() -> void:
	print("[MultiplayerManager] 成功连接到服务器")
