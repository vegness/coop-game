# HeavyEgg.gd
# 重蛋 - 质量极大，可压住压力板，可砸碎可破坏物
extends EggBase
class_name HeavyEgg

@export var crush_force: float = 2000.0

func _on_ready() -> void:
	super._on_ready()
	mass = 10.0
	gravity_scale = 2.0
	body_entered.connect(_on_heavy_body_entered)

func _on_heavy_body_entered(body: Node) -> void:
	# 砸碎可破坏物
	if body.has_method("destroy"):
		body.destroy()
	# 触发压力板
	if body.has_method("press"):
		body.press()

func _trigger_effect() -> void:
	# 重蛋主要是物理效果，已在碰撞中处理
	pass

func _get_placeholder_color() -> Color:
	return Color.DIM_GRAY
