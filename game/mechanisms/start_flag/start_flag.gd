# start_flag.gd
# 起点旗（竞速赛出发触发）
# 布局：根 Node2D 含 Sprite2D 视觉 + 子 Area2D "Sensor" 矩形检测
# 接入：关卡在 _ready() 把 race_started 连到关卡的 start_race(racer)；
#       若需"每个玩家只触发一次"由关卡侧用 HashSet/racer 字段去重
class_name StartFlag
extends Node2D

## 起点触发区 Area2D 路径
@export var sensor_path: NodePath = ^"Sensor"
## 哪个 group 算作"参赛者"（默认 "player"）
@export var target_group: StringName = &"player"

signal race_started(racer: Node)

var _sensor: Area2D = null


func _ready() -> void:
	_sensor = get_node_or_null(sensor_path) as Area2D
	if _sensor == null:
		push_warning("StartFlag: 缺少 Sensor 节点：" + str(sensor_path))
		return
	_sensor.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group(target_group):
		return
	race_started.emit(body)
