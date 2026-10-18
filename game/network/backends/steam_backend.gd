# steam_backend.gd
# Steam 后端实现（正式环境）
#
# ⚠️ 依赖 GodotSteam 插件（GDExtension）提供的 Steam 单例与 SteamMultiplayerPeer。
# 当前插件未安装，本文件为**骨架占位**：
#   - 不引用 Steam 符号，保证编译通过、项目可正常运行
#   - 安装 GodotSteam 后，按《联机解耦开发指导文档》3.3 补全
#     create_host → Steam.createLobby → _on_lobby_created → SteamMultiplayerPeer.create_host(0)
#     join_host  → Steam.joinLobby  → _on_lobby_joined → SteamMultiplayerPeer.create_client(owner_id, 0)
class_name SteamBackend
extends NetworkBackend

var _steam_peer: MultiplayerPeer
var _lobby_id: int = 0


func create_host(max_players: int) -> Error:
	push_error("[Steam] 未安装 GodotSteam 插件，Steam 后端暂不可用（见文件头注释）")
	return ERR_UNAVAILABLE


func join_host(address: String = "") -> Error:
	push_error("[Steam] 未安装 GodotSteam 插件，Steam 后端暂不可用（见文件头注释）")
	return ERR_UNAVAILABLE


func get_peer_id() -> int:
	if _steam_peer:
		return _steam_peer.get_unique_id()
	return 0


func disconnect_peer(peer_id: int) -> void:
	if _steam_peer:
		_steam_peer.close()


func get_connection_status() -> MultiplayerPeer.ConnectionStatus:
	if _steam_peer:
		return _steam_peer.get_connection_status()
	return MultiplayerPeer.CONNECTION_DISCONNECTED


func reset() -> void:
	_steam_peer = null
	_lobby_id = 0
	_is_host = false


func get_backend_name() -> String:
	return "Steam"


func get_lobby_id() -> int:
	return _lobby_id


## 将 peer 注入全局管理器
func _inject_peer() -> void:
	MultiplayerManager.set_peer(_steam_peer)
