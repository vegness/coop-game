# ExplodableWall.gd
# 可破坏墙体 - 被炸弹蛋/重蛋攻击时销毁
extends StaticBody2D
class_name ExplodableWall

# ============================================================
# 属性
# ============================================================
@export var wall_color: Color = Color.GRAY

@onready var color_rect: ColorRect = $ColorRect
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


# ============================================================
# 生命周期
# ============================================================
func _ready() -> void:
	collision_layer = 1  # World layer
	collision_mask = 0


# ============================================================
# 销毁
# ============================================================
func destroy() -> void:
	# 碎片效果（占位：颜色变暗后消失）
	var tween := create_tween()
	tween.tween_property(color_rect, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)
	collision_shape.disabled = true


# ============================================================
# 占位视觉
# ============================================================
func _setup_visual() -> void:
	if not color_rect:
		return
	color_rect.size = Vector2(32, 32)
	color_rect.color = wall_color
	color_rect.position = Vector2(-16, -32)

	# 裂缝纹理（简易占位线）
	var crack := ColorRect.new()
	crack.size = Vector2(2, 20)
	crack.color = Color.BLACK
	crack.position = Vector2(0, -28)
	crack.rotation = 0.3
	add_child(crack)
