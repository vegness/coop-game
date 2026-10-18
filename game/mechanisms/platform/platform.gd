# platform.gd
# 静态悬浮平台（草顶石木台）
# 用途：通用关卡站踏位。extends AnimatableBody2D 让站上去的小鸡/蛋能托住。
# 解耦：无 multiplayer 原生调用、无 Trigger/关卡引用，作为"放上去就能用"的独立组件。
class_name Platform
extends AnimatableBody2D
