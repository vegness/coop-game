# tools/diag_egg.gd
# 诊断脚本：多人模式退出后，单人关卡"按 K 不下蛋"问题定位
# 运行：<godot> --headless --path <project> res://tools/diag_egg.tscn -- --mode=<A|B|C>
#   A = 纯单机（从未联机，对照组）
#   B = 进 Lobby（注入 ENet 后端）后直接退出
#   C = 进 Lobby 并创建房间后退出
extends Node

var mode: String = "A"


func _ready() -> void:
	# 脱离 current_scene 树：后续 change_scene 释放关卡场景时不会连带释放本节点（协程不中断）
	reparent(get_tree().root)
	var env_mode := OS.get_environment("DIAG_MODE")
	if env_mode in ["A", "B", "C"]:
		mode = env_mode
	print("=== 下蛋链路诊断 mode=%s ===" % mode)
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	# ── 阶段 1：模拟网络状态 ──
	print("--- 阶段 1：设置网络状态 ---")
	print("initial multiplayer_peer = ", multiplayer.multiplayer_peer)
	print("initial backend = ", MultiplayerManager.backend)
	match mode:
		"A":
			pass  # 纯单机
		"B":
			MultiplayerManager.set_network_backend(ENetBackend.new())
			MultiplayerManager.disconnect_network()
		"C":
			MultiplayerManager.set_network_backend(ENetBackend.new())
			var err := MultiplayerManager.create_room(4)
			print("create_room err = ", err)
			MultiplayerManager.disconnect_network()
	print("after setup: backend = ", MultiplayerManager.backend)
	print("is_network_connected = ", MultiplayerManager.is_network_connected())
	print("is_server = ", MultiplayerManager.is_server())
	print("multiplayer_peer after setup = ", multiplayer.multiplayer_peer)
	print("unique_id = ", multiplayer.get_unique_id())

	# ── 阶段 2：加载关卡 ──
	print("--- 阶段 2：加载 level_01 ---")
	GameManager.is_online = false
	GameManager.player_count = 1
	var packed := load("res://levels/01/level_01.tscn") as PackedScene
	var level: Node = packed.instantiate()
	tree.root.add_child(level)
	tree.current_scene = level
	await tree.process_frame
	print("frame 1 done, current_scene = ", tree.current_scene)
	await tree.process_frame
	print("frame 2 done")
	await tree.process_frame
	print("frame 3 done")

	var chick: Node = level.get_node_or_null("Chick_1")
	print("chick = ", chick)
	if chick == null:
		print("FAIL: 小鸡未生成")
		tree.quit(1)
		return
	print("chick.play_ready = ", chick.play_ready)
	print("chick._is_network_client() = ", chick._is_network_client())
	var eggs: Node = level.get_node("Eggs")
	var spawner: MultiplayerSpawner = eggs.get_node("EggSpawner")
	print("spawner.authority = ", spawner.get_multiplayer_authority())
	print("spawner.is_multiplayer_authority() = ", spawner.is_multiplayer_authority())
	print("spawner.spawn_function.is_valid() = ", spawner.spawn_function.is_valid())
	print("egg container child count before = ", eggs.get_child_count())

	# ── 阶段 3：强制下蛋（绕开按键，直接走 _perform_egg_lay → _spawn_egg）──
	print("--- 阶段 3：强制下蛋 ---")
	chick._perform_egg_lay()
	await tree.process_frame
	await tree.process_frame
	var egg_count := eggs.get_child_count()
	print("egg container child count after = ", egg_count)
	for c in eggs.get_children():
		if c is MultiplayerSpawner:
			continue
		print("  egg: ", c.name, " class=", c.get_class(), " pos=", c.global_position)
	if egg_count <= 1:
		print(">>> 结果：蛋未生成（bug 复现）")
	else:
		print(">>> 结果：蛋正常生成")
	tree.quit()
