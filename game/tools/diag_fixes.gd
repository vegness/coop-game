# diag_fixes.gd
# 回归验证（headless）：
#   A) InfiniteChicken 外观：有 AnimatedSprite2D 且已加载彩色动画帧
#   B) 下蛋免碰撞：下蛋后蛋不立刻被小鸡挤走（复用 ChickenBase._spawn_egg 统一逻辑）
#   C) Door：clip_y=120（y<120 透明）、位置、按钮联动存在
# 用法：godot --headless --path game --quit-after 400 tools/diag_fixes.tscn
extends Node2D

var RESULTS: Array[String] = []

var _level: LevelBase
var _frame: int = 0
var _egg_start_pos: Vector2 = Vector2.ZERO
var _checked_egg: bool = false


func _ready() -> void:
	_level = (load("res://levels/02/level_02.tscn") as PackedScene).instantiate() as LevelBase
	add_child(_level)
	# 等 10 帧让关卡/小鸡就绪
	await get_tree().create_timer(0.2).timeout
	_check_chicken_visual()
	_check_door_config()
	# 触发下蛋
	for ch in _level.players:
		if ch.has_method("_perform_egg_lay"):
			ch._perform_egg_lay()


func _physics_process(_delta: float) -> void:
	_frame += 1
	# 下蛋后第 15 帧检查蛋位置（物理已跑 0.25s，若被挤走蛋会明显偏移）
	if _frame == 15 and not _checked_egg:
		_checked_egg = true
		_check_egg_not_knocked()
		_dump_results()
		get_tree().quit()


func _check_chicken_visual() -> void:
	var ch := _level.players[0] if not _level.players.is_empty() else null
	if ch == null:
		RESULTS.append("A) FAIL: no player spawned")
		return
	var anim := ch.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if anim == null:
		RESULTS.append("A) FAIL: no AnimatedSprite2D node")
		return
	var sf := anim.sprite_frames
	if sf == null or sf.get_animation_names().size() == 0:
		RESULTS.append("A) FAIL: sprite_frames empty (color anim not loaded)")
		return
	var names: Array = sf.get_animation_names()
	var has_stop: bool = sf.has_animation("stop")
	var has_run: bool = sf.has_animation("run")
	var has_jump: bool = sf.has_animation("jump")
	var has_down: bool = sf.has_animation("down")
	RESULTS.append("A) OK: AnimatedSprite2D anims=%s stop=%s run=%s jump=%s down=%s color=%s" %
		[str(names.size()), has_stop, has_run, has_jump, has_down, ch.chicken_color if "chicken_color" in ch else "?"])


func _check_door_config() -> void:
	var door := _level.get_node_or_null("Door")
	if door == null:
		RESULTS.append("C) FAIL: Door missing")
		return
	RESULTS.append("C) Door pos=%s scale=%s clip_y=%s" % [str(door.position), str(door.scale), str(door.clip_y)])
	# 门按钮联动存在（trigger.gd 的 linked_mechanisms）
	var btn := _level.get_node_or_null("DoorButton") as Area2D
	if btn != null and "linked_mechanisms" in btn:
		RESULTS.append("C) DoorButton linked_mechanisms=%s" % str(btn.linked_mechanisms))
	# 门体碰撞体存在
	var body_shape := door.get_node_or_null("StaticBody2D/CollisionShape2D") as CollisionShape2D
	RESULTS.append("C) Door body shape: %s" % ("OK" if body_shape != null else "MISSING"))


func _check_egg_not_knocked() -> void:
	var egg := _level.get_node_or_null("Eggs/EggNet_0")
	if egg == null:
		# 单机 fallback 命名可能是 Egg_0
		egg = _level.get_node_or_null("Eggs/Egg_0")
	if egg == null:
		RESULTS.append("B) WARN: no egg found (Eggs/EggNet_0 or Egg_0)")
		return
	var egg_pos: Vector2 = (egg as Node2D).global_position
	var ch := _level.players[0]
	var offset: float = egg_pos.x - ch.global_position.x
	# 蛋应落在鸡下方附近；若被挤走会横向飞出（|dx| 远超下蛋偏移 ~8px）
	RESULTS.append("B) egg pos=%s chicken x=%s -> dx=%.1f (%s)" %
		[str(egg_pos), str(ch.global_position.x), offset,
		"OK 未被挤走" if absf(offset) < 40.0 else "FAIL 蛋被挤走"])


func _dump_results() -> void:
	print("=== diag_fixes results ===")
	for r in RESULTS:
		print("  ", r)
	print("=== end ===")
