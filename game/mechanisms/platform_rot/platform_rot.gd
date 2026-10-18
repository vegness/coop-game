# platform_rot.gd
# 旋转平台：绕自身轴心持续匀速旋转
# 用途：挤出局/通用关卡，逼迫玩家在摇摆位之间跳切
# 解耦：仅旋转自身 transform，不影响联机同步（由 spawner 同步 rotation）
class_name RotatingPlatform
extends AnimatableBody2D

## 旋转角速度（弧度/秒）。正=逆时针
@export var angular_speed: float = 1.5


func _physics_process(delta: float) -> void:
	rotation += angular_speed * delta
