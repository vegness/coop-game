# diag_level2.gd
# 诊断工具：加载第二关，按时间把小鸡依次传送到关键位置，配合
#   godot --path game --write-movie tools/diag_l2.png --quit-after N tools/diag_level2.tscn
# 逐帧截图检查机关摆放/背景/碰撞。
# 注意：仅用于开发验证，不属于游戏内容。
extends Node2D

# 关键检查点（世界坐标）：左地按钮区 / 移动地板 / 风扇 / 柱顶 / 刺坑 / 右地传送门
const CHECKPOINTS: Array[Vector2] = [
	Vector2(850, 632),   # 左地四按钮
	Vector2(1280, 430),  # 移动地板目标位(上方俯视)
	Vector2(2200, 430),  # 移动地板原位(上方俯视)
	Vector2(2620, 632),  # 风扇
	Vector2(2900, 240),  # 柱顶两按钮
	Vector2(2100, 200),  # 门
	Vector2(4150, 690),  # 刺坑
	Vector2(4720, 632),  # 右地传送门
]

const FRAMES_PER_STOP: int = 60

var _level: LevelBase
var _idx: int = 0
var _frame: int = 0


func _ready() -> void:
	_level = (load("res://levels/02/level_02.tscn") as PackedScene).instantiate() as LevelBase
	add_child(_level)


func _physics_process(_delta: float) -> void:
	_frame += 1
	# 到达一个停留点时，把小鸡传送到下一个检查点
	if _frame % FRAMES_PER_STOP == 0 and _idx < CHECKPOINTS.size():
		for ch in _level.players:
			ch.global_position = CHECKPOINTS[_idx]
		_idx += 1
