# diag_fixes4.gd
# 回归验证（headless）：刺上死亡后复活回"最近的安全地面落脚点"，而不是刺区/原地。
# 场景复现用户 bug：玩家踩蛋过刺河（蛋在刺上方），_on_landed 把蛋上位置记成落脚点，
# 蛋碎后死亡复活到刺区 → 立刻再死 → 看起来"位置不变"。
# 修复后：只有"站普通地面(World) 且脚底不在 Hazard"才记录落脚点。
# 用法：godot --headless --path game --quit-after 800 tools/diag_fixes4.tscn
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
		# 1) 落到中地（安全地面）记录落脚点
		ch.global_position = Vector2(2600, 480)
		_phase = "land"


func _physics_process(_delta: float) -> void:
	_frame += 1
	match _phase:
		"land":
			if _frame >= 70:
				var ch := _level.players[0]
				RESULTS.append("落到中地: last_landed_position=%s (期望≈2600,632)" % str(ch.last_landed_position))
				# 2) 传送到刺顶死亡（中地 2600 → 刺区 3900）
				ch.global_position = Vector2(3900, 640)
				_phase = "die"
				_frame = 0
		"die":
			if _frame >= 90:
				var ch := _level.players[0]
				var pos: Vector2 = ch.global_position
				var in_spike: bool = pos.x > 3715.0 and pos.x < 4600.0 and pos.y > 640.0
				RESULTS.append("刺上死亡后复活位置=%s (刺区=%s)" % [str(pos), in_spike])
				var ok: bool = (not in_spike) and pos.distance_to(Vector2(2600, 632)) < 80.0
				RESULTS.append("复活回最近安全落脚点=%s" % ("OK" if ok else "FAIL"))
				_dump_results()
				get_tree().quit()


func _dump_results() -> void:
	print("=== diag_fixes4 results ===")
	for r in RESULTS:
		print("  ", r)
	print("=== end ===")
