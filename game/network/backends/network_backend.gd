# network_backend.gd
# 网络后端抽象接口（游戏逻辑层不感知具体后端）
# 所有后端（ENet / Steam / 未来 DedicatedServer）必须继承本类实现统一接口
class_name NetworkBackend
extends RefCounted

## 创建主机（房间）
## @param max_players: 最大玩家数
## @return: Error 状态
func create_host(max_players: int) -> Error:
	push_error("[NetworkBackend] create_host() 未实现")
	return ERR_UNCONFIGURED


## 加入主机
## @param address: 对 ENet 是 IP；对 Steam 是 Lobby ID 字符串
## @return: Error 状态
func join_host(address: String = "") -> Error:
	push_error("[NetworkBackend] join_host() 未实现")
	return ERR_UNCONFIGURED


## 获取本机 Peer ID
## 注意：仅 ENet 下 1=主机、>1=客机；Steam 下是 Steam ID 映射值，
##       绝对不能用来判断是否主机！
func get_peer_id() -> int:
	push_error("[NetworkBackend] get_peer_id() 未实现")
	return 0


## 是否为主机
## 由子类在 create_host()/join_host() 成功时维护 _is_host，
## 不可依赖 get_peer_id() == 1（Steam 下不成立）
var _is_host: bool = false

func is_host() -> bool:
	return _is_host


## 房主（房间创建者）Peer ID
## 后端在 create_host()/join_host() 成功时维护：ENet 恒为 1，Steam 为创建者映射 id。
## 游戏逻辑层判断"某 peer 是否房主"必须走 MultiplayerManager.is_host_peer()，
## 禁止硬编码 peer_id == 1（Steam 下不成立）。
var _host_peer_id: int = 0

func get_host_peer_id() -> int:
	return _host_peer_id


## 主动断开指定玩家（主机权限）
func disconnect_peer(peer_id: int) -> void:
	pass


## 重置后端内部状态（断开网络时调用，供再次进入单机/多人）
## 必须清除 peer 引用、主机标志与房主 id，否则"多人→主菜单→单人"会残留主机身份
func reset() -> void:
	_is_host = false
	_host_peer_id = 0


## 获取连接状态
func get_connection_status() -> MultiplayerPeer.ConnectionStatus:
	return MultiplayerPeer.CONNECTION_DISCONNECTED


## 获取后端名称（调试用）
func get_backend_name() -> String:
	return "AbstractBackend"
