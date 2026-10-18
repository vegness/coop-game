# StickyEgg.gd
# 粘蛋 - 碰到墙面/天花板粘住，可作为攀爬固定点
extends EggBase
class_name StickyEgg

@export var sticky_duration: float = 8.0

var is_stuck: bool = false

func _on_ready() -> void:
	super._on_ready()
	body_entered.connect(_on_sticky_body_entered)

func _on_sticky_body_entered(body: Node) -> void:
	if is_stuck or body is ChickenBase:
		return
	_stick_to_surface()

func _trigger_effect() -> void:
	_stick_to_surface()

func _stick_to_surface() -> void:
	if is_stuck:
		return
	is_stuck = true

	# 冻结物理，固定在当前位置
	freeze = true
	freeze_mode = RigidBody2D.FREEZE_MODE_STATIC

	# 视觉变化：颜色变深
	for child in get_children():
		if child is ColorRect:
			child.color = child.color.darkened(0.3)

	# 定时销毁
	var timer := get_tree().create_timer(sticky_duration)
	timer.timeout.connect(_destroy)

func _get_placeholder_color() -> Color:
	return Color.GREEN_YELLOW
