# goal.gd
# 球门（蛋球赛进球检测）
# 布局：根 Node2D 含 Sprite2D 视觉 + 子 Area2D "Sensor" 矩形检测区
# 复用：左右球门由 tscn 的 Sprite2D.flip_h 镜像；接入计分由关卡在 _ready() 连 scored 信号
# 解耦：只发 scored(body) 信号，不直接操作计分系统
class_name Goal
extends Node2D

## 进球区 Area2D 路径（默认 ../Sensor）
@export var sensor_path: NodePath = ^"Sensor"
## 哪个 group 算作"进球"（默认 "egg"，蛋球赛时把所有 EggBase 加入 group "egg"）
@export var target_group: StringName = &"egg"

signal scored(body: Node)

var _sensor: Area2D = null


func _ready() -> void:
	_sensor = get_node_or_null(sensor_path) as Area2D
	if _sensor == null:
		push_warning("Goal: 缺少 Sensor 节点：" + str(sensor_path))
		return
	_sensor.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group(target_group):
		return
	scored.emit(body)
