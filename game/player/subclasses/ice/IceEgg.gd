# IceEgg.gd
# 冰蛋 - 碰到地面冻结成冰面平台，摩擦力极低，玩家在上面移动失控
extends EggBase
class_name IceEgg

@export var ice_platform_duration: float = 5.0

var ice_platform: StaticBody2D = null

func _on_ready() -> void:
	super._on_ready()
	body_entered.connect(_on_ice_body_entered)

func _on_ice_body_entered(body: Node) -> void:
	if body is ChickenBase:
		return
	_freeze_to_platform()

func _trigger_effect() -> void:
	_freeze_to_platform()

func _freeze_to_platform() -> void:
	# 在当前位置创建冰面平台
	ice_platform = StaticBody2D.new()
	ice_platform.global_position = global_position + Vector2(0, 8)
	ice_platform.collision_layer = 1  # World layer

	# 平台碰撞体
	var collision := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(48, 8)
	collision.shape = rect
	ice_platform.add_child(collision)

	# 平台视觉（占位蓝色矩形）
	var color_rect := ColorRect.new()
	color_rect.size = Vector2(48, 8)
	color_rect.color = Color.LIGHT_BLUE
	color_rect.position = Vector2(-24, -4)
	ice_platform.add_child(color_rect)

	get_parent().add_child(ice_platform)

	# 定时销毁
	var timer := get_tree().create_timer(ice_platform_duration)
	timer.timeout.connect(func():
		if ice_platform:
			ice_platform.queue_free()
	)

	_destroy()

func _get_placeholder_color() -> Color:
	return Color.LIGHT_BLUE
