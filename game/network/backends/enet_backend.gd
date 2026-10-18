# enet_backend.gd
# ENet 后端实现（开发期本地/局域网测试，不依赖 Steam）
# 逻辑移植自 network/NetworkManager.gd（原管理器由 Lobby 实例化，本类为 RefCounted 后端）
class_name ENetBackend
extends NetworkBackend

## 与现有 NetworkManager 保持一致的端口
const DEFAULT_PORT: int = 9999

var _peer: ENetMultiplayerPeer


## 创建主机（房间）
func create_host(max_players: int) -> Error:
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_server(DEFAULT_PORT, max_players)
	if err == OK:
		_is_host = true
		_host_peer_id = 1  # ENet 约定主机 id 恒为 1
		_inject_peer()
	else:
		push_error("[ENet] 创建服务器失败: %d" % err)
	return err


## 加入主机
## @param address: IP 地址，留空默认 127.0.0.1（本地回环）
func join_host(address: String = "") -> Error:
	var ip := address if address != "" else "127.0.0.1"
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(ip, DEFAULT_PORT)
	if err == OK:
		_is_host = false
		_host_peer_id = 1  # ENet 约定主机 id 恒为 1（客户端侧同样记录）
		_inject_peer()
	else:
		push_error("[ENet] 连接客户端失败: %d" % err)
	return err


## 本机 Peer ID（ENet 下 1=主机，>1=客机）
func get_peer_id() -> int:
	if _peer:
		return _peer.get_unique_id()
	return 0


func disconnect_peer(peer_id: int) -> void:
	if _peer:
		_peer.disconnect_peer(peer_id)


func get_connection_status() -> MultiplayerPeer.ConnectionStatus:
	if _peer:
		return _peer.get_connection_status()
	return MultiplayerPeer.CONNECTION_DISCONNECTED


func reset() -> void:
	_peer = null
	_is_host = false


func get_backend_name() -> String:
	return "ENet"


## 将 peer 注入全局管理器（MultiplayerManager autoload）
func _inject_peer() -> void:
	MultiplayerManager.set_peer(_peer)
