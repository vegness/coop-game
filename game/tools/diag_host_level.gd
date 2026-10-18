# tools/diag_host_level.gd
# 诊断脚本：多人主机（真实 ENet 已连接）进关卡，验证解耦后 LevelBase.get_peers() 路径
# 运行：<godot> --headless --path <project> res://tools/diag_host_level.tscn
extends Node


func _ready() -> void:
	reparent(get_tree().root)
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	# ── 1) 真实建立 ENet 主机 ──
	print("--- 阶段 1：创建 ENet 主机 ---")
	MultiplayerManager.set_network_backend(ENetBackend.new())
	var err := MultiplayerManager.create_room(4)
	print("create_room err = ", err)
	print("is_network_connected = ", MultiplayerManager.is_network_connected())
	print("is_server = ", MultiplayerManager.is_server())
	print("my_id = ", MultiplayerManager.get_my_id())
	print("get_peers = ", MultiplayerManager.get_peers())
	print("is_host_peer(1) = ", MultiplayerManager.is_host_peer(1))
	print("is_host_peer(2) = ", MultiplayerManager.is_host_peer(2))

	# ── 2) 主机加载关卡（走多人分支 _spawn_players）──
	print("--- 阶段 2：主机加载 level_01 ---")
	GameManager.is_online = true
	GameManager.player_count = 1
	var packed := load("res://levels/01/level_01.tscn") as PackedScene
	var level: Node = packed.instantiate()
	tree.root.add_child(level)
	tree.current_scene = level
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	print("players count = ", level.players.size())
	print("level_ready_received = ", MultiplayerManager.level_ready_received)
	for p in level.players:
		print("  player_id=", p.player_id, " play_ready=", p.play_ready)
	var chick: Node = level.get_node_or_null("Chick_1")
	print("chick found = ", chick != null)
	# 测试脚本时序：current_scene 在 add_child 后才赋值，LevelBase._ready 内广播就绪时
	# current_scene 尚为 null → 模拟真实游戏中收到广播后的解锁路径，验证链路完整
	level._on_network_level_ready()
	await tree.process_frame
	print("after manual ready: play_ready = ", chick.play_ready)
	if chick == null:
		print("FAIL: 多人主机关卡未生成小鸡")
		MultiplayerManager.disconnect_network()
		tree.quit(1)
		return

	# ── 3) 主机下蛋（走 is_server 分支 spawner.spawn）──
	print("--- 阶段 3：主机下蛋 ---")
	var eggs: Node = level.get_node("Eggs")
	print("egg count before = ", eggs.get_child_count())
	chick._perform_egg_lay()
	await tree.process_frame
	await tree.process_frame
	var egg_count := eggs.get_child_count()
	print("egg count after = ", egg_count)
	if egg_count <= 1:
		print(">>> 结果：多人主机下蛋失败")
		MultiplayerManager.disconnect_network()
		tree.quit(1)
	else:
		print(">>> 结果：多人主机下蛋正常")
	MultiplayerManager.disconnect_network()
	tree.quit()
