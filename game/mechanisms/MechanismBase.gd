# MechanismBase.gd
# 机关抽象基类
# 所有关卡机关（压力板、移动平台、风区、门等）的基类
extends Node2D
class_name MechanismBase

# ============================================================
# 机关状态枚举
# ============================================================
enum MechanismState {
	IDLE,       # 待机
	ACTIVATED,  # 激活中
	DEACTIVATED # 已停用
}

# ============================================================
# 基本属性
# ============================================================
@export var mechanism_id: String = ""
@export var is_one_shot: bool = false   # 是否只触发一次
@export var auto_reset_time: float = 0.0 # 自动重置时间（0=不自动重置）

var current_state: MechanismState = MechanismState.IDLE
var is_triggered: bool = false


# ============================================================
# 激活/停用接口
# ============================================================
func activate() -> void:
	if is_one_shot and is_triggered:
		return
	is_triggered = true
	current_state = MechanismState.ACTIVATED
	_on_activate()

	if auto_reset_time > 0:
		await get_tree().create_timer(auto_reset_time).timeout
		deactivate()


func deactivate() -> void:
	current_state = MechanismState.DEACTIVATED
	_on_deactivate()


func reset_mechanism() -> void:
	is_triggered = false
	current_state = MechanismState.IDLE
	_on_reset()


# ============================================================
# 虚方法（子类重写）
# ============================================================
func _on_activate() -> void:
	pass

func _on_deactivate() -> void:
	pass

func _on_reset() -> void:
	pass
