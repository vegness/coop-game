# movingfloor.gd
# 移动地板（条件桥）：累计满足 N 个条件（如 4 个按钮全部按下）→ 向左移动到 target_position
# 停止；条件不满足 → 向右移动回到 home_position（原位）。
# 特性：
#   - 解耦：本脚本不引用 Trigger/关卡类/网络后端；外部只调用 condition_met(met: bool)。
#     关卡在 _setup_level 里把每个按钮的 pressed/released 信号连到 condition_met(true/false)，
#     满足"当且仅当全部按钮被按下"的 AND 语义（内部用计数器，重复连接多个按钮也安全）。
#   - extends AnimatableBody2D：作为"移动的静态体"，站上去会跟随移动。
#   - 到达端点后停止，并发出 reached_target / reached_home 信号（供音效/特效等扩展）。
# 复用：丢进关卡即可，@export 配 home_position / target_position / required_conditions / move_speed。
class_name MovingFloor
extends AnimatableBody2D

## 到达 target_position（全部条件满足后停下的位置）
signal reached_target
## 回到 home_position（原位）
signal reached_home

# ============================================================
# 属性
# ============================================================
## 原位（未满足条件时的停留位置；默认取节点初始位置）
@export var home_position: Vector2 = Vector2(2200, 475)
## 目标位置（全部条件满足后移动到这里并停止）
@export var target_position: Vector2 = Vector2(1280, 475)
## 需要同时满足的条件数（= 需要按下的按钮数）
@export var required_conditions: int = 4
## 移动速度（px/s）
@export var move_speed: float = 150.0
## 是否允许"条件不足时立刻回位"（true=松开即回，false=停在原地等条件再满）
@export var return_when_unsatisfied: bool = true

# ============================================================
# 运行时状态
# ============================================================
var _satisfied_count: int = 0
var _moving_to_target: bool = false


func _ready() -> void:
	# 默认原位 = 场景里摆放的位置（编辑器所见即初始）
	if home_position == Vector2(2200, 475):
		home_position = global_position
	# 条件未满足时直接站在原位
	position = home_position


func _physics_process(delta: float) -> void:
	if required_conditions <= 0:
		return
	if _moving_to_target:
		_move_toward(target_position, delta)
	else:
		_move_toward(home_position, delta)


# ============================================================
# 对外接口（解耦：由关卡把按钮信号接进来）
# ============================================================
## 记录一个条件是否满足（按钮按下→true，松开→false）。
## 满足的条件数 >= required_conditions 时向 target 移动，否则（若开启回位）向 home 移动。
func condition_met(met: bool) -> void:
	_satisfied_count = maxi(0, _satisfied_count + (1 if met else -1))
	_update_goal()


func _update_goal() -> void:
	var satisfied: bool = _satisfied_count >= required_conditions
	if satisfied:
		_moving_to_target = true
	elif return_when_unsatisfied:
		_moving_to_target = false


# ============================================================
# 移动
# ============================================================
func _move_toward(target: Vector2, delta: float) -> void:
	var dir := target - position
	var dist := dir.length()
	if dist < 1.5:
		position = target
		if _moving_to_target:
			_moving_to_target = false
			reached_target.emit()
		else:
			reached_home.emit()
		return
	dir = dir.normalized()
	position += dir * minf(move_speed * delta, dist)


# ============================================================
# MechanismBase 兼容接口（触发机关 linked_mechanisms / 关卡信号调用）
# ============================================================
## 视为"条件全部满足"：立即向 target 移动
func activate() -> void:
	_moving_to_target = true


## 视为"条件全部不满足"：若开启回位则回到 home
func deactivate() -> void:
	if return_when_unsatisfied:
		_moving_to_target = false
