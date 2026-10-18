# CollectibleBase.gd
# 收集物抽象基类
# 金蛋、羽毛等可收集物品的基类
extends Area2D
class_name CollectibleBase

# ============================================================
# 属性
# ============================================================
@export var collectible_name: String = ""
@export var collectible_value: int = 1
@export var collect_color: Color = Color.GOLD
@export var float_animation: bool = true

var is_collected: bool = false


# ============================================================
# 生命周期
# ============================================================
func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # Player layer
	body_entered.connect(_on_body_entered)
	_setup_visual()
	_on_ready()

	if float_animation:
		_start_float_animation()


func _on_body_entered(body: Node2D) -> void:
	if is_collected:
		return
	if body is ChickenBase:
		_collect(body as ChickenBase)


# ============================================================
# 收集逻辑
# ============================================================
func _collect(chicken: ChickenBase) -> void:
	is_collected = true

	# 收集动画（占位：缩小消失）
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.2)
	tween.tween_property(self, "position:y", position.y - 20, 0.2)
	tween.tween_callback(queue_free)

	_on_collected(chicken)


# ============================================================
# 浮动动画
# ============================================================
func _start_float_animation() -> void:
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(self, "position:y", position.y - 5, 0.8).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position:y", position.y + 5, 0.8).set_ease(Tween.EASE_IN_OUT)


# ============================================================
# 占位视觉
# ============================================================
func _setup_visual() -> void:
	var color_rect := ColorRect.new()
	color_rect.size = Vector2(16, 16)
	color_rect.color = collect_color
	color_rect.position = Vector2(-8, -8)
	add_child(color_rect)

	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10
	collision.shape = circle
	add_child(collision)


# ============================================================
# 虚方法
# ============================================================
func _on_ready() -> void:
	pass

func _on_collected(_chicken: ChickenBase) -> void:
	pass
