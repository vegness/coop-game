# pit.gd
# 断坑（竞速赛坑位，触发即复活或回起点）
# 布局：根 Node2D 含 Sprite2D 视觉（两侧石沿 + 中央深渊）+ 子 Area2D "Sensor" 矩形检测
# 接入：关卡在 _ready() 把 body_fell 连到关卡的 respawn_player(body)
class_name Pit
extends Node2D

## 坑位检测区 Area2D 路径
@export var sensor_path: NodePath = ^"Sensor"
## 哪个 group 算作"会掉坑"（默认 "player"）
@export var target_group: StringName = &"player"

signal body_fell(body: Node)

var _sensor: Area2D = null


func _ready() -> void:
	_sensor = get_node_or_null(sensor_path) as Area2D
	if _sensor == null:
		push_warning("Pit: 缺少 Sensor 节点：" + str(sensor_path))
		return
	_sensor.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group(target_group):
		return
	body_fell.emit(body)
