# diag_fixes2.gd
# 第二轮回归（headless）：
#   D) 风扇未触发时显示第一帧（animation="spin" frame=0 且可见）
#   E) 小鸡碰到刺会死亡（把鸡放到刺顶 → 应被 revive 移走，不能站在刺上）
#   F) 刺区（x>4000）下蛋蛋能显示/存活（不再被出界销毁）
# 用法：godot --headless --path game --quit-after 600 tools/diag_fixes2.tscn
extends Node2D

var RESULTS: Array[String] = []

var _level: LevelBase
var _frame: int = 0
var _phase: String = "init"
var _egg_marker: bool = false


func _ready() -> void:
	_level = (load("res://levels/02/level_02.tscn") as PackedScene).instantiate() as LevelBase
	add_child(_level)
	await get_tree().create_timer(0.25).timeout
	_check_fan_idle_frame()
	# 阶段1：刺区下蛋
	var ch := _level.players[0] if not _level.players.is_empty() else null
	if ch != null:
		ch.global_position = Vector2(4200, 600)
		if ch.has_method("_perform_egg_lay"):
			ch._perform_egg_lay()
		_phase = "egg"


func _physics_process(_delta: float) -> void:
	_frame += 1
	match _phase:
		"egg":
			if _frame >= 30:
				_check_egg_in_spike_zone()
				# 阶段2：小鸡放到刺顶
				var ch := _level.players[0]
				ch.global_position = Vector2(3900, 640)
				_phase = "spike"
				_frame = 0
		"spike":
			if _frame >= 60:
				_check_chicken_on_spike()
				_dump_results()
				get_tree().quit()


# D) 风扇未触发也显示第一帧
func _check_fan_idle_frame() -> void:
	var fan := _level.get_node_or_null("Fan")
	if fan == null:
		RESULTS.append("D) FAIL: Fan missing")
		return
	var sprite := fan.get_node_or_null("FanSprite") as AnimatedSprite2D
	if sprite == null:
		RESULTS.append("D) FAIL: FanSprite missing")
		return
	var sf := sprite.sprite_frames
	var has_frames: bool = sf != null and sf.get_frame_count("spin") >= 8
	var anim: String = sprite.animation
	var visible: bool = sprite.visible
	var is_active: bool = fan.is_active
	RESULTS.append("D) Fan idle: anim=%s frame=%d has_frames=%s visible=%s is_active=%s -> %s" %
		[anim, sprite.frame, has_frames, visible, is_active,
		"OK 显示第一帧" if (has_frames and anim == "spin" and not is_active and visible) else "FAIL"])


# F) 刺区下蛋蛋能显示（x>4000 不再被销毁）
func _check_egg_in_spike_zone() -> void:
	var egg := _level.get_node_or_null("Eggs/EggNet_0")
	if egg == null:
		egg = _level.get_node_or_null("Eggs/Egg_0")
	if egg == null:
		RESULTS.append("F) FAIL: 刺区下蛋 0.5s 后蛋不存在（可能被出界销毁）")
		return
	var pos: Vector2 = (egg as Node2D).global_position
	RESULTS.append("F) 刺区下蛋: egg pos=%s x>4000区域存活=%s -> %s" %
		[str(pos), str(pos.x > 4000.0),
		"OK 蛋存活并落在刺区" if pos.x > 4000.0 else "FAIL"])


# E) 小鸡碰到刺死亡（不能站在刺上）
func _check_chicken_on_spike() -> void:
	var ch := _level.players[0]
	# 玩家被放到刺顶 1s 后：要么 is_dead 瞬间、要么已被 revive 移走（位置不在刺区）
	var pos: Vector2 = ch.global_position
	var on_spike_zone: bool = pos.x > 3800.0 and pos.x < 4400.0 and pos.y < 720.0
	RESULTS.append("E) 放鸡到刺顶1s后: pos=%s 已离开刺区=%s -> %s" %
		[str(pos), str(not on_spike_zone),
		"OK 碰到刺已死并被移走" if not on_spike_zone else "FAIL 鸡仍站在刺上"])


func _dump_results() -> void:
	print("=== diag_fixes2 results ===")
	for r in RESULTS:
		print("  ", r)
	print("=== end ===")
