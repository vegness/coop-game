# MovingPlatform.gd
# 移动平台 - 在 point_a / point_b 两点间移动
# 两种用法：
#   1. 手动模式（默认，按钮联动）：move_forward()/move_backward()/stop() 由外部信号控制
#      · 按钮按下 → move_forward（向 point_b）；按钮松开 → move_backward（回 point_a）
#      · 到达端点后停在端点并发射 reached_end / reached_start，等待下一条指令（持续型）
#   2. 自动模式（auto_start=true）：_ready 即 move_forward，到达 B 后停下（可再由外部驱动反向）
# extends AnimatableBody2D：作为"移动的静态体"，玩家 CharacterBody2D 站上会跟随
class_name MovingPlatform
extends AnimatableBody2D

## 到达 point_b（终点）
signal reached_end
## 回到 point_a（起点）
signal reached_start

# ============================================================
# 属性
# ============================================================
## 起点/终点 Marker2D 路径（运行时解析；相对本节点，如 "../P1_A"）
@export var point_a_path: NodePath
@export var point_b_path: NodePath
@export var move_speed: float = 80.0
@export var auto_start: bool = false

var point_a: Marker2D = null
var point_b: Marker2D = null

enum PlatformState { STOPPED, MOVING_TO_B, MOVING_TO_A }
var state: PlatformState = PlatformState.STOPPED


func _ready() -> void:
	if point_a_path != NodePath():
		point_a = get_node_or_null(point_a_path) as Marker2D
	if point_b_path != NodePath():
		point_b = get_node_or_null(point_b_path) as Marker2D
	if auto_start:
		move_forward()


func _physics_process(delta: float) -> void:
	if point_a == null or point_b == null:
		return
	match state:
		PlatformState.MOVING_TO_B:
			_move_toward(point_b.global_position, delta, true)
		PlatformState.MOVING_TO_A:
			_move_toward(point_a.global_position, delta, false)

func _move_toward(target: Vector2, delta: float, is_forward: bool) -> void:
	var dir := target - global_position
	var dist := dir.length()
	if dist < 2.0:
		global_position = target
		state = PlatformState.STOPPED
		if is_forward:
			reached_end.emit()
		else:
			reached_start.emit()
		return
	dir = dir.normalized()
	var move_amount := minf(move_speed * delta, dist)
	global_position += dir * move_amount


# ============================================================
# 控制接口（按钮/信号联动）
# ============================================================
## 向 point_b（终点）移动
func move_forward() -> void:
	state = PlatformState.MOVING_TO_B


## 向 point_a（起点）移动
func move_backward() -> void:
	state = PlatformState.MOVING_TO_A


## 停止
func stop() -> void:
	state = PlatformState.STOPPED


## 直接设置进度（0 = point_a，1 = point_b）
func set_progress(p: float) -> void:
	p = clampf(p, 0.0, 1.0)
	global_position = point_a.global_position.lerp(point_b.global_position, p)
	state = PlatformState.STOPPED


# MechanismBase 兼容接口（trigger 的 linked_mechanisms / 关卡信号调用）
func activate() -> void:
	move_forward()


func deactivate() -> void:
	move_backward()
