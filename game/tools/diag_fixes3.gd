# diag_fixes3.gd
# 回归验证（headless）：死亡复活回到上一次落脚点（last_landed_position），而非起点。
# 流程：玩家先落到左地按钮区 (900, 632) 记录落脚点 → 传送到刺顶 (3900, 640) 死亡
#   → 复活位置应 ≈ (900, 632)，而不是 spawn (200, 632)。
# 用法：godot --headless --path game --quit-after 600 tools/diag_fixes3.tscn
extends Node2D

var RESULTS: Array[String] = []

var _level: LevelBase
var _frame: int = 0
var _phase: String = "land"


func _ready() -> void:
	_level = (load("res://levels/02/level_02.tscn") as PackedScene).instantiate() as LevelBase
	add_child(_level)
	await get_tree().create_timer(0.25).timeout
	var ch := _level.players[0] if not _level.players.is_empty() else null
	if ch != null:
		# 1) 先落到左地按钮区（非起点位置）：从空中 (900, 480) 落下 → 落地记录落脚点 (900, 632)
		ch.global_position = Vector2(900, 480)
		_phase = "land"


func _physics_process(_delta: float) -> void:
	_frame += 1
	match _phase:
		"land":
			if _frame >= 70:  # ~1.2s：从 y=480 落 176px 需 ~0.6s + 落地余量
				var ch := _level.players[0]
				var landed: Vector2 = ch.last_landed_position
				RESULTS.append("落地后 last_landed_position=%s (期望≈900,632)" % str(landed))
				# 2) 传送到刺顶死亡
				ch.global_position = Vector2(3900, 640)
				_phase = "die"
				_frame = 0
		"die":
			if _frame >= 90:  # 1.5s 应已完成"碰刺→死→复活"
				var ch := _level.players[0]
				var pos: Vector2 = ch.global_position
				RESULTS.append("死亡1.5s后复活位置=%s (起点spawn=200,632)" % str(pos))
				var ok: bool = pos.distance_to(Vector2(900, 632)) < 60.0
				RESULTS.append("回到上次落脚点=%s" % ("OK" if ok else "FAIL"))
				_dump_results()
				get_tree().quit()


func _dump_results() -> void:
	print("=== diag_fixes3 results ===")
	for r in RESULTS:
		print("  ", r)
	print("=== end ===")
