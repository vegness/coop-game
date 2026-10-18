# ConveyorBelt.gd
# 传送带 - 覆盖接触物体的水平速度（不施加力，直接改写速度分量）
# 影响：player 组（CharacterBody2D 鸡）/ egg 组（RigidBody2D 蛋）
# 特性：
#   - 只改水平速度：body.velocity.x = direction.x * force（垂直速度完全不受影响）
#   - 鸡跳跃脱离传送带检测范围后不再受影响 → 可逆流（配合下蛋反冲）
#   - 蛋被推走（10 秒寿命 + 传送带推力 → 蛋梯会"融化"，需要接力补蛋）
# 复用：丢进关卡即可，@export 配 direction/force；不引用关卡类/网络后端（解耦）
class_name ConveyorBelt
extends Area2D

## 传送方向（本关向左 = Vector2(-1, 0)）
@export var direction: Vector2 = Vector2(-1, 0)
## 传送速度（覆盖物体水平速度）
@export var force: float = 120.0
## 是否只影响"接触地面/在区域内"的物体（默认 true：跳跃脱离检测区即不受影响）
@export var affect_only_in_area: bool = true

# 碰撞层（鸡=2，蛋=4）
const LAYER_PLAYER: int = 2
const LAYER_EGG: int = 4


func _ready() -> void:
	collision_layer = 0
	collision_mask = LAYER_PLAYER | LAYER_EGG


func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		_apply_conveyor(body)


# 覆盖水平速度分量（垂直速度不动）
func _apply_conveyor(body: Node) -> void:
	if body is ChickenBase:
		var chicken := body as ChickenBase
		chicken.velocity.x = direction.x * force
	elif body is EggBase:
		var egg := body as EggBase
		# RigidBody2D 用 linear_velocity（不锁旋转则滚动自然被推）
		egg.linear_velocity.x = direction.x * force
